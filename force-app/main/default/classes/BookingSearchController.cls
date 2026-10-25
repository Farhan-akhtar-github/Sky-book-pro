public with sharing class BookingSearchController {

    // ── Search Inputs ──────────────────────────────────────────────────────────
    public String searchTerm { get; set; }

    // Used only for the apex:inputField Contact lookup binding
    public Booking__c dummyBooking { get; set; }

    public String selectedBookingId { get; set; }

    // ── Result Collections ─────────────────────────────────────────────────────
    public List<Booking__c> agentBookings          { get; set; }
    public List<Contact>    searchContacts         { get; set; }
    public List<Booking__c> searchBookings         { get; set; }
    public List<Booking__c> contactHistoryBookings { get; set; }

    // ── Messages ───────────────────────────────────────────────────────────────
    public String errorMessage   { get; set; }
    public String successMessage { get; set; }

    // ── Test-only exception hooks (do NOT set in production) ─────────────────
    @TestVisible private static Boolean forceAgentBookingsException  = false;
    @TestVisible private static Boolean forceSearchException         = false;
    @TestVisible private static Boolean forceContactHistoryException = false;

    // ── Constructor ───────────────────────────────────────────────────────────
    public BookingSearchController() {
        agentBookings          = new List<Booking__c>();
        searchContacts         = new List<Contact>();
        searchBookings         = new List<Booking__c>();
        contactHistoryBookings = new List<Booking__c>();
        dummyBooking           = new Booking__c();
        errorMessage           = null;
        successMessage         = null;
        loadAgentBookings();
    }

    // ── Load current user's confirmed bookings ────────────────────────────────
    private void loadAgentBookings() {
        try {
            if (forceAgentBookingsException) {
                throw new System.QueryException('Simulated agent bookings failure');
            }
            // Re-query with richer field set needed for the UI table
            List<Booking__c> base = BookingSearchService.getConfirmedBookingsByAgent(
                UserInfo.getUserId()
            );
            if (base.isEmpty()) {
                agentBookings = new List<Booking__c>();
                return;
            }
            Set<Id> ids = new Set<Id>();
            for (Booking__c b : base) {
                ids.add(b.Id);
            }
            agentBookings = [
                SELECT Id, Name, Passenger__r.Name, Booking_Status__c,
                       Number_of_Seats__c, Total_Amount__c, Booking_Date__c
                FROM   Booking__c
                WHERE  Id IN :ids
                WITH   USER_MODE
                ORDER  BY Booking_Date__c DESC
            ];
        } catch (Exception ex) {
            errorMessage  = 'Could not load agent bookings: ' + ex.getMessage();
            agentBookings = new List<Booking__c>();
        }
    }

    // ── Global SOSL Search ────────────────────────────────────────────────────
    public PageReference search() {
        errorMessage   = null;
        successMessage = null;
        searchContacts = new List<Contact>();
        searchBookings = new List<Booking__c>();

        if (String.isBlank(searchTerm)) {
            errorMessage = 'Please enter a search term.';
            return null;
        }

        try {
            if (forceSearchException) {
                throw new System.QueryException('Simulated search failure');
            }
            BookingSearchService.SearchResultWrapper result =
                BookingSearchService.searchPassengersAndBookings(searchTerm.trim());

            searchContacts = result.contacts;

            // Re-query bookings with UI-friendly fields if any were returned
            if (!result.bookings.isEmpty()) {
                Set<Id> bkIds = new Set<Id>();
                for (Booking__c b : result.bookings) {
                    bkIds.add(b.Id);
                }
                searchBookings = [
                    SELECT Id, Name, Passenger__r.Name, Booking_Status__c, Total_Amount__c
                    FROM   Booking__c
                    WHERE  Id IN :bkIds
                    WITH   USER_MODE
                ];
            }

            Integer total = searchContacts.size() + searchBookings.size();
            if (total == 0) {
                successMessage = 'No matching records found.';
            } else {
                successMessage = 'Found ' + searchContacts.size() + ' contact(s) and '
                               + searchBookings.size() + ' booking(s).';
            }
        } catch (Exception ex) {
            errorMessage   = 'Search failed: ' + ex.getMessage();
            searchContacts = new List<Contact>();
            searchBookings = new List<Booking__c>();
        }

        return null;
    }

    // ── Load Passenger Booking History ────────────────────────────────────────
    public PageReference loadContactHistory() {
        errorMessage           = null;
        successMessage         = null;
        contactHistoryBookings = new List<Booking__c>();

        if (dummyBooking.Passenger__c == null) {
            errorMessage = 'Please select a passenger.';
            return null;
        }

        try {
            if (forceContactHistoryException) {
                throw new System.QueryException('Simulated contact history failure');
            }
            List<Booking__c> base = BookingSearchService.getBookingsByContact(
                dummyBooking.Passenger__c
            );

            if (base.isEmpty()) {
                contactHistoryBookings = new List<Booking__c>();
                successMessage = 'No matching records found.';
                return null;
            }

            Set<Id> ids = new Set<Id>();
            for (Booking__c b : base) {
                ids.add(b.Id);
            }
            contactHistoryBookings = [
                SELECT Id, Name, Booking_Status__c, Number_of_Seats__c,
                       Total_Amount__c, Booking_Date__c
                FROM   Booking__c
                WHERE  Id IN :ids
                WITH   USER_MODE
                ORDER  BY Booking_Date__c DESC
            ];

            successMessage = 'Loaded ' + contactHistoryBookings.size() + ' booking(s) for selected passenger.';
        } catch (Exception ex) {
            errorMessage           = 'Could not load history: ' + ex.getMessage();
            contactHistoryBookings = new List<Booking__c>();
        }

        return null;
    }

    // ── Clear / Reset all filters ─────────────────────────────────────────────
    public PageReference clearSearch() {
        searchTerm             = null;
        searchContacts         = new List<Contact>();
        searchBookings         = new List<Booking__c>();
        contactHistoryBookings = new List<Booking__c>();
        dummyBooking           = new Booking__c();
        errorMessage           = null;
        successMessage         = null;
        loadAgentBookings();
        return null;
    }

    // ── Navigate to Booking Details ───────────────────────────────────────────
    public PageReference viewBooking() {
        if (String.isBlank(selectedBookingId)) {
            errorMessage = 'No booking selected.';
            return null;
        }
        PageReference pr = new PageReference('/apex/BookingDetail');
        pr.getParameters().put('id', selectedBookingId);
        pr.setRedirect(true);
        return pr;
    }
}
