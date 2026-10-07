# FS Inspection Data Update — Design

**Status:** implemented and **deployed to AKLCDEVSB4** (Deploy Id `0Af8r00000XThEiCAL`).  
**Tests:** `FS_SaStatusEventHandlerTest` 19/19 passing.  
**Platform event:** `FS_InspectionDataUpdate__e` (existing org event; this package does not recreate it).  
**Publisher:** Field Services Service Appointment after insert and after update (Trigger Actions Framework).  
**Inspector stamp:** Assigned Resource after insert, after update, and after delete. That trigger does not publish.  
**Source API:** 61.0.  
**PDF:** `docs/FS-InspectionDataUpdate-Design.pdf` (this design plus the post-deploy runbook).

This document describes the deployed implementation: when an event is published, how the assigned inspector is stamped, the payload contract, and the **post-deploy steps** for publisher users and subscriber application users.

---

## 1. Purpose

Salesforce publishes one High Volume platform event, `FS_InspectionDataUpdate__e`, so a subscriber application can keep inspection bookings in step with Field Service.

There is a single message type. Confirmation, schedule, reschedule, dispatch, unschedule, and cancel all use header **`EventType__c = InspectionStatusUpdate`**. The JSON body is always `FS_InspectionStatusPayloadDTO`. Properties with no value are omitted.

Travel, OnSite, and Completed status changes do **not** publish by themselves.

### Manual CRM backfill

Do not publish for a Service Appointment that is a **backfill appointment created for a manual booking created in CRM**.

Those backfills are stamped with **Is Manual Inspection** (`FS_IsManualInspection__c = true`) on Work Order, Work Order Line Item, and Service Appointment. The publisher evaluates the **Service Appointment** flag and skips the record.

---

## 2. Goals and non-goals

### Goals

- Do not publish on create. Publish when `FS_Is_Confirmed__c` changes to true on update.
- Publish on **update** when the appointment is dispatched, canceled, fully unscheduled, or scheduled with an inspector and both schedule times that just changed.
- Stamp `ServiceAppointment.FS_Assigned_Inspector__c` from Assigned Resource insert, resource change, and delete, so the schedule event can include the inspector.
- Always set header `EventType__c` to **`InspectionStatusUpdate`**.
- Map the inspection payload and omit null JSON properties.
- Skip `FS_IsManualInspection__c = true` and any record type other than **`Field_Services`**.
- Sit beside Alert Center and FSL triggers. Do not fill parent Work Order lookups.

### Non-goals

- Do not create the platform event object. It already exists in the org.
- Do not publish Travel, OnSite, or Completed unless a rule below also matches (it does not).
- Do not publish solely because arrival window, due date, actuals, or `FS_*` date stamps changed.
- Do not publish from the Assigned Resource trigger. That trigger only writes the inspector lookup.
- Do not publish on Service Appointment insert. `FS_Is_Confirmed__c` is set by an update.
- Do not stamp `FS_IsManualInspection__c` from this package.
- Do not subscribe to the event in this package. The subscriber application is configured in the org after deploy.

---

## 3. Architecture

Salesforce cannot register a trigger on one record type. Both triggers fire for every record of their object. Apex then keeps Field Services appointments that are not manual inspections.

Scheduling is two DMLs. Field Service writes the Service Appointment (status and times) and the Assigned Resource separately. The appointment trigger waits until the inspector lookup and both times are populated, so the subscriber receives **one** schedule event that already contains the inspector and the times.

```
ServiceAppointment after insert / after update
        │
        ▼
FS_SaStatusEventTrigger
        │  new MetadataTriggerHandler().run()
        ▼
Trigger Actions Framework
  sObject_Trigger_Setting.ServiceAppointment
  Trigger_Action.FS_SaStatusEventAfterInsert
  Trigger_Action.FS_SaStatusEventAfterUpdate
        │
        ▼
FS_SaStatusEventHandler
        │
        ├─ Default_Setting.Is_Active__c
        ├─ record type Field_Services
        ├─ FS_IsManualInspection__c is not true
        ├─ resolveEventType (confirm, schedule, dispatch, cancel, unschedule)
        │
        ▼
SOQL (WITH SECURITY_ENFORCED, or SYSTEM_MODE for background users)
        │
        ▼
FS_InspectionStatusEventMapper
        │
        ▼
FS_InspectionDataUpdate__e
  EventType__c = InspectionStatusUpdate
  Payload__c = JSON.serialize(FS_InspectionStatusPayloadDTO, true)


AssignedResource after insert / after update / after delete
        │
        ▼
FS_AssignedResourceInspectorTrigger
        │  new MetadataTriggerHandler().run()
        ▼
Trigger Actions Framework
  sObject_Trigger_Setting.AssignedResource
  Trigger_Action.FS_AssignedInspectorAfterInsert
  Trigger_Action.FS_AssignedInspectorAfterUpdate
  Trigger_Action.FS_AssignedInspectorAfterDelete
        │
        ▼
FS_AssignedResourceInspectorHandler
        │  writes ServiceAppointment.FS_Assigned_Inspector__c only
        ▼
Service Appointment update  →  the publisher above
```

