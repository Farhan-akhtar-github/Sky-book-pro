public with sharing class BookingDetailController {
    public String               bookingId        { get; set; }
    public Booking__c           booking          { get; set; }
    public List<Passenger_Detail__c> passengerDetails { get; set; }
    public List<Flight_Segment__c>   flightSegments   { get; set; }
    public List<Refund__c>      refunds          { get; set; }
    public String               errorMessage     { get; set; }
    public Boolean              bookingFound     { get; set; }

    @TestVisible private static Boolean forceLoadException = false;

    public BookingDetailController() {
        bookingId = ApexPages.currentPage().getParameters().get('id');
        bookingFound = false;
        passengerDetails = new List<Passenger_Detail__c>();
        flightSegments = new List<Flight_Segment__c>();
        refunds = new List<Refund__c>();

        if (String.isBlank(bookingId)) {
            errorMessage = 'Booking not found. Please return to Booking Search.';
            return;
        }
        loadBooking();
    }

    private void loadBooking() {
        try {
            if (forceLoadException) {
                throw new System.QueryException('Simulated load failure');
            }
            List<Booking__c> bookings = [
                SELECT Id, Name, Booking_Status__c, Booking_Date__c, Number_of_Seats__c,
                       Total_Amount__c, Base_Fare__c, Taxes_Fees__c, Seat_Class__c,
                       Payment_Reference__c,
                       Passenger__r.Name, Passenger__r.Email, Passenger__r.Phone,
                       User__r.Name,
                       Flight__r.Name, Flight__r.Origin_Airport__c,
                       Flight__r.Destination_Airport__c, Flight__r.Airline_Name__c,
                       Flight__r.Departure_DateTime__c, Flight__r.Arrival_DateTime__c
                FROM  Booking__c 
                WHERE Id = :bookingId 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (bookings.isEmpty()) {
                errorMessage = 'Booking not found. Please return to Booking Search.';
                return;
            }

            booking = bookings[0];
            bookingFound = true;

            // Load Passenger details
            passengerDetails = [
                SELECT Id, Name, Last_Name__c, Full_Passenger_Name__c,
                       Date_of_Birth__c, Passport_Number__c, Passenger_Type__c,
                       Seat_Number__c, Meal_Preference__c
                FROM  Passenger_Detail__c 
                WHERE Booking__c = :bookingId 
                WITH USER_MODE 
                ORDER BY Name
            ];

            // Load Flight segments
            flightSegments = [
                SELECT Id, Name, Destination__c, Carrier_Code__c, Flight_Number__c,
                       Departure_DateTime__c, Arrival_DateTime__c, Segment_Order__c
                FROM  Flight_Segment__c 
                WHERE Booking__c = :bookingId 
                WITH USER_MODE 
                ORDER BY Segment_Order__c ASC
            ];

            // Load Refunds
            refunds = [
                SELECT Id, Refund_Amount__c, Refund_Status__c, Requested_Date__c, Completed_Date__c
                FROM  Refund__c 
                WHERE Booking__c = :bookingId 
                WITH USER_MODE 
                ORDER BY Requested_Date__c DESC
            ];

        } catch (Exception ex) {
            errorMessage = 'Unable to load booking details: ' + ex.getMessage();
            bookingFound = false;
        }
    }

    public String getStatusBadgeClass() {
        if (booking == null) return 'skp-badge-grey';
        if ('Confirmed'.equals(booking.Booking_Status__c)) return 'skp-badge-green';
        if ('Draft'.equals(booking.Booking_Status__c))     return 'skp-badge-yellow';
        if ('Cancelled'.equals(booking.Booking_Status__c)) return 'skp-badge-red';
        return 'skp-badge-grey';
    }

    public PageReference goToBookingSearch() {
        PageReference pr = new PageReference('/apex/BookingSearch');
        pr.setRedirect(true);
        return pr;
    }

    public PageReference goToFlightSearch() {
        PageReference pr = new PageReference('/apex/FlightSearch');
        pr.setRedirect(true);
        return pr;
    }

    public class BookingDetailWrapper {
        @AuraEnabled public Booking__c booking { get; set; }
        @AuraEnabled public List<Passenger_Detail__c> passengerDetails { get; set; }
        @AuraEnabled public List<Flight_Segment__c> flightSegments { get; set; }
        @AuraEnabled public List<Refund__c> refunds { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static BookingDetailWrapper getBookingDetail(Id bookingId) {
        if (bookingId == null) {
            return null;
        }
        
        BookingDetailWrapper wrapper = new BookingDetailWrapper();
        
        wrapper.booking = [
            SELECT Id, Name, Booking_Status__c, Booking_Date__c, Number_of_Seats__c,
                   Total_Amount__c, Base_Fare__c, Taxes_Fees__c, Seat_Class__c,
                   Payment_Reference__c,
                   Passenger__r.Name, Passenger__r.Email, Passenger__r.Phone,
                   User__r.Name,
                   Flight__r.Name, Flight__r.Origin_Airport__c,
                   Flight__r.Destination_Airport__c, Flight__r.Airline_Name__c,
                   Flight__r.Departure_DateTime__c, Flight__r.Arrival_DateTime__c
            FROM  Booking__c 
            WHERE Id = :bookingId 
            WITH USER_MODE 
            LIMIT 1
        ];

        wrapper.passengerDetails = [
            SELECT Id, Name, Last_Name__c, Full_Passenger_Name__c,
                   Date_of_Birth__c, Passport_Number__c, Passenger_Type__c,
                   Seat_Number__c, Meal_Preference__c
            FROM  Passenger_Detail__c 
            WHERE Booking__c = :bookingId 
            WITH USER_MODE 
            ORDER BY Name
        ];

        wrapper.flightSegments = [
            SELECT Id, Name, Destination__c, Carrier_Code__c, Flight_Number__c,
                   Departure_DateTime__c, Arrival_DateTime__c, Segment_Order__c
            FROM  Flight_Segment__c 
            WHERE Booking__c = :bookingId 
            WITH USER_MODE 
            ORDER BY Segment_Order__c ASC
        ];

        wrapper.refunds = [
            SELECT Id, Refund_Amount__c, Refund_Status__c, Requested_Date__c, Completed_Date__c
            FROM  Refund__c 
            WHERE Booking__c = :bookingId 
            WITH USER_MODE 
            ORDER BY Requested_Date__c DESC
        ];
        
        return wrapper;
    }
}

