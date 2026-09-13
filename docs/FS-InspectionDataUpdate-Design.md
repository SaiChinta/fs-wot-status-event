# FS Inspection Data Update — Design

**Status:** implemented and **deployed to AKLCDEVSB4** (Deploy Id `0Af8r00000WnGE6CAN`).  
**Tests:** `FS_SaStatusEventHandlerTest` 12/12 passing.  
**Platform event:** `FS_InspectionDataUpdate__e` (existing org event; not overwritten).  
**Publisher:** Field Services Service Appointment after-update (Trigger Actions Framework).  
**Source API:** 61.0.  
**PDF:** `docs/FS-InspectionDataUpdate-Design.pdf` (design + post-deploy runbook).

This document describes the current implementation: when an event is published, what is skipped, the payload contract, the classes that implement it, and the **post-deploy manual steps** required in AKLCDEVSB4.

---

## 1. Purpose

When a **Field Services** inspection appointment changes **status** or **scheduled start / scheduled end**, Salesforce publishes one High Volume platform event so middleware can update downstream systems.

There is a single message type. Cancellation, completion, dispatch, travel, on-site, and a reschedule of `SchedStartTime` / `SchedEndTime` all use **`InspectionStatusUpdate`**. The JSON body always uses the same `FS_InspectionStatusPayloadDTO` shape. Properties with no value are omitted.

### Tracker interpretation (manual CRM backfill)

The tracker item is **not** “only portal-created completions.” It is:

> Do not publish for a Service Appointment that is a **backfill appointment created for a manual booking created in CRM**.

Those backfills are stamped with **Is Manual Inspection** (`FS_IsManualInspection__c = true`) on Work Order, Work Order Line Item, and Service Appointment. The publisher evaluates the **Service Appointment** flag and skips the record.

---

## 2. Goals and non-goals

### Goals

- Publish `FS_InspectionDataUpdate__e` after Field Services appointment **status** changes (including Canceled and unscheduled `None`).
- Also publish when **`SchedStartTime`** or **`SchedEndTime`** changes, even if status is unchanged.
- Always set header `EventType__c` to **`InspectionStatusUpdate`**.
- Map the full inspection payload; omit null JSON properties.
- Ignore appointments with `FS_IsManualInspection__c = true`.
- Ignore appointments that are not record type **`Field_Services`**.
- Sit beside existing Alert Center and FSL triggers; do not duplicate parent-lookup fill.

### Non-goals

- Do not create additional platform event objects.
- Do not publish on insert (after update only).
- Do not publish solely because arrival window, due date, actuals, or `FS_*` date stamps changed.
- Do not publish Assigned Resource–only DML (no Service Appointment field change).
- Do not stamp `FS_IsManualInspection__c` from this package. CRM / booking automation must set it on WO, WOLI, and SA when it creates a manual backfill.
- Do not subscribe to the event in this package.

---

## 3. Architecture

Salesforce cannot register a trigger on one record type. `FS_SaStatusEventTrigger` fires for every Service Appointment after update. Apex then filters.

```
ServiceAppointment after update
        │
        ▼
FS_SaStatusEventTrigger
        │  new MetadataTriggerHandler().run()
        ▼
Trigger Actions Framework
  sObject_Trigger_Setting.ServiceAppointment
  Trigger_Action.FS_SaStatusEventAfterUpdate
        │
        ▼
FS_SaStatusEventHandler.afterUpdate
        │
        ├─ keep Field_Services only
        ├─ drop FS_IsManualInspection__c = true
        ├─ require Default_Setting.Is_Active__c
        ├─ require Status change OR SchedStartTime/SchedEndTime change
        │
        ▼
SOQL (WITH SECURITY_ENFORCED, or SYSTEM_MODE for background users)
        │
        ▼
FS_InspectionStatusEventMapper
        │
        ▼
FS_InspectionDataUpdate__e  EventType__c = InspectionStatusUpdate
        Payload__c = JSON.serialize(FS_InspectionStatusPayloadDTO, true)
```

### Packaged members (deployed)

