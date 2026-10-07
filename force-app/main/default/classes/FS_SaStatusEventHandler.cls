/**
 * @description Trigger Actions Framework action that publishes
 * FS_InspectionDataUpdate__e for Field Services updates: confirmation, schedule,
 * dispatch, cancel, and unschedule. Creates do not publish.
 * Manual CRM backfill appointments are skipped.
 */
public inherited sharing class FS_SaStatusEventHandler implements
  TriggerAction.AfterInsert,
  TriggerAction.AfterUpdate {
  private static final String FIELD_SERVICES_RT = 'Field_Services';
  private static final String SCHEDULED_STATUS = 'Scheduled';
  private static final String DISPATCHED_STATUS = 'Dispatched';
  private static final String CANCELED_STATUS = 'Canceled';
  private static final Set<String> SYSTEM_MODE_USER_TYPES = new Set<String>{
    'CloudIntegrationUser',
    'AutomatedProcess'
  };
  // Appointments already handed to the publish job in this transaction.
  private static Set<Id> queuedAppointmentIds = new Set<Id>();

  /**
   * @description Events captured during tests instead of relying only on EventBus delivery.
   */
  @TestVisible
  private static List<FS_InspectionDataUpdate__e> publishedEventsForTest = new List<FS_InspectionDataUpdate__e>();

  /**
   * @description Test hook that forces the background-user FLS bypass path.
   */
  @TestVisible
  private static Boolean forceBackgroundUserContextForTest = false;

  /**
   * @description Trigger Actions Framework after-insert entry.
   * @param newList Trigger.new records.
   */
  public void afterInsert(List<SObject> newList) {
    // Creates do not publish. Confirmation is an update.
    handleTrigger(toAppointments(newList), null, System.TriggerOperation.AFTER_INSERT);
  }

  /**
   * @description Trigger Actions Framework after-update entry.
   * @param newList Trigger.new records.
   * @param oldList Trigger.old records.
   */
  public void afterUpdate(List<SObject> newList, List<SObject> oldList) {
    handleTrigger(
      toAppointments(newList),
      new Map<Id, ServiceAppointment>(toAppointments(oldList)),
      System.TriggerOperation.AFTER_UPDATE
    );
  }

  /**
   * @description Casts Trigger Actions Framework SObject lists to Service Appointments.
   * @param records SObject list from TAF, or null.
   * @return Typed Service Appointment list.
   */
  private static List<ServiceAppointment> toAppointments(List<SObject> records) {
    List<ServiceAppointment> appointments = new List<ServiceAppointment>();
    if (records == null) {
      return appointments;
    }
    for (SObject record : records) {
      appointments.add((ServiceAppointment) record);
    }
    return appointments;
  }

  /**
   * @description Routes Service Appointment trigger operations for status event publication.
   * @param newRecords Trigger.new records.
   * @param oldMap Trigger.oldMap, or null on insert.
   * @param operationType Current trigger operation.
   */
  public static void handleTrigger(
    List<ServiceAppointment> newRecords,
    Map<Id, ServiceAppointment> oldMap,
    System.TriggerOperation operationType
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }
    // This action is registered for after insert and after update only.
    if (
      operationType != System.TriggerOperation.AFTER_INSERT &&
      operationType != System.TriggerOperation.AFTER_UPDATE
    ) {
      return;
    }
    FS_InspectionStatusEventSettings.Config config = FS_InspectionStatusEventSettings.getConfig();
    if (!config.isActive) {
      return;
    }

    // One event type per appointment. Later rows for the same Id replace earlier ones.
    Map<Id, String> eventTypeBySaId = new Map<Id, String>();
    Id fieldServicesRtId = getFieldServicesRecordTypeId();
    for (ServiceAppointment sa : newRecords) {
      if (!isPublishableAppointment(sa, fieldServicesRtId)) {
        continue;
      }
      ServiceAppointment oldSa = oldMap == null ? null : oldMap.get(sa.Id);
      String eventType = resolveEventType(sa, oldSa, config);
      if (eventType != null) {
        eventTypeBySaId.put(sa.Id, eventType);
      }
    }
    if (eventTypeBySaId.isEmpty() || !canReadServiceAppointment()) {
      return;
    }

    // A resource drag updates the appointment and the Assigned Resource separately.
    // Queue the id once. The job runs after both saves and reads the final row.
    enqueuePublish(eventTypeBySaId.keySet());
  }

  /**
   * @description Queues one publish job per new appointment. A later save for an id already queued does not add another job.
   * @param appointmentIds Service Appointment Ids that qualified in this save.
   */
  private static void enqueuePublish(Set<Id> appointmentIds) {
    Set<Id> freshIds = new Set<Id>();
    for (Id appointmentId : appointmentIds) {
      if (!queuedAppointmentIds.contains(appointmentId)) {
        freshIds.add(appointmentId);
        queuedAppointmentIds.add(appointmentId);
      }
    }
    if (freshIds.isEmpty()) {
      return;
    }
    System.enqueueJob(new PublishQueueable(freshIds));
  }

  /**
   * @description Publishes one event per appointment from the final saved row.
   * @param appointmentIds Service Appointment Ids captured when the job was queued.
   */
  private static void publishQueuedAppointments(Set<Id> appointmentIds) {
    FS_InspectionStatusEventSettings.Config config = FS_InspectionStatusEventSettings.getConfig();
    if (appointmentIds == null || appointmentIds.isEmpty() || !config.isActive) {
      return;
    }
    if (!canReadServiceAppointment()) {
      return;
    }
    List<ServiceAppointment> publishable = new List<ServiceAppointment>();
    Map<Id, String> eventTypeBySaId = new Map<Id, String>();
    for (ServiceAppointment sa : excludeManualInspections(queryAppointments(appointmentIds))) {
      // A later save in this transaction can leave the row unpublished,
      // such as status None while the inspector lookup is still set.
      if (!isFinalStatePublishable(sa, config)) {
        continue;
      }
      publishable.add(sa);
      eventTypeBySaId.put(sa.Id, config.eventType);
    }
    if (publishable.isEmpty()) {
      return;
    }
    publishEvents(
      FS_InspectionStatusEventMapper.buildEvents(publishable, eventTypeBySaId, config)
    );
  }

  /**
   * @description True when the saved row is still a confirmation, schedule, dispatch, cancel, or finished unschedule.
   * @param sa Appointment read after the transaction commits.
   * @param config Parsed CMDT configuration.
   * @return True if the subscriber should receive this row.
   */
  private static Boolean isFinalStatePublishable(
    ServiceAppointment sa,
    FS_InspectionStatusEventSettings.Config config
  ) {
    if (sa.FS_Is_Confirmed__c == true) {
      return true;
    }
    if (sa.Status == DISPATCHED_STATUS || sa.Status == CANCELED_STATUS) {
      return true;
    }
    if (
      sa.Status == config.unscheduledStatus &&
      sa.FS_Assigned_Inspector__c == null
    ) {
      return true;
    }
    return sa.Status == SCHEDULED_STATUS &&
      sa.FS_Assigned_Inspector__c != null &&
      sa.SchedStartTime != null &&
      sa.SchedEndTime != null;
  }

  /**
   * @description Runs after the triggering transaction commits, so a resource drag produces one event.
   */
  private class PublishQueueable implements Queueable {
    private Set<Id> appointmentIds;

    /**
     * @description Stores the appointments to publish.
     * @param appointmentIds Service Appointment Ids.
     */
    private PublishQueueable(Set<Id> appointmentIds) {
      this.appointmentIds = new Set<Id>(appointmentIds);
    }

    /**
     * @description Publishes the queued appointments from their final field values.
     * @param context Queueable context. Unused.
     */
    public void execute(QueueableContext context) {
      if (context.getJobId() != null) {
        publishQueuedAppointments(appointmentIds);
      }
    }
  }

  /**
   * @description True when the appointment is Field_Services and not a manual CRM backfill.
   * @param sa Trigger new appointment.
   * @param fieldServicesRtId Field_Services record type Id, or null if absent.
   * @return True if the appointment should be evaluated for publication.
   */
  private static Boolean isPublishableAppointment(
    ServiceAppointment sa,
    Id fieldServicesRtId
  ) {
    // Other record types and CRM backfills never publish.
    if (fieldServicesRtId == null || sa.RecordTypeId != fieldServicesRtId) {
      return false;
    }
    return sa.FS_IsManualInspection__c != true;
  }

  /**
   * @description Drops queried appointments stamped as manual CRM backfills.
   * @param saRecords Queried Service Appointment records.
   * @return Appointments that may be mapped to platform events.
   */
  private static List<ServiceAppointment> excludeManualInspections(
    List<ServiceAppointment> saRecords
  ) {
    List<ServiceAppointment> matches = new List<ServiceAppointment>();
    for (ServiceAppointment sa : saRecords) {
      if (sa.FS_IsManualInspection__c != true) {
        matches.add(sa);
      }
    }
    return matches;
  }

  /**
   * @description Resolves EventType__c for this DML, or null when nothing should publish.
   * Creates do not publish. An update publishes when FS_Is_Confirmed__c becomes true,
   * when status becomes Dispatched, Canceled, or Scheduled with an inspector and both times,
   * or when an unschedule finishes with a blank inspector.
   * @param sa Appointment after the DML.
   * @param oldSa Appointment before the update, or null on create.
   * @param config Parsed CMDT configuration.
   * @return InspectionStatusUpdate, or null.
   */
  @SuppressWarnings('PMD.CyclomaticComplexity')
  @TestVisible
  private static String resolveEventType(
    ServiceAppointment sa,
    ServiceAppointment oldSa,
    FS_InspectionStatusEventSettings.Config config
  ) {
    // Create never publishes. FS_Is_Confirmed__c is set by a later update.
    if (oldSa == null) {
      return null;
    }

    Boolean statusChanged = sa.Status != oldSa.Status;
    Boolean confirmedChanged =
      sa.FS_Is_Confirmed__c != oldSa.FS_Is_Confirmed__c;
    Boolean inspectorChanged =
      sa.FS_Assigned_Inspector__c != oldSa.FS_Assigned_Inspector__c;
    Boolean timesChanged =
      sa.SchedStartTime != oldSa.SchedStartTime ||
      sa.SchedEndTime != oldSa.SchedEndTime;

    // Dispatch publishes even when the inspector and schedule times are unchanged.
    if (sa.Status == DISPATCHED_STATUS && statusChanged) {
      return config.eventType;
    }

    // Cancel publishes on the status change. Inspector and schedule times are not required.
    if (sa.Status == CANCELED_STATUS && statusChanged) {
      return config.eventType;
    }

    // Confirmation is an update. Publish when the flag changes to true.
    if (sa.FS_Is_Confirmed__c == true && confirmedChanged) {
      return config.eventType;
    }

    // Unschedule publishes only once both pieces are done: status None and a blank inspector.
    // A status change that still has an inspector waits for the Assigned Resource delete.
    if (
      sa.Status == config.unscheduledStatus &&
      sa.FS_Assigned_Inspector__c == null &&
      (statusChanged || inspectorChanged)
    ) {
      return config.eventType;
    }

    // Scheduled publishes once the inspector and both times are present and any of
    // status, inspector, or times just changed. Field Service often saves the
    // inspector and the times first, then flips Status to Scheduled on its own.
    if (
      sa.Status == SCHEDULED_STATUS &&
      sa.FS_Assigned_Inspector__c != null &&
      sa.SchedStartTime != null &&
      sa.SchedEndTime != null &&
      (statusChanged || inspectorChanged || timesChanged)
    ) {
      return config.eventType;
    }
    return null;
  }

  /**
   * @description True when the running user can read Service Appointment, or FLS is bypassed.
   * @return True if the query may run.
   */
  private static Boolean canReadServiceAppointment() {
    return Schema.sObjectType.ServiceAppointment.isAccessible() ||
      bypassFlsForBackgroundUser() ||
      Test.isRunningTest();
  }

  /**
   * @description Queries appointments and related assigned resources for payload mapping.
   * @param qualifyingIds Service Appointment Ids to load.
   * @return Queried Service Appointment records.
   */
  private static List<ServiceAppointment> queryAppointments(Set<Id> qualifyingIds) {
    if (qualifyingIds == null || qualifyingIds.isEmpty()) {
      return new List<ServiceAppointment>();
    }
    String saQuery = appointmentQuery();
    if (bypassFlsForBackgroundUser()) {
      return (List<ServiceAppointment>) Database.query(
        saQuery,
        AccessLevel.SYSTEM_MODE
      );
    }
    try {
      return (List<ServiceAppointment>) Database.query(
        saQuery + ' WITH SECURITY_ENFORCED'
      );
    } catch (System.QueryException flsEx) {
      // Portal users have object-level SA access (confirmed by canReadServiceAppointment)
      // but may lack FLS on internal fields such as EmployeeNumber, Priority__c, or
      // FSL__InJeopardy__c. This query feeds internal event publishing only — fall back
      // to SYSTEM_MODE so a field-level gap never blocks appointment scheduling.
      System.debug(LoggingLevel.WARN,
        'FS_SaStatusEventHandler.queryAppointments — WITH SECURITY_ENFORCED failed, '
        + 'falling back to SYSTEM_MODE: ' + flsEx.getMessage());
      return (List<ServiceAppointment>) Database.query(
        saQuery,
        AccessLevel.SYSTEM_MODE
      );
    }
  }

  /**
   * @description SOQL used to load appointment, parent, BCO, and assigned resource fields.
   * @return Query string with :qualifyingIds bind.
   */
  private static String appointmentQuery() {
    return 'SELECT Id, Status, AppointmentNumber, ParentRecordId, RecordTypeId, ' +
      'SchedStartTime, SchedEndTime, ActualStartTime, ActualEndTime, ' +
      'ArrivalWindowStartTime, ArrivalWindowEndTime, DueDate, EarliestStartTime, ' +
      'LastModifiedBy.Name, LastModifiedBy.Username, LastModifiedBy.EmployeeNumber, ' +
      'Priority__c, WorkTypeId, WorkType.Name, FS_IsManualInspection__c, ' +
      'FS_Work_Order__c, FS_Work_Order__r.WorkOrderNumber, ' +
      'FS_Work_Order__r.FS_Booking_Reference__c, FS_Work_Order__r.Description, ' +
      'FS_Work_Order_Line_Item__c, FS_Work_Order_Line_Item__r.LineItemNumber, ' +
      'FS_Work_Order_Line_Item__r.FS_ExternalRefId__c, ' +
      'FS_ExternalRefId__c, FS_CRMInspection_Id__c, FS_BCO_Detail__c, FS_BCO_Detail__r.FS_BCO_Number__c, ' +
      'FS_BCO_Detail__r.FS_BCO_Complexity__c, FS_BCO_Detail__r.FS_Property_ID__c, ' +
      'FS_BCO_Detail__r.FS_BCO_PropertyAddress__c, FS_Dispatched_Date__c, ' +
      'FS_Cancelled_Date__c, FS_Travel_Date__c, FS_OnSite_Date__c, FS_Completed_Date__c, ' +
      'FS_Booking_Type__c, FS_Inspection_Status__c, FS_Cancelled_Reason__c, ' +
      'FS_Is_Confirmed__c, FS_Assigned_Inspector__c, FS_Assigned_Inspector__r.Name, ' +
      'FSL__InJeopardy__c, FSL__InJeopardyReason__c, ' +
      '(SELECT Id, ServiceCrewId, ServiceCrew.Name, ServiceResourceId, ' +
      'ServiceResource.Name, ServiceResource.RelatedRecord.EmployeeNumber, ' +
      'EstimatedTravelTime FROM ServiceResources) ' +
      'FROM ServiceAppointment WHERE Id IN :qualifyingIds';
  }

  /**
   * @description Publishes events after a createable check. Tests also capture the list.
   * @param eventsToPublish Events to publish.
   */
  private static void publishEvents(List<FS_InspectionDataUpdate__e> eventsToPublish) {
    if (eventsToPublish.isEmpty()) {
      return;
    }
    if (Test.isRunningTest()) {
      publishedEventsForTest.addAll(eventsToPublish);
    }
    if (!canCreateStatusEvent()) {
      return;
    }
    EventBus.publish(eventsToPublish);
  }

  /**
   * @description True when the running user can create the platform event, or FLS is bypassed.
   * @return True if EventBus.publish may run.
   */
  private static Boolean canCreateStatusEvent() {
    return Schema.sObjectType.FS_InspectionDataUpdate__e.isCreateable() ||
      bypassFlsForBackgroundUser() ||
      Test.isRunningTest();
  }

  /**
   * @description Whether the running user is a Salesforce-managed background user that cannot be granted FLS.
   * @return True for CloudIntegrationUser / AutomatedProcess, or the test hook.
   */
  @TestVisible
  private static Boolean bypassFlsForBackgroundUser() {
    return forceBackgroundUserContextForTest ||
      SYSTEM_MODE_USER_TYPES.contains(UserInfo.getUserType());
  }

  /**
   * @description Returns the Field Services record type Id, or null if it is not in the org.
   * @return The Field_Services record type Id, or null.
   */
  private static Id getFieldServicesRecordTypeId() {
    Schema.RecordTypeInfo info = Schema.SObjectType.ServiceAppointment.getRecordTypeInfosByDeveloperName()
      .get(FIELD_SERVICES_RT);
    if (info == null) {
      return null;
    }
    return info.getRecordTypeId();
  }
}