### Packaged members

| Layer | Member | Role |
|---|---|---|
| Trigger | `FS_SaStatusEventTrigger` | TAF runner, Service Appointment after insert and after update |
| Trigger | `FS_AssignedResourceInspectorTrigger` | TAF runner, Assigned Resource after insert, update, and delete |
| Handler | `FS_SaStatusEventHandler` | Decides whether to publish, queries, publishes |
| Handler | `FS_AssignedResourceInspectorHandler` | Stamps `FS_Assigned_Inspector__c`. Does not publish |
| Mapper | `FS_InspectionStatusEventMapper` | Header and JSON payload |
| DTO | `FS_InspectionStatusPayloadDTO` | JSON property names |
| Settings | `FS_InspectionStatusEventSettings` | Reads `FS_Inspection_Status_Event_Setting__mdt` Default_Setting |
| Event | `FS_InspectionDataUpdate__e` | Existing org High Volume event (Publish After Commit). Not deployed by this package |
| Field | `ServiceAppointment.FS_Is_Confirmed__c` | Checkbox. Update publishes when it becomes true. Confidential |
| Field | `ServiceAppointment.FS_Assigned_Inspector__c` | Lookup to ServiceResource. Maintained by the Assigned Resource handler. Confidential |
| Field | `FS_IsManualInspection__c` | On Work Order, Work Order Line Item, and Service Appointment |
| CMDT | `Trigger_Action.FS_SaStatusEventAfterInsert` | Handler on Service Appointment after insert |
| CMDT | `Trigger_Action.FS_SaStatusEventAfterUpdate` | Handler on Service Appointment after update |
| CMDT | `Trigger_Action.FS_AssignedInspectorAfterInsert` | Stamp on Assigned Resource after insert |
| CMDT | `Trigger_Action.FS_AssignedInspectorAfterUpdate` | Stamp on Assigned Resource after update |
| CMDT | `Trigger_Action.FS_AssignedInspectorAfterDelete` | Stamp on Assigned Resource after delete |
| CMDT | `sObject_Trigger_Setting.ServiceAppointment` | TAF sObject setting |
| CMDT | `sObject_Trigger_Setting.AssignedResource` | TAF sObject setting |
| Perm set | `FS_InspectionDataUpdate_Event_Publisher` | Create the event, read payload fields, edit the inspector lookup |

Each Trigger Action record has **one** context. Insert, update, and delete are separate records that point at the same Apex class.

Parent Work Order lookups on the appointment (`FS_Work_Order__c`, `FS_Work_Order_Line_Item__c`) are filled by Alert Center (`FS_ServiceAppointmentTriggerHandler`), not by this package.

---

## 4. Publication rules

`FS_SaStatusEventHandler.resolveEventType` is the only publish decision. The first matching rule wins, so one DML produces at most one event.

These gates apply before any rule:

1. **CMDT** `FS_Inspection_Status_Event_Setting__mdt` / `Default_Setting` has `Is_Active__c` true. If the record is missing, the packaged default is active.
2. **Record type** is `Field_Services`. If that record type is missing, nothing publishes.
3. **`FS_IsManualInspection__c` is not true** on the Service Appointment. The queried row is checked again before the payload is built.

`FS_Is_Confirmed__c` is **not** one of these gates. A later dispatch, cancel, unschedule, or schedule update still publishes when the flag is false.

### Create (after insert)

Insert does not publish. A row created with `FS_Is_Confirmed__c` already true still waits for an update.

### Update (after update)

Compared with the previous row. The first match wins.

| Order | Publish when |
|---|---|
| 1 | `Status` changed to **Dispatched**. Inspector and schedule times are not required. |
| 2 | `Status` changed to **Canceled**. Inspector and schedule times are not required. The org validation still requires `FS_Cancelled_Reason__c` on the DML. |
| 3 | `FS_Is_Confirmed__c` changed to **true**. |
| 4 | `Status` is **None** (CMDT `Unscheduled_Status__c`), `FS_Assigned_Inspector__c` is blank, and either the status or the inspector just changed. |
| 5 | `Status` is **Scheduled**, `FS_Assigned_Inspector__c` is populated, **both** `SchedStartTime` and `SchedEndTime` are populated, and the status, the inspector, or the times just changed. |

A drag onto another resource saves the appointment and the Assigned Resource as separate updates. Both can match rule 5. The handler queues the appointment once and publishes after the transaction commits, so the subscriber receives one event with the final inspector and the final times. If a later save in that same transaction leaves the appointment unpublished, such as status None while the inspector is still set, the job sends nothing.