| Layer | Member | Role |
|---|---|---|
| Trigger | `FS_SaStatusEventTrigger` | TAF runner, after update only |
| Handler | `FS_SaStatusEventHandler` | Filters, qualifies, queries, publishes |
| Mapper | `FS_InspectionStatusEventMapper` | Header + DTO mapping |
| DTO | `FS_InspectionStatusPayloadDTO` | JSON property names = Salesforce schema |
| Settings | `FS_InspectionStatusEventSettings` | Reads `FS_Inspection_Status_Event_Setting__mdt` Default_Setting |
| Event | `FS_InspectionDataUpdate__e` | Existing org High Volume event (Publish After Commit). **Not redeployed.** |
| CMDT | `Trigger_Action.FS_SaStatusEventAfterUpdate` | Binds handler to ServiceAppointment |
| CMDT | `sObject_Trigger_Setting.ServiceAppointment` | TAF sObject setting |
| Perm set | `FS_InspectionDataUpdate_Event_Publisher` | Create event + read inspection fields |

Parent Work Order lookups on the appointment (`FS_Work_Order__c`, `FS_Work_Order_Line_Item__c`) are filled by Alert Center (`FS_ServiceAppointmentTriggerHandler`), not by this handler.

The deploy left org-owned Alert Center fields (`FS_Work_Order__c`, `FS_Work_Order_Line_Item__c`, `Priority__c`) and record type `Field_Services` unchanged.

---

## 4. Publication rules

An event is published when **all** of the following are true.

1. **CMDT** `FS_Inspection_Status_Event_Setting__mdt` / `Default_Setting` has `Is_Active__c` true (or the record is missing — packaged default is active).
2. **Record type** is `Field_Services`. If that record type does not exist in the org, nothing publishes.
3. **`FS_IsManualInspection__c` is not true** on the Service Appointment.
4. The update changed **at least one** of:
   - `Status` (any Field Services status, including `None` and `Canceled`)
   - `SchedStartTime`
   - `SchedEndTime`

If status and scheduled times change in the same DML, **one** event is published. The payload contains the new status and the new schedule.

### Explicit non-publish cases

| Situation | Result |
|---|---|
| Record type is not Field_Services | Skip |
| `FS_IsManualInspection__c = true` | Skip |
| Default Setting inactive | Skip |
| Only `ArrivalWindowStartTime` / `ArrivalWindowEndTime` changed | Skip |
| Only DueDate, EarliestStartTime, actuals, or FS_* date stamps changed | Skip |
| Assigned Resource created/updated with no SA field change | Skip |
| Before insert / after insert | No trigger context in this package |

### Field Services statuses (AKLC picklist)

`None`, `Scheduled`, `Dispatched`, `Travel`, `OnSite`, `Completed`, `Canceled`.

There is no `In Progress` or `Cannot Complete` on this record type. Spreadsheet “Onsite” maps to **OnSite**.

---

## 5. Manual inspection flag

### Fields

| Object | API name | Label | Type | Default |
|---|---|---|---|---|
| WorkOrder | `FS_IsManualInspection__c` | Is Manual Inspection | Checkbox | false |
| WorkOrderLineItem | `FS_IsManualInspection__c` | Is Manual Inspection | Checkbox | false |
| ServiceAppointment | `FS_IsManualInspection__c` | Is Manual Inspection | Checkbox | false |

All three are packaged so CRM can stamp the same meaning on the booking hierarchy. **Publication reads only the Service Appointment field.** Classification is Confidential.

### Who sets the flag

The process that creates a **manual CRM booking** and its **Field Service backfill appointment** must set `FS_IsManualInspection__c = true` on:

- the Work Order
- the Work Order Line Item
- the Service Appointment

If the SA flag is left false, this publisher will treat the appointment as a normal inspection and **will** emit events.

Existing portal / API booked inspections stay `false` (default) and continue to publish.

Permission set `FS_InspectionDataUpdate_Event_Publisher` grants **read and edit** on the three fields so booking and dispatch users can stamp and the publisher query can read `ServiceAppointment.FS_IsManualInspection__c` under `WITH SECURITY_ENFORCED`.

---

## 6. Platform event contract

Object: `FS_InspectionDataUpdate__e`  
Volume: High Volume  
Publish behaviour: **Publish After Commit**

### Header

| Event field | Source | Notes |
|---|---|---|
| `EventType__c` | CMDT `Event_Type__c` | Always `InspectionStatusUpdate` in the packaged default |
| `BookingReferenceNumber__c` | `WorkOrder.FS_Booking_Reference__c` | Via `FS_Work_Order__r` |
| `InspectionId__c` | `ServiceAppointment.FS_ExternalRefId__c` | |
| `WorkOrderId__c` | `ServiceAppointment.FS_Work_Order__c` | |
| `WorkOrderLineItemId__c` | `ServiceAppointment.FS_Work_Order_Line_Item__c` | |
| `ServiceAppointmentId__c` | `ServiceAppointment.Id` | |
| `Payload__c` | JSON from `FS_InspectionStatusPayloadDTO` | Null properties omitted |

