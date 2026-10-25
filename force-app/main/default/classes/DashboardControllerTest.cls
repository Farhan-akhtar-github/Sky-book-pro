@isTest
private class DashboardControllerTest {

    private static Account makeAccount() {
        return TestDataFactory.createAccount('Test Account');
    }

    private static Contact makeContact(Id accId) {
        return TestDataFactory.createContact(accId, 'John', 'Doe');
    }

    private static Flight__c makeFlight(String origin, String dest, DateTime departure) {
        return TestDataFactory.createFlight(origin, dest, departure);
    }

    @isTest
    static void testLoadMetrics() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight('DEL', 'BOM', DateTime.now().addDays(1));

        // Create Confirmed booking
        Booking__c bk1 = TestDataFactory.createBooking(con.Id, fl.Id, 2);
        bk1.Booking_Status__c = 'Confirmed';
        bk1.Base_Fare__c = 100.00;
        bk1.Taxes_Fees__c = 10.00;
        update bk1; // Formula Total_Amount__c = (100 + 10) * 2 = 220.00

        // Create Cancelled booking
        Booking__c bk2 = TestDataFactory.createBooking(con.Id, fl.Id, 1);
        bk2.Booking_Status__c = 'Cancelled';
        bk2.Cancellation_Reason__c = 'Test Cancellation Reason';
        update bk2;

        // Create Draft booking
        Booking__c bk3 = TestDataFactory.createBooking(con.Id, fl.Id, 1);
        bk3.Booking_Status__c = 'Draft';
        update bk3;

        Test.startTest();
        DashboardController ctrl = new DashboardController();
        Test.stopTest();

