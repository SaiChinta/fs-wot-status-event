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
   * @description Applies an in-memory Default_Setting override.
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
   * @description A transition into Scheduled publishes InspectionStatusUpdate.
   */
  @IsTest
  static void testEnteringScheduledPublishesEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment oldRecord = getTestAppointment();
    ServiceAppointment appointment = oldRecord.clone(true, true, false, false);

    Test.startTest();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Entering Scheduled should publish InspectionStatusUpdate.'
    );
    FS_InspectionDataUpdate__e eventRecord = FS_SaStatusEventHandler.publishedEventsForTest[0];
    System.assertEquals(
      'InspectionStatusUpdate',
      eventRecord.EventType__c,
      'Every publish uses InspectionStatusUpdate.'
    );
    System.assertEquals(
      'I004382766',
      eventRecord.InspectionId__c,
      'InspectionId__c should map from FS_ExternalRefId__c.'
    );
    System.assertEquals(
      String.valueOf(appointment.Id),
      eventRecord.ServiceAppointmentId__c,
      'ServiceAppointmentId__c should be the appointment Id.'
    );
  }

  /**
   * @description Status change to Canceled publishes InspectionStatusUpdate with parent Ids.
   */
  @IsTest
  static void testCanceledStatusPublishesEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment oldRecord = getTestAppointment();
    ServiceAppointment appointment = oldRecord.clone(true, true, false, false);

    Test.startTest();
    appointment.Status = 'Canceled';
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    List<FS_InspectionDataUpdate__e> published = FS_SaStatusEventHandler.publishedEventsForTest;
    System.assertEquals(1, published.size(), 'Canceled should publish one event.');
    FS_InspectionDataUpdate__e eventRecord = published[0];
    System.assertEquals(
      'InspectionStatusUpdate',
      eventRecord.EventType__c,
      'Canceled should still use InspectionStatusUpdate.'
    );
    System.assertEquals(
      String.valueOf(oldRecord.FS_Work_Order__c),
      eventRecord.WorkOrderId__c,
      'WorkOrderId__c should map from FS_Work_Order__c.'
    );
    System.assertEquals(
      String.valueOf(oldRecord.FS_Work_Order_Line_Item__c),
      eventRecord.WorkOrderLineItemId__c,
      'WorkOrderLineItemId__c should map from FS_Work_Order_Line_Item__c.'
    );
    System.assertEquals(
      'IB-20260731-000001',
      eventRecord.BookingReferenceNumber__c,
      'BookingReferenceNumber__c should map from WorkOrder.FS_Booking_Reference__c.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      eventRecord.Payload__c
    );
    System.assertEquals('Canceled', payload.get('status'));
    System.assertEquals('IB-20260731-000001', payload.get('bookingReferenceNumber'));
    System.assertEquals('I004382766', payload.get('inspectionId'));
    System.assertEquals(
      'InspectionStatusUpdate',
      payload.get('eventType')
    );
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
    newRecord.Status = 'Canceled';

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
    newRecord.Status = 'Canceled';

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
   * @description Scheduled start and end changes while already Scheduled publish InspectionStatusUpdate.
   */
  @IsTest
  static void testScheduleChangeOnScheduledPublishesEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment appointment = getTestAppointment();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
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
      'Changing scheduled start or end on a Scheduled appointment should publish.'
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

    ServiceAppointment oldRecord = getTestAppointment();
    Test.startTest();
    appointment.Status = 'Dispatched';
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
      'Dispatching a scheduled appointment with an assigned resource should publish.'
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
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
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
   * @description Unscheduling to None publishes InspectionStatusUpdate. Null schedule fields are omitted.
   */
  @IsTest
  static void testUnschedulePublishesEvent() {
    applySettingsOverride(true);
    registerStatusTransitions();
    ServiceAppointment appointment = getTestAppointment();
    appointment.Status = 'Scheduled';
    appointment.SchedStartTime = DateTime.now().addHours(1);
    appointment.SchedEndTime = DateTime.now().addHours(3);
    update appointment;
    ServiceAppointment oldRecord = getTestAppointment();

    Test.startTest();
    appointment.Status = 'None';
    update appointment;
    invokeAfterUpdate(getTestAppointment(), oldRecord);
    Test.stopTest();

    System.assertEquals(
      1,
      FS_SaStatusEventHandler.publishedEventsForTest.size(),
      'Unscheduling to None should publish a platform event.'
    );
    FS_InspectionDataUpdate__e eventRecord = FS_SaStatusEventHandler.publishedEventsForTest[0];
    System.assertEquals(
      'InspectionStatusUpdate',
      eventRecord.EventType__c,
      'Unschedule should use InspectionStatusUpdate.'
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      eventRecord.Payload__c
    );
    System.assertEquals('None', payload.get('status'));
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

    Test.startTest();
    appointment.Status = 'Canceled';
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
}