Middleware should key off **`EventType__c = InspectionStatusUpdate`** and read `status` (and the rest of the payload) rather than expecting `InspectionCancellation` or `InspectionUpdate`.

---

## 7. Payload (`FS_InspectionStatusPayloadDTO`)

Serialization: `JSON.serialize(payload, true)` — Apex suppress-nulls. A property is present only when it has a value. Nested `assignedCrewMembers` is omitted when there are no assigned resources (including unscheduled `None`).

`eventType` inside the JSON matches the header (`InspectionStatusUpdate`).

Apex is case-insensitive, so the DTO cannot expose both `userName` and `username`. Display name is **`lastModifiedBy.name`**; login is **`lastModifiedBy.username`**.

| Payload key | Salesforce source |
|---|---|
| `eventType` | Header event type |
| `status` | `ServiceAppointment.Status` |
| `appointmentNumber` | `AppointmentNumber` |
| `priority` | `Priority__c` (formula from parent WOLI / WO) |
| `bookingReferenceNumber` | `WorkOrder.FS_Booking_Reference__c` |
| `inspectionId` | `FS_ExternalRefId__c` |
| `bcoNumber` | `BCO_Detail__c.FS_BCO_Number__c` |
| `workOrderLineItemNumber` | `WorkOrderLineItem.LineItemNumber` |
| `workTypeName` | `WorkType.Name` |
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
| `isConfirmed` | `FS_Is_Confirmed__c` |
| `parentWork.*` | Work Order / WOLI ids and numbers |
| `lastModifiedBy.name` / `username` / `employeeNumber` | `LastModifiedBy` (`Name`, `Username`, `EmployeeNumber`) |
| `assignedCrewMembers[]` | `AssignedResource` related list |

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

When status is the configured unscheduled value (`None`), assigned resources are not added to the payload.

### Schema gaps (not mapped)

| Spreadsheet idea | Org reality | Payload |
|---|---|---|
| WorkOrder `FS_Sequence__c` | Field does not exist | `workOrderLineItemNumber` |
| ServiceResource `FS_ExternalRefId__c` | Field does not exist | related User `EmployeeNumber` |
| AssignedResource Glick-key | No field | Omitted |

Travel time in Salesforce is **minutes**. Field Service may recalculate `EstimatedTravelTime` on assign (tests observed `0.00` after insert).

---

## 8. Class design

### `FS_SaStatusEventHandler`

Implements `TriggerAction.AfterUpdate`.

| Method | Responsibility |
|---|---|
| `afterUpdate` | Cast TAF lists, keep publishable appointments, call `handleTrigger` |
| `filterPublishableAppointments` / `isPublishableAppointment` | Field_Services and not manual |
| `resolveEventType` | `InspectionStatusUpdate` if status or sched start/end changed; else null |
| `queryAppointments` | Payload SOQL; `WITH SECURITY_ENFORCED` or `AccessLevel.SYSTEM_MODE` |
| `excludeManualInspections` | Second pass on queried rows |
| `publishEvents` | `EventBus.publish`; tests capture `publishedEventsForTest` |

Background users `CloudIntegrationUser` and `AutomatedProcess` cannot be granted FLS. Those user types (and a test hook) query and publish in system mode.

Org automation on Service Appointment after create (`FS Service Appointment After Create`) requires `FS_BCO_Detail__c` (`bcoDetailId`). That is an org flow, not this package, but tests must populate BCO Detail.

### `FS_InspectionStatusEventMapper`

Builds `FS_InspectionDataUpdate__e` and `FS_InspectionStatusPayloadDTO`. Null DTO properties are left null so JSON suppress-nulls drops them.

### `FS_InspectionStatusEventSettings`

Reads `Default_Setting`. Blank `Event_Type__c` falls back to `InspectionStatusUpdate`. Blank `Unscheduled_Status__c` falls back to `None`. Tests inject `settingsOverride` or `forceMissingSettingForTest`.

---

## 9. Configuration (`FS_Inspection_Status_Event_Setting__mdt`)

Record **Default Setting** (deployed):

| Field | Packaged default | Purpose |
|---|---|---|
| `Is_Active__c` | true | Master publish switch |
| `Event_Type__c` | `InspectionStatusUpdate` | Header and payload `eventType` |
| `Unscheduled_Status__c` | `None` | Status that omits assigned crew from the payload |
| `Scope_To_Field_Services_Record_Type__c` | true | Layout compatibility; Apex always requires Field_Services |
| `Description__c` | (text) | Admin notes |

