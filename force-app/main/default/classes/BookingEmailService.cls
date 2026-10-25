public virtual class BookingEmailService {
    public static void queueConfirmationEmails(Set<Id> bookingIds) {
        System.debug('Confirmation emails queued for Booking IDs: ' + bookingIds);
    }
}
