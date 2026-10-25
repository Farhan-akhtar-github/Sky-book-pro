public with sharing class BookingEmailFutureService {
    @future
    public static void sendBookingConfirmationEmail(Set<Id> bookingIds) {
        if (bookingIds == null || bookingIds.isEmpty()) {
            return;
        }
        
        List<Booking__c> bookings = [
            SELECT Id, Name, Passenger__r.Email, Passenger__r.FirstName, Passenger__r.LastName, 
                   Flight__r.Origin_Airport__c, Flight__r.Destination_Airport__c, Flight__r.Departure_DateTime__c
            FROM Booking__c
            WHERE Id IN :bookingIds
            WITH USER_MODE
        ];
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Booking__c b : bookings) {
            if (b.Passenger__r.Email != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ b.Passenger__r.Email });
                mail.setSubject('Flight Booking Confirmation - ' + b.Name);
                String body = 'Dear ' + b.Passenger__r.FirstName + ' ' + b.Passenger__r.LastName + ',\n\n' +
                              'Your booking (' + b.Name + ') has been confirmed.\n' +
                              'Flight Details:\n' +
                              '- Origin: ' + b.Flight__r.Origin_Airport__c + '\n' +
                              '- Destination: ' + b.Flight__r.Destination_Airport__c + '\n' +
                              '- Departure: ' + b.Flight__r.Departure_DateTime__c + '\n\n' +
                              'Thank you for booking with SkyBook Pro.';
                mail.setPlainTextBody(body);
                emails.add(mail);
            }
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}
