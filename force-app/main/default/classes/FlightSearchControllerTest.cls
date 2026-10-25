@IsTest
private class FlightSearchControllerTest {

    // ── Mock callout for a successful Duffel response ──────────────────────────
    private class DuffelSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(buildDuffelJson());
            return res;
        }
    }

    // ── Mock callout for an empty Duffel response ──────────────────────────────
    private class DuffelEmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data":{"offers":[]}}');
            return res;
        }
    }

    // ── Mock callout for an error Duffel response ──────────────────────────────
    private class DuffelErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"errors":[{"message":"Bad Request"}]}');
            return res;
        }
    }

    // ── Build a minimal valid Duffel JSON payload ──────────────────────────────
    private static String buildDuffelJson() {
        return '{'
            + '"data":{"offers":['
            + '{"id":"off_1","total_amount":"4500.00","total_currency":"INR",'
            + '"owner":{"name":"IndiGo","iata_code":"6E"},'
            + '"slices":[{'
            + '"id":"slc_1","duration":"PT2H30M",'
            + '"origin":{"iata_code":"DEL","iata_country_code":"IN"},'
            + '"destination":{"iata_code":"BOM","iata_country_code":"IN"},'
            + '"segments":[{"id":"seg_1","departing_at":"2025-12-01T06:00:00",'
            + '"arriving_at":"2025-12-01T08:30:00",'
            + '"origin":{"iata_code":"DEL","iata_country_code":"IN"},'
            + '"destination":{"iata_code":"BOM","iata_country_code":"IN"},'
            + '"marketing_carrier":{"name":"IndiGo","iata_code":"6E"},'
            + '"marketing_carrier_flight_number":"6E-101","duration":"PT2H30M",'
            + '"passengers":[{"cabin_class":"economy","cabin_class_marketing_name":"Economy"}]'
            + '}]'
            + '}]}'
            + ']}}';
    }

    // Helper: produce yyyy-MM-dd string for Date.today() + N days
    private static String futureDate(Integer daysAhead) {
        Date d = Date.today().addDays(daysAhead);
        return String.valueOf(d.year()) + '-'
            + (d.month() < 10 ? '0' : '') + String.valueOf(d.month()) + '-'
            + (d.day() < 10 ? '0' : '') + String.valueOf(d.day());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Constructor defaults
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testDefaultConstructor() {
        FlightSearchController ctrl = new FlightSearchController();
        System.assertEquals('1', ctrl.passengerCountStr, 'Default passengerCountStr should be 1');
        System.assertEquals('economy', ctrl.cabinClass, 'Default cabin class should be economy');
        System.assertEquals(false, ctrl.hasSearched, 'hasSearched should default to false');
        System.assertEquals(1, ctrl.currentPage, 'Default page should be 1');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getCabinClassOptions
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetCabinClassOptions() {
        FlightSearchController ctrl = new FlightSearchController();
        List<SelectOption> opts = ctrl.getCabinClassOptions();
        System.assertEquals(4, opts.size(), 'Should have 4 cabin class options');
        System.assertEquals('economy', opts[0].getValue());
        System.assertEquals('Economy', opts[0].getLabel());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Validation – missing origin
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchValidationMissingOrigin() {
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = '';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '1';
        Test.setMock(HttpCalloutMock.class, new DuffelSuccessMock());

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage, 'Should have an error for missing origin');
        System.assert(ctrl.errorMessage.contains('Origin'), 'Error should mention Origin');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Validation – missing destination
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchValidationMissingDestination() {
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = '';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '1';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('Destination'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Validation – missing departure date
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchValidationMissingDate() {
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = null;
        ctrl.passengerCountStr = '1';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('Departure'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Validation – zero passengers (String "0")
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchValidationZeroPassengers() {
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '0';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('Passenger'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Validation – blank passengers (simulates cleared field)
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchValidationBlankPassengers() {
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('Passenger'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Validation – non-numeric passengers string
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchValidationNonNumericPassengers() {
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = 'abc';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('Passenger'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Successful search – results returned
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchSuccess() {
        Test.setMock(HttpCalloutMock.class, new DuffelSuccessMock());
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '1';
        ctrl.cabinClass = 'economy';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertEquals(null, ctrl.errorMessage, 'No error expected');
        System.assertNotEquals(null, ctrl.successMessage);
        System.assertEquals(true, ctrl.hasSearched);
        System.assertEquals(1, ctrl.totalResults);
        System.assertEquals(1, ctrl.pagedResults.size());
        System.assertEquals('DEL', ctrl.pagedResults[0].origin);
        System.assertEquals('BOM', ctrl.pagedResults[0].destination);
        System.assertEquals(150, ctrl.pagedResults[0].duration); // 2h30m = 150 min
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Empty results
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchEmptyResults() {
        Test.setMock(HttpCalloutMock.class, new DuffelEmptyMock());
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(5);
        ctrl.passengerCountStr = '1';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertEquals(true, ctrl.hasSearched);
        System.assertEquals(0, ctrl.pagedResults.size());
        System.assertNotEquals(null, ctrl.successMessage);
        System.assert(ctrl.successMessage.contains('No flights'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // API error response
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchApiError() {
        Test.setMock(HttpCalloutMock.class, new DuffelErrorMock());
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '1';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.startsWith('Search failed:'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Invalid date string – parse exception branch
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSearchInvalidDateFormat() {
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = 'not-a-date';
        ctrl.passengerCountStr = '1';

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('Invalid departure date'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Pagination – next / previous / boundary conditions
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testPaginationNextAndPrevious() {
        Test.setMock(HttpCalloutMock.class, new DuffelSuccessMock());
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '1';

        Test.startTest();
        ctrl.search();
        System.assertEquals(false, ctrl.getHasNext(), 'No next page when single result');
        System.assertEquals(false, ctrl.getHasPrevious(), 'No previous page on first page');
        ctrl.nextPage();
        System.assertEquals(1, ctrl.currentPage);
        ctrl.previousPage();
        System.assertEquals(1, ctrl.currentPage);
        Test.stopTest();
    }

    @IsTest
    static void testPaginationPageStartEnd() {
        Test.setMock(HttpCalloutMock.class, new DuffelSuccessMock());
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '1';

        Test.startTest();
        ctrl.search();
        System.assertEquals(1, ctrl.getPageStart());
        System.assertEquals(1, ctrl.getPageEnd());
        Test.stopTest();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getPageStart when no results
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testPageStartWhenNoResults() {
        FlightSearchController ctrl = new FlightSearchController();
        System.assertEquals(0, ctrl.getPageStart());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // bookFlight – with valid offerId in page parameters
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testBookFlightWithOfferId() {
        Test.setMock(HttpCalloutMock.class, new DuffelSuccessMock());
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = 'DEL';
        ctrl.destination = 'BOM';
        ctrl.departureDateStr = futureDate(3);
        ctrl.passengerCountStr = '2';
        ctrl.cabinClass = 'economy';

        Test.startTest();
        ctrl.search();
        ApexPages.currentPage().getParameters().put('offerId', 'off_1');
        PageReference ref = ctrl.bookFlight();
        Test.stopTest();

        System.assertNotEquals(null, ref, 'Should navigate to BookingCreate page');
        System.assert(ref.getUrl().contains('/apex/BookingCreate'));

        // ── Always-available params ───────────────────────────────────────────
        System.assertEquals('off_1',   ref.getParameters().get('offerId'),   'offerId must be forwarded');
        System.assertEquals('2',       ref.getParameters().get('seats'),     'seats must be forwarded');
        System.assertEquals('economy', ref.getParameters().get('seatClass'), 'seatClass must be forwarded');

        // ── Offer-specific params (populated from the matching FlightOfferWrapper) ─
        System.assertEquals('IndiGo', ref.getParameters().get('airline'),     'airline must be forwarded from offer');
        System.assertEquals('DEL',    ref.getParameters().get('origin'),      'origin must be forwarded from offer');
        System.assertEquals('BOM',    ref.getParameters().get('destination'), 'destination must be forwarded from offer');
        System.assertEquals('INR',    ref.getParameters().get('currency'),    'currency must be forwarded from offer');
        // Price is forwarded as Decimal.toString() – compare numerically to be format-agnostic
        System.assertNotEquals(null, ref.getParameters().get('price'), 'price must be present');
        System.assertEquals(4500.00,
            Decimal.valueOf(ref.getParameters().get('price')),
            'price must equal 4500.00 from mock response');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // bookFlight – offerId present but not in allResults (no prior search)
    // ── Verifies graceful fallback: redirect still built, offer-specific
    //    params are absent (selectedOffer == null branch)
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testBookFlightOfferNotInResults() {
        FlightSearchController ctrl = new FlightSearchController();
        // Do NOT call search() – allResults stays empty
        ApexPages.currentPage().getParameters().put('offerId', 'off_unknown');

        Test.startTest();
        PageReference ref = ctrl.bookFlight();
        Test.stopTest();

        // Should still redirect (offerId is present)
        System.assertNotEquals(null, ref, 'Should navigate even when offer not in results');
        System.assert(ref.getUrl().contains('/apex/BookingCreate'));
        System.assertEquals('off_unknown', ref.getParameters().get('offerId'));

        // Offer-specific params should be absent (null) – BookingController defaults kick in
        System.assertEquals(null, ref.getParameters().get('airline'),     'airline should be absent');
        System.assertEquals(null, ref.getParameters().get('origin'),      'origin should be absent');
        System.assertEquals(null, ref.getParameters().get('destination'), 'destination should be absent');
        System.assertEquals(null, ref.getParameters().get('price'),       'price should be absent');
        System.assertEquals(null, ref.getParameters().get('currency'),    'currency should be absent');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // bookFlight – no offerId in page parameters (error case)
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testBookFlightNoOfferId() {
        FlightSearchController ctrl = new FlightSearchController();
        Test.startTest();
        PageReference ref = ctrl.bookFlight();
        Test.stopTest();

        System.assertEquals(null, ref, 'Should not navigate when no offerId');
        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('No flight offer selected'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Verify cabin class select options completeness
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testAllCabinClasses() {
        FlightSearchController ctrl = new FlightSearchController();
        List<SelectOption> opts = ctrl.getCabinClassOptions();
        Set<String> vals = new Set<String>();
        for (SelectOption o : opts) { vals.add(o.getValue()); }
        System.assert(vals.contains('economy'));
        System.assert(vals.contains('premium_economy'));
        System.assert(vals.contains('business'));
        System.assert(vals.contains('first'));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Validate multiple errors at once
    // ──────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testMultipleValidationErrors() {
        FlightSearchController ctrl = new FlightSearchController();
        ctrl.origin = '';
        ctrl.destination = '';
        ctrl.departureDateStr = null;
        ctrl.passengerCountStr = null;

        Test.startTest();
        ctrl.search();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage);
        System.assert(ctrl.errorMessage.contains('Origin'));
        System.assert(ctrl.errorMessage.contains('Destination'));
        System.assert(ctrl.errorMessage.contains('Departure'));
        System.assert(ctrl.errorMessage.contains('Passenger'));
    }
}
