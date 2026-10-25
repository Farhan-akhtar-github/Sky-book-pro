@isTest
private class BookingDetailControllerTest {

    private static Account makeAccount() {
        return TestDataFactory.createAccount('Test Account');
    }

    private static Contact makeContact(Id accId) {
        return TestDataFactory.createContact(accId, 'John', 'Doe');
    }

    private static Flight__c makeFlight() {
        return TestDataFactory.createFlight('DEL', 'BOM', DateTime.now().addDays(2));
    }

    private static Booking__c makeBooking(Id conId, Id flId) {
        Booking__c bk = TestDataFactory.createBooking(conId, flId, 2);
        bk.Booking_Status__c = 'Confirmed';
        update bk;
        return bk;
    }

    @isTest
    static void testLoadBookingSuccess() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight();
        Booking__c bk = makeBooking(con.Id, fl.Id);

        Test.startTest();
        PageReference pageRef = Page.BookingDetail;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', bk.Id);

        BookingDetailController ctrl = new BookingDetailController();
        Test.stopTest();

        System.assertEquals(true, ctrl.bookingFound, 'Booking should be successfully found.');
        System.assertNotEquals(null, ctrl.booking, 'Booking record should be loaded.');
        System.assertEquals(bk.Id, ctrl.booking.Id, 'Loaded booking ID should match.');
        System.assertEquals(null, ctrl.errorMessage, 'Error message should be null on success.');
    }

    @isTest
    static void testLoadPassengerDetails() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight();
        Booking__c bk = makeBooking(con.Id, fl.Id);

        Passenger_Detail__c pd = new Passenger_Detail__c(
            Booking__c = bk.Id,
            Name = 'Jane',
            Last_Name__c = 'Doe',
            Date_of_Birth__c = Date.newInstance(1995, 5, 12),
            Passport_Number__c = 'P1234567',
            Passenger_Type__c = 'Adult',
            Seat_Number__c = '15C',
            Meal_Preference__c = 'Vegetarian'
        );
        insert pd;

        Test.startTest();
        PageReference pageRef = Page.BookingDetail;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', bk.Id);

        BookingDetailController ctrl = new BookingDetailController();
        Test.stopTest();

        System.assertEquals(true, ctrl.bookingFound);
        System.assertEquals(1, ctrl.passengerDetails.size(), 'There should be one passenger detail.');
        System.assertEquals('Jane', ctrl.passengerDetails[0].Name);
    }

    @isTest
    static void testLoadFlightSegments() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight();
        Booking__c bk = makeBooking(con.Id, fl.Id);

        Flight_Segment__c fs = new Flight_Segment__c(
            Booking__c = bk.Id,
            Name = 'DEL',
            Destination__c = 'BOM',
            Carrier_Code__c = 'AI',
            Flight_Number__c = '101',
            Departure_DateTime__c = DateTime.now().addDays(2),
            Arrival_DateTime__c = DateTime.now().addDays(2).addHours(2),
            Segment_Order__c = 1
        );
        insert fs;

        Test.startTest();
        PageReference pageRef = Page.BookingDetail;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', bk.Id);

        BookingDetailController ctrl = new BookingDetailController();
        Test.stopTest();

        System.assertEquals(true, ctrl.bookingFound);
        System.assertEquals(1, ctrl.flightSegments.size(), 'There should be one flight segment.');
        System.assertEquals('DEL', ctrl.flightSegments[0].Name);
    }

    @isTest
    static void testLoadRefunds() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight();
        Booking__c bk = makeBooking(con.Id, fl.Id);

        Refund__c rf = new Refund__c(
            Booking__c = bk.Id,
            Refund_Amount__c = 50.00,
            Refund_Status__c = 'Completed',
            Requested_Date__c = Date.today(),
            Completed_Date__c = Date.today()
        );
        insert rf;

        Test.startTest();
        PageReference pageRef = Page.BookingDetail;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', bk.Id);

        BookingDetailController ctrl = new BookingDetailController();
        Test.stopTest();

        System.assertEquals(true, ctrl.bookingFound);
        System.assertEquals(1, ctrl.refunds.size(), 'There should be one refund log.');
        System.assertEquals(50.00, ctrl.refunds[0].Refund_Amount__c);
    }

    @isTest
    static void testMissingBookingId() {
        Test.startTest();
        PageReference pageRef = Page.BookingDetail;
        Test.setCurrentPage(pageRef);
        // Do not put any 'id' parameter in the page

        BookingDetailController ctrl = new BookingDetailController();
        Test.stopTest();

        System.assertEquals(false, ctrl.bookingFound, 'Booking found should be false.');
        System.assertEquals('Booking not found. Please return to Booking Search.', ctrl.errorMessage);
    }

    @isTest
    static void testInvalidBookingId() {
        Test.startTest();
        PageReference pageRef = Page.BookingDetail;
        Test.setCurrentPage(pageRef);
        // Set an invalid ID that cannot match any booking
        ApexPages.currentPage().getParameters().put('id', 'a00hg000001cp4AAAQ');

        BookingDetailController ctrl = new BookingDetailController();
        Test.stopTest();

        System.assertEquals(false, ctrl.bookingFound);
        System.assertEquals('Booking not found. Please return to Booking Search.', ctrl.errorMessage);
    }

    @isTest
    static void testForceException() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight();
        Booking__c bk = makeBooking(con.Id, fl.Id);

        Test.startTest();
        PageReference pageRef = Page.BookingDetail;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', bk.Id);

        BookingDetailController.forceLoadException = true;
        BookingDetailController ctrl = new BookingDetailController();
        BookingDetailController.forceLoadException = false;
        Test.stopTest();

        System.assertEquals(false, ctrl.bookingFound);
        System.assert(ctrl.errorMessage.contains('Unable to load booking details'), 'Error message should contain expected text.');
    }

    @isTest
    static void testStatusBadgeClass() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight();
        
        BookingDetailController ctrl = new BookingDetailController();
        
        // Null booking
        ctrl.booking = null;
        System.assertEquals('skp-badge-grey', ctrl.getStatusBadgeClass());

        // Confirmed
        Booking__c bkConfirmed = TestDataFactory.createBooking(con.Id, fl.Id, 1);
        bkConfirmed.Booking_Status__c = 'Confirmed';
        ctrl.booking = bkConfirmed;
        System.assertEquals('skp-badge-green', ctrl.getStatusBadgeClass());

        // Draft
        Booking__c bkDraft = TestDataFactory.createBooking(con.Id, fl.Id, 1);
        bkDraft.Booking_Status__c = 'Draft';
        ctrl.booking = bkDraft;
        System.assertEquals('skp-badge-yellow', ctrl.getStatusBadgeClass());

        // Cancelled
        Booking__c bkCancelled = TestDataFactory.createBooking(con.Id, fl.Id, 1);
        bkCancelled.Booking_Status__c = 'Cancelled';
        ctrl.booking = bkCancelled;
        System.assertEquals('skp-badge-red', ctrl.getStatusBadgeClass());

        // Other status (fallback)
        Booking__c bkOther = TestDataFactory.createBooking(con.Id, fl.Id, 1);
        bkOther.Booking_Status__c = 'Pending';
        ctrl.booking = bkOther;
        System.assertEquals('skp-badge-grey', ctrl.getStatusBadgeClass());
    }

    @isTest
    static void testNavigation() {
        BookingDetailController ctrl = new BookingDetailController();
        
        Test.startTest();
        PageReference searchPage = ctrl.goToBookingSearch();
        PageReference flightPage = ctrl.goToFlightSearch();
        Test.stopTest();

        System.assertNotEquals(null, searchPage);
        System.assert(searchPage.getUrl().contains('/apex/BookingSearch'));
        System.assertEquals(true, searchPage.getRedirect());

        System.assertNotEquals(null, flightPage);
        System.assert(flightPage.getUrl().contains('/apex/FlightSearch'));
        System.assertEquals(true, flightPage.getRedirect());
    }

    @isTest
    static void testGetBookingDetail() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight();
        Booking__c bk = makeBooking(con.Id, fl.Id);

        Test.startTest();
        BookingDetailController.BookingDetailWrapper detail = BookingDetailController.getBookingDetail(bk.Id);
        BookingDetailController.BookingDetailWrapper detailNull = BookingDetailController.getBookingDetail(null);
        Test.stopTest();

        System.assertNotEquals(null, detail);
        System.assertEquals(bk.Id, detail.booking.Id);
        System.assertEquals(null, detailNull);
    }
}