        System.assertEquals(3, ctrl.totalBookings, 'Total bookings count should be 3');
        System.assertEquals(1, ctrl.confirmedBookings, 'Confirmed bookings count should be 1');
        System.assertEquals(1, ctrl.cancelledBookings, 'Cancelled bookings count should be 1');
        System.assertEquals(1, ctrl.draftBookings, 'Draft bookings count should be 1');
        System.assertEquals(220.00, ctrl.totalRevenue, 'Total revenue should be 220.00');
        System.assertEquals(false, ctrl.hasError, 'Should not have error.');
    }

    @isTest
    static void testRevenueAnalytics() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight('DEL', 'BOM', DateTime.now().addDays(1));

        // Booking in month 1 (e.g. Jan 2026)
        Booking__c bk1 = TestDataFactory.createBooking(con.Id, fl.Id, 2);
        bk1.Booking_Status__c = 'Confirmed';
        bk1.Booking_Date__c = Date.newInstance(2026, 1, 15);
        bk1.Base_Fare__c = 100.00;
        bk1.Taxes_Fees__c = 0.00;
        update bk1; // Total = 200.00

        // Booking in month 2 (e.g. Feb 2026) - with larger revenue
        Booking__c bk2 = TestDataFactory.createBooking(con.Id, fl.Id, 2);
        bk2.Booking_Status__c = 'Confirmed';
        bk2.Booking_Date__c = Date.newInstance(2026, 2, 20);
        bk2.Base_Fare__c = 200.00;
        bk2.Taxes_Fees__c = 0.00;
        update bk2; // Total = 400.00

        Test.startTest();
        DashboardController ctrl = new DashboardController();
        Test.stopTest();

        System.assertEquals(2, ctrl.monthlyRevenue.size(), 'Should have two months of revenue data.');
        
        // Month 1 (Jan 2026)
        System.assertEquals('Jan 2026', ctrl.monthlyRevenue[0].monthName);
        System.assertEquals(200.00, ctrl.monthlyRevenue[0].revenue);
        System.assertEquals(50, ctrl.monthlyRevenue[0].percent, 'Jan percentage should scale to 50% of peak');

        // Month 2 (Feb 2026)
        System.assertEquals('Feb 2026', ctrl.monthlyRevenue[1].monthName);
        System.assertEquals(400.00, ctrl.monthlyRevenue[1].revenue);
        System.assertEquals(100, ctrl.monthlyRevenue[1].percent, 'Feb percentage should scale to 100% of peak');
    }

    @isTest
    static void testUpcomingDepartures() {
        // Insert flights with different departure datetimes (past flights should be ignored)
        Flight__c pastFlight = makeFlight('DEL', 'BOM', DateTime.now().addDays(-2));
        
        // Future flights
        Flight__c flFar = makeFlight('DEL', 'CCU', DateTime.now().addDays(10));
        Flight__c flNear = makeFlight('DEL', 'MAA', DateTime.now().addDays(2));
        Flight__c flMid = makeFlight('DEL', 'BOM', DateTime.now().addDays(5));

        Test.startTest();
        DashboardController ctrl = new DashboardController();
        Test.stopTest();

        // Should return 3 future flights sorted by date ASC (flNear, flMid, flFar)
        System.assertEquals(3, ctrl.upcomingFlights.size(), 'Should find 3 future departures.');
        System.assertEquals(flNear.Id, ctrl.upcomingFlights[0].Id, 'Nearest flight first');
        System.assertEquals(flMid.Id, ctrl.upcomingFlights[1].Id, 'Middle flight second');
        System.assertEquals(flFar.Id, ctrl.upcomingFlights[2].Id, 'Farthest flight third');
    }

    @isTest
    static void testEmptyState() {
        Test.startTest();
        DashboardController ctrl = new DashboardController();
        Test.stopTest();

        System.assertEquals(0, ctrl.totalBookings);
        System.assertEquals(0, ctrl.confirmedBookings);
        System.assertEquals(0, ctrl.cancelledBookings);
        System.assertEquals(0.0, ctrl.totalRevenue);
        System.assertEquals(0, ctrl.monthlyRevenue.size());
        System.assertEquals(0, ctrl.upcomingFlights.size());
        System.assertEquals(false, ctrl.hasError);
    }

    @isTest
    static void testExceptionHandling() {
        Test.startTest();
        DashboardController.forceException = true;
        DashboardController ctrl = new DashboardController();
        DashboardController.forceException = false;
        Test.stopTest();

        System.assertEquals(true, ctrl.hasError);
        System.assertEquals('Unable to load dashboard data.', ctrl.errorMessage);
        System.assertEquals(0, ctrl.totalBookings);
        System.assertEquals(0.0, ctrl.totalRevenue);
        System.assertEquals(0, ctrl.monthlyRevenue.size());
        System.assertEquals(0, ctrl.upcomingFlights.size());
    }

    @isTest
    static void testNavigation() {
        DashboardController ctrl = new DashboardController();
        
        Test.startTest();
        PageReference flightSearch = ctrl.goToFlightSearch();
        PageReference bookingSearch = ctrl.goToBookingSearch();
        PageReference bookingCreate = ctrl.goToBookingCreate();
        Test.stopTest();

        System.assertNotEquals(null, flightSearch);
        System.assert(flightSearch.getUrl().contains('/apex/FlightSearch'));
        System.assertEquals(true, flightSearch.getRedirect());

        System.assertNotEquals(null, bookingSearch);
        System.assert(bookingSearch.getUrl().contains('/apex/BookingSearch'));
        System.assertEquals(true, bookingSearch.getRedirect());

        System.assertNotEquals(null, bookingCreate);
        System.assert(bookingCreate.getUrl().contains('/apex/BookingCreate'));
        System.assertEquals(true, bookingCreate.getRedirect());
    }

    @isTest
    static void testGetDashboardData() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id);
        Flight__c fl = makeFlight('DEL', 'BOM', DateTime.now().addDays(1));

        Booking__c bk = TestDataFactory.createBooking(con.Id, fl.Id, 2);
        bk.Booking_Status__c = 'Confirmed';
        update bk;

        Test.startTest();
        DashboardController.DashboardDataWrapper data = DashboardController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertEquals(1, data.totalBookings);
    }

    @isTest
    static void testDashboardEnhancements() {
        // Create setup object (User) first to prevent Mixed DML
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User otherUser = new User(
            Alias = 'othusr',
            Email = 'otheruser@testskybook.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'otheruser' + DateTime.now().getTime() + '@testskybook.com',
            ManagerId = UserInfo.getUserId()
        );
        insert otherUser;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Group_Booking_Manager' LIMIT 1];
        insert new PermissionSetAssignment(
            AssigneeId = otherUser.Id,
            PermissionSetId = ps.Id
        );

        System.runAs(otherUser) {
            Account acc = makeAccount();
            Contact con = makeContact(acc.Id);
            Flight__c fl = makeFlight('DEL', 'BOM', DateTime.now().addDays(1));

            // Create booking for today (with 10 seats to trigger group booking formula)
            Booking__c bkToday = TestDataFactory.createBooking(con.Id, fl.Id, 10);
            bkToday.Booking_Status__c = 'Confirmed';
            bkToday.Booking_Date__c = Date.today();
            bkToday.Base_Fare__c = 20.00;
            bkToday.Taxes_Fees__c = 2.00;
            update bkToday; // Total Amount = 220.00

            // Create another booking for today but Cancelled (should be excluded from revenue)
            Booking__c bkTodayCancel = TestDataFactory.createBooking(con.Id, fl.Id, 1);
            bkTodayCancel.Booking_Status__c = 'Cancelled';
            bkTodayCancel.Cancellation_Reason__c = 'Customer Request';
            bkTodayCancel.Booking_Date__c = Date.today();
            bkTodayCancel.Base_Fare__c = 50.00;
            bkTodayCancel.Taxes_Fees__c = 0.00;
            update bkTodayCancel;

            // For Pending Group Approvals, submit bkToday for approval
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setComments('Submitting group booking for approval.');
            req.setObjectId(bkToday.Id);
            req.setProcessDefinitionNameOrId('Group_Booking_Approval');
            req.setSkipEntryCriteria(true);
            Approval.ProcessResult result = Approval.process(req);
            System.assert(result.isSuccess(), 'Approval submission should succeed');

            Test.startTest();
            DashboardController ctrl = new DashboardController();
            Test.stopTest();

            // 1. Today's Bookings count should be 2 (bkToday and bkTodayCancel)
            System.assertEquals(2, ctrl.todayBookingsCount, 'Today bookings should be 2');

            // 2. Today's Revenue should be 220.00 (bkToday only; bkTodayCancel is Cancelled so excluded)
            System.assertEquals(220.00, ctrl.todayRevenue, 'Today revenue should be 220.00');

            // 3. Pending Group Approvals should be 1
            System.assertEquals(1, ctrl.pendingGroupApprovals, 'Pending group approvals should be 1');

            // 4. Active Cancellation Cases should be 1
            System.assertEquals(1, ctrl.activeCancellationCases, 'Active cancellation cases should be 1');

            // 5. Recent Bookings should contain bkToday and bkTodayCancel
            System.assertEquals(2, ctrl.recentBookings.size(), 'Should return 2 recent bookings');
            System.assertEquals(bkTodayCancel.Id, ctrl.recentBookings[0].Id, 'Newest booking first (ordered by CreatedDate DESC)');
        }
    }
}