Removed from this design (do not use):

- Separate cancellation / dates event types
- Portal-creator filter on Completed
- Skip-on-enter status list
- Tracked-status allowlist (every Field Services status change publishes)

---

## 10. Security

Permission set **`FS_InspectionDataUpdate_Event_Publisher`**:

- Apex access to handler, mapper, settings, DTO
- Create + read `FS_InspectionDataUpdate__e` and its fields
- Read inspection fields used in the publisher query
- Read/edit `FS_IsManualInspection__c` on WorkOrder, WorkOrderLineItem, ServiceAppointment
- Record type visibility `ServiceAppointment.Field_Services`

CRUD/FLS:

- SOQL uses `WITH SECURITY_ENFORCED` for interactive users
- `EventBus.publish` after `isCreateable()` (or system-mode bypass for background users)
- Tests capture events even when the running user cannot create the platform event

Custom fields created in this package use `securityClassification` **Confidential**. Retrieved `FS_InspectionDataUpdate__e` fields match the org and were not rewritten with a classification.

---

## 11. Tests (`FS_SaStatusEventHandlerTest`)

Tests call `afterUpdate` explicitly so they do not depend on TAF CMDT already being in the org. DML still exercises Field Service status transitions. Setup creates Operating Hours, Territory, Work Order, WOLI, BCO Detail, and a Field Services Service Appointment.

| Test | Expectation |
|---|---|
| Parent lookups on insert | Alert Center filled `FS_Work_Order__c` / WOLI / Priority |
| Enter Scheduled | One `InspectionStatusUpdate` |
| Canceled | One `InspectionStatusUpdate` with WO / WOLI / booking reference / payload keys |
| Non-Field_Services | No event |
| `FS_IsManualInspection__c = true` | No event |
| Change SchedStartTime / SchedEndTime | One `InspectionStatusUpdate` with schedule in payload |
| Assigned resource travel mapping | Payload includes `assignedCrewMembers` and travel minutes |
| Arrival window only | `resolveEventType` returns null |
| Unschedule to None | One `InspectionStatusUpdate` |
| Inactive CMDT | No event |
| Missing / blank CMDT | Defaults to active + `InspectionStatusUpdate` + `None` |

---

## 12. Post-deploy manual steps (AKLCDEVSB4)

Complete these in the org. Metadata deploy does **not** assign permission sets, add fields to page layouts, stamp CRM backfills, or configure subscribers.

### 12.1 Assign the publisher permission set

1. Open **Setup → Users → Permission Sets**.
2. Open **`FS_InspectionDataUpdate_Event_Publisher`**.
3. **Manage Assignments** and assign it to:
   - Field Service dispatchers who change appointment status or schedule
   - Field resources / mobile users who move appointments through Travel, OnSite, Completed, Canceled
   - Integration users that update Field Services appointments and must **publish** the event
4. Do **not** expect to assign this set to `CloudIntegrationUser` / `AutomatedProcess`. Those user types cannot take Field Service FLS; the handler already queries and publishes in system mode for them.

Without this assignment, interactive users fail `WITH SECURITY_ENFORCED` on the payload query or cannot create `FS_InspectionDataUpdate__e`.

### 12.2 Field-level security for other profiles

If some users update Service Appointments using profile FLS instead of this permission set:

1. Grant **Read** on `ServiceAppointment.FS_IsManualInspection__c` (required for the publisher query).
2. Grant **Read** on the other inspection fields already listed on the permission set (BCO, booking reference, FS date stamps, jeopardy, parent lookups, Status).
3. Grant **Create** on `FS_InspectionDataUpdate__e` for anyone who should publish.

Prefer assigning the permission set rather than editing many profiles.

### 12.3 Add Is Manual Inspection to page layouts

The checkbox was deployed but is **not** automatically on page layouts.

1. **Work Order** layout used by CRM booking: add **Is Manual Inspection**.
2. **Work Order Line Item** layout used by CRM booking: add **Is Manual Inspection**.
3. **Service Appointment** Field Services layout: add **Is Manual Inspection**.
   - Keep it editable for the CRM / booking process that stamps backfills.
   - Optionally read-only for dispatchers if they should not uncheck it.

Until the field is on the layout, admins can still set it via Inspector, Data Loader, or Apex.

### 12.4 Confirm custom metadata Default Setting

