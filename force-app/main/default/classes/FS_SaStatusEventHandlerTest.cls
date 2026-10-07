/**
 * @description Tests for FS_SaStatusEventHandler, mapper, and FS_InspectionStatusEventSettings.
 * Uses Field Services record type and Auckland Council parent lookup fields.
 */
@IsTest
private class FS_SaStatusEventHandlerTest {
  /**
   * @description Creates Operating Hours, Service Territory, Work Order, WOLI, and SA.
   */
  @TestSetup
  static void setupTestData() {
    Test.startTest();
    registerStatusTransitions();
    OperatingHours operatingHours = new OperatingHours(
      Name = 'Standard Business Hours',
      TimeZone = 'Pacific/Auckland'
    );
    insert operatingHours;

    ServiceTerritory territory = new ServiceTerritory(
      Name = 'AKLC Test Territory',
      OperatingHoursId = operatingHours.Id,
      IsActive = true
    );
    insert territory;

    WorkOrder workOrder = new WorkOrder(
      Status = 'New',
      Priority = 'High',
      Description = 'Inspection status event test work order',
      FS_Booking_Reference__c = 'IB-20260731-000001',
      FS_IsManualInspection__c = false
    );
    insert workOrder;

    WorkOrderLineItem lineItem = new WorkOrderLineItem(
      WorkOrderId = workOrder.Id,
      ServiceTerritoryId = territory.Id,
      Description = 'Inspection status event test line item',
      Duration = 2,
      DurationType = 'Hours',
      Priority = 'High',
      FS_ExternalRefId__c = 'IB-20260731-000002',
      FS_IsManualInspection__c = false
    );
    insert lineItem;

    BCO_Detail__c bcoDetail = new BCO_Detail__c(
      FS_BCO_Number__c = 'BCO-TEST-000001'
    );
    insert bcoDetail;

    insert new ServiceAppointment(
      ParentRecordId = lineItem.Id,
      ServiceTerritoryId = territory.Id,
      EarliestStartTime = DateTime.now(),
      DueDate = DateTime.now().addDays(7),
      Status = 'None',
      RecordTypeId = getFieldServicesRecordTypeId(),
      FS_ExternalRefId__c = 'I004382766',
      FS_IsManualInspection__c = false,
      FS_BCO_Detail__c = bcoDetail.Id
    );
    Test.stopTest();
  }

  /**
   * @description Registers Field Service status transitions used by these tests.
   * FSL throws if a transition was already registered in TestSetup.
   */
  private static void registerStatusTransitions() {
    addStatusTransition('None', 'Scheduled');
    addStatusTransition('Scheduled', 'Dispatched');
    addStatusTransition('Scheduled', 'None');
    addStatusTransition('Dispatched', 'Travel');
    addStatusTransition('Travel', 'OnSite');
    addStatusTransition('OnSite', 'Completed');
    addStatusTransition('None', 'Canceled');
    addStatusTransition('Dispatched', 'Canceled');
  }

  /**
   * @description Registers one Field Service status transition, ignoring duplicates.
   * @param fromStatus Current status API value.
   * @param toStatus Target status API value.
   */
  private static void addStatusTransition(String fromStatus, String toStatus) {
    try {
      FSL.GlobalAPIS.addStatusTransition(fromStatus, toStatus);
    } catch (Exception e) {
      if (e.getMessage() == null || !e.getMessage().contains('already exists')) {
        throw e;
      }
    }
  }

  /**
   * @description Returns the packaged Field Services record type Id.
   * @return The Field_Services record type Id.
   */
  private static Id getFieldServicesRecordTypeId() {
    Schema.RecordTypeInfo info = Schema.SObjectType.ServiceAppointment.getRecordTypeInfosByDeveloperName()
      .get('Field_Services');
    System.assertNotEquals(
      null,
      info,
      'The Field_Services record type must exist on Service Appointment.'
    );
    return info.getRecordTypeId();
  }

