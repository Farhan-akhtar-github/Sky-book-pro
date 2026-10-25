// ── One-time script: Populate User__c on Confirmed bookings where User__c is null ──
// Run via: sf apex run --file fix_confirmed_booking_user.apex

// Step 1 – Query target records
List<Booking__c> bookings = [
    SELECT Id, Name, OwnerId, User__c
    FROM   Booking__c
    WHERE  Booking_Status__c = 'Confirmed'
    AND    User__c = null
];

System.debug('Records found: ' + bookings.size());

if (bookings.isEmpty()) {
    System.debug('No records to update. Exiting.');
} else {

    // Step 2 – Set User__c = OwnerId on each record
    for (Booking__c b : bookings) {
        b.User__c = b.OwnerId;
    }

    // Step 3 – Bulk update
    Database.SaveResult[] results = Database.update(bookings, false);

    // Step 4 – Report results
    Integer successCount = 0;
    Integer failCount    = 0;

    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successCount++;
            System.debug('Updated: ' + bookings[i].Name + ' (Id=' + bookings[i].Id + ') → User__c=' + bookings[i].OwnerId);
        } else {
            failCount++;
            for (Database.Error err : results[i].getErrors()) {
                System.debug('FAILED: ' + bookings[i].Name + ' — ' + err.getMessage());
            }
        }
    }

    System.debug('=== SUMMARY ===');
    System.debug('Records found:        ' + bookings.size());
    System.debug('Successfully updated: ' + successCount);
    System.debug('Failed:               ' + failCount);
}