Rule 5 also covers the Field Service schedule save that only flips `Status` to Scheduled after the inspector and both times are already stored. It still covers these cases with one event:

- A new inspector on an appointment that already has both times.
- New times on an appointment that already has an inspector.
- A new inspector and new times in the same update.

### Why schedule is one event

Field Service often saves the appointment and the Assigned Resource as separate transactions.

- The appointment update that sets Scheduled and the times does **not** publish while `FS_Assigned_Inspector__c` is still blank.
- The Assigned Resource trigger then writes the lookup. That Service Appointment update publishes, and the payload is queried after the stamp, so it includes the inspector and both times.
- If the inspector is stamped before the times exist, the later update that fills both times publishes instead.

A status change to None while the inspector is still populated does not publish. Clearing the inspector while status is still Scheduled does not publish. The unschedule event is published once both are true.

### Explicit non-publish cases

| Situation | Result |
|---|---|
| Record type is not Field_Services | Skip |
| `FS_IsManualInspection__c = true` | Skip |
| Default Setting inactive | Skip |
| Service Appointment insert, confirmed or not | Skip |
| Status becomes Scheduled but inspector or either schedule time is blank | Skip |
| Only `ArrivalWindowStartTime` / `ArrivalWindowEndTime` changed | Skip |
| Only DueDate, EarliestStartTime, actuals, or FS_* date stamps changed | Skip |
| Status becomes Travel, OnSite, or Completed, with no other matching change | Skip |
| Status becomes None while the inspector lookup is still populated | Skip |
| Inspector lookup cleared while status is still Scheduled | Skip |
| Already Canceled or Dispatched, and status did not change on this update | Skip |
| Assigned Resource travel-time-only update | Lookup unchanged, so the appointment trigger does not publish |

### Field Services statuses (AKLC picklist)

`None`, `Scheduled`, `Dispatched`, `Travel`, `OnSite`, `Completed`, `Canceled`.

There is no `In Progress` or `Cannot Complete` on this record type. Spreadsheet “Onsite” is **OnSite**. `FS_Inspection_Status__c` (including OPEN) is a payload field. It is not a publish trigger.

---

## 5. Assigned inspector stamp

`FS_AssignedResourceInspectorHandler` maintains `ServiceAppointment.FS_Assigned_Inspector__c` (lookup to ServiceResource, delete constraint SetNull, relationship `FS_Assigned_Inspections`).

| Assigned Resource DML | Lookup result |
|---|---|
| Insert with a Service Resource | Set the lookup to that Service Resource. The last row in the batch wins if several appointments share one trigger invocation for the same appointment. |
| Update that changes `ServiceResourceId` | Set the lookup to the new Service Resource. |
| Update that does not change `ServiceResourceId` (for example travel time) | No Service Appointment write. |
| Insert or update with a blank Service Appointment or blank Service Resource | Ignored. |
| Delete, and other Assigned Resources remain | Keep the Service Resource on the earliest remaining row (`CreatedDate` ascending). |
| Delete, and none remain | Clear the lookup. |

Other filters:

- Only Field Services appointments are updated.
- The write is skipped when the lookup already equals the desired value, so the appointment trigger does not fire again for the same inspector.
- `stampInProgress` stops the appointment update from re-entering the stamp in the same transaction.
- A listed assignment wins over a clear. Apex maps cannot store a null Id, so clears are a separate set.

Interactive users need update access to `FS_Assigned_Inspector__c` (granted by the publisher permission set). `CloudIntegrationUser` and `AutomatedProcess` cannot be granted that FLS, so their stamp DML runs in system mode. Tests use the same bypass.

---

## 6. Confirmation

`ServiceAppointment.FS_Is_Confirmed__c` is an existing checkbox, label **Is Confirmed**, default false. This package retrieved it and set security classification Confidential.

The booking process sets the flag on an **update**, not on insert. That update publishes one event when the flag changes to true. Insert does not publish, even if the new row is already confirmed. Dispatch, cancel, unschedule, and schedule updates still publish if the flag is left false.

The publisher permission set grants **read** on this field, not edit. The user or automation that confirms the booking needs edit from its own profile or permission set.

---

## 7. Manual inspection flag

| Object | API name | Label | Type | Default |
|---|---|---|---|---|
| WorkOrder | `FS_IsManualInspection__c` | Is Manual Inspection | Checkbox | false |
| WorkOrderLineItem | `FS_IsManualInspection__c` | Is Manual Inspection | Checkbox | false |
| ServiceAppointment | `FS_IsManualInspection__c` | Is Manual Inspection | Checkbox | false |

All three are packaged so CRM can stamp the same meaning on the booking hierarchy. **Publication reads only the Service Appointment field.** Classification is Confidential.

