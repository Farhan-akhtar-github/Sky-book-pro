trigger BookingTrigger on Booking__c (before insert, before update) {
    BookingTriggerHandler.handle(
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap,
        Trigger.operationType
    );
}
