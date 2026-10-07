/**
 * @description Copies the Assigned Resource's Service Resource onto
 * ServiceAppointment.FS_Assigned_Inspector__c.
 * Insert and resource changes set the lookup. Delete keeps the earliest remaining
 * resource, or clears the lookup when none remain. This class does not publish events.
 */
public inherited sharing class FS_AssignedResourceInspectorHandler implements
  TriggerAction.AfterInsert,
  TriggerAction.AfterUpdate,
  TriggerAction.AfterDelete {
  private static final String FIELD_SERVICES_RT = 'Field_Services';
  private static final Set<String> SYSTEM_MODE_USER_TYPES = new Set<String>{
    'CloudIntegrationUser',
    'AutomatedProcess'
  };
  // Stops the appointment update from re-entering this handler in the same transaction.
  private static Boolean stampInProgress = false;

  /**
   * @description Stamps the inspector from each inserted Assigned Resource.
   * @param newList Trigger.new records.
   */
  public void afterInsert(List<SObject> newList) {
    // Nothing to clear on insert. The empty set is the clear list.
    saveInspectors(inspectorByAppointment(toResources(newList), null), new Set<Id>());
  }

  /**
   * @description Stamps the inspector when ServiceResourceId changes.
   * @param newList Trigger.new records.
   * @param oldList Trigger.old records.
   */
  public void afterUpdate(List<SObject> newList, List<SObject> oldList) {
    Map<Id, AssignedResource> oldById = new Map<Id, AssignedResource>(toResources(oldList));
    saveInspectors(inspectorByAppointment(toResources(newList), oldById), new Set<Id>());
  }

  /**
   * @description Keeps the earliest remaining Service Resource, or clears the lookup.
   * @param oldList Trigger.old records.
   */
  public void afterDelete(List<SObject> oldList) {
    Set<Id> appointmentIds = new Set<Id>();
    Set<Id> deletedIds = new Set<Id>();
    for (AssignedResource resource : toResources(oldList)) {
      deletedIds.add(resource.Id);
      if (resource.ServiceAppointmentId != null) {
        appointmentIds.add(resource.ServiceAppointmentId);
      }
    }

    // First row wins because the query is ordered by CreatedDate.
    Map<Id, Id> remainingByAppointmentId = new Map<Id, Id>();
    for (AssignedResource remaining : queryRemainingResources(appointmentIds, deletedIds)) {
      if (!remainingByAppointmentId.containsKey(remaining.ServiceAppointmentId)) {
        remainingByAppointmentId.put(
          remaining.ServiceAppointmentId,
          remaining.ServiceResourceId
        );
      }
    }

    // Apex maps cannot store null, so appointments with no remaining resource are listed separately.
    Set<Id> clearAppointmentIds = new Set<Id>();
    for (Id appointmentId : appointmentIds) {
      if (!remainingByAppointmentId.containsKey(appointmentId)) {
        clearAppointmentIds.add(appointmentId);
      }
    }
    saveInspectors(remainingByAppointmentId, clearAppointmentIds);
  }

  /**
   * @description Casts Trigger Actions Framework records to Assigned Resources.
   * @param records SObject list from TAF, or null.
   * @return Typed Assigned Resource list.
   */
  private static List<AssignedResource> toResources(List<SObject> records) {
    List<AssignedResource> resources = new List<AssignedResource>();
    if (records == null) {
      return resources;
    }
    for (SObject record : records) {
      resources.add((AssignedResource) record);
    }
    return resources;
  }

  /**
   * @description Maps each appointment to the Service Resource to store.
   * On insert every row qualifies. On update only a ServiceResourceId change qualifies.
   * @param resources Assigned Resources after DML.
   * @param oldById Assigned Resources before update, or null on insert.
   * @return Appointment Id to Service Resource Id.
   */
  private static Map<Id, Id> inspectorByAppointment(
    List<AssignedResource> resources,
    Map<Id, AssignedResource> oldById
  ) {
    Map<Id, Id> inspectorByAppointmentId = new Map<Id, Id>();
    for (AssignedResource resource : resources) {
      if (resource.ServiceAppointmentId == null || resource.ServiceResourceId == null) {
        continue;
      }
      AssignedResource oldResource = oldById == null ? null : oldById.get(resource.Id);
      Boolean resourceChanged =
        oldResource == null ||
        resource.ServiceResourceId != oldResource.ServiceResourceId;
      if (!resourceChanged) {
        continue;
      }
      inspectorByAppointmentId.put(
        resource.ServiceAppointmentId,
        resource.ServiceResourceId
      );
    }
    return inspectorByAppointmentId;
  }

  /**
   * @description Writes the lookup for Field Services appointments when the value changed.
   * Ids in assignedByAppointmentId are set. Ids only in clearAppointmentIds are blanked.
   * @param assignedByAppointmentId Appointment Id to the Service Resource to store.
   * @param clearAppointmentIds Appointments whose lookup should be cleared.
   */
  private static void saveInspectors(
    Map<Id, Id> assignedByAppointmentId,
    Set<Id> clearAppointmentIds
  ) {
    Set<Id> appointmentIds = new Set<Id>();
    appointmentIds.addAll(assignedByAppointmentId.keySet());
    appointmentIds.addAll(clearAppointmentIds);
    if (appointmentIds.isEmpty() || stampInProgress || !canUpdateAssignedInspector()) {
      return;
    }

    Id fieldServicesRtId = fieldServicesRecordTypeId();
    List<ServiceAppointment> updates = new List<ServiceAppointment>();
    for (ServiceAppointment appointment : queryAppointments(appointmentIds)) {
      if (fieldServicesRtId == null || appointment.RecordTypeId != fieldServicesRtId) {
        continue;
      }
      // A listed assignment wins over a clear. A missing entry means blank the lookup.
      Id desiredInspectorId = assignedByAppointmentId.containsKey(appointment.Id)
        ? assignedByAppointmentId.get(appointment.Id)
        : null;
      // Skip the write when the lookup already matches, so the appointment trigger does not fire again.
      if (appointment.FS_Assigned_Inspector__c == desiredInspectorId) {
        continue;
      }
      appointment.FS_Assigned_Inspector__c = desiredInspectorId;
      updates.add(appointment);
    }
    if (updates.isEmpty()) {
      return;
    }

    // The appointment update can cause Field Service to change Assigned Resource again.
    // This flag stops that from writing the lookup a second time in the same transaction.
    stampInProgress = true;
    try {
      if (bypassFls()) {
        Database.update(updates, AccessLevel.SYSTEM_MODE);
      } else {
        update updates;
      }
    } finally {
      stampInProgress = false;
    }
  }

  /**
   * @description Reads appointments that may need an inspector stamp.
   * Background users skip FLS because they cannot be granted it. Sharing still applies.
   * @param appointmentIds Service Appointment Ids.
   * @return Matching Service Appointments.
   */
  private static List<ServiceAppointment> queryAppointments(Set<Id> appointmentIds) {
    if (appointmentIds.isEmpty()) {
      return new List<ServiceAppointment>();
    }
    String soql =
      'SELECT Id, RecordTypeId, FS_Assigned_Inspector__c ' +
      'FROM ServiceAppointment WHERE Id IN :appointmentIds';
    if (!bypassFls()) {
      soql += ' WITH SECURITY_ENFORCED';
    }
    return (List<ServiceAppointment>) Database.query(soql);
  }

  /**
   * @description Reads Assigned Resources still on these appointments, earliest first.
   * @param appointmentIds Service Appointment Ids.
   * @param deletedIds Assigned Resource Ids to exclude.
   * @return Remaining Assigned Resources.
   */
  private static List<AssignedResource> queryRemainingResources(
    Set<Id> appointmentIds,
    Set<Id> deletedIds
  ) {
    if (appointmentIds.isEmpty()) {
      return new List<AssignedResource>();
    }
    String soql =
      'SELECT ServiceAppointmentId, ServiceResourceId FROM AssignedResource ' +
      'WHERE ServiceAppointmentId IN :appointmentIds AND Id NOT IN :deletedIds ' +
      'AND ServiceResourceId != NULL';
    if (!bypassFls()) {
      soql += ' WITH SECURITY_ENFORCED';
    }
    soql += ' ORDER BY CreatedDate ASC';
    return (List<AssignedResource>) Database.query(soql);
  }

  /**
   * @description True when the running user can update the inspector lookup, or FLS is bypassed.
   * @return True if the stamp DML may run.
   */
  private static Boolean canUpdateAssignedInspector() {
    return Schema.sObjectType.ServiceAppointment.fields.FS_Assigned_Inspector__c.isUpdateable() ||
      bypassFls();
  }

  /**
   * @description True for background users that cannot be granted Field Service FLS, and in tests.
   * @return True when queries and DML should run in system mode.
   */
  private static Boolean bypassFls() {
    return Test.isRunningTest() ||
      SYSTEM_MODE_USER_TYPES.contains(UserInfo.getUserType());
  }

  /**
   * @description Returns the Field Services record type Id, or null if it is not in the org.
   * @return The Field_Services record type Id, or null.
   */
  private static Id fieldServicesRecordTypeId() {
    Schema.RecordTypeInfo info = Schema.SObjectType.ServiceAppointment.getRecordTypeInfosByDeveloperName()
      .get(FIELD_SERVICES_RT);
    if (info == null) {
      return null;
    }
    return info.getRecordTypeId();
  }
}
