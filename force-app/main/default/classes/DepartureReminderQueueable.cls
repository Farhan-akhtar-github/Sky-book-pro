public with sharing class DepartureReminderQueueable implements Queueable {
    
    public void execute(QueueableContext context) {
        Datetime tomorrowStart = Datetime.newInstance(Date.today().addDays(1), Time.newInstance(0, 0, 0, 0));
        Datetime tomorrowEnd = Datetime.newInstance(Date.today().addDays(1), Time.newInstance(23, 59, 59, 999));
        
        List<Booking__c> bookings = [
            SELECT Id, Passenger__c, Flight__c, Passenger__r.Name, Flight__r.Departure_DateTime__c
            FROM Booking__c
            WHERE Booking_Status__c = 'Confirmed'
            AND Flight__r.Departure_DateTime__c >= :tomorrowStart
            AND Flight__r.Departure_DateTime__c <= :tomorrowEnd
            WITH USER_MODE
        ];
        
        for (Booking__c b : bookings) {
            System.debug('Departure reminder processed for Booking ID: ' + b.Id + 
                         ' Passenger: ' + b.Passenger__r.Name + 
                         ' Departure: ' + b.Flight__r.Departure_DateTime__c);
        }
    }
}
