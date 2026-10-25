public with sharing class BookingService {

    @AuraEnabled
    public static Booking__c createBooking(
        Id contactId,
        FlightOfferWrapper offer,
        Integer seats,
        String seatClass
    ) {
        // Step 1: Input Validation
        if (contactId == null) {
            throw new AuraHandledException('Contact ID cannot be null.');
        }
        if (offer == null || String.isBlank(offer.offerId)) {
            throw new AuraHandledException('Offer details cannot be null.');
        }
        if (seats == null || seats <= 0) {
            throw new AuraHandledException('Seat count must be greater than zero.');
        }
        if (String.isBlank(seatClass)) {
            throw new AuraHandledException('Seat Class cannot be blank.');
        }
        
        // Standardize seat class to match restricted picklist values: 'Economy', 'Business', 'First Class'
        String mappedSeatClass = seatClass;
        if (seatClass.equalsIgnoreCase('economy') || seatClass.equalsIgnoreCase('premium_economy')) {
            mappedSeatClass = 'Economy';
        } else if (seatClass.equalsIgnoreCase('business')) {
            mappedSeatClass = 'Business';
        } else if (seatClass.equalsIgnoreCase('first') || seatClass.equalsIgnoreCase('first class')) {
            mappedSeatClass = 'First Class';
        }

        // Step 2: Price Reconfirmation (Callout must occur BEFORE setting savepoint)
        FlightOfferWrapper confirmedOffer;
        try {
            confirmedOffer = DuffelFlightPricingService.confirmPrice(offer.offerId);
        } catch (Exception ex) {
            if (ex instanceof AuraHandledException) {
                throw ex;
            }
            throw new AuraHandledException('Unable to confirm pricing: ' + ex.getMessage());
        }

        if (confirmedOffer == null || confirmedOffer.price == null) {
            throw new AuraHandledException('Unable to confirm pricing with Duffel.');
        }

        // Step 3: Seat Availability Validation
        if (confirmedOffer.seatsAvailable != null && confirmedOffer.seatsAvailable < seats) {
            throw new AuraHandledException('Insufficient seats available. Only ' + confirmedOffer.seatsAvailable + ' seats left.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            // Step 4: Create/Retrieve Flight__c record
            Flight__c flight = FlightService.createFlight(confirmedOffer);

            // Step 5: Query primary contact to map Passenger_Detail__c fields
            Contact primaryContact = [
                SELECT FirstName, LastName, Birthdate 
                FROM Contact 
                WHERE Id = :contactId 
                WITH USER_MODE
                LIMIT 1
            ];

            // Create Booking__c
            Booking__c booking = new Booking__c();
            booking.Passenger__c = contactId;
            booking.Flight__c = flight.Id;
            booking.Seat_Class__c = mappedSeatClass;
            booking.Number_of_Seats__c = seats;
            booking.Base_Fare__c = confirmedOffer.price / seats;
            booking.Taxes_Fees__c = 0.0;
            booking.Booking_Status__c = (seats >= 10) ? 'Draft' : 'Confirmed';
            booking.Booking_Date__c = Date.today();
            booking.User__c = UserInfo.getUserId();
            
            insert as user booking;

            // Step 6: Create Passenger_Detail__c
            Passenger_Detail__c pd = new Passenger_Detail__c();
            pd.Booking__c = booking.Id;
            pd.Name = String.isNotBlank(primaryContact.FirstName) ? primaryContact.FirstName : 'Primary';
            pd.Last_Name__c = primaryContact.LastName;
            pd.Passenger_Type__c = 'Adult';
            pd.Date_of_Birth__c = primaryContact.Birthdate != null ? primaryContact.Birthdate : Date.newInstance(1990, 1, 1);
            if (flight.Is_International__c) {
                pd.Passport_Number__c = 'AUTO-PASSPORT';
            }
            
            insert as user pd;

            // Step 7: Create Flight_Segment__c list
            List<Flight_Segment__c> segments = new List<Flight_Segment__c>();
            if (confirmedOffer.segments != null) {
                for (Integer i = 0; i < confirmedOffer.segments.size(); i++) {
                    SegmentWrapper seg = confirmedOffer.segments[i];
                    Flight_Segment__c fs = new Flight_Segment__c();
                    fs.Booking__c = booking.Id;
                    fs.Name = seg.origin; // Standard name holds Origin
                    fs.Destination__c = seg.destination;
                    fs.Departure_DateTime__c = seg.departingAt;
                    fs.Arrival_DateTime__c = seg.arrivingAt;
                    fs.Flight_Number__c = seg.flightNumber;
                    fs.Carrier_Code__c = seg.carrierCode;
                    fs.Segment_Order__c = i + 1; // 1-based leg sequence
                    segments.add(fs);
                }
            }
            
            if (!segments.isEmpty()) {
                insert as user segments;
            }

            return booking;

        } catch (Exception ex) {
            Database.rollback(sp);
            if (ex instanceof AuraHandledException) {
                throw ex;
            }
            throw new AuraHandledException('Unable to create booking: ' + ex.getMessage());
        }
    }

    private static final Set<String> ALLOWED_MEALS = new Set<String>{
        'Vegetarian', 'Non-Veg', 'Vegan', 'Jain'
    };

    private static Date parseDob(String dobStr, Integer passengerIndex) {
        if (String.isBlank(dobStr)) {
            throw new AuraHandledException('Date of birth is required for passenger #' + passengerIndex);
        }
        try {
            Date d = Date.valueOf(dobStr);
            if (d >= Date.today()) {
                throw new AuraHandledException('Date of birth must be in the past for passenger #' + passengerIndex);
            }
            return d;
        } catch (Exception ex) {
            throw new AuraHandledException('Invalid date of birth format YYYY-MM-DD for passenger #' + passengerIndex);
        }
    }

    private static String validateAndFormatMeals(List<String> meals) {
        if (meals == null || meals.isEmpty()) {
            return null;
        }
        List<String> validMeals = new List<String>();
        for (String m : meals) {
            if (String.isBlank(m)) continue;
            if (!ALLOWED_MEALS.contains(m)) {
                throw new AuraHandledException('Invalid meal preference value: ' + m);
            }
            validMeals.add(m);
        }
        return validMeals.isEmpty() ? null : String.join(validMeals, ';');
    }

    @AuraEnabled
    public static Booking__c createBookingWithPassengers(
        Id contactId,
        FlightOfferWrapper offer,
        Integer seats,
        String seatClass,
        List<PassengerInput> passengers
    ) {
        if (contactId == null) {
            throw new AuraHandledException('Contact ID cannot be null.');
        }
        if (offer == null || String.isBlank(offer.offerId)) {
            throw new AuraHandledException('Offer details cannot be null.');
        }
        if (passengers == null || passengers.isEmpty()) {
            throw new AuraHandledException('Passenger list cannot be empty.');
        }

        Integer actualSeats = passengers.size();

        if (String.isBlank(seatClass)) {
            throw new AuraHandledException('Seat Class cannot be blank.');
        }
        
        String mappedSeatClass = seatClass;
        if (seatClass.equalsIgnoreCase('economy') || seatClass.equalsIgnoreCase('premium_economy')) {
            mappedSeatClass = 'Economy';
        } else if (seatClass.equalsIgnoreCase('business')) {
            mappedSeatClass = 'Business';
        } else if (seatClass.equalsIgnoreCase('first') || seatClass.equalsIgnoreCase('first class')) {
            mappedSeatClass = 'First Class';
        }

        FlightOfferWrapper confirmedOffer;
        try {
            confirmedOffer = DuffelFlightPricingService.confirmPrice(offer.offerId);
        } catch (Exception ex) {
            if (ex instanceof AuraHandledException) {
                throw ex;
            }
            throw new AuraHandledException('Unable to confirm pricing: ' + ex.getMessage());
        }

        if (confirmedOffer == null || confirmedOffer.price == null) {
            throw new AuraHandledException('Unable to confirm pricing with Duffel.');
        }

        if (confirmedOffer.seatsAvailable != null && confirmedOffer.seatsAvailable < actualSeats) {
            throw new AuraHandledException('Insufficient seats available. Only ' + confirmedOffer.seatsAvailable + ' seats left.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Flight__c flight = FlightService.createFlight(confirmedOffer);

            Booking__c booking = new Booking__c();
            booking.Passenger__c = contactId;
            booking.Flight__c = flight.Id;
            booking.Seat_Class__c = mappedSeatClass;
            booking.Number_of_Seats__c = actualSeats;
            booking.Base_Fare__c = confirmedOffer.price / actualSeats;
            booking.Taxes_Fees__c = 0.0;
            booking.Booking_Status__c = (actualSeats >= 10) ? 'Draft' : 'Confirmed';
            booking.Booking_Date__c = Date.today();
            booking.User__c = UserInfo.getUserId();
            
            insert as user booking;

            List<Passenger_Detail__c> details = new List<Passenger_Detail__c>();
            for (Integer i = 0; i < passengers.size(); i++) {
                PassengerInput pi = passengers[i];
                Integer idx = i + 1;

                if (pi == null) {
                    throw new AuraHandledException('Passenger details at index ' + idx + ' cannot be null.');
                }
                if (String.isBlank(pi.firstName)) {
                    throw new AuraHandledException('First Name is required for passenger #' + idx);
                }
                if (String.isBlank(pi.lastName)) {
                    throw new AuraHandledException('Last Name is required for passenger #' + idx);
                }

                Date dob = parseDob(pi.dob, idx);
                String meals = validateAndFormatMeals(pi.mealPreference);

                if (flight.Is_International__c && String.isBlank(pi.passport)) {
                    throw new AuraHandledException('Passport Number is required for passenger #' + idx + ' on international routes.');
                }

                Passenger_Detail__c pd = new Passenger_Detail__c();
                pd.Booking__c = booking.Id;
                pd.Name = pi.firstName;
                pd.Last_Name__c = pi.lastName;
                pd.Passenger_Type__c = String.isNotBlank(pi.passengerType) ? pi.passengerType : 'Adult';
                pd.Date_of_Birth__c = dob;
                pd.Passport_Number__c = pi.passport;
                pd.Meal_Preference__c = meals;
                details.add(pd);
            }

            if (!details.isEmpty()) {
                insert as user details;
            }

            List<Flight_Segment__c> segments = new List<Flight_Segment__c>();
            if (confirmedOffer.segments != null) {
                for (Integer i = 0; i < confirmedOffer.segments.size(); i++) {
                    SegmentWrapper seg = confirmedOffer.segments[i];
                    Flight_Segment__c fs = new Flight_Segment__c();
                    fs.Booking__c = booking.Id;
                    fs.Name = seg.origin;
                    fs.Destination__c = seg.destination;
                    fs.Departure_DateTime__c = seg.departingAt;
                    fs.Arrival_DateTime__c = seg.arrivingAt;
                    fs.Flight_Number__c = seg.flightNumber;
                    fs.Carrier_Code__c = seg.carrierCode;
                    fs.Segment_Order__c = i + 1;
                    segments.add(fs);
                }
            }
            
            if (!segments.isEmpty()) {
                insert as user segments;
            }

            return booking;

        } catch (Exception ex) {
            Database.rollback(sp);
            if (ex instanceof AuraHandledException) {
                throw ex;
            }
            throw new AuraHandledException('Unable to create booking: ' + ex.getMessage());
        }
    }

    public class PassengerInput {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String dob { get; set; }
        @AuraEnabled public String passengerType { get; set; }
        @AuraEnabled public String passport { get; set; }
        @AuraEnabled public List<String> mealPreference { get; set; }
    }
}
