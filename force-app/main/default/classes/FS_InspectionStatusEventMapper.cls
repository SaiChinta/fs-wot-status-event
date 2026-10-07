/**
 * @description Maps queried Service Appointments onto FS_InspectionDataUpdate__e
 * and a JSON payload whose property names match the Salesforce schema.
 * Null DTO properties are omitted from the serialized payload.
 */
public inherited sharing class FS_InspectionStatusEventMapper {
  /**
   * @description Maps queried appointments to platform events.
   * @param saRecords Queried Service Appointment records.
   * @param eventTypeBySaId EventType__c value keyed by appointment Id.
   * @param config Parsed CMDT configuration.
   * @return Events ready to publish.
   */
  public static List<FS_InspectionDataUpdate__e> buildEvents(
    List<ServiceAppointment> saRecords,
    Map<Id, String> eventTypeBySaId,
    FS_InspectionStatusEventSettings.Config config
  ) {
    List<FS_InspectionDataUpdate__e> eventsToPublish = new List<FS_InspectionDataUpdate__e>();
    for (ServiceAppointment sa : saRecords) {
      String eventType = eventTypeBySaId.get(sa.Id);
      if (String.isBlank(eventType)) {
        eventType = config.eventType;
      }
      eventsToPublish.add(buildEvent(sa, eventType, config));
    }
    return eventsToPublish;
  }

  /**
   * @description Maps one appointment to a platform event header and payload.
   * @param sa Queried Service Appointment.
   * @param eventType EventType__c value for this change.
   * @param config Parsed CMDT configuration.
   * @return Populated platform event.
   */
  public static FS_InspectionDataUpdate__e buildEvent(
    ServiceAppointment sa,
    String eventType,
    FS_InspectionStatusEventSettings.Config config
  ) {
    FS_InspectionStatusPayloadDTO payload = buildPayload(sa, eventType, config);
    FS_InspectionDataUpdate__e peEvent = new FS_InspectionDataUpdate__e();
    peEvent.EventType__c = eventType;
    peEvent.ServiceAppointmentId__c = sa.Id;
    peEvent.WorkOrderId__c = sa.FS_Work_Order__c;
    peEvent.WorkOrderLineItemId__c = sa.FS_Work_Order_Line_Item__c;
    peEvent.InspectionId__c = sa.FS_ExternalRefId__c;
    peEvent.BookingReferenceNumber__c = bookingReference(sa);
    peEvent.Payload__c = JSON.serialize(payload, true);
    return peEvent;
  }

  /**
   * @description Builds the nested JSON DTO for one appointment. Every mapped field is
   * populated when a value exists; JSON.serialize omits remaining nulls.
   * @param sa Queried Service Appointment.
   * @param eventType EventType__c value for this change.
   * @param config Parsed CMDT configuration.
   * @return Populated payload DTO.
   */
  public static FS_InspectionStatusPayloadDTO buildPayload(
    ServiceAppointment sa,
    String eventType,
    FS_InspectionStatusEventSettings.Config config
  ) {
    FS_InspectionStatusPayloadDTO payload = new FS_InspectionStatusPayloadDTO();
    payload.eventType = eventType;
    payload.status = sa.Status;
    payload.appointmentNumber = sa.AppointmentNumber;
    payload.priority = sa.Priority__c;
    payload.bookingReferenceNumber = bookingReference(sa);
    payload.bookingNotes = bookingNotes(sa);
    payload.contactInformation = contactInformation(sa);
    payload.crmInspectionId = sa.FS_CRMInspection_Id__c;
    payload.sfsInspectionId = sa.FS_ExternalRefId__c;
    payload.bcoNumber = bcoNumber(sa);
    payload.propertyId = bcoPropertyId(sa);
    payload.propertyAddress = bcoPropertyAddress(sa);
    payload.workOrderLineItemNumber = lineItemNumber(sa);
    payload.workTypeName = sa.WorkType == null ? null : sa.WorkType.Name;
    payload.inspectionType = sa.WorkType == null ? null : sa.WorkType.Name.substringBefore('_');
    payload.bcoComplexity = bcoComplexity(sa);
    payload.arrivalWindowStartTime = sa.ArrivalWindowStartTime;
    payload.arrivalWindowEndTime = sa.ArrivalWindowEndTime;
    payload.schedStartTime = sa.SchedStartTime;
    payload.schedEndTime = sa.SchedEndTime;
    payload.dispatchedDate = sa.FS_Dispatched_Date__c;
    payload.dueDate = sa.DueDate;
    payload.earliestStartTime = sa.EarliestStartTime;
    payload.cancelledDate = sa.FS_Cancelled_Date__c;
    payload.travelDate = sa.FS_Travel_Date__c;
    payload.onSiteDate = sa.FS_OnSite_Date__c;
    payload.completedDate = sa.FS_Completed_Date__c;
    payload.inJeopardy = sa.FSL__InJeopardy__c == true;
    payload.inJeopardyReason = sa.FSL__InJeopardyReason__c;
    payload.inspectionStatus = sa.FS_Inspection_Status__c;
    payload.cancelledReason = sa.FS_Cancelled_Reason__c;
    payload.bookingType = sa.FS_Booking_Type__c;
    payload.isConfirmed = sa.FS_Is_Confirmed__c == true;
    payload.assignedInspectorId = sa.FS_Assigned_Inspector__c;
    payload.assignedInspectorName = sa.FS_Assigned_Inspector__r == null
      ? null
      : sa.FS_Assigned_Inspector__r.Name;
    payload.parentWork = buildParentWork(sa);
    payload.lastModifiedBy = buildAudit(sa);
    List<FS_InspectionStatusPayloadDTO.AssignedResourceDTO> members = mapAssignedResources(
      sa,
      config
    );
    if (members != null && !members.isEmpty()) {
      payload.assignedCrewMembers = members;
      applyTravelDuration(payload, members);
    }
    return payload;
  }

  /**
   * @description Copies the first assigned resource travel time onto the payload root.
   * @param payload Payload being populated.
   * @param members Mapped assigned resources.
   */
  private static void applyTravelDuration(
    FS_InspectionStatusPayloadDTO payload,
    List<FS_InspectionStatusPayloadDTO.AssignedResourceDTO> members
  ) {
    if (members == null || members.isEmpty()) {
      return;
    }
    FS_InspectionStatusPayloadDTO.AssignedResourceDTO firstMember = members[0];
    payload.estimatedTravelTimeMinutes = firstMember.estimatedTravelTimeMinutes;
    payload.estimatedTravelTimeSeconds = firstMember.estimatedTravelTimeSeconds;
  }

  /**
 * Retrieves formatted site contact details for a given Service Appointment.
 * Returns formatted string "Name, Phone, Email" if found, otherwise returns null.
 */
public static String contactInformation(ServiceAppointment sa) {
    if (sa == null || sa.FS_Work_Order__c == null) {
        return null;
    }

    // Query into a List to safely prevent 'List has no rows for assignment' exceptions
    List<Inspection_Site_Contact__c> siteContacts = [
        SELECT FS_Contact_Name__c, FS_Contact_Phone__c, FS_Contact_Email__c
        FROM Inspection_Site_Contact__c
        WHERE FS_Work_Order__c = :sa.FS_Work_Order__c
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    if (siteContacts.isEmpty()) {
        return null;
    }

    Inspection_Site_Contact__c objSiteContact = siteContacts[0];

    // Build formatted string filtering out null/empty fields dynamically
    List<String> contactDetails = new List<String>();

    if (String.isNotBlank(objSiteContact.FS_Contact_Name__c)) {
        contactDetails.add(objSiteContact.FS_Contact_Name__c);
    }
    if (String.isNotBlank(objSiteContact.FS_Contact_Phone__c)) {
        contactDetails.add(objSiteContact.FS_Contact_Phone__c);
    }
    if (String.isNotBlank(objSiteContact.FS_Contact_Email__c)) {
        contactDetails.add(objSiteContact.FS_Contact_Email__c);
    }

    return contactDetails.isEmpty() ? null : String.join(contactDetails, ', ');
}

  /**
   * @description Maps parent Work Order and Work Order Line Item fields.
   * @param sa Queried Service Appointment.
   * @return Parent work DTO.
   */
  private static FS_InspectionStatusPayloadDTO.ParentWorkDTO buildParentWork(
    ServiceAppointment sa
  ) {
    FS_InspectionStatusPayloadDTO.ParentWorkDTO parentWork = new FS_InspectionStatusPayloadDTO.ParentWorkDTO();
    parentWork.workOrderId = sa.FS_Work_Order__c;
    parentWork.workOrderNumber = sa.FS_Work_Order__r == null
      ? null
      : sa.FS_Work_Order__r.WorkOrderNumber;
    parentWork.bookingReferenceNumber = bookingReference(sa);
    parentWork.workOrderLineItemId = sa.FS_Work_Order_Line_Item__c;
    parentWork.workOrderLineItemNumber = lineItemNumber(sa);
    parentWork.workOrderLineItemExternalRefId = sa.FS_Work_Order_Line_Item__r == null
      ? null
      : sa.FS_Work_Order_Line_Item__r.FS_ExternalRefId__c;
    return parentWork;
  }

  /**
   * @description Maps last-modified user name, username, and employee number.
   * @param sa Queried Service Appointment.
   * @return Audit DTO, or null when LastModifiedBy is not queried.
   */
  private static FS_InspectionStatusPayloadDTO.UserAuditDTO buildAudit(
    ServiceAppointment sa
  ) {
    if (sa.LastModifiedBy == null) {
      return null;
    }
    FS_InspectionStatusPayloadDTO.UserAuditDTO audit = new FS_InspectionStatusPayloadDTO.UserAuditDTO();
    audit.name = sa.LastModifiedBy.Name;
    audit.username = sa.LastModifiedBy.Username;
    audit.employeeNumber = sa.LastModifiedBy.EmployeeNumber;
    return audit;
  }

  /**
   * @description Maps AssignedResource children. Unscheduled appointments send an empty list.
   * @param sa Queried Service Appointment.
   * @param config Parsed CMDT configuration.
   * @return Assigned resource DTOs.
   */
  private static List<FS_InspectionStatusPayloadDTO.AssignedResourceDTO> mapAssignedResources(
    ServiceAppointment sa,
    FS_InspectionStatusEventSettings.Config config
  ) {
    List<FS_InspectionStatusPayloadDTO.AssignedResourceDTO> members = new List<FS_InspectionStatusPayloadDTO.AssignedResourceDTO>();
    if (sa.Status == config.unscheduledStatus || sa.ServiceResources == null) {
      return members;
    }
    for (AssignedResource assignedResource : sa.ServiceResources) {
      members.add(mapAssignedResource(assignedResource, sa));
    }
    return members;
  }

  /**
   * @description Maps one AssignedResource row, including travel time in minutes and seconds.
   * @param assignedResource Assigned Resource with related crew and resource.
   * @param sa Parent appointment, used for scheduled window confirmation.
   * @return Assigned resource DTO.
   */
  private static FS_InspectionStatusPayloadDTO.AssignedResourceDTO mapAssignedResource(
    AssignedResource assignedResource,
    ServiceAppointment sa
  ) {
    FS_InspectionStatusPayloadDTO.AssignedResourceDTO dto = new FS_InspectionStatusPayloadDTO.AssignedResourceDTO();
    dto.recordId = assignedResource.Id;
    dto.serviceCrewId = assignedResource.ServiceCrewId;
    dto.serviceCrewName = assignedResource.ServiceCrew == null
      ? null
      : assignedResource.ServiceCrew.Name;
    dto.serviceResourceId = assignedResource.ServiceResourceId;
    dto.serviceResourceName = assignedResource.ServiceResource == null
      ? null
      : assignedResource.ServiceResource.Name;
    dto.serviceResourceEmployeeNumber = assignedResource.ServiceResource == null ||
      assignedResource.ServiceResource.RelatedRecord == null
      ? null
      : assignedResource.ServiceResource.RelatedRecord.EmployeeNumber;
    dto.estimatedTravelTimeMinutes = assignedResource.EstimatedTravelTime;
    if (assignedResource.EstimatedTravelTime != null) {
      dto.estimatedTravelTimeSeconds = assignedResource.EstimatedTravelTime * 60;
    }
    dto.schedStartTime = sa.SchedStartTime;
    dto.schedEndTime = sa.SchedEndTime;
    return dto;
  }

  /**
   * @description Work Order booking reference used as BookingReferenceNumber.
   * @param sa Queried Service Appointment.
   * @return Booking reference, or null.
   */
  private static String bookingReference(ServiceAppointment sa) {
    if (sa.FS_Work_Order__r == null) {
      return null;
    }
    return sa.FS_Work_Order__r.FS_Booking_Reference__c;
  }

  /**
   * @description Work Order booking notes used as Description.
   * @param sa Queried Service Appointment.
   * @return Booking Notes, or null.
   */
  private static String bookingNotes(ServiceAppointment sa) {
    if (sa.FS_Work_Order__r == null) {
      return null;
    }
    return sa.FS_Work_Order__r.Description;
  }

  /**
   * @description BCO Number from the related BCO Detail record.
   * @param sa Queried Service Appointment.
   * @return BCO Number, or null.
   */
  private static String bcoNumber(ServiceAppointment sa) {
    if (sa.FS_BCO_Detail__r == null) {
      return null;
    }
    return sa.FS_BCO_Detail__r.FS_BCO_Number__c;
  }

  /**
   * @description BCO Property Id from the related BCO Detail record.
   * @param sa Queried Service Appointment.
   * @return BCO Property Id, or null.
   */
  private static String bcoPropertyId(ServiceAppointment sa) {
    if (sa.FS_BCO_Detail__r == null) {
      return null;
    }
    return sa.FS_BCO_Detail__r.FS_Property_ID__c;
  }

   /**
   * @description BCO Property Address from the related BCO Detail record.
   * @param sa Queried Service Appointment.
   * @return BCO Property Address, or null.
   */
  private static String bcoPropertyAddress(ServiceAppointment sa) {
    if (sa.FS_BCO_Detail__r == null) {
      return null;
    }
    return sa.FS_BCO_Detail__r.FS_BCO_PropertyAddress__c;
  }

  /**
   * @description BCO complexity picklist value.
   * @param sa Queried Service Appointment.
   * @return Complexity API value, or null.
   */
  private static String bcoComplexity(ServiceAppointment sa) {
    if (sa.FS_BCO_Detail__r == null) {
      return null;
    }
    return sa.FS_BCO_Detail__r.FS_BCO_Complexity__c;
  }

  /**
   * @description Work Order Line Item number from the parent line item.
   * @param sa Queried Service Appointment.
   * @return Line item number, or null.
   */
  private static String lineItemNumber(ServiceAppointment sa) {
    if (sa.FS_Work_Order_Line_Item__r == null) {
      return null;
    }
    return sa.FS_Work_Order_Line_Item__r.LineItemNumber;
  }
}