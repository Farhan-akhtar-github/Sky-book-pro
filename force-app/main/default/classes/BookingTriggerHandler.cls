public with sharing class BookingTriggerHandler {

    private static Boolean isExecuting = false;

    public static void handle(
        List<Booking__c> newBookings,
        Map<Id, Booking__c> newMap,
        List<Booking__c> oldBookings,
        Map<Id, Booking__c> oldMap,
        System.TriggerOperation operationType
    ) {
        if (isExecuting) {
            return;
        }
        isExecuting = true;
        
        try {
            switch on operationType {
                when BEFORE_INSERT {
                    beforeInsert(newBookings);
                }
                when BEFORE_UPDATE {
                    beforeUpdate(newBookings, oldMap);
                }
            }
        } finally {
            isExecuting = false;
        }
    }

    private static void beforeInsert(List<Booking__c> newBookings) {
        for (Booking__c b : newBookings) {
            if (b.Booking_Date__c == null) {
                b.Booking_Date__c = Date.today();
            }
            if (b.User__c == null) {
                b.User__c = UserInfo.getUserId();
            }
            if (String.isBlank(b.Booking_Status__c)) {
                b.Booking_Status__c = 'Draft';
            }
        }
    }

    private static void beforeUpdate(List<Booking__c> newBookings, Map<Id, Booking__c> oldMap) {
        Set<Id> bookingIdsToCheckSeats = new Set<Id>();
        List<Booking__c> bookingsToCheckSeats = new List<Booking__c>();

        for (Booking__c b : newBookings) {
            Booking__c oldBooking = oldMap.get(b.Id);

            // Rule 1: Prevent Cancelled -> Confirmed
            if (oldBooking.Booking_Status__c == 'Cancelled' && b.Booking_Status__c == 'Confirmed') {
                b.addError('Cancelled bookings cannot be re-confirmed.');
            }

            // Rule 2: Check if seat count has changed
            if (b.Number_of_Seats__c != oldBooking.Number_of_Seats__c) {
                bookingIdsToCheckSeats.add(b.Id);
                bookingsToCheckSeats.add(b);
            }
        }

        // Rule 2: Prevent reducing seat count below passenger count
        if (!bookingIdsToCheckSeats.isEmpty()) {
            Map<Id, Integer> bookingToPassengerCount = new Map<Id, Integer>();
            List<AggregateResult> arList = [
                SELECT Booking__c, COUNT(Id) passengerCount
                FROM Passenger_Detail__c
                WHERE Booking__c IN :bookingIdsToCheckSeats
                WITH USER_MODE
                GROUP BY Booking__c
            ];
            for (AggregateResult ar : arList) {
                bookingToPassengerCount.put((Id) ar.get('Booking__c'), (Integer) ar.get('passengerCount'));
            }

            for (Booking__c b : bookingsToCheckSeats) {
                Integer passengerCount = bookingToPassengerCount.get(b.Id);
                if (passengerCount != null && b.Number_of_Seats__c < passengerCount) {
                    b.addError('Seats cannot be less than passengers.');
                }
            }
        }
    }
}
