/**
 * @description JSON payload for FS_InspectionDataUpdate__e. Property names match
 * the Salesforce schema used by Field Services appointments.
 */
public class FS_InspectionStatusPayloadDTO {
  public String eventType;
  public String status;
  public String appointmentNumber;
  public String priority;
  public String bookingReferenceNumber;
  public String bookingNotes;
  public String crmInspectionId;
  public String sfsInspectionId;
  public String bcoNumber;
  public String propertyId;
  public String propertyAddress;
  public String manufacturerBPID;
  public String manufacturerName;
  public String workOrderLineItemNumber;
  public String workTypeName;
  public String inspectionType;
  public String contactInformation;
  public String bcoComplexity;
  public Datetime arrivalWindowStartTime;
  public Datetime arrivalWindowEndTime;
  public Datetime schedStartTime;
  public Datetime schedEndTime;
  public Datetime dispatchedDate;
  public Datetime dueDate;
  public Datetime earliestStartTime;
  public Datetime cancelledDate;
  public Datetime travelDate;
  public Datetime onSiteDate;
  public Datetime completedDate;
  public Decimal estimatedTravelTimeMinutes;
  public Decimal estimatedTravelTimeSeconds;
  public Boolean inJeopardy;
  public String inJeopardyReason;
  public String inspectionStatus;
  public String cancelledReason;
  public String bookingType;
  public Boolean isConfirmed;
  public Boolean isManualInspection;
  public Id assignedInspectorId;
  public String assignedInspectorName;
  public ParentWorkDTO parentWork;
  public UserAuditDTO lastModifiedBy;
  public List<AssignedResourceDTO> assignedCrewMembers;
  

  /**
   * @description Parent Work Order and Work Order Line Item identifiers and numbers.
   */
  public class ParentWorkDTO {
    public String workOrderId;
    public String workOrderNumber;
    public String bookingReferenceNumber;
    public String workOrderLineItemId;
    public String workOrderLineItemNumber;
    public String workOrderLineItemExternalRefId;
  }

  /**
   * @description Last-modified user details captured at publish time.
   */
  public class UserAuditDTO {
    public String name;
    public String username;
    public String employeeNumber;
  }

  /**
   * @description Assigned Resource row included in the payload.
   */
  public class AssignedResourceDTO {
    public Id recordId;
    public Id serviceCrewId;
    public String serviceCrewName;
    public Id serviceResourceId;
    public String serviceResourceName;
    public String serviceResourceEmployeeNumber;
    public Decimal estimatedTravelTimeMinutes;
    public Decimal estimatedTravelTimeSeconds;
    public Datetime schedStartTime;
    public Datetime schedEndTime;
  }
}