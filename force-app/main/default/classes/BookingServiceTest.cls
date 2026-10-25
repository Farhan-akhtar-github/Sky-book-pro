@isTest
public class BookingServiceTest {

    public class DuffelPricingMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public DuffelPricingMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    private static String getMockPricingJson(String offerId, Integer seatsAvailable, Decimal price) {
        return '{"data": {' +
            '"id": "' + offerId + '",' +
            '"total_amount": "' + price + '",' +
            '"total_currency": "USD",' +
            '"owner": {"name": "Duffel Airways", "iata_code": "ZZ"},' +
            '"slices": [{' +
                '"id": "sli_123",' +
                '"duration": "PT2H30M",' +
                '"origin": {"iata_code": "DEL", "iata_country_code": "IN"},' +
                '"destination": {"iata_code": "BOM", "iata_country_code": "IN"},' +
                '"segments": [{' +
                    '"id": "seg_123",' +
                    '"departing_at": "2026-10-15T10:50:00",' +
                    '"arriving_at": "2026-10-15T13:20:00",' +
                    '"origin": {"iata_code": "DEL", "iata_country_code": "IN"},' +
                    '"destination": {"iata_code": "BOM", "iata_country_code": "IN"},' +
                    '"marketing_carrier": {"name": "Duffel Airways", "iata_code": "ZZ"},' +
                    '"marketing_carrier_flight_number": "123",' +
                    '"duration": "PT2H30M",' +
                    '"passengers": [{"cabin_class": "economy", "cabin_class_marketing_name": "Economy"}]' +
                '}]' +
            '}]' +
        '}}';
    }