The process that creates a manual CRM booking and its Field Service backfill appointment must set the flag true on the Work Order, the Work Order Line Item, and the Service Appointment. If the Service Appointment flag is left false, this publisher treats the appointment as a normal inspection and emits events.

The publisher permission set grants **read and edit** on the three fields.

---

## 8. Platform event contract

Object: `FS_InspectionDataUpdate__e`  
Volume: High Volume  
Publish behaviour: **Publish After Commit**

### Header

| Event field | Source | Notes |
|---|---|---|
| `EventType__c` | CMDT `Event_Type__c` | Always `InspectionStatusUpdate` in the packaged default |
| `BookingReferenceNumber__c` | `WorkOrder.FS_Booking_Reference__c` | Via `FS_Work_Order__r` |
| `InspectionId__c` | `ServiceAppointment.FS_ExternalRefId__c` | Same value as payload `sfsInspectionId` |
| `WorkOrderId__c` | `ServiceAppointment.FS_Work_Order__c` | |
| `WorkOrderLineItemId__c` | `ServiceAppointment.FS_Work_Order_Line_Item__c` | |
| `ServiceAppointmentId__c` | `ServiceAppointment.Id` | |
| `Payload__c` | JSON from `FS_InspectionStatusPayloadDTO` | Null properties omitted |

The subscriber should key off **`EventType__c = InspectionStatusUpdate`** and read payload `status`, `assignedInspectorId`, and the schedule fields. Do not expect `InspectionCancellation` or `InspectionUpdate`.

---

## 9. Payload (`FS_InspectionStatusPayloadDTO`)

Serialization: `JSON.serialize(payload, true)`. A property is present only when it has a value. `assignedCrewMembers` is omitted when the list is empty, including unscheduled `None`.

`eventType` inside the JSON matches the header (`InspectionStatusUpdate`).

Apex is case-insensitive, so the DTO cannot expose both `userName` and `username`. Display name is **`lastModifiedBy.name`**. Login is **`lastModifiedBy.username`**.

| Payload key | Salesforce source |
|---|---|
| `eventType` | Header event type |
| `status` | `ServiceAppointment.Status` |
| `appointmentNumber` | `AppointmentNumber` |
| `priority` | `Priority__c` |
| `bookingReferenceNumber` | `WorkOrder.FS_Booking_Reference__c` |
| `bookingNotes` | `WorkOrder.Description` |
| `crmInspectionId` | `ServiceAppointment.FS_CRMInspection_Id__c` |
| `sfsInspectionId` | `ServiceAppointment.FS_ExternalRefId__c` |
| `bcoNumber` | `BCO_Detail__c.FS_BCO_Number__c` |
| `propertyId` | `BCO_Detail__c.FS_Property_ID__c` |
| `propertyAddress` | `BCO_Detail__c.FS_BCO_PropertyAddress__c` |
| `workOrderLineItemNumber` | `WorkOrderLineItem.LineItemNumber` |
| `workTypeName` | `WorkType.Name` |
| `inspectionType` | `WorkType.Name` text before the first `_` |
| `contactInformation` | First `Inspection_Site_Contact__c` for the Work Order: name, phone, and email joined with a comma. Queried in system mode |
| `bcoComplexity` | `BCO_Detail__c.FS_BCO_Complexity__c` |
| `arrivalWindowStartTime` / `arrivalWindowEndTime` | `ArrivalWindowStartTime` / `ArrivalWindowEndTime` |
| `schedStartTime` / `schedEndTime` | `SchedStartTime` / `SchedEndTime` |
| `dispatchedDate` | `FS_Dispatched_Date__c` |
| `dueDate` | `DueDate` |
| `earliestStartTime` | `EarliestStartTime` |
| `cancelledDate` | `FS_Cancelled_Date__c` |
| `travelDate` | `FS_Travel_Date__c` |
| `onSiteDate` | `FS_OnSite_Date__c` |
| `completedDate` | `FS_Completed_Date__c` |
| `estimatedTravelTimeMinutes` | First `AssignedResource.EstimatedTravelTime` (minutes) |
| `estimatedTravelTimeSeconds` | Minutes × 60 |
| `inJeopardy` | `FSL__InJeopardy__c` |
| `inJeopardyReason` | `FSL__InJeopardyReason__c` |
| `inspectionStatus` | `FS_Inspection_Status__c` |
| `cancelledReason` | `FS_Cancelled_Reason__c` |
| `bookingType` | `FS_Booking_Type__c` |
| `isConfirmed` | `FS_Is_Confirmed__c` is true |
| `assignedInspectorId` | `FS_Assigned_Inspector__c` |
| `assignedInspectorName` | `FS_Assigned_Inspector__r.Name` |
| `parentWork.*` | Work Order and WOLI ids and numbers |
| `lastModifiedBy.name` / `username` / `employeeNumber` | `LastModifiedBy` |
| `assignedCrewMembers[]` | `AssignedResource` related list, omitted when status is the unscheduled value |

