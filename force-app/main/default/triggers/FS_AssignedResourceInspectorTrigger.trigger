/**
 * @description Trigger Actions Framework entry for AssignedResource insert, update, and delete.
 * FS_AssignedResourceInspectorHandler stamps ServiceAppointment.FS_Assigned_Inspector__c.
 * Do not publish platform events from this trigger.
 */
trigger FS_AssignedResourceInspectorTrigger on AssignedResource (after insert, after update, after delete) {
  new MetadataTriggerHandler().run();
}