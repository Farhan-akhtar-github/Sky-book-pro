public with sharing class CancellationService {

    @AuraEnabled
    public static Booking__c cancelBooking(Id bookingId, String reason) {
        if (bookingId == null) {
            throw new AuraHandledException('Booking ID cannot be null.');
        }
        if (String.isBlank(reason)) {
            throw new AuraHandledException('Cancellation reason is required.');
        }

        // 1. Query the booking
        List<Booking__c> bookings = [
            SELECT Id, Name, Booking_Status__c, Total_Amount__c, Cancellation_Reason__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH USER_MODE
            LIMIT 1
        ];

        if (bookings.isEmpty()) {
            throw new AuraHandledException('Booking record not found.');
        }

        Booking__c booking = bookings[0];

        // 2. Check if already cancelled
        if (booking.Booking_Status__c == 'Cancelled') {
            throw new AuraHandledException('This booking is already cancelled.');
        }

        // 3. Update status and reason
        booking.Booking_Status__c = 'Cancelled';
        booking.Cancellation_Reason__c = reason;

        try {
            update as user booking;
            return booking;

        } catch (Exception ex) {
            throw new AuraHandledException('Failed to process cancellation: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getRefundStatus(Id bookingId) {
        if (bookingId == null) {
            return null;
        }
        List<Refund__c> refunds = [
            SELECT Refund_Status__c 
            FROM Refund__c 
            WHERE Booking__c = :bookingId 
            WITH USER_MODE 
            ORDER BY Requested_Date__c DESC 
            LIMIT 1
        ];
        if (refunds.isEmpty()) {
            return null;
        }
        return refunds[0].Refund_Status__c;
    }
}
