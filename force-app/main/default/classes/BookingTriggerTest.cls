@isTest
public class BookingTriggerTest {

    @isTest
    static void testBeforeInsertDefaults() {
        // Create a Contact
        Contact c = new Contact(
            FirstName = 'Test', 
            LastName = 'Passenger', 
            Email = 'test.passenger@example.com', 
            Birthdate = Date.newInstance(1990, 1, 1)
        );
        insert c;

        // Create a Flight
        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_test_defaults_123',
            Arrival_DateTime__c = DateTime.now().addHours(3),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'BOM',
            Duration_Minutes__c = 120,
            Is_International__c = false,
            Origin_Airport__c = 'DEL',
            Status__c = 'Active'
        );
        insert f;

        // Create a Booking without setting Booking_Date__c, User__c, or Booking_Status__c
        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 2,
            Base_Fare__c = 100.00,
            Taxes_Fees__c = 10.00
        );

        Test.startTest();
        insert b;
        Test.stopTest();

        // Query and verify defaults
        Booking__c insertedBooking = [
            SELECT Id, Booking_Date__c, User__c, Booking_Status__c 
            FROM Booking__c 
            WHERE Id = :b.Id
        ];
        
        System.assertEquals(Date.today(), insertedBooking.Booking_Date__c, 'Booking Date should default to Today.');
        System.assertEquals(UserInfo.getUserId(), insertedBooking.User__c, 'User should default to current user.');
        System.assertEquals('Draft', insertedBooking.Booking_Status__c, 'Booking Status should default to Draft.');
    }

    @isTest
    static void testTransitionCancelledToConfirmedBlocked() {
        Contact c = new Contact(
            FirstName = 'Test', 
            LastName = 'Passenger', 
            Email = 'test.passenger@example.com'
        );
        insert c;

        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_test_cancel_123',
            Arrival_DateTime__c = DateTime.now().addHours(3),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'BOM',
            Duration_Minutes__c = 120,
            Origin_Airport__c = 'DEL',
            Status__c = 'Active'
        );
        insert f;

        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 2,
            Base_Fare__c = 100.00,
            Taxes_Fees__c = 10.00,
            Booking_Status__c = 'Cancelled'
        );
        insert b;

        // Verify status is Cancelled
        Booking__c checkBooking = [SELECT Booking_Status__c FROM Booking__c WHERE Id = :b.Id];
        System.assertEquals('Cancelled', checkBooking.Booking_Status__c);

        // Attempt to update to Confirmed
        b.Booking_Status__c = 'Confirmed';

        Test.startTest();
        try {
            update b;
            System.assert(false, 'Should have thrown a DML exception when re-confirming a cancelled booking.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Cancelled bookings cannot be re-confirmed.'), 
                'Expected error message not found. Message was: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testSeatReductionValidation() {
        Contact c = new Contact(
            FirstName = 'Test', 
            LastName = 'Passenger', 
            Email = 'test.passenger@example.com'
        );
        insert c;

        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_test_seats_123',
            Arrival_DateTime__c = DateTime.now().addHours(3),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'BOM',
            Duration_Minutes__c = 120,
            Origin_Airport__c = 'DEL',
            Status__c = 'Active'
        );
        insert f;

        Booking__c b = new Booking__c(
            Passenger__c = c.Id,
            Flight__c = f.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 3,
            Base_Fare__c = 100.00,
            Taxes_Fees__c = 10.00,
            Booking_Status__c = 'Draft'
        );
        insert b;

        // Insert two passenger details under this booking
        Passenger_Detail__c pd1 = new Passenger_Detail__c(
            Booking__c = b.Id,
            Name = 'Passenger 1',
            Last_Name__c = 'One',
            Passenger_Type__c = 'Adult',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1)
        );
        Passenger_Detail__c pd2 = new Passenger_Detail__c(
            Booking__c = b.Id,
            Name = 'Passenger 2',
            Last_Name__c = 'Two',
            Passenger_Type__c = 'Adult',
            Date_of_Birth__c = Date.newInstance(1995, 5, 5)
        );
        insert new List<Passenger_Detail__c>{pd1, pd2};

        Test.startTest();

        // 1. Reducing seats below 2 (passenger count) should throw an error
        b.Number_of_Seats__c = 1;
        try {
            update b;
            System.assert(false, 'Should have thrown a DML exception when seats < passenger count.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Seats cannot be less than passengers.'), 
                'Expected seat count error, got: ' + e.getMessage());
        }

        // 2. Reducing to 2 (equal to passenger count) should succeed
        b.Number_of_Seats__c = 2;
        update b;

        // Verify successful update
        Booking__c updatedBooking = [SELECT Number_of_Seats__c FROM Booking__c WHERE Id = :b.Id];
        System.assertEquals(2, updatedBooking.Number_of_Seats__c);

        // 3. Increasing to 4 (greater than passenger count) should succeed
        b.Number_of_Seats__c = 4;
        update b;

        updatedBooking = [SELECT Number_of_Seats__c FROM Booking__c WHERE Id = :b.Id];
        System.assertEquals(4, updatedBooking.Number_of_Seats__c);

        Test.stopTest();
    }

    @isTest
    static void testBulkInsertAndUpdate() {
        Contact c = new Contact(
            FirstName = 'Test', 
            LastName = 'Passenger', 
            Email = 'test.passenger@example.com'
        );
        insert c;

        Flight__c f = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_test_bulk_123',
            Arrival_DateTime__c = DateTime.now().addHours(3),
            Departure_DateTime__c = DateTime.now().addHours(1),
            Destination_Airport__c = 'BOM',
            Duration_Minutes__c = 120,
            Origin_Airport__c = 'DEL',
            Status__c = 'Active'
        );
        insert f;

        List<Booking__c> bulkBookings = new List<Booking__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkBookings.add(new Booking__c(
                Passenger__c = c.Id,
                Flight__c = f.Id,
                Seat_Class__c = 'Economy',
                Number_of_Seats__c = 2,
                Base_Fare__c = 100.00,
                Taxes_Fees__c = 10.00
            ));
        }

        Test.startTest();
        insert bulkBookings;

        // Verify bulk insert succeeded and defaults are applied
        List<Booking__c> insertedBookings = [
            SELECT Id, Booking_Date__c, User__c, Booking_Status__c 
            FROM Booking__c 
            WHERE Flight__c = :f.Id
        ];
        System.assertEquals(200, insertedBookings.size());
        for (Booking__c b : insertedBookings) {
            System.assertEquals(Date.today(), b.Booking_Date__c);
            System.assertEquals(UserInfo.getUserId(), b.User__c);
            System.assertEquals('Draft', b.Booking_Status__c);
        }

        // Verify bulk update works (change seats to 3)
        for (Booking__c b : bulkBookings) {
            b.Number_of_Seats__c = 3;
        }
        update bulkBookings;

        List<Booking__c> updatedBookings = [
            SELECT Number_of_Seats__c 
            FROM Booking__c 
            WHERE Flight__c = :f.Id
        ];
        System.assertEquals(200, updatedBookings.size());
        for (Booking__c b : updatedBookings) {
            System.assertEquals(3, b.Number_of_Seats__c);
        }

        Test.stopTest();
    }
}