### Nested `parentWork`

| Key | Source |
|---|---|
| `workOrderId` | `FS_Work_Order__c` |
| `workOrderNumber` | `FS_Work_Order__r.WorkOrderNumber` |
| `bookingReferenceNumber` | `FS_Work_Order__r.FS_Booking_Reference__c` |
| `workOrderLineItemId` | `FS_Work_Order_Line_Item__c` |
| `workOrderLineItemNumber` | `FS_Work_Order_Line_Item__r.LineItemNumber` |
| `workOrderLineItemExternalRefId` | `FS_Work_Order_Line_Item__r.FS_ExternalRefId__c` |

### Nested `assignedCrewMembers[]`

| Key | Source |
|---|---|
| `recordId` | `AssignedResource.Id` |
| `serviceCrewId` / `serviceCrewName` | `ServiceCrew` |
| `serviceResourceId` / `serviceResourceName` | `ServiceResource` |
| `serviceResourceEmployeeNumber` | `ServiceResource.RelatedRecord.EmployeeNumber` |
| `estimatedTravelTimeMinutes` / `estimatedTravelTimeSeconds` | `EstimatedTravelTime` |
| `schedStartTime` / `schedEndTime` | Parent appointment schedule |

When status is the configured unscheduled value (`None`), assigned resources are not added. `assignedInspectorId` is also absent on that event because the unschedule rule requires the lookup to be blank.

### Schema gaps (not mapped)

| Spreadsheet idea | Org reality | Payload |
|---|---|---|
| WorkOrder `FS_Sequence__c` | Field does not exist | `workOrderLineItemNumber` |
| ServiceResource `FS_ExternalRefId__c` | Field does not exist | related User `EmployeeNumber` |
| AssignedResource external key | No field | Omitted |
| Separate cancellation event type | Not used | Same `InspectionStatusUpdate`; read `status` and `cancelledReason` |

Travel time in Salesforce is **minutes**. Field Service may recalculate `EstimatedTravelTime` after assign.

---

## 10. Class design

### `FS_SaStatusEventHandler`

Implements `TriggerAction.AfterInsert` and `TriggerAction.AfterUpdate`.

| Method | Responsibility |
|---|---|
| `afterInsert` / `afterUpdate` | Cast the TAF lists and call `handleTrigger` |
| `handleTrigger` | Active setting, Field Services filter, `resolveEventType`, query, map, publish |
| `isPublishableAppointment` | Field_Services and not a manual inspection |
| `resolveEventType` | No create. Confirm, Dispatched, Canceled, finished unschedule, or Scheduled with inspector and both times |
| `queryAppointments` | Payload SOQL. `WITH SECURITY_ENFORCED`, with a system-mode retry when FLS blocks a payload field |
| `excludeManualInspections` | Second pass on the queried rows |
| `publishEvents` | `EventBus.publish`. Tests also capture `publishedEventsForTest` |

Background users `CloudIntegrationUser` and `AutomatedProcess` cannot be granted FLS. Those user types, and a test hook, query and publish in system mode. If an interactive user can read Service Appointment but lacks FLS on a payload field such as `EmployeeNumber`, the query retries in system mode so scheduling is not blocked.

Org automation on Service Appointment after create requires `FS_BCO_Detail__c`. That flow is not part of this package. Tests and smoke tests must populate BCO Detail.

### `FS_AssignedResourceInspectorHandler`

Implements `TriggerAction.AfterInsert`, `AfterUpdate`, and `AfterDelete`. See section 5. It does not call `EventBus.publish`.

### `FS_InspectionStatusEventMapper`

Builds the platform event and the DTO. Null properties stay null so JSON suppress-nulls drops them.

### `FS_InspectionStatusEventSettings`

Reads `Default_Setting`. Blank `Event_Type__c` falls back to `InspectionStatusUpdate`. Blank `Unscheduled_Status__c` falls back to `None`. Tests inject `settingsOverride` or `forceMissingSettingForTest`.

---

## 11. Configuration (`FS_Inspection_Status_Event_Setting__mdt`)

Record **Default Setting** (deployed):

| Field | Packaged default | Purpose |
|---|---|---|
| `Is_Active__c` | true | Master publish switch. Does not change which rules match |
| `Event_Type__c` | `InspectionStatusUpdate` | Header and payload `eventType` |
| `Unscheduled_Status__c` | `None` | Status used by the unschedule rule, and the status that omits assigned crew |
| `Scope_To_Field_Services_Record_Type__c` | true | Layout compatibility. Apex always requires Field_Services |
| `Description__c` | (text) | Admin notes |

`Unscheduled_Status__c` does not by itself decide whether to publish. It names the status that means “unscheduled” inside the unschedule rule.

There is no tracked-status allowlist. The rules in section 4 are the allowlist.

