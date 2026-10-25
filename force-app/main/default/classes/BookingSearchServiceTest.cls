@isTest
public class BookingSearchServiceTest {

    @isTest
    static void testGetConfirmedBookingsByAgent() {
        // Create Contact
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        // Create Flight
        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_agent_123',
            Arrival_DateTime__c = DateTime.now().addHours(2),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'JFK',
            Origin_Airport__c = 'LHR',
            Duration_Minutes__c = 120,
            Is_International__c = true,
            Status__c = 'Active'
        );
        insert f;

        Id currentUserId = UserInfo.getUserId();

        // Create Confirmed Booking
        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 1,
            Base_Fare__c = 150.00,
            Taxes_Fees__c = 0.0,
            Booking_Status__c = 'Confirmed',
            Booking_Date__c = Date.today(),
            User__c = currentUserId
        );
        insert b;

        // Create Draft Booking (should be excluded)
        Booking__c draftB = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 1,
            Base_Fare__c = 150.00,
            Taxes_Fees__c = 0.0,
            Booking_Status__c = 'Draft',
            Booking_Date__c = Date.today(),
            User__c = currentUserId
        );
        insert draftB;

        Test.startTest();
        List<Booking__c> results = BookingSearchService.getConfirmedBookingsByAgent(currentUserId);
        List<Booking__c> nullResults = BookingSearchService.getConfirmedBookingsByAgent(null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find exactly 1 booking (excluding Draft)');
        System.assertEquals(b.Id, results[0].Id);
        System.assertEquals('Test Airline', results[0].Flight__r.Airline_Name__c);
        System.assertEquals('LHR', results[0].Flight__r.Origin_Airport__c);
        System.assertEquals('JFK', results[0].Flight__r.Destination_Airport__c);
        System.assertEquals('Economy', results[0].Seat_Class__c);
        System.assertNotEquals(null, results[0].Flight__r.Departure_DateTime__c);
        System.assertEquals(0, nullResults.size());
    }

    @isTest
    static void testGetUpcomingDepartures() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        // Departure is tomorrow
        DateTime tomorrow = DateTime.now().addDays(1);
        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_tomorrow_123',
            Arrival_DateTime__c = tomorrow.addHours(2),
            Departure_DateTime__c = tomorrow,
            Destination_Airport__c = 'JFK',
            Origin_Airport__c = 'LHR',
            Duration_Minutes__c = 120,
            Is_International__c = true,
            Status__c = 'Active'
        );
        insert f;

        // Confirmed Booking
        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 1,
            Base_Fare__c = 150.00,
            Taxes_Fees__c = 0.0,
            Booking_Status__c = 'Confirmed',
            Booking_Date__c = Date.today(),
            User__c = UserInfo.getUserId()
        );
        insert b;

        Test.startTest();
        List<Booking__c> departures = BookingSearchService.getUpcomingDepartures();
        Test.stopTest();

        System.assertEquals(1, departures.size(), 'Should return 1 upcoming departure');
        System.assertEquals(b.Id, departures[0].Id);
    }

    @isTest
    static void testGetRevenueAggregationByMonth() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_rev_123',
            Arrival_DateTime__c = DateTime.now().addHours(2),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'JFK',
            Origin_Airport__c = 'LHR',
            Duration_Minutes__c = 120,
            Is_International__c = true,
            Status__c = 'Active'
        );
        insert f;

        // Use standard booking date (today) to get a predictable month string
        Date d1 = Date.newInstance(2026, 6, 14);
        
        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 1,
            Base_Fare__c = 150.00,
            Taxes_Fees__c = 50.00,
            Booking_Status__c = 'Confirmed',
            Booking_Date__c = d1,
            User__c = UserInfo.getUserId()
        );
        insert b;

        Test.startTest();
        List<BookingSearchService.RevenueSummaryWrapper> rev = BookingSearchService.getRevenueAggregationByMonth();
        Test.stopTest();

        System.assert(rev.size() > 0, 'Should return aggregated revenue');
        System.assertEquals('6/2026', rev[0].month);
        System.assertEquals(200.00, rev[0].revenue, 'Total amount should be (150+50)*1 = 200');
    }

    @isTest
    static void testSearchPassengersAndBookings() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_sosl_123',
            Arrival_DateTime__c = DateTime.now().addHours(2),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'JFK',
            Origin_Airport__c = 'LHR',
            Duration_Minutes__c = 120,
            Is_International__c = true,
            Status__c = 'Active'
        );
        insert f;

        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 1,
            Base_Fare__c = 150.00,
            Taxes_Fees__c = 0.0,
            Booking_Status__c = 'Confirmed',
            Booking_Date__c = Date.today(),
            User__c = UserInfo.getUserId()
        );
        insert b;

        // Mock SOSL Search Results
        Id [] searchIds = new Id[]{c.Id, b.Id};
        Test.setFixedSearchResults(searchIds);

        Test.startTest();
        BookingSearchService.SearchResultWrapper wrap = BookingSearchService.searchPassengersAndBookings('John');
        BookingSearchService.SearchResultWrapper emptyWrap = BookingSearchService.searchPassengersAndBookings('');
        Test.stopTest();

        System.assertEquals(1, wrap.contacts.size());
        System.assertEquals(c.Id, wrap.contacts[0].Id);
        System.assertEquals(1, wrap.bookings.size());
        System.assertEquals(b.Id, wrap.bookings[0].Id);

        System.assertEquals(0, emptyWrap.contacts.size());
        System.assertEquals(0, emptyWrap.bookings.size());
    }

    @isTest
    static void testGetBookingsByContact() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_contact_123',
            Arrival_DateTime__c = DateTime.now().addHours(2),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'JFK',
            Origin_Airport__c = 'LHR',
            Duration_Minutes__c = 120,
            Is_International__c = true,
            Status__c = 'Active'
        );
        insert f;

        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 1,
            Base_Fare__c = 150.00,
            Taxes_Fees__c = 0.0,
            Booking_Status__c = 'Confirmed',
            Booking_Date__c = Date.today(),
            User__c = UserInfo.getUserId()
        );
        insert b;

        Test.startTest();
        List<Booking__c> results = BookingSearchService.getBookingsByContact(c.Id);
        List<Booking__c> nullResults = BookingSearchService.getBookingsByContact(null);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(b.Id, results[0].Id);
        System.assertEquals(0, nullResults.size());
    }

    @isTest
    static void testGetFlightByOfferId() {
        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_lookup_123',
            Arrival_DateTime__c = DateTime.now().addHours(2),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'JFK',
            Origin_Airport__c = 'LHR',
            Duration_Minutes__c = 120,
            Is_International__c = true,
            Status__c = 'Active'
        );
        insert f;

        Test.startTest();
        Flight__c found = BookingSearchService.getFlightByOfferId('off_lookup_123');
        Flight__c notFound = BookingSearchService.getFlightByOfferId('invalid_offer_id');
        Flight__c blankOffer = BookingSearchService.getFlightByOfferId('');
        Test.stopTest();

        System.assertNotEquals(null, found);
        System.assertEquals(f.Id, found.Id);
        System.assertEquals(null, notFound);
        System.assertEquals(null, blankOffer);
    }

    @isTest
    static void testGetRefundsByBookingId() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_refund_123',
            Arrival_DateTime__c = DateTime.now().addHours(2),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'JFK',
            Origin_Airport__c = 'LHR',
            Duration_Minutes__c = 120,
            Is_International__c = true,
            Status__c = 'Active'
        );
        insert f;

        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 1,
            Base_Fare__c = 150.00,
            Taxes_Fees__c = 0.0,
            Booking_Status__c = 'Confirmed',
            Booking_Date__c = Date.today(),
            User__c = UserInfo.getUserId()
        );
        insert b;

        Refund__c ref = new Refund__c(
            Booking__c = b.Id,
            Refund_Amount__c = 50.00,
            Refund_Status__c = 'Completed',
            Requested_Date__c = Date.today()
        );
        insert ref;

        Test.startTest();
        List<Refund__c> refunds = BookingSearchService.getRefundsByBookingId(b.Id);
        List<Refund__c> nullRefunds = BookingSearchService.getRefundsByBookingId(null);
        Test.stopTest();

        System.assertEquals(1, refunds.size());
        System.assertEquals(ref.Id, refunds[0].Id);
        System.assertEquals(0, nullRefunds.size());
    }
}
