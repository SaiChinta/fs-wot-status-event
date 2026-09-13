#!/usr/bin/env python3
"""Generate the Inspection Data Update design PDF. No URLs in output."""

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    KeepTogether,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

NAVY = colors.HexColor("#032D60")
TEAL = colors.HexColor("#0B827C")
SLATE = colors.HexColor("#2E2E2E")
MUTED = colors.HexColor("#5C5C5C")
RULE = colors.HexColor("#D8E0E8")
ROW = colors.HexColor("#F4F7FA")
WHITE = colors.white


def styles():
    base = getSampleStyleSheet()
    s = {
        "cover_kicker": ParagraphStyle(
            "cover_kicker",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9,
            textColor=TEAL,
            spaceAfter=8,
        ),
        "cover_title": ParagraphStyle(
            "cover_title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=22,
            leading=26,
            textColor=NAVY,
            alignment=TA_LEFT,
            spaceAfter=10,
        ),
        "cover_sub": ParagraphStyle(
            "cover_sub",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=11,
            leading=15,
            textColor=MUTED,
            spaceAfter=6,
        ),
        "h1": ParagraphStyle(
            "h1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=14,
            leading=18,
            textColor=NAVY,
            spaceBefore=14,
            spaceAfter=8,
            borderPadding=0,
        ),
        "h2": ParagraphStyle(
            "h2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=11.5,
            leading=15,
            textColor=TEAL,
            spaceBefore=10,
            spaceAfter=6,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9,
            leading=12.5,
            textColor=SLATE,
            alignment=TA_LEFT,
            spaceAfter=6,
        ),
        "bullet": ParagraphStyle(
            "bullet",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9,
            leading=12.2,
            textColor=SLATE,
            leftIndent=12,
            spaceAfter=2,
        ),
        "cell": ParagraphStyle(
            "cell",
            parent=base["Normal"],
            fontName="Courier",
            fontSize=7,
            leading=9.2,
            textColor=SLATE,
        ),
        "cell_h": ParagraphStyle(
            "cell_h",
            parent=base["Normal"],
            fontName="Courier-Bold",
            fontSize=7,
            leading=9.2,
            textColor=WHITE,
        ),
        "meta": ParagraphStyle(
            "meta",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=8,
            leading=11,
            textColor=MUTED,
            spaceAfter=3,
        ),
        "quote": ParagraphStyle(
            "quote",
            parent=base["Normal"],
            fontName="Helvetica-Oblique",
            fontSize=9.5,
            leading=13,
            textColor=NAVY,
            leftIndent=10,
            rightIndent=10,
            spaceBefore=4,
            spaceAfter=8,
            borderPadding=6,
        ),
        "code": ParagraphStyle(
            "code",
            parent=base["Code"],
            fontName="Courier",
            fontSize=7.2,
            leading=9.4,
            textColor=SLATE,
            backColor=ROW,
            leftIndent=4,
            rightIndent=4,
            spaceBefore=4,
            spaceAfter=8,
        ),
        "check": ParagraphStyle(
            "check",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9,
            leading=12.5,
            textColor=SLATE,
            leftIndent=4,
            spaceAfter=3,
        ),
        "footer": ParagraphStyle(
            "footer",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=7.5,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
        "toc": ParagraphStyle(
            "toc",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9,
            leading=13,
            textColor=SLATE,
            leftIndent=4,
        ),
    }
    return s


def header_footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(NAVY)
    canvas.rect(0, A4[1] - 14 * mm, A4[0], 14 * mm, fill=1, stroke=0)
    canvas.setFillColor(WHITE)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(
        18 * mm,
        A4[1] - 8.5 * mm,
        "FS Inspection Data Update  |  Design and post-deploy guide",
    )
    canvas.setFillColor(TEAL)
    canvas.rect(0, 0, A4[0], 10 * mm, fill=1, stroke=0)
    canvas.setFillColor(WHITE)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(18 * mm, 4 * mm, "AKLCDEVSB4  |  Confidential")
    canvas.drawRightString(A4[0] - 18 * mm, 4 * mm, "Page %d" % doc.page)
    canvas.restoreState()


def cover_header_footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(NAVY)
    canvas.rect(0, A4[1] - 42 * mm, A4[0], 42 * mm, fill=1, stroke=0)
    canvas.setFillColor(TEAL)
    canvas.rect(0, A4[1] - 46 * mm, A4[0], 4 * mm, fill=1, stroke=0)
    canvas.setFillColor(WHITE)
    canvas.setFont("Helvetica", 9)
    canvas.drawString(18 * mm, A4[1] - 14 * mm, "AUCKLAND COUNCIL  |  FIELD SERVICE")
    canvas.setFont("Helvetica-Bold", 11)
    canvas.drawString(18 * mm, A4[1] - 22 * mm, "Reusable component")
    canvas.setFillColor(TEAL)
    canvas.rect(0, 0, A4[0], 10 * mm, fill=1, stroke=0)
    canvas.setFillColor(WHITE)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(18 * mm, 4 * mm, "AKLCDEVSB4  |  Confidential")
    canvas.restoreState()


def p(text, style):
    return Paragraph(text, style)


def table(headers, rows, col_widths, s):
    head = [p(h, s["cell_h"]) for h in headers]
    body = []
    for row in rows:
        body.append([p(c, s["cell"]) for c in row])
    data = [head] + body
    t = Table(data, colWidths=col_widths, repeatRows=1)
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("GRID", (0, 0), (-1, -1), 0.3, RULE),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            cmds.append(("BACKGROUND", (0, i), (-1, i), ROW))
    t.setStyle(TableStyle(cmds))
    return t


def bullets(items, s):
    out = []
    for item in items:
        out.append(p("&bull;&nbsp;&nbsp;" + item, s["bullet"]))
    return out


def checks(items, s):
    out = []
    for item in items:
        out.append(p("[ ]&nbsp;&nbsp;" + item, s["check"]))
    return out


def build():
    s = styles()
    story = []
    W = 174 * mm

    story.append(Spacer(1, 40 * mm))
    story.append(p("DESIGN DOCUMENT  +  POST-DEPLOY RUNBOOK", s["cover_kicker"]))
    story.append(
        p("FS Inspection Data Update<br/>Platform event publisher", s["cover_title"])
    )
    story.append(
        p(
            "Publishes the existing org platform event FS_InspectionDataUpdate__e when a "
            "Field Services Service Appointment changes status or scheduled start/end.",
            s["cover_sub"],
        )
    )
    story.append(Spacer(1, 8 * mm))
    meta = [
        ["Org", "AKLCDEVSB4"],
        ["Status", "Deployed"],
        ["Deploy Id", "0Af8r00000WnGE6CAN"],
        ["Tests", "FS_SaStatusEventHandlerTest  12 / 12 passing"],
        ["Event", "FS_InspectionDataUpdate__e  (existing; not overwritten)"],
        ["Event type", "InspectionStatusUpdate  (single type)"],
        ["Source API", "61.0"],
        ["Classification", "Confidential"],
    ]
    mt = Table(
        [[p("<b>%s</b>" % a, s["cell"]), p(b, s["cell"])] for a, b in meta],
        colWidths=[38 * mm, 120 * mm],
    )
    mt.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                ("LINEBELOW", (0, 0), (-1, -2), 0.3, RULE),
                ("BACKGROUND", (0, 0), (0, -1), ROW),
            ]
        )
    )
    story.append(mt)
    story.append(Spacer(1, 6 * mm))
    story.append(p("Contents", s["h2"]))
    toc = [
        "1. Purpose and tracker interpretation",
        "2. Goals and non-goals",
        "3. Architecture and deployed members",
        "4. Publication rules",
        "5. Manual inspection flag",
        "6. Platform event contract",
        "7. Payload (FS_InspectionStatusPayloadDTO)",
        "8. Class design",
        "9. Configuration",
        "10. Security",
        "11. Automated tests",
        "12. Post-deploy manual steps (complete in the org)",
        "13. What was not deployed",
    ]
    for line in toc:
        story.append(p(line, s["toc"]))
    story.append(PageBreak())

    story.append(p("1. Purpose and tracker interpretation", s["h1"]))
    story.append(
        p(
            "When a Field Services inspection appointment changes <b>status</b> or "
            "<b>scheduled start / scheduled end</b>, Salesforce publishes one High Volume "
            "platform event so middleware can update downstream systems.",
            s["body"],
        )
    )
    story.append(
        p(
            "There is a single message type. Cancellation, completion, dispatch, travel, "
            "on-site, and a reschedule of SchedStartTime / SchedEndTime all use "
            "<b>InspectionStatusUpdate</b>. The JSON body always uses the same "
            "FS_InspectionStatusPayloadDTO shape. Properties with no value are omitted.",
            s["body"],
        )
    )
    story.append(p("Tracker interpretation", s["h2"]))
    story.append(
        p(
            "The tracker item is not &ldquo;only portal-created completions.&rdquo; It is:",
            s["body"],
        )
    )
    story.append(
        p(
            "Do not publish for a Service Appointment that is a backfill appointment "
            "created for a manual booking created in CRM.",
            s["quote"],
        )
    )
    story.append(
        p(
            "Those backfills are stamped with Is Manual Inspection "
            "(FS_IsManualInspection__c = true) on Work Order, Work Order Line Item, and "
            "Service Appointment. The publisher evaluates the <b>Service Appointment</b> "
            "flag and skips the record.",
            s["body"],
        )
    )

    story.append(p("2. Goals and non-goals", s["h1"]))
    story.append(p("Goals", s["h2"]))
    story.extend(
        bullets(
            [
                "Publish FS_InspectionDataUpdate__e after Field Services appointment status changes (including Canceled and unscheduled None).",
                "Also publish when SchedStartTime or SchedEndTime changes, even if status is unchanged.",
                "Always set header EventType__c to InspectionStatusUpdate.",
                "Map the full inspection payload; omit null JSON properties.",
                "Ignore appointments with FS_IsManualInspection__c = true.",
                "Ignore appointments that are not record type Field_Services.",
                "Sit beside existing Alert Center and FSL triggers; do not duplicate parent-lookup fill.",
            ],
            s,
        )
    )
    story.append(p("Non-goals", s["h2"]))
    story.extend(
        bullets(
            [
                "Do not create additional platform event objects.",
                "Do not publish on insert (after update only).",
                "Do not publish solely because arrival window, due date, actuals, or FS_* date stamps changed.",
                "Do not publish Assigned Resource-only DML (no Service Appointment field change).",
                "Do not stamp FS_IsManualInspection__c from this package. CRM / booking automation must set it on WO, WOLI, and SA.",
                "Do not subscribe to the event in this package.",
            ],
            s,
        )
    )

    story.append(p("3. Architecture and deployed members", s["h1"]))
    story.append(
        p(
            "Salesforce cannot register a trigger on one record type. FS_SaStatusEventTrigger "
            "fires for every Service Appointment after update. Apex then filters.",
            s["body"],
        )
    )
    flow = """ServiceAppointment after update
        |
        v
FS_SaStatusEventTrigger
        |  new MetadataTriggerHandler().run()
        v
Trigger Actions Framework
  sObject_Trigger_Setting.ServiceAppointment
  Trigger_Action.FS_SaStatusEventAfterUpdate
        |
        v
FS_SaStatusEventHandler.afterUpdate
        |-- keep Field_Services only
        |-- drop FS_IsManualInspection__c = true
        |-- require Default_Setting.Is_Active__c
        |-- require Status change OR SchedStartTime/SchedEndTime change
        v
SOQL (WITH SECURITY_ENFORCED, or SYSTEM_MODE for background users)
        v
FS_InspectionStatusEventMapper
        v
FS_InspectionDataUpdate__e
  EventType__c = InspectionStatusUpdate
  Payload__c   = JSON.serialize(DTO, suppress nulls)"""
    story.append(KeepTogether([Preformatted(flow, s["code"])]))
    story.append(p("Deployed members", s["h2"]))
    story.append(
        table(
            ["Layer", "Member", "Role"],
            [
                ["Trigger", "FS_SaStatusEventTrigger", "TAF runner, after update only"],
                ["Handler", "FS_SaStatusEventHandler", "Filters, qualifies, queries, publishes"],
                ["Mapper", "FS_InspectionStatusEventMapper", "Header + DTO mapping"],
                ["DTO", "FS_InspectionStatusPayloadDTO", "JSON names = Salesforce schema"],
                ["Settings", "FS_InspectionStatusEventSettings", "Reads Default_Setting CMDT"],
                [
                    "Event",
                    "FS_InspectionDataUpdate__e",
                    "Existing org event. Not redeployed.",
                ],
                [
                    "CMDT",
                    "Trigger_Action.FS_SaStatusEventAfterUpdate",
                    "Binds handler to ServiceAppointment",
                ],
                [
                    "CMDT",
                    "sObject_Trigger_Setting.ServiceAppointment",
                    "TAF sObject setting",
                ],
                [
                    "Perm set",
                    "FS_InspectionDataUpdate_Event_Publisher",
                    "Create event + read inspection fields",
                ],
            ],
            [28 * mm, 68 * mm, 78 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "Parent Work Order lookups (FS_Work_Order__c, FS_Work_Order_Line_Item__c) are "
            "filled by Alert Center (FS_ServiceAppointmentTriggerHandler), not by this handler. "
            "The deploy left those Alert Center fields, Priority__c, and record type "
            "Field_Services unchanged.",
            s["body"],
        )
    )

    story.append(p("4. Publication rules", s["h1"]))
    story.append(p("An event is published when <b>all</b> of the following are true.", s["body"]))
    story.extend(
        bullets(
            [
                "CMDT FS_Inspection_Status_Event_Setting__mdt / Default_Setting has Is_Active__c true (packaged default is active if the record is missing).",
                "Record type is Field_Services. If that record type does not exist, nothing publishes.",
                "FS_IsManualInspection__c is not true on the Service Appointment.",
                "The update changed Status (any Field Services status, including None and Canceled), and/or SchedStartTime, and/or SchedEndTime.",
            ],
            s,
        )
    )
    story.append(
        p(
            "If status and scheduled times change in the same DML, one event is published. "
            "The payload contains the new status and the new schedule.",
            s["body"],
        )
    )
    story.append(p("Explicit non-publish cases", s["h2"]))
    story.append(
        table(
            ["Situation", "Result"],
            [
                ["Record type is not Field_Services", "Skip"],
                ["FS_IsManualInspection__c = true", "Skip"],
                ["Default Setting inactive", "Skip"],
                ["Only ArrivalWindowStartTime / ArrivalWindowEndTime changed", "Skip"],
                ["Only DueDate, EarliestStartTime, actuals, or FS_* date stamps changed", "Skip"],
                ["Assigned Resource created/updated with no SA field change", "Skip"],
                ["Before insert / after insert", "No trigger context in this package"],
            ],
            [110 * mm, 64 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "Field Services statuses: None, Scheduled, Dispatched, Travel, OnSite, Completed, "
            "Canceled. There is no In Progress or Cannot Complete. Spreadsheet Onsite maps to OnSite.",
            s["body"],
        )
    )

    story.append(p("5. Manual inspection flag", s["h1"]))
    story.append(
        table(
            ["Object", "API name", "Label", "Type", "Default"],
            [
                ["WorkOrder", "FS_IsManualInspection__c", "Is Manual Inspection", "Checkbox", "false"],
                ["WorkOrderLineItem", "FS_IsManualInspection__c", "Is Manual Inspection", "Checkbox", "false"],
                ["ServiceAppointment", "FS_IsManualInspection__c", "Is Manual Inspection", "Checkbox", "false"],
            ],
            [38 * mm, 52 * mm, 42 * mm, 22 * mm, 20 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "All three are packaged so CRM can stamp the same meaning on the booking hierarchy. "
            "<b>Publication reads only the Service Appointment field.</b> Security classification is Confidential.",
            s["body"],
        )
    )
    story.append(
        p(
            "The process that creates a manual CRM booking and its Field Service backfill "
            "appointment must set FS_IsManualInspection__c = true on the Work Order, Work Order "
            "Line Item, and Service Appointment. If the SA flag is left false, this publisher "
            "will emit events. Portal / API booked inspections stay false (default) and continue to publish.",
            s["body"],
        )
    )

    story.append(p("6. Platform event contract", s["h1"]))
    story.append(
        p(
            "Object FS_InspectionDataUpdate__e. High Volume. Publish After Commit. "
            "This object already existed in AKLCDEVSB4 and was not overwritten by the deploy.",
            s["body"],
        )
    )
    story.append(
        table(
            ["Event field", "Source", "Notes"],
            [
                ["EventType__c", "CMDT Event_Type__c", "Always InspectionStatusUpdate"],
                ["BookingReferenceNumber__c", "WorkOrder.FS_Booking_Reference__c", "Via FS_Work_Order__r"],
                ["InspectionId__c", "ServiceAppointment.FS_ExternalRefId__c", ""],
                ["WorkOrderId__c", "ServiceAppointment.FS_Work_Order__c", ""],
                ["WorkOrderLineItemId__c", "ServiceAppointment.FS_Work_Order_Line_Item__c", ""],
                ["ServiceAppointmentId__c", "ServiceAppointment.Id", ""],
                ["Payload__c", "JSON from FS_InspectionStatusPayloadDTO", "Null properties omitted"],
            ],
            [48 * mm, 76 * mm, 50 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "Middleware should key off EventType__c = InspectionStatusUpdate and read payload "
            "status (and the rest of the body) rather than expecting InspectionCancellation or InspectionUpdate.",
            s["body"],
        )
    )

    story.append(p("7. Payload (FS_InspectionStatusPayloadDTO)", s["h1"]))
    story.append(
        p(
            "Serialization: JSON.serialize(payload, true). A property is present only when it "
            "has a value. Nested assignedCrewMembers is omitted when there are no assigned "
            "resources (including unscheduled None). eventType inside the JSON matches the header.",
            s["body"],
        )
    )
    story.append(
        p(
            "Apex is case-insensitive, so the DTO cannot expose both userName and username. "
            "Display name is lastModifiedBy.name; login is lastModifiedBy.username.",
            s["body"],
        )
    )
    story.append(
        table(
            ["Payload key", "Salesforce source"],
            [
                ["eventType", "Header event type"],
                ["status", "ServiceAppointment.Status"],
                ["appointmentNumber", "AppointmentNumber"],
                ["priority", "Priority__c (formula from parent WOLI / WO)"],
                ["bookingReferenceNumber", "WorkOrder.FS_Booking_Reference__c"],
                ["inspectionId", "FS_ExternalRefId__c"],
                ["bcoNumber", "BCO_Detail__c.FS_BCO_Number__c"],
                ["workOrderLineItemNumber", "WorkOrderLineItem.LineItemNumber"],
                ["workTypeName", "WorkType.Name"],
                ["bcoComplexity", "BCO_Detail__c.FS_BCO_Complexity__c"],
                ["arrivalWindowStartTime / EndTime", "ArrivalWindowStartTime / EndTime"],
                ["schedStartTime / schedEndTime", "SchedStartTime / SchedEndTime"],
                ["dispatchedDate", "FS_Dispatched_Date__c"],
                ["dueDate", "DueDate"],
                ["earliestStartTime", "EarliestStartTime"],
                ["cancelledDate", "FS_Cancelled_Date__c"],
                ["travelDate / onSiteDate / completedDate", "FS_Travel_Date__c / FS_OnSite_Date__c / FS_Completed_Date__c"],
                ["estimatedTravelTimeMinutes", "First AssignedResource.EstimatedTravelTime (minutes)"],
                ["estimatedTravelTimeSeconds", "Minutes x 60"],
                ["inJeopardy / inJeopardyReason", "FSL__InJeopardy__c / FSL__InJeopardyReason__c"],
                ["inspectionStatus", "FS_Inspection_Status__c"],
                ["cancelledReason", "FS_Cancelled_Reason__c"],
                ["bookingType", "FS_Booking_Type__c"],
                ["isConfirmed", "FS_Is_Confirmed__c"],
                ["parentWork.*", "Work Order / WOLI ids and numbers"],
                ["lastModifiedBy.name / username / employeeNumber", "LastModifiedBy Name, Username, EmployeeNumber"],
                ["assignedCrewMembers[]", "AssignedResource related list"],
            ],
            [72 * mm, 102 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(p("Nested parentWork", s["h2"]))
    story.append(
        table(
            ["Key", "Source"],
            [
                ["workOrderId", "FS_Work_Order__c"],
                ["workOrderNumber", "FS_Work_Order__r.WorkOrderNumber"],
                ["bookingReferenceNumber", "FS_Work_Order__r.FS_Booking_Reference__c"],
                ["workOrderLineItemId", "FS_Work_Order_Line_Item__c"],
                ["workOrderLineItemNumber", "FS_Work_Order_Line_Item__r.LineItemNumber"],
                ["workOrderLineItemExternalRefId", "FS_Work_Order_Line_Item__r.FS_ExternalRefId__c"],
            ],
            [72 * mm, 102 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(p("Nested assignedCrewMembers[]", s["h2"]))
    story.append(
        table(
            ["Key", "Source"],
            [
                ["recordId", "AssignedResource.Id"],
                ["serviceCrewId / serviceCrewName", "ServiceCrew"],
                ["serviceResourceId / serviceResourceName", "ServiceResource"],
                ["serviceResourceEmployeeNumber", "ServiceResource.RelatedRecord.EmployeeNumber"],
                ["estimatedTravelTimeMinutes / Seconds", "EstimatedTravelTime"],
                ["schedStartTime / schedEndTime", "Parent appointment schedule"],
            ],
            [72 * mm, 102 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "When status is the configured unscheduled value (None), assigned resources are "
            "not added to the payload. Travel time in Salesforce is minutes. Field Service may "
            "recalculate EstimatedTravelTime on assign.",
            s["body"],
        )
    )
    story.append(p("Schema gaps (not mapped)", s["h2"]))
    story.append(
        table(
            ["Spreadsheet idea", "Org reality", "Payload"],
            [
                ["WorkOrder FS_Sequence__c", "Field does not exist", "workOrderLineItemNumber"],
                ["ServiceResource FS_ExternalRefId__c", "Field does not exist", "related User EmployeeNumber"],
                ["AssignedResource Glick-key", "No field", "Omitted"],
            ],
            [58 * mm, 58 * mm, 58 * mm],
            s,
        )
    )

    story.append(p("8. Class design", s["h1"]))
    story.append(p("FS_SaStatusEventHandler", s["h2"]))
    story.append(p("Implements TriggerAction.AfterUpdate.", s["body"]))
    story.append(
        table(
            ["Method", "Responsibility"],
            [
                ["afterUpdate", "Cast TAF lists, keep publishable appointments, call handleTrigger"],
                ["filterPublishableAppointments / isPublishableAppointment", "Field_Services and not manual"],
                ["resolveEventType", "InspectionStatusUpdate if status or sched start/end changed; else null"],
                ["queryAppointments", "Payload SOQL; WITH SECURITY_ENFORCED or AccessLevel.SYSTEM_MODE"],
                ["excludeManualInspections", "Second pass on queried rows"],
                ["publishEvents", "EventBus.publish; tests capture publishedEventsForTest"],
            ],
            [70 * mm, 104 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "Background users CloudIntegrationUser and AutomatedProcess cannot be granted FLS. "
            "Those user types query and publish in system mode. Org automation "
            "&ldquo;FS Service Appointment After Create&rdquo; requires FS_BCO_Detail__c "
            "(bcoDetailId). That is an org flow, not this package; tests populate BCO Detail.",
            s["body"],
        )
    )
    story.append(p("FS_InspectionStatusEventMapper", s["h2"]))
    story.append(
        p(
            "Builds FS_InspectionDataUpdate__e and FS_InspectionStatusPayloadDTO. Null DTO "
            "properties are left null so JSON suppress-nulls drops them.",
            s["body"],
        )
    )
    story.append(p("FS_InspectionStatusEventSettings", s["h2"]))
    story.append(
        p(
            "Reads Default_Setting. Blank Event_Type__c falls back to InspectionStatusUpdate. "
            "Blank Unscheduled_Status__c falls back to None. Tests inject settingsOverride or "
            "forceMissingSettingForTest.",
            s["body"],
        )
    )

    story.append(p("9. Configuration", s["h1"]))
    story.append(
        p("Custom metadata type FS_Inspection_Status_Event_Setting__mdt, record Default Setting (deployed):", s["body"])
    )
    story.append(
        table(
            ["Field", "Packaged default", "Purpose"],
            [
                ["Is_Active__c", "true", "Master publish switch"],
                ["Event_Type__c", "InspectionStatusUpdate", "Header and payload eventType"],
                ["Unscheduled_Status__c", "None", "Status that omits assigned crew from the payload"],
                ["Scope_To_Field_Services_Record_Type__c", "true", "Layout compatibility; Apex always requires Field_Services"],
                ["Description__c", "(text)", "Admin notes"],
            ],
            [62 * mm, 42 * mm, 70 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(p("Removed from this design (do not use):", s["body"]))
    story.extend(
        bullets(
            [
                "Separate cancellation / dates event types",
                "Portal-creator filter on Completed",
                "Skip-on-enter status list",
                "Tracked-status allowlist (every Field Services status change publishes)",
            ],
            s,
        )
    )

    story.append(p("10. Security", s["h1"]))
    story.append(p("Permission set FS_InspectionDataUpdate_Event_Publisher grants:", s["body"]))
    story.extend(
        bullets(
            [
                "Apex access to handler, mapper, settings, DTO",
                "Create + read FS_InspectionDataUpdate__e and its fields",
                "Read inspection fields used in the publisher query",
                "Read/edit FS_IsManualInspection__c on WorkOrder, WorkOrderLineItem, ServiceAppointment",
                "Record type visibility ServiceAppointment.Field_Services",
            ],
            s,
        )
    )
    story.append(
        p(
            "SOQL uses WITH SECURITY_ENFORCED for interactive users. EventBus.publish runs after "
            "isCreateable() (or system-mode bypass for background users). Custom fields created "
            "in this package use securityClassification Confidential.",
            s["body"],
        )
    )

    story.append(p("11. Automated tests", s["h1"]))
    story.append(
        p(
            "FS_SaStatusEventHandlerTest calls afterUpdate explicitly so tests do not depend on "
            "TAF CMDT already being in the org. Setup creates Operating Hours, Territory, Work "
            "Order, WOLI, BCO Detail, and a Field Services Service Appointment.",
            s["body"],
        )
    )
    story.append(
        table(
            ["Test", "Expectation"],
            [
                ["Parent lookups on insert", "Alert Center filled FS_Work_Order__c / WOLI / Priority"],
                ["Enter Scheduled", "One InspectionStatusUpdate"],
                ["Canceled", "One InspectionStatusUpdate with WO / WOLI / booking reference"],
                ["Non-Field_Services", "No event"],
                ["FS_IsManualInspection__c = true", "No event"],
                ["Change SchedStartTime / SchedEndTime", "One InspectionStatusUpdate with schedule in payload"],
                ["Assigned resource travel mapping", "Payload includes assignedCrewMembers and travel minutes"],
                ["Arrival window only", "resolveEventType returns null"],
                ["Unschedule to None", "One InspectionStatusUpdate"],
                ["Inactive CMDT", "No event"],
                ["Missing / blank CMDT", "Defaults to active + InspectionStatusUpdate + None"],
            ],
            [62 * mm, 112 * mm],
            s,
        )
    )

    story.append(PageBreak())
    story.append(p("12. Post-deploy manual steps (AKLCDEVSB4)", s["h1"]))
    story.append(
        p(
            "Complete these in the org. Metadata deploy does <b>not</b> assign permission sets, "
            "add fields to page layouts, stamp CRM backfills, or configure subscribers.",
            s["body"],
        )
    )

    story.append(p("12.1 Assign the publisher permission set", s["h2"]))
    story.extend(
        bullets(
            [
                "Setup &rarr; Users &rarr; Permission Sets &rarr; FS_InspectionDataUpdate_Event_Publisher.",
                "Manage Assignments. Assign to Field Service dispatchers who change appointment status or schedule.",
                "Assign to field resources / mobile users who move appointments through Travel, OnSite, Completed, Canceled.",
                "Assign to integration users that update Field Services appointments and must publish the event.",
                "Do not expect to assign this set to CloudIntegrationUser / AutomatedProcess. Those user types cannot take Field Service FLS; the handler already queries and publishes in system mode for them.",
            ],
            s,
        )
    )
    story.append(
        p(
            "Without this assignment, interactive users fail WITH SECURITY_ENFORCED on the payload "
            "query or cannot create FS_InspectionDataUpdate__e.",
            s["body"],
        )
    )

    story.append(p("12.2 Field-level security for other profiles", s["h2"]))
    story.append(
        p(
            "If some users update Service Appointments using profile FLS instead of this permission set:",
            s["body"],
        )
    )
    story.extend(
        bullets(
            [
                "Grant Read on ServiceAppointment.FS_IsManualInspection__c (required for the publisher query).",
                "Grant Read on the other inspection fields already listed on the permission set (BCO, booking reference, FS date stamps, jeopardy, parent lookups, Status).",
                "Grant Create on FS_InspectionDataUpdate__e for anyone who should publish.",
                "Prefer assigning the permission set rather than editing many profiles.",
            ],
            s,
        )
    )

    story.append(p("12.3 Add Is Manual Inspection to page layouts", s["h2"]))
    story.append(
        p(
            "The checkbox was deployed but is not automatically on page layouts.",
            s["body"],
        )
    )
    story.extend(
        bullets(
            [
                "Work Order layout used by CRM booking: add Is Manual Inspection.",
                "Work Order Line Item layout used by CRM booking: add Is Manual Inspection.",
                "Service Appointment Field Services layout: add Is Manual Inspection. Keep it editable for the CRM / booking process that stamps backfills. Optionally read-only for dispatchers if they should not uncheck it.",
                "Until the field is on the layout, admins can still set it via Inspector, Data Loader, or Apex.",
            ],
            s,
        )
    )

    story.append(p("12.4 Confirm custom metadata Default Setting", s["h2"]))
    story.extend(
        bullets(
            [
                "Setup &rarr; Custom Metadata Types &rarr; FS Inspection Status Event Setting &rarr; Manage Records &rarr; Default Setting.",
                "Is Active = true.",
                "Event Type = InspectionStatusUpdate.",
                "Unscheduled Status = None.",
                "Leave it active unless you need an emergency kill switch.",
            ],
            s,
        )
    )

    story.append(p("12.5 Confirm Trigger Actions Framework wiring", s["h2"]))
    story.extend(
        bullets(
            [
                "sObject Trigger Setting record ServiceAppointment: Bypass Execution = false; Object API Name = ServiceAppointment.",
                "Trigger Action record FS_SaStatusEventAfterUpdate: After Update bound to the ServiceAppointment sObject setting; Apex Class Name = FS_SaStatusEventHandler; Bypass Execution = false; Order = 1 (or an agreed order next to other future SA actions).",
                "Confirm only one unpackaged Service Appointment trigger calls new MetadataTriggerHandler().run(). A second TAF runner on the same object will double-publish.",
                "Leave FSL-managed TR001_Service_* and Alert Center FS_ServiceAppointmentTrigger in place. This package does not replace them.",
            ],
            s,
        )
    )

    story.append(p("12.6 Subscriber / middleware access", s["h2"]))
    story.extend(
        bullets(
            [
                "Grant the subscriber integration user Read on FS_InspectionDataUpdate__e (subscribe). Create remains on the publisher set.",
                "Point middleware at FS_InspectionDataUpdate__e, not at three separate event objects.",
                "Branch only on EventType__c = InspectionStatusUpdate. Status, cancellation, and reschedule share that value; use payload status and the date fields to distinguish.",
                "Treat omitted JSON keys as null. Do not expect InspectionCancellation or InspectionUpdate as EventType__c.",
                "Map lastModifiedBy.name (display name) and lastModifiedBy.username (login).",
            ],
            s,
        )
    )

    story.append(p("12.7 CRM manual-booking backfill process (required)", s["h2"]))
    story.append(
        p(
            "The publisher does not infer &ldquo;manual&rdquo; from CreatedBy or UserType. "
            "When CRM creates a manual booking and a Field Service backfill appointment, set "
            "FS_IsManualInspection__c = true on Work Order, Work Order Line Item, and Service Appointment.",
            s["body"],
        )
    )
    story.append(
        p(
            "If the Service Appointment flag stays false, events will publish. Optional data fix: "
            "if historical backfill appointments already exist, set the checkbox true on those "
            "SAs (and parents) so they stop emitting.",
            s["body"],
        )
    )

    story.append(p("12.8 Smoke test in AKLCDEVSB4", s["h2"]))
    story.append(
        p(
            "Use a Field Services appointment with BCO Detail populated (org after-create automation requires bcoDetailId).",
            s["body"],
        )
    )
    story.append(
        table(
            ["Step", "Action", "Expected"],
            [
                [
                    "1",
                    "Unscheduled Field Services SA to status Scheduled (set sched start/end)",
                    "One event, EventType__c = InspectionStatusUpdate, status = Scheduled, Inspection Id and booking reference populated",
                ],
                [
                    "2",
                    "Change SchedStartTime / SchedEndTime only",
                    "One event, same event type, new times in payload",
                ],
                ["3", "Change arrival window only", "No event"],
                [
                    "4",
                    "Status Canceled",
                    "One event, status = Canceled, cancelledDate if FS_Cancelled_Date__c is set",
                ],
                ["5", "Check Is Manual Inspection, then change status", "No event"],
                ["6", "Non-Field_Services appointment status change", "No event"],
                [
                    "7",
                    "Dispatcher vs integration user",
                    "Event still publishes (system mode for background users)",
                ],
            ],
            [14 * mm, 68 * mm, 92 * mm],
            s,
        )
    )

    story.append(Spacer(1, 4 * mm))
    story.append(p("12.9 Sign-off checklist", s["h2"]))
    story.extend(
        checks(
            [
                "Permission set assigned to dispatcher, field, and publisher integration users",
                "Is Manual Inspection on WO, WOLI, and Field Services SA layouts",
                "Default Setting active, Event Type InspectionStatusUpdate",
                "TAF ServiceAppointment setting and FS_SaStatusEventAfterUpdate not bypassed",
                "No second MetadataTriggerHandler on Service Appointment",
                "Subscriber can read the platform event",
                "Middleware updated for a single event type and schema-named payload keys",
                "CRM stamps FS_IsManualInspection__c on manual backfills",
                "Smoke tests 1-6 passed",
            ],
            s,
        )
    )

    story.append(p("13. What was not deployed", s["h1"]))
    story.extend(
        bullets(
            [
                "FS_InspectionDataUpdate__e object and fields (already in the org; source-tracking conflict).",
                "Alert Center FS_Work_Order__c, FS_Work_Order_Line_Item__c, Priority__c.",
                "Record type ServiceAppointment.Field_Services (already in the org).",
                "TAF object definitions (Trigger_Action__mdt, sObject_Trigger_Setting__mdt) — only the Service Appointment records were deployed.",
                "Alert Center and FSL managed trigger bodies.",
            ],
            s,
        )
    )

    out = (
        "/Users/sai.chinta/Library/CloudStorage/GoogleDrive-sai.chinta@salesforce.com/"
        "My Drive/FSE/Reusable Components/fs-wot-status-event/docs/"
        "FS-InspectionDataUpdate-Design.pdf"
    )
    doc = SimpleDocTemplate(
        out,
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=22 * mm,
        bottomMargin=16 * mm,
        title="FS Inspection Data Update — Design and post-deploy guide",
        author="Field Service Engineering",
        subject="AKLCDEVSB4 implementation and post-deploy steps",
    )
    doc.build(story, onFirstPage=cover_header_footer, onLaterPages=header_footer)
    print(out)


if __name__ == "__main__":
    build()