---

## 12. Security and permission assignments

Permission set **`FS_InspectionDataUpdate_Event_Publisher`** is the **publisher** set. It is not the subscriber set. This package does not deploy a second permission set for the subscriber application.

### 12.1 What the publisher set grants

- Apex class access: `FS_SaStatusEventHandler`, `FS_AssignedResourceInspectorHandler`, `FS_InspectionStatusEventMapper`, `FS_InspectionStatusEventSettings`, `FS_InspectionStatusPayloadDTO`
- Object **Create and Read** on `FS_InspectionDataUpdate__e`
- Object **Read** on `BCO_Detail__c`
- Record type visibility `ServiceAppointment.Field_Services`
- **Read and edit** `ServiceAppointment.FS_Assigned_Inspector__c` (the stamp writes this field)
- **Read and edit** `FS_IsManualInspection__c` on Work Order, Work Order Line Item, and Service Appointment
- **Read** (not edit) `ServiceAppointment.FS_Is_Confirmed__c`
- **Read** (not edit) `ServiceAppointment.Status`
- **Read** (not edit) `WorkOrder.FS_Booking_Reference__c`
- **Read** on the other payload fields packaged on the set: BCO number and complexity, booking type, cancelled date and reason, completed / dispatched / onsite / travel dates, external ref, inspection status, parent Work Order and WOLI lookups, priority, and WOLI external ref

Platform-event **field** permissions are not listed on this set. Required event fields are available with object Create/Read. Do not add field permissions for required event fields if the deploy rejects them.

Custom fields created or updated in this package use `securityClassification` **Confidential**.

### 12.2 Who must receive the publisher set

Assign `FS_InspectionDataUpdate_Event_Publisher` to every **interactive** user who:

- creates a confirmed Field Services appointment,
- dispatches, cancels, unschedules, or reschedules one, or
- assigns or removes an Assigned Resource (so the inspector lookup can be updated).

Typical assignees:

- Field Service dispatchers
- Field resources and mobile users who change status to Dispatched or Canceled
- CRM or booking users who insert a confirmed appointment, if that insert runs as that user
- An integration user that **updates** Service Appointments or Assigned Resources and must cause a publish

Do **not** assign this set to `CloudIntegrationUser` or `AutomatedProcess`. Those user types cannot take the Field Service field permissions. The handler and the stamp already use system mode for them.

The user who sets `FS_Is_Confirmed__c` also needs **edit** on that checkbox from a profile or another permission set. This publisher set only grants read.

### 12.3 Subscriber application users

The subscriber application reads the event. It does not need to create it, and it does not need the publisher Apex classes, unless that same user also updates appointments.

For the integration user, connected app user, or platform-event subscriber user:

1. Grant **Read** on `FS_InspectionDataUpdate__e`.
2. Do **not** grant Create unless that user is also a publisher.
3. Do **not** assign `FS_InspectionDataUpdate_Event_Publisher` only to “listen.” That set is for users who cause publishes.
4. If the subscriber uses a Flow, Apex trigger, or Emp API / Pub/Sub client running as a named user, that user needs Read on the event and Read on any event fields the client selects. Required fields are included with object Read.
5. If the subscriber is an external application, store its credentials in that application’s secret store. This package does not contain endpoints, tokens, or subscriber credentials.
6. Point the subscriber at **`FS_InspectionDataUpdate__e`** only. Branch on `EventType__c = InspectionStatusUpdate`. Use payload `status` to tell create, Scheduled, Dispatched, None, and Canceled apart.
7. Treat a missing JSON key as null. Read `assignedInspectorId` and `assignedInspectorName` for the inspector. Read `sfsInspectionId` for the Field Service external id and `crmInspectionId` for the CRM id. Header `InspectionId__c` matches `sfsInspectionId`.
8. Read `lastModifiedBy.name` as the display name and `lastModifiedBy.username` as the login.
9. On an unschedule event, expect `status` = `None`, no `assignedInspectorId`, and no `assignedCrewMembers`.
10. On a cancel event, expect `status` = `Canceled` and `cancelledReason` when the org validation supplied one.

Give the subscriber user no edit rights on Service Appointment, Assigned Resource, or `FS_Assigned_Inspector__c` unless that user is also allowed to change bookings.

---

## 13. Tests (`FS_SaStatusEventHandlerTest`)

Deploy `0Af8r00000XThEiCAL` ran this class: **19 passed, 0 failed**.

Tests call the handlers directly so they do not depend on TAF metadata delivery timing. DML still runs Field Service status transitions and the real Assigned Resource trigger. Setup creates Operating Hours, a Service Territory, a Work Order, a Work Order Line Item, a BCO Detail, and a Field Services Service Appointment in status None.