1. **Setup → Custom Metadata Types → FS Inspection Status Event Setting → Manage Records**.
2. Open **Default Setting**.
3. Confirm:
   - **Is Active** = true
   - **Event Type** = `InspectionStatusUpdate`
   - **Unscheduled Status** = `None`
4. Leave it active unless you need an emergency kill switch.

### 12.5 Confirm Trigger Actions Framework wiring

1. **sObject Trigger Setting** record **ServiceAppointment**:
   - **Bypass Execution** = false
   - **Object API Name** = `ServiceAppointment`
2. **Trigger Action** record **FS_SaStatusEventAfterUpdate**:
   - **After Update** bound to the ServiceAppointment sObject setting
   - **Apex Class Name** = `FS_SaStatusEventHandler`
   - **Bypass Execution** = false
   - **Order** = 1 (or an agreed order next to other future SA actions)
3. Confirm **only one** unpackaged Service Appointment trigger calls `new MetadataTriggerHandler().run()`. A second TAF runner on the same object will double-publish.
4. Leave FSL-managed `TR001_Service_*` and Alert Center `FS_ServiceAppointmentTrigger` in place. This package does not replace them.

### 12.6 Subscriber / middleware access

1. Grant the **subscriber** integration user **Read** on `FS_InspectionDataUpdate__e` (subscribe). Create remains on the publisher set.
2. Point middleware at **`FS_InspectionDataUpdate__e`**, not at three separate event objects.
3. Branch only on **`EventType__c = InspectionStatusUpdate`**. Status, cancellation, and reschedule share that value; use payload `status` and the date fields to distinguish.
4. Treat omitted JSON keys as null. Do not expect `InspectionCancellation` or `InspectionUpdate` as `EventType__c`.
5. Map `lastModifiedBy.name` (display name) and `lastModifiedBy.username` (login).

### 12.7 CRM manual-booking backfill process (required)

The publisher does **not** infer “manual” from CreatedBy or UserType.

When CRM creates a manual booking and a Field Service backfill appointment, set **`FS_IsManualInspection__c = true`** on:

1. Work Order
2. Work Order Line Item
3. Service Appointment

If the Service Appointment flag stays false, events **will** publish.

Optional data fix: if historical backfill appointments already exist, set the checkbox true on those SAs (and parents) so they stop emitting.

### 12.8 Smoke test in AKLCDEVSB4

Use a Field Services appointment with BCO Detail populated (org after-create automation requires `bcoDetailId`).

| Step | Action | Expected |
|---|---|---|
| 1 | Unscheduled Field Services SA → status **Scheduled** (set sched start/end) | One event, `EventType__c` = `InspectionStatusUpdate`, `status` = Scheduled, Inspection Id and booking reference populated |
| 2 | Change **SchedStartTime** / **SchedEndTime** only | One event, same event type, new times in payload |
| 3 | Change **arrival window** only | No event |
| 4 | Status **Canceled** | One event, `status` = Canceled, `cancelledDate` if `FS_Cancelled_Date__c` is set |
| 5 | Check **Is Manual Inspection**, then change status | No event |
| 6 | Non-Field_Services appointment status change | No event |
| 7 | Dispatcher vs integration user | Event still publishes (system mode for background users) |

Debug / Event Log: search for `FS_InspectionDataUpdate__e` publishes after each step.

### 12.9 Sign-off

- [ ] Permission set assigned to dispatcher, field, and publisher integration users
- [ ] Is Manual Inspection on WO, WOLI, and Field Services SA layouts
- [ ] Default Setting active, Event Type `InspectionStatusUpdate`
- [ ] TAF ServiceAppointment setting and FS_SaStatusEventAfterUpdate not bypassed
- [ ] No second `MetadataTriggerHandler` on Service Appointment
- [ ] Subscriber can read the platform event
- [ ] Middleware updated for a single event type and schema-named payload keys
- [ ] CRM stamps `FS_IsManualInspection__c` on manual backfills
- [ ] Smoke tests 1–6 passed

---

## 13. What was not deployed

- `FS_InspectionDataUpdate__e` object and fields (already in the org; source-tracking conflict)
- Alert Center `FS_Work_Order__c`, `FS_Work_Order_Line_Item__c`, `Priority__c`
- Record type `ServiceAppointment.Field_Services` (already in the org)
- TAF **object definitions** (`Trigger_Action__mdt`, `sObject_Trigger_Setting__mdt`) — only the Service Appointment **records** were deployed
- Alert Center and FSL managed trigger bodies

Org discovery notes remain in `docs/AKLCDEVSB4-InspectionDataUpdate-Alignment.md`.
