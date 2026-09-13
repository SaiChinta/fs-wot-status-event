/**
 * @description Trigger Actions Framework after-update action that publishes
 * FS_InspectionDataUpdate__e when a Field Services Service Appointment status
 * or scheduled start/end time changes. Manual CRM backfill appointments are skipped.
 */
public inherited sharing class FS_SaStatusEventHandler implements TriggerAction.AfterUpdate {
  private static final String FIELD_SERVICES_RT = 'Field_Services';
  private static final Set<String> SYSTEM_MODE_USER_TYPES = new Set<String>{
    'CloudIntegrationUser',
    'AutomatedProcess'
  };

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
   * @description Trigger Actions Framework after-update entry. Mirrors org BCO handler pattern.
   * @param newList Trigger.new records.
   * @param oldList Trigger.old records.
   */
  public void afterUpdate(List<SObject> newList, List<SObject> oldList) {
    List<ServiceAppointment> newRecords = filterPublishableAppointments(
      toAppointments(newList)
    );
    if (newRecords.isEmpty()) {
      return;
    }
    Map<Id, ServiceAppointment> oldMap = new Map<Id, ServiceAppointment>(
      toAppointments(oldList)
    );
    handleTrigger(newRecords, oldMap, System.TriggerOperation.AFTER_UPDATE);
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
    FS_InspectionStatusEventSettings.Config config = FS_InspectionStatusEventSettings.getConfig();
    if (operationType == System.TriggerOperation.AFTER_UPDATE && config.isActive) {
      publishStatusEvents(newRecords, oldMap, config);
    }
  }

  /**
   * @description Filters qualifying appointments, builds payloads, and publishes events.
   * @param newRecords Trigger.new records.
   * @param oldMap Trigger.oldMap.
   * @param config Parsed CMDT configuration.
   */
  private static void publishStatusEvents(
    List<ServiceAppointment> newRecords,
    Map<Id, ServiceAppointment> oldMap,
    FS_InspectionStatusEventSettings.Config config
  ) {
    Map<Id, String> eventTypeBySaId = collectQualifyingEventTypes(
      newRecords,
      oldMap,
      config
    );
    if (eventTypeBySaId.isEmpty()) {
      return;
    }
    if (!canReadServiceAppointment()) {
      return;
    }
    List<ServiceAppointment> saRecords = queryAppointments(eventTypeBySaId.keySet());
    List<FS_InspectionDataUpdate__e> eventsToPublish = FS_InspectionStatusEventMapper.buildEvents(
      excludeManualInspections(saRecords),
      eventTypeBySaId,
      config
    );
    publishEvents(eventsToPublish);
  }

  /**
   * @description Collects appointment Ids that should publish, with EventType__c per Id.
   * @param newRecords Trigger.new records.
   * @param oldMap Trigger.oldMap.
   * @param config Parsed CMDT configuration.
   * @return Map of Service Appointment Id to EventType__c.
   */
  private static Map<Id, String> collectQualifyingEventTypes(
    List<ServiceAppointment> newRecords,
    Map<Id, ServiceAppointment> oldMap,
    FS_InspectionStatusEventSettings.Config config
  ) {
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
    return eventTypeBySaId;
  }

  /**
   * @description Keeps Field_Services appointments that are not CRM manual backfills.
   * @param appointments Trigger.new Service Appointments.
   * @return Appointments eligible for publication, or an empty list if Field_Services is missing.
   */
  private static List<ServiceAppointment> filterPublishableAppointments(
    List<ServiceAppointment> appointments
  ) {
    List<ServiceAppointment> scoped = new List<ServiceAppointment>();
    Id fieldServicesRtId = getFieldServicesRecordTypeId();
    if (fieldServicesRtId == null) {
      return scoped;
    }
    for (ServiceAppointment appointment : appointments) {
      if (isPublishableAppointment(appointment, fieldServicesRtId)) {
        scoped.add(appointment);
      }
    }
    return scoped;
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
   * @description Resolves EventType__c for this update, or null when nothing should publish.
   * @param sa Appointment after the update.
   * @param oldSa Appointment before the update.
   * @param config Parsed CMDT configuration.
   * @return InspectionStatusUpdate, or null.
   */
  @TestVisible
  private static String resolveEventType(
    ServiceAppointment sa,
    ServiceAppointment oldSa,
    FS_InspectionStatusEventSettings.Config config
  ) {
    if (oldSa == null) {
      return null;
    }
    Boolean statusChanged = sa.Status != oldSa.Status;
    Boolean scheduleChanged =
      sa.SchedStartTime != oldSa.SchedStartTime ||
      sa.SchedEndTime != oldSa.SchedEndTime;
    if (statusChanged || scheduleChanged) {
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
    return (List<ServiceAppointment>) Database.query(
      saQuery + ' WITH SECURITY_ENFORCED'
    );
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
      'FS_Work_Order__r.FS_Booking_Reference__c, ' +
      'FS_Work_Order_Line_Item__c, FS_Work_Order_Line_Item__r.LineItemNumber, ' +
      'FS_Work_Order_Line_Item__r.FS_ExternalRefId__c, ' +
      'FS_ExternalRefId__c, FS_BCO_Detail__c, FS_BCO_Detail__r.FS_BCO_Number__c, ' +
      'FS_BCO_Detail__r.FS_BCO_Complexity__c, FS_Dispatched_Date__c, ' +
      'FS_Cancelled_Date__c, FS_Travel_Date__c, FS_OnSite_Date__c, FS_Completed_Date__c, ' +
      'FS_Booking_Type__c, FS_Inspection_Status__c, FS_Cancelled_Reason__c, ' +
      'FS_Is_Confirmed__c, FSL__InJeopardy__c, FSL__InJeopardyReason__c, ' +
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
