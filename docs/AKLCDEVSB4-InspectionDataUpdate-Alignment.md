# AKLCDEVSB4 Inspection Data Update — org notes

Implementation design lives in **`docs/FS-InspectionDataUpdate-Design.md`**. This file keeps the org findings that shaped the package.

**Org:** AKLCDEVSB4 (read-only describe/retrieve). **No deploy** from this repository unless separately approved.

## Platform event

`FS_InspectionDataUpdate__e` (label Inspection Data Update) already exists:

- High Volume, **Publish After Commit**
- Fields: `BookingReferenceNumber__c`, `InspectionId__c`, `EventType__c`, `Payload__c`, `WorkOrderId__c`, `WorkOrderLineItemId__c`, `ServiceAppointmentId__c`

Spreadsheet objects `InspectionStatusUpdate__e`, `InspectionCancellation__e`, and `InspectionUpdate__e` are **not** in the org. This package uses **one** `EventType__c` value: **`InspectionStatusUpdate`**.

## Service Appointment triggers

| Trigger | Namespace | Role |
|---|---|---|
| `FS_ServiceAppointmentTrigger` | unpackaged | Alert Center: parent lookups, alerts, BCO counts |
| `FS_SaStatusEventTrigger` (this package) | unpackaged | TAF runner (`MetadataTriggerHandler.run`) |
| `TR001_Service_*` | FSL managed | Field Service internal automation |
| `CalculateTravelTimeOnServiceChange` | FSL managed | Travel time |

`FS_SaStatusEventTrigger` fires for every Service Appointment after update. `FS_SaStatusEventHandler` publishes only for **Field_Services** and only when `FS_IsManualInspection__c` is false.

TAF pattern in the org (`BCO_Customer_Access__c`): unpackaged trigger calls `new MetadataTriggerHandler().run()`; handler implements `TriggerAction.*`; CMDT binds the class.

Parent lookup fill stays in `FS_ServiceAppointmentTriggerHandler.populateParentFields`.

## Field Services statuses

`None`, `Scheduled`, `Dispatched`, `Travel`, `OnSite`, `Completed`, `Canceled`. No `In Progress` / `Cannot Complete`.

## Inspection fields used in the payload

| Object | Field | Use |
|---|---|---|
| WorkOrder | `FS_Booking_Reference__c` | Booking reference |
| WorkOrderLineItem | `FS_ExternalRefId__c` | Line-item inspection id |
| ServiceAppointment | `FS_ExternalRefId__c` | Inspection Id |
| ServiceAppointment | `FS_BCO_Detail__c` | BCO lookup |
| BCO_Detail__c | `FS_BCO_Number__c` / `FS_BCO_Complexity__c` | Consent number / complexity |
| ServiceAppointment | `FS_Dispatched_Date__c`, `FS_Cancelled_Date__c`, `FS_Travel_Date__c`, `FS_OnSite_Date__c`, `FS_Completed_Date__c` | Status timestamps |
| ServiceAppointment | `FS_Booking_Type__c`, `FS_Inspection_Status__c`, `FS_Cancelled_Reason__c`, `FS_Is_Confirmed__c` | Inspection attributes |
| ServiceAppointment | `FSL__InJeopardy__c`, `FSL__InJeopardyReason__c` | Jeopardy |
| AssignedResource | `EstimatedTravelTime` | Minutes in Salesforce |

## Tracker correction

An earlier draft treated a “do not publish” rule as a portal-creator filter on Completed. The tracker intent is: **skip backfill appointments for manual CRM bookings**, implemented as `FS_IsManualInspection__c` on Work Order, Work Order Line Item, and Service Appointment.

## What this package does not do

- No deploy to AKLCDEVSB4 from this work.
- TAF object definitions are not packaged; they already exist.
- Alert Center and FSL managed triggers are not modified.
- CRM still owns stamping `FS_IsManualInspection__c` when it creates a manual backfill.
