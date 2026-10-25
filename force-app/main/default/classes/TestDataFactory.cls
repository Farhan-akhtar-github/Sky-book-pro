@isTest
public class TestDataFactory {
    public static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    public static Contact createContact(Id accountId, String firstName, String lastName) {
        Contact con = new Contact(
            AccountId = accountId,
            FirstName = firstName,
            LastName = lastName,
            Email = firstName.toLowerCase() + '.' + lastName.toLowerCase() + '@example.com',
            Birthdate = Date.newInstance(1990, 1, 1)
        );
        insert con;
        return con;
    }

    public static Flight__c createFlight(String origin, String destination, Datetime departure) {
        Flight__c fl = new Flight__c(
            Airline_Name__c = 'Test Airline',
            Amadeus_Offer__c = 'off_' + origin + '_' + destination + '_' + departure.getTime(),
            Departure_DateTime__c = departure,
            Arrival_DateTime__c = departure.addHours(2),
            Origin_Airport__c = origin,
            Destination_Airport__c = destination,
            Duration_Minutes__c = 120,
            Status__c = 'Active'
        );
        insert fl;
        return fl;
    }

    public static Booking__c createBooking(Id contactId, Id flightId, Integer seats) {
        Booking__c bk = new Booking__c(
            Passenger__c = contactId,
            Flight__c = flightId,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = seats,
            Base_Fare__c = 100.00,
            Taxes_Fees__c = 10.00,
            Booking_Status__c = 'Draft'
        );
        insert bk;
        return bk;
    }
}
