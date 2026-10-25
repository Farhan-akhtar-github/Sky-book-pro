@isTest
public class DuffelFlightSearchServiceTest {

    public class DuffelSearchMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public DuffelSearchMock(Integer statusCode, String responseBody) {
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

    @isTest
    static void testSearchFlightsSuccess() {
        String mockJson = '{"data": {"offers": [{' +
            '"id": "off_12345",' +
            '"total_amount": "250.50",' +
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
                    '"marketing_carrier": {"name": "Duffel Airways", "iata_code": "ZZ"},' +
                    '"marketing_carrier_flight_number": "123",' +
                    '"duration": "PT2H30M",' +
                    '"passengers": [{"cabin_class": "economy", "cabin_class_marketing_name": "Economy"}]' +
                '}]' +
            '}]' +
        '}]}}';

        Test.setMock(HttpCalloutMock.class, new DuffelSearchMock(201, mockJson));

        Test.startTest();
        List<FlightOfferWrapper> results = DuffelFlightSearchService.searchFlights('DEL', 'BOM', Date.today().addDays(7), 1, 'economy');
        Test.stopTest();

        System.assertEquals(1, results.size());
        FlightOfferWrapper w = results[0];
        System.assertEquals('off_12345', w.offerId);
        System.assertEquals(250.50, w.price);
        System.assertEquals('USD', w.currencyIsoCode);
        System.assertEquals('DEL', w.origin);
        System.assertEquals('BOM', w.destination);
        System.assertEquals(150, w.duration);
        System.assertEquals('Duffel Airways', w.airline);
        System.assertEquals('123', w.flightNumber);
        System.assertNotEquals(null, w.departureTime);
        System.assertNotEquals(null, w.arrivalTime);
        System.assertEquals('economy', w.cabinClass);
        System.assertEquals(false, w.isInternational);
        System.assertEquals(9, w.seatsAvailable);
    }

    @isTest
    static void testSearchFlightsEmptyInputs() {
        Test.startTest();
        List<FlightOfferWrapper> r1 = DuffelFlightSearchService.searchFlights('', 'BOM', Date.today(), 1, 'economy');
        List<FlightOfferWrapper> r2 = DuffelFlightSearchService.searchFlights('DEL', '', Date.today(), 1, 'economy');
        List<FlightOfferWrapper> r3 = DuffelFlightSearchService.searchFlights('DEL', 'BOM', null, 1, 'economy');
        Test.stopTest();

        System.assertEquals(0, r1.size());
        System.assertEquals(0, r2.size());
        System.assertEquals(0, r3.size());
    }

    @isTest
    static void testSearchFlightsFailure() {
        Test.setMock(HttpCalloutMock.class, new DuffelSearchMock(500, 'Internal Server Error'));

        Test.startTest();
        try {
            DuffelFlightSearchService.searchFlights('DEL', 'BOM', Date.today().addDays(7), 1, 'economy');
            System.assert(false, 'Should have thrown exception');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to search flights'));
        }
        Test.stopTest();
    }

    @isTest
    static void testParseIsoDuration() {
        System.assertEquals(150, DuffelFlightSearchService.parseIsoDuration('PT2H30M'));
        System.assertEquals(720, DuffelFlightSearchService.parseIsoDuration('PT12H'));
        System.assertEquals(45, DuffelFlightSearchService.parseIsoDuration('PT45M'));
        System.assertEquals(1500, DuffelFlightSearchService.parseIsoDuration('P1DT1H'));
        System.assertEquals(0, DuffelFlightSearchService.parseIsoDuration(''));
        System.assertEquals(0, DuffelFlightSearchService.parseIsoDuration(null));
    }

    @isTest
    static void testParseIsoDateTime() {
        System.assertNotEquals(null, DuffelFlightSearchService.parseIsoDateTime('2026-10-15T10:50:00'));
        System.assertNotEquals(null, DuffelFlightSearchService.parseIsoDateTime('2026-10-15T10:50:00Z'));
        System.assertNotEquals(null, DuffelFlightSearchService.parseIsoDateTime('2026-10-15T10:50:00+02:00'));
        System.assertEquals(null, DuffelFlightSearchService.parseIsoDateTime(''));
        System.assertEquals(null, DuffelFlightSearchService.parseIsoDateTime(null));
    }

