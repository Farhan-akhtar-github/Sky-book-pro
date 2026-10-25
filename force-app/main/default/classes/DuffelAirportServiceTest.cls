@isTest
public class DuffelAirportServiceTest {
    
    public class DuffelAirportMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public DuffelAirportMock(Integer statusCode, String responseBody) {
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
    static void testSearchAirportsSuccess() {
        String mockJson = '{"data": [' +
            '{"city_name":"Aachen","icao_code":"EDKA","iata_city_code":"AAH","iata_country_code":"DE","iata_code":"AAH","latitude":50.823345,"longitude":6.186722,"city":null,"time_zone":"Europe/Berlin","name":"Aachen Merzbrück Airfield","id":"arp_aah_de"},' +
            '{"city_name":"Delhi","icao_code":"VIDP","iata_city_code":"DEL","iata_country_code":"IN","iata_code":"DEL","latitude":28.556111,"longitude":77.100278,"city":null,"time_zone":"Asia/Kolkata","name":"Indira Gandhi International Airport","id":"arp_del_in"}' +
            ']}';
        
        Test.setMock(HttpCalloutMock.class, new DuffelAirportMock(200, mockJson));
        
        Test.startTest();
        List<AirportWrapper> results = DuffelAirportService.searchAirports('DEL');
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should find 1 matching airport');
        System.assertEquals('DEL', results[0].iataCode);
        System.assertEquals('Delhi', results[0].city);
        System.assertEquals('Indira Gandhi International Airport', results[0].airportName);
        System.assertEquals('IN', results[0].country);
        System.assertEquals('Asia/Kolkata', results[0].timezone);
    }
    
    @isTest
    static void testSearchAirportsEmpty() {
        Test.startTest();
        List<AirportWrapper> results = DuffelAirportService.searchAirports('');
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Blank keyword should return empty list');
    }
    
    @isTest
    static void testGetAirportSuccess() {
        String mockJson = '{"data": [' +
            '{"city_name":"Delhi","icao_code":"VIDP","iata_city_code":"DEL","iata_country_code":"IN","iata_code":"DEL","latitude":28.556111,"longitude":77.100278,"city":null,"time_zone":"Asia/Kolkata","name":"Indira Gandhi International Airport","id":"arp_del_in"}' +
            ']}';
        
        Test.setMock(HttpCalloutMock.class, new DuffelAirportMock(200, mockJson));
        
        Test.startTest();
        AirportWrapper result = DuffelAirportService.getAirport('DEL');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals('DEL', result.iataCode);
    }
    
    @isTest
    static void testGetAirportNotFound() {
        String mockJson = '{"data": []}';
        
        Test.setMock(HttpCalloutMock.class, new DuffelAirportMock(200, mockJson));
        
        Test.startTest();
        AirportWrapper result = DuffelAirportService.getAirport('DEL');
        Test.stopTest();
        
        System.assertEquals(null, result);
    }
    
    @isTest
    static void testGetAirportFailure() {
        Test.setMock(HttpCalloutMock.class, new DuffelAirportMock(500, 'Error'));
        
        Test.startTest();
        try {
            DuffelAirportService.getAirport('DEL');
            System.assert(false, 'Should have thrown exception');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to fetch airports'));
        }
        Test.stopTest();
    }
}
