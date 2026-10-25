@IsTest
private class BookingControllerTest {

    // ── Pricing callout mock (success) ────────────────────────────────────────
    private class PricingSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(buildPricingJson('off_test_bc_001', 9, 250.00));
            return res;
        }
    }

    // ── Pricing callout mock (API error) ──────────────────────────────────────
    private class PricingErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"errors":[{"message":"Internal Server Error"}]}');
            return res;
        }
    }

    // ── Build minimal pricing JSON ─────────────────────────────────────────────
    private static String buildPricingJson(String offerId, Integer seats, Decimal price) {
        return '{"data":{'
            + '"id":"' + offerId + '",'
            + '"total_amount":"' + price + '",'
            + '"total_currency":"USD",'
            + '"owner":{"name":"Duffel Airways","iata_code":"ZZ"},'
            + '"slices":[{'
            + '"id":"sli_1","duration":"PT2H30M",'
            + '"origin":{"iata_code":"DEL","iata_country_code":"IN"},'
            + '"destination":{"iata_code":"BOM","iata_country_code":"IN"},'
            + '"segments":[{'
            + '"id":"seg_1","departing_at":"2026-12-01T06:00:00",'
            + '"arriving_at":"2026-12-01T08:30:00",'
            + '"origin":{"iata_code":"DEL","iata_country_code":"IN"},'
            + '"destination":{"iata_code":"BOM","iata_country_code":"IN"},'
            + '"marketing_carrier":{"name":"Duffel Airways","iata_code":"ZZ"},'
            + '"marketing_carrier_flight_number":"ZZ101",'
            + '"duration":"PT2H30M",'
            + '"passengers":[{"cabin_class":"economy","cabin_class_marketing_name":"Economy"}]'
            + '}]'
            + '}]'
            + '}}';
    }

    // ── Helper: inject URL parameters into the test page context ─────────────
    private static void setPageParams(String offerId, String airline, String origin,
                                      String destination, String price, String currencyParam,
                                      String seatClass, String seats) {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        if (offerId       != null) params.put('offerId',     offerId);
        if (airline       != null) params.put('airline',     airline);
        if (origin        != null) params.put('origin',      origin);
        if (destination   != null) params.put('destination', destination);
        if (price         != null) params.put('price',       price);
        if (currencyParam != null) params.put('currency',    currencyParam);
        if (seatClass     != null) params.put('seatClass',   seatClass);
        if (seats         != null) params.put('seats',       seats);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. URL parameter loading
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testUrlParameterLoading() {
        setPageParams('off_test_bc_001', 'Duffel Airways', 'DEL', 'BOM',
                      '250.00', 'USD', 'economy', '2');

        Test.startTest();
        BookingController ctrl = new BookingController();
        Test.stopTest();

        System.assertEquals('off_test_bc_001', ctrl.offerId,     'offerId should be loaded');
        System.assertEquals('Duffel Airways',   ctrl.airline,     'airline should be loaded');
        System.assertEquals('DEL',              ctrl.origin,      'origin should be loaded');
        System.assertEquals('BOM',              ctrl.destination, 'destination should be loaded');
        System.assertEquals(250.00,             ctrl.price,       'price should be parsed to Decimal');
        System.assertEquals('USD',              ctrl.currencyCode,'currency should be loaded');
        System.assertEquals('economy',          ctrl.seatClass,   'seatClass should be loaded');
        System.assertEquals(2,                  ctrl.seats,       'seats should be parsed to Integer');
        System.assertNotEquals(null,            ctrl.dummyBooking,'dummyBooking should be initialized');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Default values when no URL params provided
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testDefaultsWhenNoParams() {
        Test.startTest();
        BookingController ctrl = new BookingController();
        Test.stopTest();

        System.assertEquals(0.0, ctrl.price,  'price should default to 0.0');
        System.assertEquals(1,   ctrl.seats,  'seats should default to 1');
        System.assertEquals('economy', ctrl.seatClass, 'seatClass should default to economy');
        System.assertEquals('USD',     ctrl.currencyCode, 'currency should default to USD');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. getCabinClassLabel() – all four cabin values
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testCabinClassLabel() {
        BookingController ctrl = new BookingController();

        ctrl.seatClass = 'economy';
        System.assertEquals('Economy',       ctrl.getCabinClassLabel());

        ctrl.seatClass = 'premium_economy';
        System.assertEquals('Premium Economy', ctrl.getCabinClassLabel());

        ctrl.seatClass = 'business';
        System.assertEquals('Business',      ctrl.getCabinClassLabel());

        ctrl.seatClass = 'first';
        System.assertEquals('First Class',   ctrl.getCabinClassLabel());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Validation – missing passenger
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testConfirmBookingMissingPassenger() {
        setPageParams('off_test_bc_001', 'Duffel Airways', 'DEL', 'BOM',
                      '250.00', 'USD', 'economy', '1');

        Test.startTest();
        BookingController ctrl = new BookingController();
        // dummyBooking.Passenger__c remains null
        PageReference ref = ctrl.confirmBooking();
        Test.stopTest();

        System.assertEquals(null, ref, 'Should not navigate when passenger missing');
        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('passenger'), 'Error should mention passenger');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Validation – missing offerId
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testConfirmBookingMissingOfferId() {
        // Do NOT set offerId param
        Contact c = new Contact(FirstName = 'Test', LastName = 'Passenger',
                                Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        Test.startTest();
        BookingController ctrl = new BookingController();
        ctrl.dummyBooking.Passenger__c = c.Id;
        PageReference ref = ctrl.confirmBooking();
        Test.stopTest();

        System.assertEquals(null, ref);
        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('flight offer'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Successful booking creation → redirects to BookingSearch
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testConfirmBookingSuccess() {
        Contact c = new Contact(FirstName = 'Jane', LastName = 'Traveller',
                                Email = 'jane.traveller@example.com',
                                Birthdate = Date.newInstance(1985, 6, 15));
        insert c;

        setPageParams('off_test_bc_001', 'Duffel Airways', 'DEL', 'BOM',
                      '250.00', 'USD', 'economy', '1');
        Test.setMock(HttpCalloutMock.class, new PricingSuccessMock());

        Test.startTest();
        BookingController ctrl = new BookingController();
        ctrl.dummyBooking.Passenger__c = c.Id;
        PageReference ref = ctrl.confirmBooking();
        Test.stopTest();

        System.assertNotEquals(null, ref, 'Should navigate after successful booking');
        System.assert(ref.getUrl().contains('/apex/BookingSearch'),
                      'Should redirect to BookingSearch');

        // Verify Booking__c record was created in DB
        List<Booking__c> bookings = [SELECT Id, Passenger__c, Booking_Status__c
                                     FROM Booking__c
                                     WHERE Passenger__c = :c.Id];
        System.assertEquals(1, bookings.size(), 'One booking should be created');
        System.assertEquals('Confirmed', bookings[0].Booking_Status__c);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Pricing API error → errorMessage set, no redirect
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testConfirmBookingPricingApiError() {
        Contact c = new Contact(FirstName = 'Error', LastName = 'Test',
                                Birthdate = Date.newInstance(1990, 1, 1));
        insert c;

        setPageParams('off_test_bc_001', 'Duffel Airways', 'DEL', 'BOM',
                      '250.00', 'USD', 'economy', '1');
        Test.setMock(HttpCalloutMock.class, new PricingErrorMock());

        Test.startTest();
        BookingController ctrl = new BookingController();
        ctrl.dummyBooking.Passenger__c = c.Id;
        PageReference ref = ctrl.confirmBooking();
        Test.stopTest();

        System.assertEquals(null, ref, 'Should not navigate on pricing error');
        System.assertNotEquals(null, ctrl.errorMessage, 'Should have error message');
        // No booking should be persisted
        System.assertEquals(0, [SELECT count() FROM Booking__c]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. cancel() → navigates to FlightSearch
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testCancel() {
        Test.startTest();
        BookingController ctrl = new BookingController();
        PageReference ref = ctrl.cancel();
        Test.stopTest();

        System.assertNotEquals(null, ref);
        System.assert(ref.getUrl().contains('/apex/FlightSearch'), 'Cancel should go to FlightSearch');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Invalid price/seats strings – safe defaults, no exception
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testInvalidNumericParams() {
        setPageParams('off_test_bc_999', null, null, null,
                      'not-a-price', null, null, 'not-a-number');

        Test.startTest();
        BookingController ctrl = new BookingController();
        Test.stopTest();

        System.assertEquals(0.0, ctrl.price, 'price should default to 0.0 on bad input');
        System.assertEquals(1,   ctrl.seats, 'seats should default to 1 on bad input');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Negative seats value – clamped to 1
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testNegativeSeats() {
        setPageParams('off_test_bc_999', null, null, null, null, null, null, '-5');

        Test.startTest();
        BookingController ctrl = new BookingController();
        Test.stopTest();

        System.assertEquals(1, ctrl.seats, 'Negative seats should be clamped to 1');
    }
}
