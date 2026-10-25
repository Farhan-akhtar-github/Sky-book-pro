public with sharing class BookingArchiveBatch implements Database.Batchable<SObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Booking_Date__c, Booking_Status__c
            FROM Booking__c
            WHERE Booking_Date__c < LAST_N_YEARS:2
            AND Booking_Status__c IN ('Completed', 'Cancelled')
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Booking__c> scope) {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Booking__c.fields.getMap();
        
        if (!fields.containsKey('Archive__c')) {
            System.debug('Archive__c field not found. Archival skipped.');
            return;
        }
        
        // If Archive__c existed (Option B), we would populate and update it dynamically:
        List<Booking__c> bookingsToUpdate = new List<Booking__c>();
        for (Booking__c b : scope) {
            b.put('Archive__c', true);
            bookingsToUpdate.add(b);
        }
        if (!bookingsToUpdate.isEmpty()) {
            update as user bookingsToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('Archive batch completed');
    }
}
