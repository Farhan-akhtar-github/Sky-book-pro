@isTest
public class DuffelFlightPricingServiceTest {

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

    @isTest
    static void testConfirmPriceSuccess() {
        String mockJson = '{"data": {' +
            '"id": "off_12345",' +
            '"total_amount": "260.00",' +
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
        '}}';

        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(200, mockJson));

        Test.startTest();
        FlightOfferWrapper w = DuffelFlightPricingService.confirmPrice('off_12345');
        Test.stopTest();

        System.assertNotEquals(null, w);
        System.assertEquals('off_12345', w.offerId);
        System.assertEquals(260.00, w.price);
        System.assertEquals('USD', w.currencyIsoCode);
        System.assertEquals('DEL', w.origin);
        System.assertEquals('BOM', w.destination);
    }

    @isTest
    static void testConfirmPriceBlank() {
        Test.startTest();
        FlightOfferWrapper w = DuffelFlightPricingService.confirmPrice('');
        Test.stopTest();
        System.assertEquals(null, w);
    }

    @isTest
    static void testConfirmPriceFailure() {
        Test.setMock(HttpCalloutMock.class, new DuffelPricingMock(404, 'Not Found'));

        Test.startTest();
        try {
            DuffelFlightPricingService.confirmPrice('off_invalid');
            System.assert(false, 'Should have thrown exception');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to retrieve offer price'));
        }
        Test.stopTest();
    }
}
