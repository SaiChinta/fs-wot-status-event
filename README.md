# FS Inspection Data Update Event

Reusable Field Service package that publishes the existing org platform event **FS_InspectionDataUpdate__e** when a **Field Services** Service Appointment **status** or **scheduled start / end** changes.

Full design: `docs/FS-InspectionDataUpdate-Design.md` (PDF: `docs/FS-InspectionDataUpdate-Design.pdf`). Org schema notes: `docs/AKLCDEVSB4-InspectionDataUpdate-Alignment.md`.

This package does **not** include Urban Utilities-only objects. It does **not** create a new platform event.

## What publishes

Trigger: `FS_SaStatusEventTrigger` calls `new MetadataTriggerHandler().run()`.

Handler: `FS_SaStatusEventHandler` implements `TriggerAction.AfterUpdate`.

An event is published on **after update** when all of the following are true:

1. Custom metadata **FS Inspection Status Event Setting** / **Default Setting** has `Is_Active__c` true.
2. Record type is `Field_Services`.
3. `FS_IsManualInspection__c` is **false** (CRM manual backfills are skipped).
4. **Status** changed, or **`SchedStartTime`** / **`SchedEndTime`** changed.

Every publish uses **`EventType__c = InspectionStatusUpdate`**. The JSON payload is `FS_InspectionStatusPayloadDTO`; null properties are omitted.

Parent Work Order lookups are **not** populated here. Alert Center already copies `ParentRecordId` onto blank `FS_Work_Order__c` and `FS_Work_Order_Line_Item__c`.

## Manual inspection flag

Checkbox **Is Manual Inspection** (`FS_IsManualInspection__c`) exists on Work Order, Work Order Line Item, and Service Appointment. CRM must set it to true on all three when it creates a backfill appointment for a manual booking. The publisher reads the Service Appointment field only.

## Security

Assign permission set **FS_InspectionDataUpdate_Event_Publisher**. It grants create on `FS_InspectionDataUpdate__e`, Apex access, Field Services record type visibility, read on inspection query fields, and read/edit on `FS_IsManualInspection__c`.

Background users (`CloudIntegrationUser`, `AutomatedProcess`) query in system mode because Field Service optimisation cannot be granted FLS.

## Configurability

Edit **FS Inspection Status Event Setting** record **Default Setting**.

| Field | Packaged default | Purpose |
|---|---|---|
| `Is_Active__c` | true | Master publish switch |
| `Event_Type__c` | `InspectionStatusUpdate` | Header and payload event type |
| `Unscheduled_Status__c` | `None` | Status that omits assigned crew from the payload |
| `Scope_To_Field_Services_Record_Type__c` | true | Layout only; Apex always requires Field_Services |

## Deploy

Deployed to **AKLCDEVSB4** (Deploy Id `0Af8r00000WnGE6CAN`). Tests: `FS_SaStatusEventHandlerTest` 12/12.

Redeploy if needed:

```bash
sf project deploy start --manifest manifest/package.xml --target-org AKLCDEVSB4 --test-level RunSpecifiedTests --tests FS_SaStatusEventHandlerTest --wait 30
```

Post-deploy steps (permission set, layouts, TAF, CRM stamp, smoke tests) are in `docs/FS-InspectionDataUpdate-Design.md` section 12 and in the PDF.

Source API version in `sfdx-project.json` is **61.0**.
