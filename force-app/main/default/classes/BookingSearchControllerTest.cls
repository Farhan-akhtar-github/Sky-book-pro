@isTest
private class BookingSearchControllerTest {

    // ── Shared test data builder ──────────────────────────────────────────────
    private static Contact makeContact(String first, String last, String emailPrefix) {
        Contact c = new Contact(
            FirstName = first,
            LastName  = last,
            Email     = emailPrefix + '@skybooktest.com',
            Birthdate = Date.newInstance(1990, 1, 1)
        );
        insert c;
        return c;
    }

    private static Flight__c makeFlight(String offerSuffix) {
        Flight__c f = new Flight__c(
            Airline_Name__c      = 'Test Airline',
            Amadeus_Offer__c     = 'off_bsc_' + offerSuffix,
            Departure_DateTime__c = DateTime.now().addHours(1),
            Arrival_DateTime__c   = DateTime.now().addHours(3),
            Origin_Airport__c    = 'DEL',
            Destination_Airport__c = 'BOM',
            Duration_Minutes__c  = 120,
            Is_International__c  = false,
            Status__c            = 'Active'
        );
        insert f;
        return f;
    }

    private static Booking__c makeBooking(Id contactId, Id flightId, String status, Id userId) {
        Booking__c b = new Booking__c(
            Passenger__c     = contactId,
            Flight__c        = flightId,
            Seat_Class__c    = 'Economy',
            Number_of_Seats__c = 2,
            Base_Fare__c     = 200.00,
            Taxes_Fees__c    = 20.00,
            Booking_Status__c = status,
            Booking_Date__c  = Date.today(),
            User__c          = userId
        );
        insert b;
        return b;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. testLoadAgentBookings – confirmed bookings load on construction
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testLoadAgentBookings() {
        Contact c     = makeContact('Agent', 'Load', 'agentload');
        Flight__c f   = makeFlight('agentload');
        Id userId     = UserInfo.getUserId();
        Booking__c bk = makeBooking(c.Id, f.Id, 'Confirmed', userId);

        // Also create a Draft booking that must NOT appear
        Booking__c draft = makeBooking(c.Id, f.Id, 'Draft', userId);

        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.agentBookings, 'agentBookings should not be null');
        System.assertEquals(1, ctrl.agentBookings.size(), 'Only the Confirmed booking should appear');
        System.assertEquals(bk.Id, ctrl.agentBookings[0].Id, 'Should return the confirmed booking');
        System.assertEquals(null, ctrl.errorMessage, 'No error should be set');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. testSearchContactsAndBookings – SOSL returns records via setFixedSearchResults
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSearchContactsAndBookings() {
        Contact c   = makeContact('Search', 'Passenger', 'searchpax');
        Flight__c f = makeFlight('search');
        Booking__c b = makeBooking(c.Id, f.Id, 'Confirmed', UserInfo.getUserId());

        // Tell the test framework which IDs SOSL should return
        Id[] fixedResults = new Id[]{ c.Id, b.Id };
        Test.setFixedSearchResults(fixedResults);

        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        ctrl.searchTerm = 'Search';
        PageReference ref = ctrl.search();
        Test.stopTest();

        System.assertEquals(null, ref, 'search() should return null (no redirect)');
        System.assertEquals(null, ctrl.errorMessage, 'No error should be set');
        System.assertNotEquals(null, ctrl.successMessage, 'Success message should be set');
        System.assertEquals(1, ctrl.searchContacts.size(), 'One contact should be found');
        System.assertEquals(c.Id, ctrl.searchContacts[0].Id);
        System.assertEquals(1, ctrl.searchBookings.size(), 'One booking should be found');
        System.assertEquals(b.Id, ctrl.searchBookings[0].Id);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. testSearchValidation – blank search term shows validation error
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSearchValidation() {
        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        ctrl.searchTerm = '';          // blank
        PageReference ref = ctrl.search();
        Test.stopTest();

        System.assertEquals(null, ref);
        System.assertEquals('Please enter a search term.', ctrl.errorMessage,
            'Correct validation message should appear');
        System.assertEquals(0, ctrl.searchContacts.size(), 'No contacts on blank search');
        System.assertEquals(0, ctrl.searchBookings.size(), 'No bookings on blank search');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. testContactHistory – loadContactHistory returns bookings for a passenger
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testContactHistory() {
        Contact c     = makeContact('History', 'Passenger', 'historypax');
        Flight__c f   = makeFlight('history');
        Booking__c b  = makeBooking(c.Id, f.Id, 'Confirmed', UserInfo.getUserId());

        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        ctrl.dummyBooking.Passenger__c = c.Id;
        PageReference ref = ctrl.loadContactHistory();
        Test.stopTest();

        System.assertEquals(null, ref, 'loadContactHistory() should return null');
        System.assertEquals(null, ctrl.errorMessage, 'No error expected');
        System.assertNotEquals(null, ctrl.successMessage, 'Success message expected');
        System.assertEquals(1, ctrl.contactHistoryBookings.size(), 'One booking history record expected');
        System.assertEquals(b.Id, ctrl.contactHistoryBookings[0].Id);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. testContactHistoryValidation – no passenger selected shows error
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testContactHistoryValidation() {
        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        // dummyBooking.Passenger__c remains null
        PageReference ref = ctrl.loadContactHistory();
        Test.stopTest();

        System.assertEquals(null, ref);
        System.assertEquals('Please select a passenger.', ctrl.errorMessage,
            'Correct passenger validation message should appear');
        System.assertEquals(0, ctrl.contactHistoryBookings.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. testClearSearch – all collections reset and agent bookings reload
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testClearSearch() {
        Contact c     = makeContact('Clear', 'Test', 'cleartest');
        Flight__c f   = makeFlight('clear');
        Booking__c b  = makeBooking(c.Id, f.Id, 'Confirmed', UserInfo.getUserId());

        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();

        // Simulate having search results
        ctrl.searchTerm             = 'something';
        ctrl.searchContacts         = new List<Contact>{ c };
        ctrl.searchBookings         = new List<Booking__c>{ b };
        ctrl.contactHistoryBookings = new List<Booking__c>{ b };
        ctrl.errorMessage           = 'old error';
        ctrl.successMessage         = 'old success';

        PageReference ref = ctrl.clearSearch();
        Test.stopTest();

        System.assertEquals(null, ref, 'clearSearch() should return null');
        System.assertEquals(null, ctrl.searchTerm,             'searchTerm should be cleared');
        System.assertEquals(0,    ctrl.searchContacts.size(),  'searchContacts should be empty');
        System.assertEquals(0,    ctrl.searchBookings.size(),  'searchBookings should be empty');
        System.assertEquals(0,    ctrl.contactHistoryBookings.size(), 'contactHistoryBookings should be empty');
        System.assertEquals(null, ctrl.errorMessage,           'errorMessage should be cleared');
        System.assertEquals(null, ctrl.successMessage,         'successMessage should be cleared');
        // Agent bookings should be reloaded
        System.assertNotEquals(null, ctrl.agentBookings, 'agentBookings should be reloaded');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. testNoSearchResults – SOSL returns nothing → "No matching records" message
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testNoSearchResults() {
        // Fix SOSL to return an empty set so the service returns empty lists
        Test.setFixedSearchResults(new Id[]{});

        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        ctrl.searchTerm = 'zzznomatch';
        PageReference ref = ctrl.search();
        Test.stopTest();

        System.assertEquals(null, ref);
        System.assertEquals(null, ctrl.errorMessage);
        System.assertEquals('No matching records found.', ctrl.successMessage,
            '"No matching records" message expected when SOSL returns nothing');
        System.assertEquals(0, ctrl.searchContacts.size());
        System.assertEquals(0, ctrl.searchBookings.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. testAllExceptionCatchPaths – uses @TestVisible flags to cover all three
    //     catch blocks in loadAgentBookings(), search(), and loadContactHistory()
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testAllExceptionCatchPaths() {
        Contact c = makeContact('CatchPath', 'Test', 'catchpathtest');

        // ── (a) loadAgentBookings catch ───────────────────────────────────────
        BookingSearchController.forceAgentBookingsException = true;
        Test.startTest();
        BookingSearchController ctrl1 = new BookingSearchController();
        Test.stopTest();
        BookingSearchController.forceAgentBookingsException = false;

        System.assertNotEquals(null, ctrl1.errorMessage,
            'errorMessage should be set when agent bookings load fails');
        System.assert(ctrl1.errorMessage.contains('Could not load agent bookings'),
            'Error message should mention agent bookings failure');
        System.assertEquals(0, ctrl1.agentBookings.size(),
            'agentBookings should be empty on exception');

        // ── (b) search() catch ────────────────────────────────────────────────
        BookingSearchController.forceSearchException = true;
        BookingSearchController ctrl2 = new BookingSearchController();
        ctrl2.searchTerm = 'anything';
        PageReference refSearch = ctrl2.search();
        BookingSearchController.forceSearchException = false;

        System.assertEquals(null, refSearch);
        System.assertNotEquals(null, ctrl2.errorMessage,
            'errorMessage should be set when search fails');
        System.assert(ctrl2.errorMessage.contains('Search failed'),
            'Error message should mention search failure');
        System.assertEquals(0, ctrl2.searchContacts.size());
        System.assertEquals(0, ctrl2.searchBookings.size());

        // ── (c) loadContactHistory() catch ───────────────────────────────────
        BookingSearchController.forceContactHistoryException = true;
        BookingSearchController ctrl3 = new BookingSearchController();
        ctrl3.dummyBooking.Passenger__c = c.Id;
        PageReference refHistory = ctrl3.loadContactHistory();
        BookingSearchController.forceContactHistoryException = false;

        System.assertEquals(null, refHistory);
        System.assertNotEquals(null, ctrl3.errorMessage,
            'errorMessage should be set when contact history load fails');
        System.assert(ctrl3.errorMessage.contains('Could not load history'),
            'Error message should mention contact history failure');
        System.assertEquals(0, ctrl3.contactHistoryBookings.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. testConstructorInitialization – all collections initialized, no NPE
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testConstructorInitialization() {
        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.agentBookings,          'agentBookings not null');
        System.assertNotEquals(null, ctrl.searchContacts,         'searchContacts not null');
        System.assertNotEquals(null, ctrl.searchBookings,         'searchBookings not null');
        System.assertNotEquals(null, ctrl.contactHistoryBookings, 'contactHistoryBookings not null');
        System.assertNotEquals(null, ctrl.dummyBooking,           'dummyBooking not null');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. testContactHistoryEmpty – passenger exists but has no bookings
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testContactHistoryEmpty() {
        Contact c = makeContact('Empty', 'History', 'emptyhist');

        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        ctrl.dummyBooking.Passenger__c = c.Id;
        PageReference ref = ctrl.loadContactHistory();
        Test.stopTest();

        System.assertEquals(null, ref);
        System.assertEquals(null, ctrl.errorMessage, 'No error when passenger has no bookings');
        System.assertEquals('No matching records found.', ctrl.successMessage);
        System.assertEquals(0, ctrl.contactHistoryBookings.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. testViewBooking – viewBooking redirects to BookingDetail with id param
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testViewBooking() {
        Contact c = makeContact('View', 'Test', 'viewtest');
        Flight__c f = makeFlight('view');
        Booking__c b = makeBooking(c.Id, f.Id, 'Confirmed', UserInfo.getUserId());

        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        ctrl.selectedBookingId = b.Id;
        PageReference ref = ctrl.viewBooking();
        Test.stopTest();

        System.assertNotEquals(null, ref, 'Redirect PageReference should not be null');
        System.assert(ref.getUrl().contains('/apex/BookingDetail'), 'Url should point to BookingDetail page');
        System.assertEquals(b.Id, ref.getParameters().get('id'), 'Id parameter should be set to the booking Id');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 12. testViewBookingBlankId – viewBooking with blank id sets errorMessage
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testViewBookingBlankId() {
        Test.startTest();
        BookingSearchController ctrl = new BookingSearchController();
        ctrl.selectedBookingId = '';
        PageReference ref = ctrl.viewBooking();
        Test.stopTest();

        System.assertEquals(null, ref, 'PageReference should be null on validation error');
        System.assertEquals('No booking selected.', ctrl.errorMessage, 'Correct error message should be set');
    }
}