    @isTest
    static void testCreateBookingSuccess() {
        // Create a Contact
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        // Build FlightOfferWrapper
        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_booking_123';
        offer.price = 220.00;
        offer.currencyIsoCode = 'USD';

        String mockJson = getMockPricingJson('off_test_booking_123', 9, 220.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        Test.startTest();
        Booking__c booking = BookingService.createBooking(c.Id, offer, 1, 'Economy');
        Test.stopTest();

        System.assertNotEquals(null, booking.Id);
        System.assertEquals(c.Id, booking.Passenger__c);
        System.assertEquals('Economy', booking.Seat_Class__c);
        System.assertEquals('Confirmed', booking.Booking_Status__c);
        System.assertEquals(1, booking.Number_of_Seats__c);

        // Verify Passenger Detail child created
        List<Passenger_Detail__c> details = [
            SELECT Id, Name, Last_Name__c, Passenger_Type__c 
            FROM Passenger_Detail__c 
            WHERE Booking__c = :booking.Id
        ];
        System.assertEquals(1, details.size());
        System.assertEquals('John', details[0].Name);
        System.assertEquals('Doe', details[0].Last_Name__c);
        System.assertEquals('Adult', details[0].Passenger_Type__c);

        // Verify Flight Segment children created
        List<Flight_Segment__c> segments = [
            SELECT Id, Name, Destination__c, Flight_Number__c, Carrier_Code__c, Segment_Order__c 
            FROM Flight_Segment__c 
            WHERE Booking__c = :booking.Id
        ];
        System.assertEquals(1, segments.size());
        System.assertEquals('DEL', segments[0].Name);
        System.assertEquals('BOM', segments[0].Destination__c);
        System.assertEquals('123', segments[0].Flight_Number__c);
        System.assertEquals('ZZ', segments[0].Carrier_Code__c);
        System.assertEquals(1.0, segments[0].Segment_Order__c);
    }

    @isTest
    static void testCreateBookingInvalidContact() {
        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_booking_123';

        Test.startTest();
        try {
            BookingService.createBooking(null, offer, 1, 'Economy');
            System.assert(false, 'Should throw exception for null Contact ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateBookingNullOffer() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        Test.startTest();
        try {
            BookingService.createBooking(c.Id, null, 1, 'Economy');
            System.assert(false, 'Should throw exception for null offer');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateBookingInsufficientSeats() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_booking_no_seats';

        String mockJson = getMockPricingJson('off_test_booking_no_seats', 9, 220.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        Test.startTest();
        try {
            BookingService.createBooking(c.Id, offer, 10, 'Economy');
            System.assert(false, 'Should throw exception for insufficient seats');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();

        // Verify no booking created
        System.assertEquals(0, [SELECT count() FROM Booking__c]);
    }

    @isTest
    static void testCreateBookingDMLFailure() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_dml_fail';

        String mockJson = getMockPricingJson('off_test_dml_fail', 9, 220.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        Test.startTest();
        try {
            // Induce DML Failure using invalid restricted picklist seatClass
            BookingService.createBooking(c.Id, offer, 1, 'InvalidClass');
            System.assert(false, 'Should throw exception for DML failure');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();

        // Verify transaction rolled back and no records remain
        System.assertEquals(0, [SELECT count() FROM Booking__c]);
        System.assertEquals(0, [SELECT count() FROM Passenger_Detail__c]);
        System.assertEquals(0, [SELECT count() FROM Flight_Segment__c]);
    }

    @isTest
    static void testCreateBookingWithSinglePassenger() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_multi_1';
        offer.price = 100.00;
        offer.currencyIsoCode = 'USD';

        String mockJson = getMockPricingJson('off_test_multi_1', 5, 100.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        BookingService.PassengerInput pi = new BookingService.PassengerInput();
        pi.firstName = 'Alice';
        pi.lastName = 'Smith';
        pi.dob = '1995-05-12';
        pi.passengerType = 'Adult';
        pi.passport = 'A1234567';
        pi.mealPreference = new List<String>{'Vegetarian', 'Vegan'};

        List<BookingService.PassengerInput> passengers = new List<BookingService.PassengerInput>{pi};

        Test.startTest();
        Booking__c booking = BookingService.createBookingWithPassengers(c.Id, offer, 1, 'Economy', passengers);
        Test.stopTest();

        System.assertNotEquals(null, booking.Id);
        System.assertEquals(1, booking.Number_of_Seats__c);

        List<Passenger_Detail__c> details = [
            SELECT Id, Name, Last_Name__c, Passenger_Type__c, Date_of_Birth__c, Passport_Number__c, Meal_Preference__c 
            FROM Passenger_Detail__c 
            WHERE Booking__c = :booking.Id
        ];
        System.assertEquals(1, details.size());
        System.assertEquals('Alice', details[0].Name);
        System.assertEquals('Smith', details[0].Last_Name__c);
        System.assertEquals('Adult', details[0].Passenger_Type__c);
        System.assertEquals(Date.newInstance(1995, 5, 12), details[0].Date_of_Birth__c);
        System.assertEquals('A1234567', details[0].Passport_Number__c);
        System.assertEquals('Vegetarian;Vegan', details[0].Meal_Preference__c);
    }

    @isTest
    static void testCreateBookingWithMultiplePassengers() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_multi_2';
        offer.price = 200.00;
        offer.currencyIsoCode = 'USD';

        String mockJson = getMockPricingJson('off_test_multi_2', 5, 200.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        BookingService.PassengerInput pi1 = new BookingService.PassengerInput();
        pi1.firstName = 'Alice';
        pi1.lastName = 'Smith';
        pi1.dob = '1995-05-12';
        pi1.passengerType = 'Adult';
        pi1.passport = 'A1234567';
        pi1.mealPreference = new List<String>{'Vegetarian'};

        BookingService.PassengerInput pi2 = new BookingService.PassengerInput();
        pi2.firstName = 'Bob';
        pi2.lastName = 'Smith';
        pi2.dob = '2015-08-20';
        pi2.passengerType = 'Child';
        pi2.passport = 'B7654321';
        pi2.mealPreference = new List<String>{'Vegan', 'Jain'};

        List<BookingService.PassengerInput> passengers = new List<BookingService.PassengerInput>{pi1, pi2};

        Test.startTest();
        Booking__c booking = BookingService.createBookingWithPassengers(c.Id, offer, 2, 'Business', passengers);
        Test.stopTest();

        System.assertNotEquals(null, booking.Id);
        System.assertEquals(2, booking.Number_of_Seats__c);

        List<Passenger_Detail__c> details = [
            SELECT Id, Name, Last_Name__c, Passenger_Type__c, Date_of_Birth__c, Passport_Number__c, Meal_Preference__c 
            FROM Passenger_Detail__c 
            WHERE Booking__c = :booking.Id
            ORDER BY Name ASC
        ];
        System.assertEquals(2, details.size());
        System.assertEquals('Alice', details[0].Name);
        System.assertEquals('Vegetarian', details[0].Meal_Preference__c);

        System.assertEquals('Bob', details[1].Name);
        System.assertEquals('Vegan;Jain', details[1].Meal_Preference__c);
    }

    @isTest
    static void testCreateBookingWithPassengersValidationErrors() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_multi_val';
        offer.price = 100.00;

        String mockJson = getMockPricingJson('off_test_multi_val', 5, 100.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        // 1. Check Invalid Meal Preference choice
        BookingService.PassengerInput pi1 = new BookingService.PassengerInput();
        pi1.firstName = 'Alice';
        pi1.lastName = 'Smith';
        pi1.dob = '1995-05-12';
        pi1.mealPreference = new List<String>{'Keto'}; // Invalid!

        List<BookingService.PassengerInput> list1 = new List<BookingService.PassengerInput>{pi1};

        Test.startTest();
        try {
            BookingService.createBookingWithPassengers(c.Id, offer, 1, 'Economy', list1);
            System.assert(false, 'Should throw validation error for invalid meal');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 2. Check Future Date of Birth
        pi1.mealPreference = new List<String>{'Vegetarian'};
        pi1.dob = String.valueOf(Date.today().addDays(5)); // Invalid (Future DOB)

        try {
            BookingService.createBookingWithPassengers(c.Id, offer, 1, 'Economy', list1);
            System.assert(false, 'Should throw validation error for future DOB');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 3. Check Null/Empty Passengers
        try {
            BookingService.createBookingWithPassengers(c.Id, offer, 1, 'Economy', null);
            System.assert(false, 'Should throw validation error for null passenger list');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateBookingWithPassengersRollbackOnError() {
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_rollback';
        offer.price = 100.00;

        String mockJson = getMockPricingJson('off_test_rollback', 5, 100.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        // Create passenger with correct format, but force exception inside DML using invalid field mapping
        BookingService.PassengerInput pi = new BookingService.PassengerInput();
        pi.firstName = 'Alice';
        pi.lastName = 'Smith';
        pi.dob = '1995-05-12';
        pi.mealPreference = new List<String>{'Vegetarian'};

        List<BookingService.PassengerInput> passengers = new List<BookingService.PassengerInput>{pi};

        Test.startTest();
        try {
            // Induce rollback via DML error in booking creation: pass invalid seat class (fails picklist validation)
            BookingService.createBookingWithPassengers(c.Id, offer, 1, 'InvalidSeatClass', passengers);
            System.assert(false, 'Should throw exception and rollback');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();

        // Verify that no booking, passenger, or segment records were committed
        System.assertEquals(0, [SELECT count() FROM Booking__c]);
        System.assertEquals(0, [SELECT count() FROM Passenger_Detail__c]);
        System.assertEquals(0, [SELECT count() FROM Flight_Segment__c]);
    }

    @isTest
    static void testNormalBookingAndCancellationLifecycle() {
        // Create base Contact
        Contact c = new Contact(FirstName = 'Lifecycle', LastName = 'Test', Email = 'lifecycle.test@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        // Mock Duffel responses
        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_lifecycle_test';
        offer.price = 900.00;

        String mockJson = getMockPricingJson('off_lifecycle_test', 15, 900.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        // Create passenger inputs
        BookingService.PassengerInput pi1 = new BookingService.PassengerInput();
        pi1.firstName = 'Alice';
        pi1.lastName = 'Smith';
        pi1.dob = '1995-05-12';
        pi1.passengerType = 'Adult';
        pi1.mealPreference = new List<String>{'Vegetarian'};

        // 1. Multi-passenger / 1-seat normal booking -> Confirmed
        Test.startTest();
        Booking__c normalBk1 = BookingService.createBookingWithPassengers(c.Id, offer, 1, 'Economy', new List<BookingService.PassengerInput>{pi1});
        System.assertEquals('Confirmed', normalBk1.Booking_Status__c, '1-seat normal booking status should be Confirmed.');

        // 2. Cancellation of a newly Confirmed booking -> Cancelled
        Booking__c cancelledBk = CancellationService.cancelBooking(normalBk1.Id, 'Change of plans');
        System.assertEquals('Cancelled', cancelledBk.Booking_Status__c, 'Cancelled status should transition correctly.');
        System.assertEquals('Change of plans', cancelledBk.Cancellation_Reason__c, 'Cancellation reason should be saved.');
        
        // Verify Refund__c record created
        List<Refund__c> refunds = [SELECT Id, Refund_Status__c FROM Refund__c WHERE Booking__c = :normalBk1.Id];
        System.assertEquals(1, refunds.size(), 'A Refund record should be generated automatically.');
        System.assertEquals('Initiated', refunds[0].Refund_Status__c, 'Initial refund status should be Initiated.');
        Test.stopTest();
    }

    @isTest
    static void testNineSeatBookingConfirmed() {
        // Create base Contact
        Contact c = new Contact(FirstName = 'NineSeats', LastName = 'Test', Email = 'nineseats.test@example.com', Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        // Mock Duffel responses
        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_nineseats_test';
        offer.price = 1800.00;

        String mockJson = getMockPricingJson('off_nineseats_test', 15, 1800.00);
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        List<BookingService.PassengerInput> ninePassengers = new List<BookingService.PassengerInput>();
        for (Integer i = 0; i < 9; i++) {
            BookingService.PassengerInput pi = new BookingService.PassengerInput();
            pi.firstName = 'Pass' + i;
            pi.lastName = 'Last' + i;
            pi.dob = '1990-01-01';
            pi.passengerType = 'Adult';
            ninePassengers.add(pi);
        }

        Test.startTest();
        Booking__c normalBk9 = BookingService.createBookingWithPassengers(c.Id, offer, 9, 'Economy', ninePassengers);
        Test.stopTest();

        System.assertEquals('Confirmed', normalBk9.Booking_Status__c, '9-seat normal booking status should be Confirmed.');
    }

    @isTest
    static void testGroupBookingDraftWithPermissions() {
        // 4. 10-seat group booking -> Draft (using a valid context that satisfies validation permission)
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User groupManagerUser = new User(
            Alias = 'gpmgr',
            Email = 'gpmgr@testskybook.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'GroupManager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'gpmgr_' + DateTime.now().getTime() + '@testskybook.com'
        );
        insert groupManagerUser;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Group_Booking_Manager' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = groupManagerUser.Id, PermissionSetId = ps.Id);

        System.runAs(groupManagerUser) {
            // Create Contact
            Contact c = new Contact(FirstName = 'Group', LastName = 'Lead', Email = 'group.lead@example.com', Birthdate = Date.newInstance(1990, 1, 1));
            insert c;

            // Mock Duffel responses
            FlightOfferWrapper offer = new FlightOfferWrapper();
            offer.offerId = 'off_group_test';
            offer.price = 5000.00;

            String mockJson = getMockPricingJson('off_group_test', 15, 5000.00);
            Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

            List<BookingService.PassengerInput> tenPassengers = new List<BookingService.PassengerInput>();
            for (Integer i = 0; i < 10; i++) {
                BookingService.PassengerInput pi = new BookingService.PassengerInput();
                pi.firstName = 'Group' + i;
                pi.lastName = 'Member' + i;
                pi.dob = '1990-01-01';
                pi.passengerType = 'Adult';
                tenPassengers.add(pi);
            }

            Test.startTest();
            Booking__c groupBk = BookingService.createBookingWithPassengers(c.Id, offer, 10, 'Economy', tenPassengers);
            Test.stopTest();

            System.assertEquals('Draft', groupBk.Booking_Status__c, '10-seat group booking status should default to Draft.');
        }
    }
}