  /**
   * @description Returns the setup Service Appointment with fields used by the action.
   * @return The test Service Appointment.
   */
  private static ServiceAppointment getTestAppointment() {
    return [
      SELECT
        Id,
        Status,
        AppointmentNumber,
        RecordTypeId,
        ServiceTerritoryId,
        FS_Work_Order__c,
        FS_Work_Order_Line_Item__c,
        FS_ExternalRefId__c,
        FS_IsManualInspection__c,
        FS_Is_Confirmed__c,
        FS_Assigned_Inspector__c,
        Priority__c,
        SchedStartTime,
        SchedEndTime,
        ArrivalWindowStartTime,
        ArrivalWindowEndTime,
        DueDate,
        EarliestStartTime,
        ActualStartTime,
        ActualEndTime,
        FS_Dispatched_Date__c,
        FS_Cancelled_Date__c,
        FS_Travel_Date__c,
        FS_OnSite_Date__c,
        FS_Completed_Date__c
      FROM ServiceAppointment
      LIMIT 1
    ];
  }

  /**
   * @description Returns a Service Resource Id that can be stored on FS_Assigned_Inspector__c.
   * @return An active technician Service Resource Id for the running user.
   */
  private static Id ensureInspectorId() {
    List<ServiceResource> existingResources = [
      SELECT Id
      FROM ServiceResource
      WHERE RelatedRecordId = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (!existingResources.isEmpty()) {
      return existingResources[0].Id;
    }
    ServiceResource resource = new ServiceResource(
      Name = 'Inspection Test Resource',
      RelatedRecordId = UserInfo.getUserId(),
      IsActive = true,
      ResourceType = 'T'
    );
    insert resource;
    return resource.Id;
  }

  /**
   * @description Ensures the Service Resource can be assigned in the appointment territory.
   * @param resourceId Service Resource Id.
   * @param territoryId Service Territory Id.
   */
  private static void ensureTerritoryMembership(Id resourceId, Id territoryId) {
    List<ServiceTerritoryMember> existingMembers = [
      SELECT Id
      FROM ServiceTerritoryMember
      WHERE ServiceResourceId = :resourceId
        AND ServiceTerritoryId = :territoryId
      LIMIT 1
    ];
    if (!existingMembers.isEmpty()) {
      return;
    }
    insert new ServiceTerritoryMember(
      ServiceResourceId = resourceId,
      ServiceTerritoryId = territoryId,
      EffectiveStartDate = DateTime.now().addDays(-1),
      TerritoryType = 'P'
    );
  }

  /**
   * @description Overrides the CMDT setting for the rest of the test transaction.
   * @param isActive Whether publication is active.
   */
  private static void applySettingsOverride(Boolean isActive) {
    FS_InspectionStatusEventSettings.settingsOverride = new FS_Inspection_Status_Event_Setting__mdt(
      Is_Active__c = isActive,
      Event_Type__c = 'InspectionStatusUpdate',
      Unscheduled_Status__c = 'None',
      Scope_To_Field_Services_Record_Type__c = true
    );
  }

  /**
   * @description Invokes the Trigger Action after a DML update, ignoring any TAF double-publish.
   * @param newRecord Appointment after DML.
   * @param oldRecord Appointment snapshot before DML.
   */
  private static void invokeAfterUpdate(
    ServiceAppointment newRecord,
    ServiceAppointment oldRecord
  ) {
    FS_SaStatusEventHandler.publishedEventsForTest.clear();
    List<SObject> newList = new List<SObject>{ newRecord };
    List<SObject> oldList = new List<SObject>{ oldRecord };
    new FS_SaStatusEventHandler().afterUpdate(newList, oldList);
  }

  /**
   * @description Confirms before-insert from the org Alert Center trigger copies parent lookups.
   */
  @IsTest
  static void testParentLookupsPopulatedOnInsert() {
    ServiceAppointment appointment = getTestAppointment();
    Test.startTest();
    WorkOrderLineItem lineItem = [
      SELECT Id, WorkOrderId
      FROM WorkOrderLineItem
      WHERE Id = :appointment.FS_Work_Order_Line_Item__c
      LIMIT 1
    ];
    Test.stopTest();
    System.assertEquals(
      lineItem.Id,
      appointment.FS_Work_Order_Line_Item__c,
      'FS_Work_Order_Line_Item__c should be copied from ParentRecordId.'
    );
    System.assertEquals(
      lineItem.WorkOrderId,
      appointment.FS_Work_Order__c,
      'FS_Work_Order__c should be populated from the Work Order Line Item.'
    );
    System.assertEquals(
      'High',
      appointment.Priority__c,
      'Priority__c should resolve from the parent Work Order Line Item.'
    );
  }

  /**
   * @description A Scheduled update that sets a new inspector and both schedule times publishes once.
   */
  @IsTest
  static void testNewInspectorAndNewTimesPublishesEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    Id inspectorId = ensureInspectorId();
    ServiceAppointment oldRecord = getTestAppointment();
    ServiceAppointment appointment = oldRecord.clone(true, true, false, false);

    Test.startTest();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    appointment.FS_Assigned_Inspector__c = inspectorId;
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'A new inspector and new schedule times should publish one event.'
    );
    FS_InspectionDataUpdate__e eventRecord = FS_SaStatusEventHandler.publishedEventsForTest[0];
    System.assertEquals(
      'InspectionStatusUpdate',
      eventRecord.EventType__c,
      'Every publish uses InspectionStatusUpdate.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      eventRecord.Payload__c
    );
    System.assertEquals('Scheduled', payload.get('status'));
    System.assertEquals(String.valueOf(inspectorId), payload.get('assignedInspectorId'));
    System.assertNotEquals(null, payload.get('schedStartTime'));
    System.assertNotEquals(null, payload.get('schedEndTime'));
    System.assertEquals('IB-20260731-000001', payload.get('bookingReferenceNumber'));
    System.assertEquals('I004382766', payload.get('sfsInspectionId'));
  }

  /**
   * @description A transition to Canceled publishes one inspection event.
   */
  @IsTest
  static void testCanceledStatusPublishesEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment appointment = getTestAppointment();
    ServiceAppointment oldRecord = appointment.clone(true, true, false, false);

    Test.startTest();
    appointment.Status = 'Canceled';
    appointment.FS_Cancelled_Reason__c = 'Other';
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Canceling an appointment should publish one event.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      FS_SaStatusEventHandler.publishedEventsForTest[0].Payload__c
    );
    System.assertEquals('Canceled', payload.get('status'));
    System.assertEquals('Other', payload.get('cancelledReason'));
  }

  /**
   * @description Non-Field_Services appointments do not publish.
   */
  @IsTest
  static void testNonFieldServicesRecordTypeDoesNotPublish() {
    applySettingsOverride(true);
    ServiceAppointment oldRecord = getTestAppointment();
    ServiceAppointment newRecord = oldRecord.clone(true, true, false, false);
    newRecord.RecordTypeId = null;
    newRecord.Status = 'Scheduled';
    newRecord.SchedStartTime = DateTime.now().addHours(1);
    newRecord.SchedEndTime = DateTime.now().addHours(3);
    newRecord.FS_Assigned_Inspector__c = ensureInspectorId();

    Test.startTest();
    FS_SaStatusEventHandler.publishedEventsForTest.clear();
    new FS_SaStatusEventHandler().afterUpdate(
      new List<SObject>{ newRecord },
      new List<SObject>{ oldRecord }
    );
    Test.stopTest();

    System.assertEquals(
      0,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Appointments without Field_Services record type should not publish.'
    );
  }

  /**
   * @description CRM manual backfill appointments do not publish.
   */
  @IsTest
  static void testManualInspectionDoesNotPublish() {
    applySettingsOverride(true);
    ServiceAppointment oldRecord = getTestAppointment();
    ServiceAppointment newRecord = oldRecord.clone(true, true, false, false);
    newRecord.FS_IsManualInspection__c = true;
    newRecord.Status = 'Scheduled';
    newRecord.SchedStartTime = DateTime.now().addHours(1);
    newRecord.SchedEndTime = DateTime.now().addHours(3);
    newRecord.FS_Assigned_Inspector__c = ensureInspectorId();

    Test.startTest();
    FS_SaStatusEventHandler.publishedEventsForTest.clear();
    new FS_SaStatusEventHandler().afterUpdate(
      new List<SObject>{ newRecord },
      new List<SObject>{ oldRecord }
    );
    Test.stopTest();

    System.assertEquals(
      0,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Service Appointments with FS_IsManualInspection__c true should not publish.'
    );
  }

  /**
   * @description Schedule time changes with the same inspector publish InspectionStatusUpdate.
   */
  @IsTest
  static void testScheduleChangeOnScheduledPublishesEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    Id inspectorId = ensureInspectorId();
    ServiceAppointment appointment = getTestAppointment();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    appointment.FS_Assigned_Inspector__c = inspectorId;
    update appointment;
    ServiceAppointment oldRecord = getTestAppointment();

    Test.startTest();
    appointment.SchedStartTime = DateTime.now().addHours(2);
    appointment.SchedEndTime = DateTime.now().addHours(4);
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Changing scheduled start or end with the same inspector should publish.'
    );
    FS_InspectionDataUpdate__e eventRecord = FS_SaStatusEventHandler.publishedEventsForTest[0];
    System.assertEquals(
      'InspectionStatusUpdate',
      eventRecord.EventType__c,
      'Schedule changes use InspectionStatusUpdate.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      eventRecord.Payload__c
    );
    System.assertNotEquals(
      null,
      payload.get('schedStartTime'),
      'schedStartTime should be present when the appointment has a scheduled start.'
    );
    System.assertNotEquals(
      null,
      payload.get('schedEndTime'),
      'schedEndTime should be present when the appointment has a scheduled end.'
    );
  }

  /**
   * @description Assigned resource travel time is copied onto the payload.
   */
  @IsTest
  static void testAssignedResourceTravelIsMapped() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment appointment = getTestAppointment();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    update appointment;

    Id resourceId;
    List<ServiceResource> existingResources = [
      SELECT Id
      FROM ServiceResource
      WHERE RelatedRecordId = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (existingResources.isEmpty()) {
      ServiceResource resource = new ServiceResource(
        Name = 'Inspection Test Resource',
        RelatedRecordId = UserInfo.getUserId(),
        IsActive = true,
        ResourceType = 'T'
      );
      insert resource;
      resourceId = resource.Id;
    } else {
      resourceId = existingResources[0].Id;
    }

    List<ServiceTerritoryMember> existingMembers = [
      SELECT Id
      FROM ServiceTerritoryMember
      WHERE ServiceResourceId = :resourceId
        AND ServiceTerritoryId = :appointment.ServiceTerritoryId
      LIMIT 1
    ];
    if (existingMembers.isEmpty()) {
      insert new ServiceTerritoryMember(
        ServiceResourceId = resourceId,
        ServiceTerritoryId = appointment.ServiceTerritoryId,
        EffectiveStartDate = DateTime.now().addDays(-1),
        TerritoryType = 'P'
      );
    }

    insert new AssignedResource(
      ServiceAppointmentId = appointment.Id,
      ServiceResourceId = resourceId,
      EstimatedTravelTime = 12
    );
    appointment.FS_Assigned_Inspector__c = resourceId;
    update appointment;

    ServiceAppointment oldRecord = getTestAppointment();
    Test.startTest();
    appointment.SchedStartTime = DateTime.now().addHours(2);
    appointment.SchedEndTime = DateTime.now().addHours(4);
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    AssignedResource assigned = [
      SELECT EstimatedTravelTime
      FROM AssignedResource
      WHERE ServiceAppointmentId = :appointment.Id
      LIMIT 1
    ];
    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'A schedule change on a Scheduled appointment with an assigned resource should publish.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      FS_SaStatusEventHandler.publishedEventsForTest[0].Payload__c
    );
    Decimal travelMinutes = Decimal.valueOf(
      String.valueOf(payload.get('estimatedTravelTimeMinutes'))
    );
    System.assertEquals(
      assigned.EstimatedTravelTime,
      travelMinutes,
      'estimatedTravelTimeMinutes should copy AssignedResource.EstimatedTravelTime.'
    );
    System.assertNotEquals(
      null,
      payload.get('assignedCrewMembers'),
      'assignedCrewMembers should be present when a resource is assigned.'
    );
  }

  /**
   * @description Arrival window changes alone do not publish.
   */
  @IsTest
  static void testArrivalWindowOnlyDoesNotPublish() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment appointment = getTestAppointment();
    Id inspectorId = ensureInspectorId();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    appointment.FS_Assigned_Inspector__c = inspectorId;
    update appointment;
    ServiceAppointment oldRecord = getTestAppointment();
    ServiceAppointment newRecord = oldRecord.clone(true, true, false, false);
    newRecord.ArrivalWindowStartTime = DateTime.now().addHours(2);
    newRecord.ArrivalWindowEndTime = DateTime.now().addHours(4);

    Test.startTest();
    String eventType = FS_SaStatusEventHandler.resolveEventType(
      newRecord,
      oldRecord,
      FS_InspectionStatusEventSettings.getConfig()
    );
    Test.stopTest();

    System.assertEquals(
      null,
      eventType,
      'Arrival window changes without status or scheduled-time changes should not publish.'
    );
  }

  /**
   * @description Status None while the inspector is still set does not publish.
   */
  @IsTest
  static void testUnscheduleDoesNotPublish() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment appointment = getTestAppointment();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    appointment.FS_Assigned_Inspector__c = ensureInspectorId();
    update appointment;
    ServiceAppointment oldRecord = getTestAppointment();

    Test.startTest();
    appointment.Status = 'None';
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      0,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Unschedule should wait until the assigned inspector lookup is cleared.'
    );
  }

  /**
   * @description Insert does not publish, including when the row is already confirmed.
   */
  @IsTest
  static void testCreateDoesNotPublish() {
    applySettingsOverride(true);
    ServiceAppointment created = getTestAppointment();
    created.FS_Is_Confirmed__c = true;

    Test.startTest();
    FS_SaStatusEventHandler.publishedEventsForTest.clear();
    new FS_SaStatusEventHandler().afterInsert(new List<SObject>{ created });
    Test.stopTest();

    System.assertEquals(
      0,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Creating a Service Appointment should not publish.'
    );
  }

  /**
   * @description Setting FS_Is_Confirmed__c to true on update publishes one event.
   */
  @IsTest
  static void testConfirmedUpdatePublishesEvent() {
    applySettingsOverride(true);
    ServiceAppointment oldRecord = getTestAppointment();
    oldRecord.FS_Is_Confirmed__c = false;
    ServiceAppointment newRecord = oldRecord.clone(true, true, false, false);
    newRecord.FS_Is_Confirmed__c = true;

    Test.startTest();
    String eventType = FS_SaStatusEventHandler.resolveEventType(
      newRecord,
      oldRecord,
      FS_InspectionStatusEventSettings.getConfig()
    );
    Test.stopTest();

    System.assertEquals(
      'InspectionStatusUpdate',
      eventType,
      'Setting Is Confirmed on update should publish.'
    );
  }

  /**
   * @description Status None to Scheduled publishes when the inspector and both times are already stored.
   */
  @IsTest
  static void testStatusBecomesScheduledPublishesEvent() {
    applySettingsOverride(true);
    ServiceAppointment oldRecord = getTestAppointment();
    oldRecord.Status = 'None';
    oldRecord.SchedStartTime = DateTime.now().addHours(1);
    oldRecord.SchedEndTime = DateTime.now().addHours(2);
    oldRecord.FS_Assigned_Inspector__c = ensureInspectorId();
    ServiceAppointment newRecord = oldRecord.clone(true, true, false, false);
    newRecord.Status = 'Scheduled';

    Test.startTest();
    String eventType = FS_SaStatusEventHandler.resolveEventType(
      newRecord,
      oldRecord,
      FS_InspectionStatusEventSettings.getConfig()
    );
    Test.stopTest();

    System.assertEquals(
      'InspectionStatusUpdate',
      eventType,
      'Flipping status to Scheduled should publish when the inspector and both times are already set.'
    );
  }

  /**
   * @description A scheduled appointment moved to a new time and a new inspector publishes once.
   */
  @IsTest
  static void testResourceDragPublishesOneEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    User owner = newReplacementOwner();
    insert owner;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      dragScheduledAppointment(owner.Id);
    }
  }

  /**
   * @description Saves a new time and a new inspector as two updates and expects one event.
   * @param replacementOwnerId User who owns the resource the appointment is dropped onto.
   */
  private static void dragScheduledAppointment(Id replacementOwnerId) {
    Id firstInspectorId = ensureInspectorId();
    ServiceResource replacement = new ServiceResource(
      Name = 'Drag Target Resource',
      RelatedRecordId = replacementOwnerId,
      IsActive = true,
      ResourceType = 'T'
    );
    insert replacement;
    ServiceAppointment appointment = getTestAppointment();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(2);
    appointment.FS_Assigned_Inspector__c = firstInspectorId;
    update appointment;

    Test.startTest();
    FS_SaStatusEventHandler.publishedEventsForTest.clear();
    appointment.SchedStartTime = DateTime.now().addHours(3);
    appointment.SchedEndTime = DateTime.now().addHours(4);
    update appointment;
    appointment.FS_Assigned_Inspector__c = replacement.Id;
    update appointment;
    Test.stopTest();

    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Dragging a scheduled appointment onto another resource should publish one event.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      FS_SaStatusEventHandler.publishedEventsForTest[0].Payload__c
    );
    System.assertEquals(String.valueOf(replacement.Id), payload.get('assignedInspectorId'));
    System.assertNotEquals(null, payload.get('schedStartTime'));
  }

  /**
   * @description Entering Scheduled without both schedule times does not publish.
   */
  @IsTest
  static void testScheduledWithoutTimesDoesNotPublish() {
    applySettingsOverride(true);
    ServiceAppointment oldRecord = getTestAppointment();
    ServiceAppointment newRecord = oldRecord.clone(true, true, false, false);
    newRecord.Status = 'Scheduled';
    newRecord.FS_Assigned_Inspector__c = ensureInspectorId();

    Test.startTest();
    String eventType = FS_SaStatusEventHandler.resolveEventType(
      newRecord,
      oldRecord,
      FS_InspectionStatusEventSettings.getConfig()
    );
    Test.stopTest();

    System.assertEquals(
      null,
      eventType,
      'Scheduled without SchedStartTime and SchedEndTime should not publish.'
    );
  }

  /**
   * @description Inactive CMDT suppresses publication.
   */
  @IsTest
  static void testInactiveSettingDoesNotPublish() {
    applySettingsOverride(false);
    registerStatusTransitions();
    ServiceAppointment oldRecord = getTestAppointment();
    ServiceAppointment appointment = oldRecord.clone(true, true, false, false);
    Id inspectorId = ensureInspectorId();

    Test.startTest();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    appointment.FS_Assigned_Inspector__c = inspectorId;
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      0,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Inactive Default_Setting should not publish events.'
    );
  }

  /**
   * @description Settings parser returns defaults when CMDT is missing.
   */
  @IsTest
  static void testSettingsDefaultWhenMissing() {
    FS_InspectionStatusEventSettings.settingsOverride = null;
    FS_InspectionStatusEventSettings.forceMissingSettingForTest = true;
    Test.startTest();
    FS_InspectionStatusEventSettings.Config config = FS_InspectionStatusEventSettings.getConfig();
    Boolean bypass = FS_SaStatusEventHandler.bypassFlsForBackgroundUser();
    FS_SaStatusEventHandler.forceBackgroundUserContextForTest = true;
    Boolean forcedBypass = FS_SaStatusEventHandler.bypassFlsForBackgroundUser();
    FS_SaStatusEventHandler.forceBackgroundUserContextForTest = false;
    FS_InspectionStatusEventSettings.forceMissingSettingForTest = false;
    Test.stopTest();

    System.assertEquals(true, config.isActive, 'Missing CMDT should default to active.');
    System.assertEquals(
      'InspectionStatusUpdate',
      config.eventType,
      'Default event type should be InspectionStatusUpdate.'
    );
    System.assertEquals(
      'None',
      config.unscheduledStatus,
      'Default unscheduled status should be None.'
    );
    System.assertEquals(
      false,
      bypass,
      'Interactive test user should not use the background FLS bypass.'
    );
    System.assertEquals(
      true,
      forcedBypass,
      'Test hook should force the background FLS bypass path.'
    );
  }

  /**
   * @description Blank CMDT text fields fall back to packaged defaults. Empty trigger lists are ignored.
   */
  @IsTest
  static void testBlankSettingFieldsAndEmptyTrigger() {
    FS_InspectionStatusEventSettings.settingsOverride = new FS_Inspection_Status_Event_Setting__mdt(
      Is_Active__c = true,
      Event_Type__c = '',
      Unscheduled_Status__c = '',
      Scope_To_Field_Services_Record_Type__c = false
    );

    Test.startTest();
    FS_InspectionStatusEventSettings.Config config = FS_InspectionStatusEventSettings.getConfig();
    FS_SaStatusEventHandler.handleTrigger(
      null,
      null,
      System.TriggerOperation.AFTER_UPDATE
    );
    FS_SaStatusEventHandler.handleTrigger(
      new List<ServiceAppointment>(),
      null,
      System.TriggerOperation.AFTER_UPDATE
    );
    Test.stopTest();

    System.assertEquals(
      'InspectionStatusUpdate',
      config.eventType,
      'Blank Event_Type__c should default to InspectionStatusUpdate.'
    );
    System.assertEquals(
      'None',
      config.unscheduledStatus,
      'Blank Unscheduled_Status__c should default to None.'
    );
  }

  /**
   * @description Clearing the inspector while status is None publishes one unschedule event.
   */
  @IsTest
  static void testUnschedulePublishesWhenInspectorCleared() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment appointment = getTestAppointment();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    appointment.FS_Assigned_Inspector__c = ensureInspectorId();
    update appointment;
    ServiceAppointment oldRecord = getTestAppointment();

    Test.startTest();
    appointment.Status = 'None';
    appointment.FS_Assigned_Inspector__c = null;
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Clearing the inspector on an unscheduled appointment should publish one event.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      FS_SaStatusEventHandler.publishedEventsForTest[0].Payload__c
    );
    System.assertEquals('None', payload.get('status'));
    System.assertEquals(null, payload.get('assignedInspectorId'));
  }

  /**
   * @description A transition to Dispatched publishes even when the inspector is unchanged.
   */
  @IsTest
  static void testDispatchedPublishesEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment appointment = getTestAppointment();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    appointment.FS_Assigned_Inspector__c = ensureInspectorId();
    update appointment;
    ServiceAppointment oldRecord = getTestAppointment();

    Test.startTest();
    appointment.Status = 'Dispatched';
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Dispatching an appointment should publish one event.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      FS_SaStatusEventHandler.publishedEventsForTest[0].Payload__c
    );
    System.assertEquals('Dispatched', payload.get('status'));
  }

  /**
   * @description Changing only the inspector on a Scheduled appointment publishes.
   */
  @IsTest
  static void testInspectorChangePublishesEvent() {
    applySettingsOverride(true);
    ServiceAppointment oldRecord = getTestAppointment();
    oldRecord.Status = 'Scheduled';
    oldRecord.SchedStartTime = DateTime.now().addHours(1);
    oldRecord.SchedEndTime = DateTime.now().addHours(3);
    oldRecord.FS_Assigned_Inspector__c = ensureInspectorId();
    ServiceAppointment newRecord = oldRecord.clone(true, true, false, false);
    // In memory only. A second technician needs its own user, which this assertion does not.
    newRecord.FS_Assigned_Inspector__c = fakeServiceResourceId();

    Test.startTest();
    String eventType = FS_SaStatusEventHandler.resolveEventType(
      newRecord,
      oldRecord,
      FS_InspectionStatusEventSettings.getConfig()
    );
    Test.stopTest();

    System.assertEquals(
      'InspectionStatusUpdate',
      eventType,
      'An inspector change with the same schedule times should publish.'
    );
  }

  /**
   * @description Assigned Resource insert, update, and delete maintain the inspector lookup.
   */
  @IsTest
  static void testAssignedResourceStampsInspector() {
    User owner = newReplacementOwner();
    insert owner;
    // User is a setup object. The rest of the DML has to run in another context.
    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      stampInspectorFromAssignedResource(owner.Id);
    }
    Test.stopTest();
  }

  /**
   * @description Inserts, reassigns, and deletes Assigned Resources and checks the inspector lookup.
   * @param replacementOwnerId User who owns the second technician.
   */
  private static void stampInspectorFromAssignedResource(Id replacementOwnerId) {
    applySettingsOverride(true);
    ServiceAppointment appointment = getTestAppointment();
    Id inspectorId = ensureInspectorId();
    ensureTerritoryMembership(inspectorId, appointment.ServiceTerritoryId);
    ServiceResource replacement = new ServiceResource(
      Name = 'Inspection Replacement Resource',
      RelatedRecordId = replacementOwnerId,
      IsActive = true,
      ResourceType = 'T'
    );
    insert replacement;
    ensureTerritoryMembership(replacement.Id, appointment.ServiceTerritoryId);
    registerStatusTransitions();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    update appointment;

    AssignedResource firstResource = new AssignedResource(
      ServiceAppointmentId = appointment.Id,
      ServiceResourceId = inspectorId
    );
    insert firstResource;
    System.assertEquals(
      inspectorId,
      inspectorOn(appointment.Id),
      'Inserting an Assigned Resource should stamp FS_Assigned_Inspector__c.'
    );

    firstResource.ServiceResourceId = replacement.Id;
    update firstResource;
    System.assertEquals(
      replacement.Id,
      inspectorOn(appointment.Id),
      'Changing ServiceResourceId should update FS_Assigned_Inspector__c.'
    );

    firstResource.EstimatedTravelTime = 15;
    update firstResource;
    System.assertEquals(
      replacement.Id,
      inspectorOn(appointment.Id),
      'A non-resource field change should leave the inspector lookup unchanged.'
    );

    AssignedResource secondResource = new AssignedResource(
      ServiceAppointmentId = appointment.Id,
      ServiceResourceId = inspectorId
    );
    insert secondResource;
    delete secondResource;
    System.assertEquals(
      replacement.Id,
      inspectorOn(appointment.Id),
      'Deleting one Assigned Resource should keep the remaining inspector.'
    );

    delete firstResource;
    System.assertEquals(
      null,
      inspectorOn(appointment.Id),
      'Deleting the last Assigned Resource should clear FS_Assigned_Inspector__c.'
    );
  }

  /**
   * @description Builds an Id that is not a real Service Resource. Used for in-memory comparisons.
   * @return A Service Resource Id that does not exist.
   */
  private static Id fakeServiceResourceId() {
    return (Id) (ServiceResource.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
  }

  /**
   * @description Builds the user who will own the second technician. The caller inserts it.
   * @return An unsaved User.
   */
  private static User newReplacementOwner() {
    String unique = String.valueOf(DateTime.now().getTime());
    return new User(
      Alias = 'insp2',
      Email = 'insp2' + unique + '@test.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Inspector Two',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_NZ',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'Pacific/Auckland',
      Username = 'insp2' + unique + '@test.invalid'
    );
  }

  /**
   * @description Returns the inspector lookup currently stored on the appointment.
   * @param appointmentId Service Appointment Id.
   * @return FS_Assigned_Inspector__c, or null.
   */
  private static Id inspectorOn(Id appointmentId) {
    return [
      SELECT FS_Assigned_Inspector__c
      FROM ServiceAppointment
      WHERE Id = :appointmentId
    ].FS_Assigned_Inspector__c;
  }
}