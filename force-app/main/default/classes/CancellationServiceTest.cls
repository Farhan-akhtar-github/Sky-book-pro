@isTest
private class CancellationServiceTest {

    @isTest
    static void testCancelBookingSuccess() {
        Account acc = TestDataFactory.createAccount('Test Account');
        Contact con = TestDataFactory.createContact(acc.Id, 'John', 'Doe');
        Flight__c fl = TestDataFactory.createFlight('DEL', 'BOM', DateTime.now().addDays(2));
        Booking__c bk = TestDataFactory.createBooking(con.Id, fl.Id, 2);
        bk.Booking_Status__c = 'Confirmed';
        bk.Base_Fare__c = 200.00;
        bk.Taxes_Fees__c = 50.00;
        bk.Number_of_Seats__c = 2;
        update bk;

        Test.startTest();
        Booking__c cancelledBk = CancellationService.cancelBooking(bk.Id, 'Passenger changed plans');
        Test.stopTest();

        System.assertEquals('Cancelled', cancelledBk.Booking_Status__c);
        System.assertEquals('Passenger changed plans', cancelledBk.Cancellation_Reason__c);

        // Verify Refund record was created
        List<Refund__c> refunds = [SELECT Id, Refund_Amount__c, Refund_Status__c FROM Refund__c WHERE Booking__c = :bk.Id];
        System.assertEquals(1, refunds.size());
        System.assertEquals('Initiated', refunds[0].Refund_Status__c);
        System.assertEquals(500.00, refunds[0].Refund_Amount__c);
    }

    @isTest
    static void testCancelBookingAlreadyCancelled() {
        Account acc = TestDataFactory.createAccount('Test Account');
        Contact con = TestDataFactory.createContact(acc.Id, 'John', 'Doe');
        Flight__c fl = TestDataFactory.createFlight('DEL', 'BOM', DateTime.now().addDays(2));
        Booking__c bk = TestDataFactory.createBooking(con.Id, fl.Id, 2);
        bk.Booking_Status__c = 'Cancelled';
        bk.Cancellation_Reason__c = 'Initial cancel';
        update bk;

        Test.startTest();
        try {
            CancellationService.cancelBooking(bk.Id, 'Duplicate cancel');
            System.assert(false, 'Exception should have been thrown.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Script-thrown exception') || ex.getMessage().contains('already cancelled'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCancelBookingInvalidArgs() {
        Test.startTest();
        try {
            CancellationService.cancelBooking(null, 'Reason');
            System.assert(false, 'Exception should have been thrown.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Script-thrown exception') || ex.getMessage().contains('Booking ID cannot be null'));
        }

        try {
            CancellationService.cancelBooking('a00hg000001cp4AAAQ', '');
            System.assert(false, 'Exception should have been thrown.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Script-thrown exception') || ex.getMessage().contains('reason is required'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetRefundStatus() {
        Account acc = TestDataFactory.createAccount('Test Account');
        Contact con = TestDataFactory.createContact(acc.Id, 'John', 'Doe');
        Flight__c fl = TestDataFactory.createFlight('DEL', 'BOM', DateTime.now().addDays(2));
        Booking__c bk = TestDataFactory.createBooking(con.Id, fl.Id, 2);
        
        Refund__c ref = new Refund__c(
            Booking__c = bk.Id,
            Refund_Amount__c = 100.00,
            Refund_Status__c = 'Initiated',
            Requested_Date__c = Date.today()
        );
        insert ref;

        Test.startTest();
        String status = CancellationService.getRefundStatus(bk.Id);
        String nullStatus = CancellationService.getRefundStatus(null);
        String noRefundStatus = CancellationService.getRefundStatus(TestDataFactory.createBooking(con.Id, fl.Id, 1).Id);
        Test.stopTest();

        System.assertEquals('Initiated', status);
        System.assertEquals(null, nullStatus);
        System.assertEquals(null, noRefundStatus);
    }
}
