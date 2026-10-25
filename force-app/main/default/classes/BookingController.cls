public with sharing class BookingController {

    // ── URL parameter properties (populated by initialize()) ──────────────────
    public String offerId       { get; set; }
    public String airline       { get; set; }
    public String origin        { get; set; }
    public String destination   { get; set; }
    public String priceStr      { get; set; }  // String to avoid VF coercion issues
    public String currencyCode  { get; set; }
    public String seatClass     { get; set; }
    public String seatsStr      { get; set; }  // String for same reason
    public Decimal price        { get; private set; }
    public Integer seats        { get; private set; }

    // ── UI state ──────────────────────────────────────────────────────────────
    public String errorMessage   { get; set; }
    public String successMessage { get; set; }

    // ── Dummy Booking__c solely for apex:inputField Contact lookup rendering ──
    public Booking__c dummyBooking { get; set; }

    // ── Constructor ───────────────────────────────────────────────────────────
    public BookingController() {
        dummyBooking   = new Booking__c();
        errorMessage   = null;
        successMessage = null;
        initialize();
    }

    // ── Load URL parameters passed from FlightSearch ──────────────────────────
    private void initialize() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        offerId       = params.get('offerId');
        airline       = params.get('airline');
        origin        = params.get('origin');
        destination   = params.get('destination');
        priceStr      = params.get('price');
        currencyCode  = params.get('currency');
        seatClass     = params.get('seatClass');
        seatsStr      = params.get('seats');

        // Parse numeric fields safely
        try {
            price = String.isNotBlank(priceStr) ? Decimal.valueOf(priceStr) : 0.0;
        } catch (Exception e) {
            price = 0.0;
        }
        try {
            seats = String.isNotBlank(seatsStr) ? Integer.valueOf(seatsStr) : 1;
            if (seats <= 0) seats = 1;
        } catch (Exception e) {
            seats = 1;
        }

        // Default seatClass label for display
        if (String.isBlank(seatClass)) seatClass = 'economy';
        if (String.isBlank(currencyCode)) currencyCode = 'USD';
    }

    // ── Human-readable cabin class label ─────────────────────────────────────
    public String getCabinClassLabel() {
        if (String.isBlank(seatClass)) return 'Economy';
        if (seatClass.equalsIgnoreCase('economy')) return 'Economy';
        if (seatClass.equalsIgnoreCase('premium_economy')) return 'Premium Economy';
        if (seatClass.equalsIgnoreCase('business')) return 'Business';
        if (seatClass.equalsIgnoreCase('first')) return 'First Class';
        return seatClass;
    }

    // ── Confirm and create the booking ────────────────────────────────────────
    public PageReference confirmBooking() {
        errorMessage  = null;
        successMessage = null;

        // Validate passenger selected
        if (dummyBooking.Passenger__c == null) {
            errorMessage = 'Please select a passenger (Contact) before confirming the booking.';
            return null;
        }

        // Validate offerId available
        if (String.isBlank(offerId)) {
            errorMessage = 'No flight offer found. Please return to Flight Search and select a flight.';
            return null;
        }

        // Build FlightOfferWrapper from URL parameters
        FlightOfferWrapper offerWrapper = new FlightOfferWrapper();
        offerWrapper.offerId       = offerId;
        offerWrapper.price         = price;
        offerWrapper.currencyIsoCode = currencyCode;
        offerWrapper.airline       = airline;
        offerWrapper.origin        = origin;
        offerWrapper.destination   = destination;
        offerWrapper.cabinClass    = seatClass;

        try {
            BookingService.createBooking(
                dummyBooking.Passenger__c,
                offerWrapper,
                seats,
                seatClass
            );
            // Redirect to BookingSearch on success
            PageReference redirectPage = new PageReference('/apex/BookingSearch');
            redirectPage.setRedirect(true);
            return redirectPage;
        } catch (AuraHandledException ahe) {
            errorMessage = 'Booking failed: ' + ahe.getMessage();
            return null;
        } catch (Exception ex) {
            errorMessage = 'An unexpected error occurred: ' + ex.getMessage();
            return null;
        }
    }

    // ── Cancel – return to FlightSearch ──────────────────────────────────────
    public PageReference cancel() {
        PageReference flightSearch = new PageReference('/apex/FlightSearch');
        flightSearch.setRedirect(true);
        return flightSearch;
    }
}
