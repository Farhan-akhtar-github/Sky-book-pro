@isTest
public class FlightServiceTest {

    @isTest
    static void testCreateFlightSuccess() {
        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_123';
        offer.airline = 'Test Airline';
        offer.arrivalTime = DateTime.now().addHours(2);
        offer.departureTime = DateTime.now();
        offer.destination = 'JFK';
        offer.origin = 'LHR';
        offer.duration = 120;
        offer.isInternational = true;
        offer.price = 300.00;
        offer.currencyIsoCode = 'USD';

        Test.startTest();
        Flight__c f = FlightService.createFlight(offer);
        Test.stopTest();

        System.assertNotEquals(null, f.Id);
        System.assertEquals('off_test_123', f.Amadeus_Offer__c);
        System.assertEquals('Test Airline', f.Airline_Name__c);
        System.assertEquals('JFK', f.Destination_Airport__c);
        System.assertEquals('LHR', f.Origin_Airport__c);
        System.assertEquals(120, f.Duration_Minutes__c);
        System.assertEquals(true, f.Is_International__c);
        System.assertEquals('Active', f.Status__c);
    }

    @isTest
    static void testCreateFlightDuplicate() {
        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_duplicate';
        offer.airline = 'Test Airline';
        offer.arrivalTime = DateTime.now().addHours(2);
        offer.departureTime = DateTime.now();
        offer.destination = 'JFK';
        offer.origin = 'LHR';
        offer.duration = 120;
        offer.isInternational = true;

        Flight__c f1 = FlightService.createFlight(offer);
        
        Test.startTest();
        Flight__c f2 = FlightService.createFlight(offer);
        Test.stopTest();

        System.assertEquals(f1.Id, f2.Id, 'Should return existing flight record on duplicate offer ID');
    }

    @isTest
    static void testUpdateFlight() {
        FlightOfferWrapper offer = new FlightOfferWrapper();
        offer.offerId = 'off_test_update';
        offer.airline = 'Test Airline';
        offer.arrivalTime = DateTime.now().addHours(2);
        offer.departureTime = DateTime.now();
        offer.destination = 'JFK';
        offer.origin = 'LHR';
        offer.duration = 120;
        offer.isInternational = true;

        Flight__c f = FlightService.createFlight(offer);
        f.Status__c = 'Delayed';

        Test.startTest();
        FlightService.updateFlight(f);
        Flight__c updated = FlightService.getFlight(f.Id);
        Test.stopTest();

        System.assertEquals('Delayed', updated.Status__c);
    }

    @isTest
    static void testGetFlightNull() {
        Test.startTest();
        Flight__c f = FlightService.getFlight(null);
        Test.stopTest();
        System.assertEquals(null, f);
    }
}
