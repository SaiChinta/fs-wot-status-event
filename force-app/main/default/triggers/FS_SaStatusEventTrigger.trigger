/**
 * @description Trigger Actions Framework entry for ServiceAppointment after update.
 * FS_SaStatusEventHandler publishes only for record type Field_Services and only
 * when FS_IsManualInspection__c is false. Registers through Trigger_Action__mdt;
 * do not add a second handler call here.
 */
trigger FS_SaStatusEventTrigger on ServiceAppointment (after update) {
  new MetadataTriggerHandler().run();
}