    @isTest
    static void testLogoUrlParsingScenarios() {
        // Scenario 1: Marketing carrier logo exists
        String mockJson1 = '{"data": {"offers": [{' +
            '"id": "off_logo_1",' +
            '"total_amount": "250.50",' +
            '"total_currency": "USD",' +
            '"owner": {"name": "Duffel Owner", "iata_code": "ZZ", "logo_symbol_url": "https://duffel.com/owner_logo.png"},' +
            '"slices": [{' +
                '"id": "sli_1",' +
                '"duration": "PT2H30M",' +
                '"origin": {"iata_code": "DEL", "iata_country_code": "IN"},' +
                '"destination": {"iata_code": "BOM", "iata_country_code": "IN"},' +
                '"segments": [{' +
                    '"id": "seg_1",' +
                    '"departing_at": "2026-10-15T10:50:00",' +
                    '"arriving_at": "2026-10-15T13:20:00",' +
                    '"marketing_carrier": {"name": "Duffel Marketing", "iata_code": "ZZ", "logo_symbol_url": "https://duffel.com/carrier_logo.png"},' +
                    '"marketing_carrier_flight_number": "123",' +
                    '"duration": "PT2H30M",' +
                    '"passengers": [{"cabin_class": "economy", "cabin_class_marketing_name": "Economy"}]' +
                '}]' +
            '}]' +
        '}]}}';

        // Scenario 2: Marketing carrier logo missing but owner logo exists
        String mockJson2 = '{"data": {"offers": [{' +
            '"id": "off_logo_2",' +
            '"total_amount": "250.50",' +
            '"total_currency": "USD",' +
            '"owner": {"name": "Duffel Owner", "iata_code": "ZZ", "logo_symbol_url": "https://duffel.com/owner_logo.png"},' +
            '"slices": [{' +
                '"id": "sli_2",' +
                '"duration": "PT2H30M",' +
                '"origin": {"iata_code": "DEL", "iata_country_code": "IN"},' +
                '"destination": {"iata_code": "BOM", "iata_country_code": "IN"},' +
                '"segments": [{' +
                    '"id": "seg_2",' +
                    '"departing_at": "2026-10-15T10:50:00",' +
                    '"arriving_at": "2026-10-15T13:20:00",' +
                    '"marketing_carrier": {"name": "Duffel Marketing", "iata_code": "ZZ"},' +
                    '"marketing_carrier_flight_number": "123",' +
                    '"duration": "PT2H30M",' +
                    '"passengers": [{"cabin_class": "economy", "cabin_class_marketing_name": "Economy"}]' +
                '}]' +
            '}]' +
        '}]}}';

        // Scenario 3: Both logos missing
        String mockJson3 = '{"data": {"offers": [{' +
            '"id": "off_logo_3",' +
            '"total_amount": "250.50",' +
            '"total_currency": "USD",' +
            '"owner": {"name": "Duffel Owner", "iata_code": "ZZ"},' +
            '"slices": [{' +
                '"id": "sli_3",' +
                '"duration": "PT2H30M",' +
                '"origin": {"iata_code": "DEL", "iata_country_code": "IN"},' +
                '"destination": {"iata_code": "BOM", "iata_country_code": "IN"},' +
                '"segments": [{' +
                    '"id": "seg_3",' +
                    '"departing_at": "2026-10-15T10:50:00",' +
                    '"arriving_at": "2026-10-15T13:20:00",' +
                    '"marketing_carrier": {"name": "Duffel Marketing", "iata_code": "ZZ"},' +
                    '"marketing_carrier_flight_number": "123",' +
                    '"duration": "PT2H30M",' +
                    '"passengers": [{"cabin_class": "economy", "cabin_class_marketing_name": "Economy"}]' +
                '}]' +
            '}]' +
        '}]}}';

        // Scenario 4: Empty slices or segments
        String mockJson4 = '{"data": {"offers": [{' +
            '"id": "off_logo_4",' +
            '"total_amount": "250.50",' +
            '"total_currency": "USD",' +
            '"owner": {"name": "Duffel Owner", "iata_code": "ZZ", "logo_symbol_url": "https://duffel.com/owner_logo.png"}' +
        '}]}}';

        Test.startTest();
        
        Test.setMock(HttpCalloutMock.class, new DuffelSearchMock(201, mockJson1));
        List<FlightOfferWrapper> res1 = DuffelFlightSearchService.searchFlights('DEL', 'BOM', Date.today().addDays(7), 1, 'economy');
        System.assertEquals('https://duffel.com/carrier_logo.png', res1[0].logoUrl);

        Test.setMock(HttpCalloutMock.class, new DuffelSearchMock(201, mockJson2));
        List<FlightOfferWrapper> res2 = DuffelFlightSearchService.searchFlights('DEL', 'BOM', Date.today().addDays(7), 1, 'economy');
        System.assertEquals('https://duffel.com/owner_logo.png', res2[0].logoUrl);

        Test.setMock(HttpCalloutMock.class, new DuffelSearchMock(201, mockJson3));
        List<FlightOfferWrapper> res3 = DuffelFlightSearchService.searchFlights('DEL', 'BOM', Date.today().addDays(7), 1, 'economy');
        System.assertEquals(null, res3[0].logoUrl);

        Test.setMock(HttpCalloutMock.class, new DuffelSearchMock(201, mockJson4));
        List<FlightOfferWrapper> res4 = DuffelFlightSearchService.searchFlights('DEL', 'BOM', Date.today().addDays(7), 1, 'economy');
        System.assertEquals('https://duffel.com/owner_logo.png', res4[0].logoUrl);
        System.assertEquals(null, res4[0].origin);

        Test.stopTest();
    }
}