| Test | Expectation |
|---|---|
| `testParentLookupsPopulatedOnInsert` | Alert Center copied the parent Work Order and WOLI lookups |
| `testCreateDoesNotPublish` | Insert does not publish, even when already confirmed |
| `testConfirmedUpdatePublishesEvent` | Setting Is Confirmed on update publishes |
| `testStatusBecomesScheduledPublishesEvent` | Status None to Scheduled publishes when inspector and both times are already set |
| `testNewInspectorAndNewTimesPublishesEvent` | One event with the new inspector and both times |
| `testScheduleChangeOnScheduledPublishesEvent` | Same inspector, new times, one event |
| `testInspectorChangePublishesEvent` | Inspector change on a Scheduled appointment with both times publishes |
| `testScheduledWithoutTimesDoesNotPublish` | Scheduled with an inspector and no times does not publish |
| `testArrivalWindowOnlyDoesNotPublish` | Arrival window only does not publish |
| `testDispatchedPublishesEvent` | Status change to Dispatched publishes |
| `testCanceledStatusPublishesEvent` | Status change to Canceled publishes, with `cancelledReason` |
| `testUnscheduleDoesNotPublish` | Status None while the inspector is still set does not publish |
| `testUnschedulePublishesWhenInspectorCleared` | Status None and a blank inspector publishes one event |
| `testAssignedResourceStampsInspector` | Insert stamps the lookup, resource change updates it, travel-only does not, deleting the last row clears it |
| `testAssignedResourceTravelIsMapped` | Payload includes crew members and travel minutes |
| `testNonFieldServicesRecordTypeDoesNotPublish` | Other record types do not publish |
| `testManualInspectionDoesNotPublish` | Manual inspection does not publish |
| `testInactiveSettingDoesNotPublish` | Inactive CMDT publishes nothing |
| `testSettingsDefaultWhenMissing` | Missing CMDT defaults to active, `InspectionStatusUpdate`, and `None` |
| `testBlankSettingFieldsAndEmptyTrigger` | Blank CMDT text uses the same defaults |

Cancel DML in the test sets `FS_Cancelled_Reason__c` because the org requires a cancellation reason. A second technician is created for the stamp test because `ServiceResource.RelatedRecordId` is required and is unique per user.

---

## 14. Post-deploy manual steps (AKLCDEVSB4)

Metadata deploy does **not** assign permission sets, add fields to page layouts, set `FS_Is_Confirmed__c`, stamp CRM backfills, or connect the subscriber application.

### 14.1 Assign the publisher permission set

1. Setup → Users → Permission Sets → **`FS_InspectionDataUpdate_Event_Publisher`**.
2. Manage Assignments. Assign it to the users in section 12.2 (dispatchers, field users who dispatch or cancel, booking users who insert confirmed appointments, and integration users that update appointments or Assigned Resources).
3. Leave `CloudIntegrationUser` and `AutomatedProcess` unassigned.

Without this assignment, an interactive user fails the payload query or cannot create `FS_InspectionDataUpdate__e`, and an assignment done by that user cannot update `FS_Assigned_Inspector__c`.

### 14.2 Let the confirmation process edit Is Confirmed

1. Identify the profile, permission set, or automation that sets **Is Confirmed** (`FS_Is_Confirmed__c`).
2. Grant that process **edit** on `ServiceAppointment.FS_Is_Confirmed__c`.
3. Leave the publisher set as read-only for this field.

Insert stays silent. The update that sets the flag to true publishes.

### 14.3 Subscriber application user

1. Create or identify the integration user the subscriber application runs as.
2. Grant that user **Read** on `FS_InspectionDataUpdate__e` only.
3. Do not assign the publisher permission set unless that same user also updates Service Appointments.
4. Configure the subscriber to consume `FS_InspectionDataUpdate__e` and to treat `EventType__c = InspectionStatusUpdate` as the only type.
5. Confirm the subscriber maps the payload keys in section 9, including `assignedInspectorId`, `sfsInspectionId`, `crmInspectionId`, `cancelledReason`, and `isConfirmed`.
6. Keep subscriber credentials outside this repository.

### 14.4 Page layouts

The new and existing checkboxes are not added to layouts by this deploy.

1. Work Order layout used by CRM booking: **Is Manual Inspection**.
2. Work Order Line Item layout used by CRM booking: **Is Manual Inspection**.
3. Service Appointment Field Services layout:
   - **Is Manual Inspection** — editable for the CRM backfill process.
   - **Is Confirmed** — editable for the booking process that confirms on update.
   - **Assigned Inspector** — show it so dispatchers can see the stamped Service Resource. Prefer read-only on the layout. The Assigned Resource trigger overwrites a manual edit on the next assign or unassign.

### 14.5 Confirm Default Setting

1. Setup → Custom Metadata Types → FS Inspection Status Event Setting → Manage Records → **Default Setting**.
2. Confirm **Is Active** = true, **Event Type** = `InspectionStatusUpdate`, **Unscheduled Status** = `None`.
3. Set Is Active false only as an emergency kill switch. It stops every publish, including cancel and dispatch.

