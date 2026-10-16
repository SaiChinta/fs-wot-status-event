#!/usr/bin/env python3
"""Generate the Inspection Data Update design PDF. No URLs in output."""

import os

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
            "Publishes FS_InspectionDataUpdate__e when a Field Services appointment is "
            "confirmed, scheduled, dispatched, unscheduled, or canceled. Assigned Resource "
            "changes stamp the inspector lookup and do not publish by themselves.",
            s["cover_sub"],
        )
    )
    story.append(Spacer(1, 8 * mm))
    meta = [
        ["Org", "AKLCDEVSB4"],
        ["Status", "Deployed"],
        ["Deploy Id", "0Af8r00000XThEiCAL"],
        ["Tests", "FS_SaStatusEventHandlerTest  19 / 19 passing"],
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
    for item in [
        "1. Purpose",
        "2. Goals and non-goals",
        "3. Architecture",
        "4. Publication rules",
        "5. Assigned inspector stamp",
        "6. Confirmation and manual inspections",
        "7. Platform event and payload",
        "8. Classes and configuration",
        "9. Publisher and subscriber permissions",
        "10. Tests",
        "11. Post-deploy steps and sign-off",
    ]:
        story.append(p(item, s["toc"]))

    story.append(PageBreak())
    story.append(p("1. Purpose", s["h1"]))
    story.append(
        p(
            "Salesforce publishes one High Volume platform event, "
            "<font face='Courier'>FS_InspectionDataUpdate__e</font>, so a subscriber "
            "application can keep inspection bookings in step with Field Service.",
            s["body"],
        )
    )
    story.append(
        p(
            "There is a single message type. Confirmation, schedule, reschedule, "
            "dispatch, unschedule, and cancel all use "
            "<font face='Courier'>EventType__c = InspectionStatusUpdate</font>. "
            "The JSON body is <font face='Courier'>FS_InspectionStatusPayloadDTO</font>. "
            "Properties with no value are omitted.",
            s["body"],
        )
    )
    story.append(
        p(
            "Travel, OnSite, and Completed status changes do not publish by themselves.",
            s["body"],
        )
    )
    story.append(
        p(
            "Manual inspections are stamped "
            "<font face='Courier'>FS_IsManualInspection__c = true</font> on the "
            "Service Appointment. That insert publishes one event, and the payload "
            "includes isManualInspection. Other creates do not publish. The same checkbox "
            "exists on Work Order and Work Order Line Item so CRM can stamp the booking hierarchy.",
            s["body"],
        )
    )

    story.append(p("2. Goals and non-goals", s["h1"]))
    story.append(p("Goals", s["h2"]))
    story.extend(
        bullets(
            [
                "Publish a manual inspection on insert. Other creates do not publish. Publish when FS_Is_Confirmed__c changes to true on update.",
                "Publish on update when the appointment is dispatched, canceled, fully unscheduled, or scheduled with an inspector and both schedule times that just changed.",
                "Stamp ServiceAppointment.FS_Assigned_Inspector__c from Assigned Resource insert, resource change, and delete.",
                "Always set EventType__c to InspectionStatusUpdate.",
                "Publish manual inspections and include isManualInspection. Skip any record type other than Field_Services.",
                "Leave Alert Center parent-lookup fill and FSL managed triggers in place.",
            ],
            s,
        )
    )
    story.append(p("Non-goals", s["h2"]))
    story.extend(
        bullets(
            [
                "Do not create the platform event. It already exists in the org.",
                "Do not publish from the Assigned Resource trigger. It only writes the inspector lookup.",
                "Do not publish on Service Appointment insert.",
                "Do not stamp FS_IsManualInspection__c from this package.",
                "Do not subscribe to the event in this package.",
            ],
            s,
        )
    )

    story.append(p("3. Architecture", s["h1"]))
    story.append(
        p(
            "Scheduling is two saves. Field Service writes the Service Appointment "
            "(status and times) and the Assigned Resource separately. The appointment "
            "trigger waits until the inspector lookup and both times are populated, "
            "so the subscriber receives one schedule event that already contains both.",
            s["body"],
        )
    )
    story.append(
        p(
            "ServiceAppointment after insert and after update<br/>"
            "FS_SaStatusEventTrigger &rarr; MetadataTriggerHandler<br/>"
            "Trigger_Action.FS_SaStatusEventAfterInsert<br/>"
            "Trigger_Action.FS_SaStatusEventAfterUpdate<br/>"
            "FS_SaStatusEventHandler.resolveEventType<br/>"
            "query, map, EventBus.publish<br/><br/>"
            "AssignedResource after insert, update, and delete<br/>"
            "FS_AssignedResourceInspectorTrigger &rarr; MetadataTriggerHandler<br/>"
            "Trigger_Action.FS_AssignedInspectorAfterInsert / AfterUpdate / AfterDelete<br/>"
            "FS_AssignedResourceInspectorHandler writes FS_Assigned_Inspector__c<br/>"
            "That Service Appointment update is what publishes.",
            s["code"],
        )
    )
    story.append(
        table(
            ["Layer", "Member", "Role"],
            [
                ["Trigger", "FS_SaStatusEventTrigger", "SA after insert and after update"],
                ["Trigger", "FS_AssignedResourceInspectorTrigger", "AR after insert, update, delete"],
                ["Handler", "FS_SaStatusEventHandler", "Publish decision, query, publish"],
                ["Handler", "FS_AssignedResourceInspectorHandler", "Stamps the inspector lookup"],
                ["Mapper", "FS_InspectionStatusEventMapper", "Header and JSON payload"],
                ["DTO", "FS_InspectionStatusPayloadDTO", "JSON property names"],
                ["Settings", "FS_InspectionStatusEventSettings", "Default_Setting CMDT"],
                ["Field", "FS_Is_Confirmed__c", "Update publishes when it becomes true"],
                ["Field", "FS_Assigned_Inspector__c", "Lookup to ServiceResource. Confidential"],
                ["Perm set", "FS_InspectionDataUpdate_Event_Publisher", "Publisher users only"],
            ],
            [28 * mm, 78 * mm, 68 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "Each Trigger Action record has one context. Insert, update, and delete "
            "are separate records that point at the same Apex class. Parent Work Order "
            "lookups are filled by Alert Center, not by this package.",
            s["body"],
        )
    )

    story.append(p("4. Publication rules", s["h1"]))
    story.append(
        p(
            "resolveEventType is the only publish decision. The first matching rule "
            "wins, so one save produces at most one event. These gates apply first: "
            "Default Setting Is Active is true (missing CMDT defaults to active); "
            "record type is Field_Services. Manual inspections are included, and the "
            "payload sets isManualInspection. "
            "FS_Is_Confirmed__c is not one of these gates.",
            s["body"],
        )
    )
    story.append(p("Create", s["h2"]))
    story.append(
        p(
            "A manual inspection publishes on insert. Any other insert does not publish, "
            "even when FS_Is_Confirmed__c is already true. Confirmation of those "
            "appointments is a later update.",
            s["body"],
        )
    )
    story.append(p("Update — first match wins", s["h2"]))
    story.append(
        table(
            ["Order", "Publish when"],
            [
                ["1", "Status changed to Dispatched. Inspector and times are not required."],
                ["2", "Status changed to Canceled. Inspector and times are not required. The org still requires FS_Cancelled_Reason__c."],
                ["3", "FS_Is_Confirmed__c changed to true."],
                ["4", "Status is None, the inspector lookup is blank, and status or the inspector just changed."],
                ["5", "Status is Scheduled, the inspector and both times are populated, and status, the inspector, or the times just changed."],
            ],
            [18 * mm, 156 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "A drag onto another resource saves the appointment and the Assigned Resource "
            "separately. The handler queues that appointment once and publishes after "
            "the transaction commits, so the subscriber gets one event with the final "
            "inspector and times. A later save that leaves the appointment unpublished, "
            "such as status None while the inspector is still set, sends nothing. "
            "Rule 5 also publishes when status flips to Scheduled "
            "after the inspector and both times are already stored. It is one event for a new inspector, "
            "new times, or both together. A Scheduled save does not publish "
            "while the inspector lookup is blank. The Assigned Resource stamp writes "
            "the lookup, and that later appointment update publishes the inspector "
            "and both times together. If the inspector is stamped first, the update "
            "that fills both times publishes instead.",
            s["body"],
        )
    )
    story.append(
        p(
            "A change to None while the inspector is still populated does not publish. "
            "Clearing the inspector while status is still Scheduled does not publish. "
            "The unschedule event is published once both are true.",
            s["body"],
        )
    )
    story.append(p("Does not publish", s["h2"]))
    story.append(
        table(
            ["Situation", "Result"],
            [
                ["Not Field_Services, or CMDT inactive", "Skip"],
                ["Non-manual Service Appointment insert", "Skip"],
                ["Scheduled while inspector or either time is blank", "Skip"],
                ["Arrival window, due date, actuals, or FS date stamps only", "Skip"],
                ["Travel, OnSite, or Completed with no other matching change", "Skip"],
                ["None while the inspector lookup is still populated", "Skip"],
                ["Inspector cleared while status is still Scheduled", "Skip"],
                ["Already Canceled or Dispatched, status unchanged", "Skip"],
                ["Assigned Resource travel-time-only update", "Lookup unchanged"],
            ],
            [112 * mm, 62 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "Field Services statuses: None, Scheduled, Dispatched, Travel, OnSite, "
            "Completed, Canceled. FS_Inspection_Status__c, including OPEN, is a payload "
            "field and is not a publish trigger. Unscheduled_Status__c names the "
            "unscheduled status (None). It is not a separate allowlist.",
            s["body"],
        )
    )

    story.append(p("5. Assigned inspector stamp", s["h1"]))
    story.append(
        p(
            "FS_AssignedResourceInspectorHandler maintains "
            "ServiceAppointment.FS_Assigned_Inspector__c (lookup to ServiceResource, "
            "relationship FS_Assigned_Inspections). It does not call EventBus.publish.",
            s["body"],
        )
    )
    story.append(
        table(
            ["Assigned Resource DML", "Lookup result"],
            [
                ["Insert with a Service Resource", "Set the lookup. Last row in the batch wins for one appointment."],
                ["ServiceResourceId changes", "Set the lookup to the new Service Resource."],
                ["Other field changes, such as travel time", "No Service Appointment write."],
                ["Blank appointment or blank Service Resource", "Ignored."],
                ["Delete, other resources remain", "Keep the earliest remaining row by CreatedDate."],
                ["Delete, none remain", "Clear the lookup."],
            ],
            [70 * mm, 104 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.extend(
        bullets(
            [
                "Only Field Services appointments are updated.",
                "The write is skipped when the lookup already matches, so the appointment trigger does not fire again.",
                "stampInProgress stops the appointment update from re-entering the stamp in the same transaction.",
                "Interactive users need update access on FS_Assigned_Inspector__c. CloudIntegrationUser and AutomatedProcess stamp in system mode.",
            ],
            s,
        )
    )

    story.append(p("6. Confirmation and manual inspections", s["h1"]))
    story.append(
        p(
            "FS_Is_Confirmed__c (Is Confirmed) defaults to false. The booking process "
            "sets it on an update. That update publishes when the flag changes to true. "
            "Insert does not publish. Dispatch, cancel, unschedule, and schedule updates "
            "still publish if the flag is left false. "
            "The publisher permission set grants read, not edit.",
            s["body"],
        )
    )
    story.append(
        p(
            "FS_IsManualInspection__c is a checkbox on Work Order, Work Order Line Item, "
            "and Service Appointment. Inserting a Service Appointment with the flag true "
            "publishes one event. The payload sets isManualInspection. CRM stamps all three "
            "on a manual booking. The publisher set grants read and edit.",
            s["body"],
        )
    )

    story.append(p("7. Platform event and payload", s["h1"]))
    story.append(
        p(
            "FS_InspectionDataUpdate__e is High Volume and Publish After Commit. "
            "Header EventType__c, BookingReferenceNumber__c, InspectionId__c "
            "(FS_ExternalRefId__c), WorkOrderId__c, WorkOrderLineItemId__c, "
            "ServiceAppointmentId__c, and Payload__c. InspectionId__c matches payload sfsInspectionId.",
            s["body"],
        )
    )
    story.append(
        table(
            ["Payload key", "Source"],
            [
                ["status", "ServiceAppointment.Status"],
                ["bookingReferenceNumber", "WorkOrder.FS_Booking_Reference__c"],
                ["bookingNotes", "WorkOrder.Description"],
                ["crmInspectionId", "FS_CRMInspection_Id__c"],
                ["sfsInspectionId", "FS_ExternalRefId__c"],
                ["bcoNumber / propertyId / propertyAddress", "BCO_Detail__c number, property id, address"],
                ["contactInformation", "First Inspection_Site_Contact__c name, phone, email"],
                ["inspectionType", "WorkType.Name text before the first underscore"],
                ["isConfirmed", "FS_Is_Confirmed__c"],
                ["isManualInspection", "FS_IsManualInspection__c"],
                ["assignedInspectorId / Name", "FS_Assigned_Inspector__c and its Name"],
                ["cancelledReason / cancelledDate", "FS_Cancelled_Reason__c / FS_Cancelled_Date__c"],
                ["schedStartTime / schedEndTime", "SchedStartTime / SchedEndTime"],
                ["assignedCrewMembers[]", "AssignedResource rows. Omitted when status is None"],
                ["lastModifiedBy.name / username", "LastModifiedBy display name and login"],
            ],
            [78 * mm, 96 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "JSON.serialize omits nulls. On an unschedule event, status is None and "
            "assignedInspectorId and assignedCrewMembers are absent. On a cancel event, "
            "read status and cancelledReason. There is no separate cancellation event type. "
            "Travel time is minutes. estimatedTravelTimeSeconds is minutes times 60.",
            s["body"],
        )
    )

    story.append(p("8. Classes and configuration", s["h1"]))
    story.append(
        table(
            ["Method", "Responsibility"],
            [
                ["afterInsert / afterUpdate", "Cast TAF lists and call handleTrigger"],
                ["handleTrigger", "Active setting, Field Services filter, resolve, query, publish"],
                ["resolveEventType", "No create. Confirm, Dispatched, Canceled, unschedule, schedule"],
                ["queryAppointments", "WITH SECURITY_ENFORCED, then system mode if FLS blocks a field"],
                ["stamp saveInspectors", "Field Services lookup write, skipped when unchanged"],
            ],
            [52 * mm, 122 * mm],
            s,
        )
    )
    story.append(Spacer(1, 3 * mm))
    story.append(
        p(
            "Background users CloudIntegrationUser and AutomatedProcess query and publish "
            "in system mode. An interactive user who can read Service Appointment but lacks "
            "FLS on a payload field is retried in system mode so scheduling is not blocked. "
            "Org after-create automation requires FS_BCO_Detail__c.",
            s["body"],
        )
    )
    story.append(
        table(
            ["Default Setting field", "Value", "Purpose"],
            [
                ["Is_Active__c", "true", "Master publish switch"],
                ["Event_Type__c", "InspectionStatusUpdate", "Header and payload eventType"],
                ["Unscheduled_Status__c", "None", "Unschedule rule and empty crew list"],
                ["Scope_To_Field_Services_Record_Type__c", "true", "Apex always requires Field_Services"],
            ],
            [78 * mm, 42 * mm, 54 * mm],
            s,
        )
    )

    story.append(p("9. Publisher and subscriber permissions", s["h1"]))
    story.append(
        p(
            "FS_InspectionDataUpdate_Event_Publisher is the publisher set. This package "
            "does not deploy a subscriber permission set.",
            s["body"],
        )
    )
    story.append(p("Publisher set", s["h2"]))
    story.extend(
        bullets(
            [
                "Apex: FS_SaStatusEventHandler, FS_AssignedResourceInspectorHandler, mapper, settings, DTO.",
                "Create and Read on FS_InspectionDataUpdate__e. Read on BCO_Detail__c.",
                "ServiceAppointment.Field_Services record type visibility.",
                "Read and edit FS_Assigned_Inspector__c, and FS_IsManualInspection__c on Work Order, Work Order Line Item, and Service Appointment.",
                "Read, not edit: FS_Is_Confirmed__c, Status, and WorkOrder.FS_Booking_Reference__c, plus the other payload fields on the set.",
                "Required platform-event fields are available with object Create and Read. Do not add field permissions that the deploy rejects.",
            ],
            s,
        )
    )
    story.append(p("Assign the publisher set to", s["h2"]))
    story.extend(
        bullets(
            [
                "Dispatchers, and field or mobile users who dispatch or cancel.",
                "Booking users whose insert of a confirmed appointment runs as that user.",
                "Integration users that update Service Appointments or Assigned Resources and must cause a publish.",
                "Do not assign it to CloudIntegrationUser or AutomatedProcess. Those users already run in system mode.",
            ],
            s,
        )
    )
    story.append(
        p(
            "The process that sets Is Confirmed needs edit on FS_Is_Confirmed__c from "
            "its own profile or permission set.",
            s["body"],
        )
    )
    story.append(p("Subscriber application user", s["h2"]))
    story.extend(
        bullets(
            [
                "Grant Read on FS_InspectionDataUpdate__e. Do not grant Create unless that user also publishes.",
                "Do not assign the publisher set only so the application can listen.",
                "A Flow, Apex subscriber, or streaming client running as a named user needs Read on the event.",
                "Store subscriber credentials in the subscriber application. This package has no endpoints or tokens.",
                "Consume FS_InspectionDataUpdate__e only. Branch on EventType__c = InspectionStatusUpdate and payload status.",
                "Map assignedInspectorId, assignedInspectorName, sfsInspectionId, crmInspectionId, cancelledReason, and isConfirmed.",
                "A missing JSON key means null. Unschedule has status None and no inspector. Cancel has status Canceled.",
                "Give the subscriber no edit rights on Service Appointment or Assigned Resource unless that user may change bookings.",
            ],
            s,
        )
    )

    story.append(p("10. Tests", s["h1"]))
    story.append(
        p(
            "Deploy 0Af8r00000XThEiCAL ran FS_SaStatusEventHandlerTest: 19 passed, 0 failed. "
            "Tests call the handlers directly and still run Field Service DML.",
            s["body"],
        )
    )
    story.append(
        table(
            ["Test", "Expectation"],
            [
                ["testCreateDoesNotPublish", "Insert does not publish"],
                ["testConfirmedUpdatePublishesEvent", "Is Confirmed changing to true publishes"],
                ["testStatusBecomesScheduledPublishesEvent", "Status flip to Scheduled publishes when inspector and times exist"],
                ["testNewInspectorAndNewTimesPublishesEvent", "One event with inspector and both times"],
                ["testScheduleChangeOnScheduledPublishesEvent", "Same inspector, new times, one event"],
                ["testInspectorChangePublishesEvent", "Inspector change on Scheduled publishes"],
                ["testScheduledWithoutTimesDoesNotPublish", "Scheduled without both times does not publish"],
                ["testDispatchedPublishesEvent", "Dispatched publishes"],
                ["testCanceledStatusPublishesEvent", "Canceled publishes, with cancelledReason"],
                ["testUnscheduleDoesNotPublish", "None with an inspector still set does not publish"],
                ["testUnschedulePublishesWhenInspectorCleared", "None and a blank inspector publishes"],
                ["testAssignedResourceStampsInspector", "Insert, reassignment, and delete maintain the lookup"],
                ["testManualInspectionPublishesEvent", "A scheduled manual inspection publishes, isManualInspection true"],
                ["testInactiveSettingDoesNotPublish", "Inactive CMDT publishes nothing"],
            ],
            [88 * mm, 86 * mm],
            s,
        )
    )

    story.append(p("11. Post-deploy steps", s["h1"]))
    story.append(
        p(
            "Metadata deploy does not assign permission sets, add fields to layouts, "
            "set Is Confirmed, stamp CRM backfills, or connect the subscriber.",
            s["body"],
        )
    )
    story.append(p("11.1 Publisher permission set", s["h2"]))
    story.extend(
        bullets(
            [
                "Setup, Users, Permission Sets, FS_InspectionDataUpdate_Event_Publisher, Manage Assignments.",
                "Assign the users in section 9. Leave CloudIntegrationUser and AutomatedProcess unassigned.",
            ],
            s,
        )
    )
    story.append(p("11.2 Is Confirmed edit", s["h2"]))
    story.append(
        p(
            "Grant the booking or confirmation process edit on ServiceAppointment.FS_Is_Confirmed__c. "
            "Insert stays silent. The update that sets the flag to true publishes.",
            s["body"],
        )
    )
    story.append(p("11.3 Subscriber application user", s["h2"]))
    story.extend(
        bullets(
            [
                "Identify the integration user the subscriber runs as.",
                "Grant Read on FS_InspectionDataUpdate__e only.",
                "Assign the publisher set only if that same user also updates appointments.",
                "Point the subscriber at this one event and at EventType__c = InspectionStatusUpdate.",
                "Confirm it maps the payload keys in section 7.",
            ],
            s,
        )
    )
    story.append(p("11.4 Page layouts", s["h2"]))
    story.extend(
        bullets(
            [
                "Work Order and Work Order Line Item CRM layouts: Is Manual Inspection.",
                "Field Services Service Appointment layout: Is Manual Inspection, Is Confirmed, and Assigned Inspector.",
                "Prefer Assigned Inspector read-only. The Assigned Resource trigger overwrites a manual edit on the next assign or unassign.",
            ],
            s,
        )
    )
    story.append(p("11.5 Default Setting and Trigger Actions", s["h2"]))
    story.extend(
        bullets(
            [
                "Default Setting: Is Active true, Event Type InspectionStatusUpdate, Unscheduled Status None.",
                "Service Appointment actions FS_SaStatusEventAfterInsert and FS_SaStatusEventAfterUpdate, class FS_SaStatusEventHandler, one context each, not bypassed.",
                "Assigned Resource actions FS_AssignedInspectorAfterInsert, AfterUpdate, and AfterDelete, class FS_AssignedResourceInspectorHandler, not bypassed.",
                "Only one unpackaged trigger on each object calls MetadataTriggerHandler. Leave FSL TR001_Service, TR021_AssignedResource, and Alert Center FS_ServiceAppointmentTrigger in place.",
            ],
            s,
        )
    )
    story.append(p("11.6 CRM backfill and smoke test", s["h2"]))
    story.append(
        p(
            "Set FS_IsManualInspection__c true on the Work Order, line item, and Service "
            "Appointment for a manual booking. The event still publishes, with "
            "isManualInspection true. Use a Field Services appointment with BCO Detail.",
            s["body"],
        )
    )
    story.append(
        table(
            ["Step", "Expected"],
            [
                ["Insert a non-manual appointment", "No event"],
                ["Insert a manual inspection", "One event, isManualInspection true"],
                ["Update Is Confirmed to true", "One event, isConfirmed true"],
                ["Scheduled, both times, then assign a resource", "One event after the lookup is stamped, with inspector and both times"],
                ["Change schedule times only", "One event with the new times"],
                ["Change the assigned resource only", "One event with the new assignedInspectorId"],
                ["Arrival window only", "No event"],
                ["Dispatched", "One event, status Dispatched"],
                ["Canceled, with a cancellation reason", "One event, status Canceled, cancelledReason set"],
                ["None while the inspector is still set", "No event yet"],
                ["Remove the last Assigned Resource at status None", "One event, status None, no assignedInspectorId"],
                ["Is Manual Inspection checked, then schedule or dispatch", "One event, isManualInspection true"],
                ["Subscriber user reads the event", "Read succeeds. Create is not required"],
            ],
            [88 * mm, 86 * mm],
            s,
        )
    )
    story.append(p("Sign-off", s["h2"]))
    story.extend(
        checks(
            [
                "Publisher set assigned to dispatcher, field, booking, and publisher integration users",
                "Confirmation process can edit FS_Is_Confirmed__c",
                "Subscriber user has Read on FS_InspectionDataUpdate__e and Create only if that user also publishes",
                "Subscriber maps InspectionStatusUpdate, status, inspector, schedule, and cancellation fields",
                "Is Manual Inspection, Is Confirmed, and Assigned Inspector are on the Field Services layouts",
                "Default Setting active; SA and Assigned Resource trigger actions are not bypassed",
                "No second MetadataTriggerHandler on Service Appointment or Assigned Resource",
                "CRM stamps FS_IsManualInspection__c so the payload identifies manual inspections",
                "Smoke tests passed",
            ],
            s,
        )
    )
    story.append(p("Not included in this deploy", s["h2"]))
    story.extend(
        bullets(
            [
                "FS_InspectionDataUpdate__e object and fields (already in the org).",
                "Alert Center parent lookup fields and the Field_Services record type.",
                "TAF object definitions. Only the Service Appointment and Assigned Resource records are deployed.",
                "A subscriber permission set, named credential, or subscriber credentials.",
                "Alert Center and FSL managed trigger bodies.",
            ],
            s,
        )
    )

    out = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "FS-InspectionDataUpdate-Design.pdf",
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


