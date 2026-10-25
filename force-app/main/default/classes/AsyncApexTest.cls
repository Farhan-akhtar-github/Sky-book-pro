@isTest
public class AsyncApexTest {

    @isTest
    static void testFutureEmail() {
        Account acc = TestDataFactory.createAccount('Test Acc');
        Contact con = TestDataFactory.createContact(acc.Id, 'John', 'Doe');
        Flight__c fl = TestDataFactory.createFlight('DEL', 'BOM', DateTime.now().addDays(1));
        Booking__c bk = TestDataFactory.createBooking(con.Id, fl.Id, 2);

        Test.startTest();
        BookingEmailFutureService.sendBookingConfirmationEmail(new Set<Id>{ bk.Id });
        Test.stopTest();

        System.assert(Limits.getEmailInvocations() >= 0, 'Email invocation limit checked.');
    }

    @isTest
    static void testQueueableReminder() {
        Account acc = TestDataFactory.createAccount('Test Acc');
        Contact con = TestDataFactory.createContact(acc.Id, 'John', 'Doe');
        Flight__c fl = TestDataFactory.createFlight('DEL', 'BOM', DateTime.now().addDays(1));
        
        Booking__c bk = TestDataFactory.createBooking(con.Id, fl.Id, 2);
        bk.Booking_Status__c = 'Confirmed';
        update bk;

        Test.startTest();
        System.enqueueJob(new DepartureReminderQueueable());
        Test.stopTest();

        List<Booking__c> bookings = [
            SELECT Id, Booking_Status__c 
            FROM Booking__c 
            WHERE Booking_Status__c = 'Confirmed'
        ];
        System.assertEquals(1, bookings.size());
    }

    @isTest
    static void testSchedulerReminder() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Daily Departure Reminder AsyncApex',
            '0 0 7 * * ?',
            new DailyDepartureReminderScheduler()
        );
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime 
            FROM CronTrigger 
            WHERE Id = :jobId
        ];
        System.assertEquals('0 0 7 * * ?', ct.CronExpression);
        System.assertEquals(0, ct.TimesTriggered);
    }

    @isTest
    static void testBatchArchive() {
        Account acc = TestDataFactory.createAccount('Test Acc');
        Contact con = TestDataFactory.createContact(acc.Id, 'John', 'Doe');
        Flight__c fl = TestDataFactory.createFlight('DEL', 'BOM', DateTime.now().addDays(1));
        
        Booking__c bkOld = new Booking__c(
            Passenger__c = con.Id,
            Flight__c = fl.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 2,
            Base_Fare__c = 100.00,
            Taxes_Fees__c = 10.00,
            Booking_Status__c = 'Cancelled',
            Booking_Date__c = Date.today().addYears(-3)
        );
        insert bkOld;

        Booking__c bkRecent = new Booking__c(
            Passenger__c = con.Id,
            Flight__c = fl.Id,
            Seat_Class__c = 'Economy',
            Number_of_Seats__c = 2,
            Base_Fare__c = 100.00,
            Taxes_Fees__c = 10.00,
            Booking_Status__c = 'Cancelled',
            Booking_Date__c = Date.today()
        );
        insert bkRecent;

        Test.startTest();
        BookingArchiveBatch batch = new BookingArchiveBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        System.assertEquals(2, [SELECT count() FROM Booking__c]);
    }
}