### 14.6 Confirm Trigger Actions Framework wiring

Service Appointment:

1. **sObject Trigger Setting** `ServiceAppointment`: Bypass Execution = false, Object API Name = `ServiceAppointment`.
2. **Trigger Action** `FS_SaStatusEventAfterInsert`: After Insert only, Apex Class `FS_SaStatusEventHandler`, Bypass Execution = false.
3. **Trigger Action** `FS_SaStatusEventAfterUpdate`: After Update only, same class, Bypass Execution = false.
4. Each action has one context. Do not put After Insert and After Update on the same Trigger Action record.

Assigned Resource:

1. **sObject Trigger Setting** `AssignedResource`: Bypass Execution = false, Object API Name = `AssignedResource`.
2. **Trigger Action** `FS_AssignedInspectorAfterInsert`, `FS_AssignedInspectorAfterUpdate`, and `FS_AssignedInspectorAfterDelete`: one context each, Apex Class `FS_AssignedResourceInspectorHandler`, Bypass Execution = false.

Both objects:

1. Confirm only one unpackaged trigger on each object calls `new MetadataTriggerHandler().run()`. A second runner double-fires the actions.
2. Leave FSL-managed `TR001_Service_*` and `TR021_AssignedResource_*`, and Alert Center `FS_ServiceAppointmentTrigger`, in place.

### 14.7 CRM manual-booking backfill

When CRM creates a manual booking and a Field Service backfill appointment, set **`FS_IsManualInspection__c = true`** on the Work Order, the Work Order Line Item, and the Service Appointment. If the Service Appointment flag stays false, events will publish.

Optional data fix: set the checkbox on historical backfill appointments so they stop emitting.

### 14.8 Smoke test

Use a Field Services appointment with BCO Detail populated.

| Step | Action | Expected |
|---|---|---|
| 1 | Insert, whether or not **Is Confirmed** is true | No event |
| 2 | Update **Is Confirmed** from false to true | One event, `isConfirmed` true |
| 3 | Set status **Scheduled**, both schedule times, and assign a Service Resource | One event after the inspector lookup is stamped. Payload has `assignedInspectorId`, `schedStartTime`, and `schedEndTime`. No second event for the incomplete save |
| 4 | Change **SchedStartTime** or **SchedEndTime** only, same inspector | One event with the new times |
| 5 | Change the assigned Service Resource only | One event with the new `assignedInspectorId` |
| 6 | Change the arrival window only | No event |
| 7 | Status **Dispatched** | One event, `status` = Dispatched |
| 8 | Status **Canceled**, with a cancellation reason | One event, `status` = Canceled, `cancelledReason` populated |
| 9 | Unschedule: status **None** while the inspector is still set | No event yet |
| 10 | Remove the Assigned Resource so the inspector lookup clears, status **None** | One event, `status` = None, no `assignedInspectorId` |
| 11 | Check **Is Manual Inspection**, then change status | No event |
| 12 | Repeat step 3 as a dispatcher with the publisher set, and as the subscriber user | Dispatcher publish succeeds. Subscriber user can read the event and cannot be required to create it |

---

## 15. Sign-off

- [ ] Publisher permission set assigned to dispatcher, field, booking, and publisher integration users
- [ ] Confirmation process can edit `FS_Is_Confirmed__c`
- [ ] Subscriber application user has Read on `FS_InspectionDataUpdate__e` and does not have Create unless that user also publishes
- [ ] Subscriber maps `InspectionStatusUpdate`, `status`, inspector, schedule, and cancellation fields
- [ ] Is Manual Inspection on WO, WOLI, and Field Services SA layouts
- [ ] Is Confirmed and Assigned Inspector on the Field Services SA layout
- [ ] Default Setting active, Event Type `InspectionStatusUpdate`, Unscheduled Status `None`
- [ ] SA after-insert and after-update actions, and the three Assigned Resource actions, are not bypassed
- [ ] No second `MetadataTriggerHandler` on Service Appointment or Assigned Resource
- [ ] CRM stamps `FS_IsManualInspection__c` on manual backfills
- [ ] Smoke tests 1–12 passed

---

## 16. What this deploy does not include

- `FS_InspectionDataUpdate__e` object and fields (already in the org)
- Alert Center `FS_Work_Order__c`, `FS_Work_Order_Line_Item__c`, `Priority__c`
- Record type `ServiceAppointment.Field_Services` (already in the org; not in `manifest/package.xml`)
- TAF object definitions (`Trigger_Action__mdt`, `sObject_Trigger_Setting__mdt`). This package deploys the Service Appointment and Assigned Resource **records** only
- A subscriber permission set, a named credential, or subscriber credentials
- Alert Center and FSL managed trigger bodies
