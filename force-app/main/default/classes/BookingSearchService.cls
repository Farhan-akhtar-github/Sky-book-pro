public with sharing class BookingSearchService {

    public class RevenueSummaryWrapper {
        @AuraEnabled public String month { get; set; }
        @AuraEnabled public Decimal revenue { get; set; }

        public RevenueSummaryWrapper(String month, Decimal revenue) {
            this.month = month;
            this.revenue = revenue != null ? revenue : 0.0;
        }
    }

    public class SearchResultWrapper {
        @AuraEnabled public List<Contact> contacts { get; set; }
        @AuraEnabled public List<Booking__c> bookings { get; set; }

        public SearchResultWrapper(List<Contact> contacts, List<Booking__c> bookings) {
            this.contacts = contacts != null ? contacts : new List<Contact>();
            this.bookings = bookings != null ? bookings : new List<Booking__c>();
        }
    }

    /**
     * Requirement 1: Get Confirmed Bookings by Travel Agent
     * Purpose: Display all confirmed bookings owned by the currently logged-in travel agent.
     */
    @AuraEnabled
    public static List<Booking__c> getConfirmedBookingsByAgent(Id userId) {
        if (userId == null) {
            return new List<Booking__c>();
        }
        return [
            SELECT Id, Name, Total_Amount__c, Booking_Status__c, Booking_Date__c,
                   Seat_Class__c, Flight__c,
                   Flight__r.Airline_Name__c, Flight__r.Origin_Airport__c,
                   Flight__r.Destination_Airport__c, Flight__r.Departure_DateTime__c
            FROM Booking__c
            WHERE User__c = :userId
            AND Booking_Status__c != 'Draft'
            WITH USER_MODE
            ORDER BY Booking_Date__c DESC
        ];
    }

    /**
     * Requirement 2: Upcoming Departures (Reminder Flow)
     * Purpose: Used by DepartureReminderQueueable and scheduler.
     */
    public static List<Booking__c> getUpcomingDepartures() {
        return [
            SELECT Id, Passenger__c, Flight__c
            FROM Booking__c
            WHERE Flight__r.Departure_DateTime__c = TOMORROW
            AND Booking_Status__c = 'Confirmed'
            WITH USER_MODE
        ];
    }

    /**
     * Requirement 3: Revenue Aggregation by Month
     * Purpose: Dashboard reporting and revenue analytics.
     */
    @AuraEnabled(cacheable=true)
    public static List<RevenueSummaryWrapper> getRevenueAggregationByMonth() {
        List<AggregateResult> results = [
            SELECT CALENDAR_MONTH(Booking_Date__c) monthVal, 
                   CALENDAR_YEAR(Booking_Date__c) yearVal, 
                   SUM(Total_Amount__c) totalRevenue
            FROM Booking__c
            WHERE Booking_Status__c = 'Confirmed'
            WITH USER_MODE
            GROUP BY CALENDAR_YEAR(Booking_Date__c), CALENDAR_MONTH(Booking_Date__c)
            ORDER BY CALENDAR_YEAR(Booking_Date__c), CALENDAR_MONTH(Booking_Date__c)
        ];
        
        List<RevenueSummaryWrapper> summary = new List<RevenueSummaryWrapper>();
        for (AggregateResult ar : results) {
            Integer m = (Integer) ar.get('monthVal');
            Integer y = (Integer) ar.get('yearVal');
            summary.add(new RevenueSummaryWrapper(
                String.valueOf(m) + '/' + String.valueOf(y),
                (Decimal) ar.get('totalRevenue')
            ));
        }
        return summary;
    }

    /**
     * Requirement 4: Passenger Search (SOSL)
     * Purpose: Global search across passengers and bookings.
     */
    @AuraEnabled(cacheable=true)
    public static SearchResultWrapper searchPassengersAndBookings(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new SearchResultWrapper(new List<Contact>(), new List<Booking__c>());
        }
        
        List<List<SObject>> searchResults = [
            FIND :searchTerm
            IN ALL FIELDS
            RETURNING
            Contact(Id, Name, Email),
            Booking__c(Id, Name, Booking_Status__c, Booking_Date__c, Total_Amount__c,
                       Seat_Class__c, Flight__c,
                       Flight__r.Airline_Name__c, Flight__r.Origin_Airport__c,
                       Flight__r.Destination_Airport__c, Flight__r.Departure_DateTime__c)
            WITH USER_MODE
        ];
        
        List<Contact> contacts = (List<Contact>) searchResults[0];
        List<Booking__c> bookings = (List<Booking__c>) searchResults[1];
        
        if (!contacts.isEmpty()) {
            Set<Id> contactIds = new Set<Id>();
            for (Contact c : contacts) {
                contactIds.add(c.Id);
            }
            
            List<Booking__c> contactBookings = [
                SELECT Id, Name, Booking_Status__c, Booking_Date__c, Total_Amount__c,
                       Seat_Class__c, Flight__c,
                       Flight__r.Airline_Name__c, Flight__r.Origin_Airport__c,
                       Flight__r.Destination_Airport__c, Flight__r.Departure_DateTime__c
                FROM Booking__c
                WHERE Passenger__c IN :contactIds
                WITH USER_MODE
            ];
            
            Set<Id> existingBookingIds = new Set<Id>();
            for (Booking__c b : bookings) {
                existingBookingIds.add(b.Id);
            }
            
            for (Booking__c cb : contactBookings) {
                if (!existingBookingIds.contains(cb.Id)) {
                    bookings.add(cb);
                    existingBookingIds.add(cb.Id);
                }
            }
        }
        
        return new SearchResultWrapper(contacts, bookings);
    }

    /**
     * Requirement 5: Booking Lookup by Contact
     * Purpose: Show booking history for a passenger.
     */
    @AuraEnabled(cacheable=true)
    public static List<Booking__c> getBookingsByContact(Id contactId) {
        if (contactId == null) {
            return new List<Booking__c>();
        }
        return [
            SELECT Id, Name, Booking_Status__c, Booking_Date__c, Total_Amount__c,
                   Seat_Class__c, Flight__c,
                   Flight__r.Airline_Name__c, Flight__r.Origin_Airport__c,
                   Flight__r.Destination_Airport__c, Flight__r.Departure_DateTime__c
            FROM Booking__c
            WHERE Passenger__c = :contactId
            WITH USER_MODE
            ORDER BY Booking_Date__c DESC
        ];
    }

    /**
     * Requirement 6: Flight Lookup by Offer ID
     * Purpose: Prevent duplicate Flight__c creation (delegates to FlightService).
     */
    public static Flight__c getFlightByOfferId(String offerId) {
        return FlightService.getFlightByOfferId(offerId);
    }

    /**
     * Requirement 7: Refund Lookup
     * Purpose: Used during cancellation processing.
     */
    @AuraEnabled(cacheable=true)
    public static List<Refund__c> getRefundsByBookingId(Id bookingId) {
        if (bookingId == null) {
            return new List<Refund__c>();
        }
        return [
            SELECT Id, Refund_Amount__c, Refund_Status__c
            FROM Refund__c
            WHERE Booking__c = :bookingId
            WITH USER_MODE
        ];
    }
}
