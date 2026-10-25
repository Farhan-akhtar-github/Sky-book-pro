public with sharing class FlightSearchController {

    public String origin { get; set; }
    public String destination { get; set; }
    public String departureDateStr { get; set; }   // bound to html-type="date" input (yyyy-MM-dd)
    public String passengerCountStr { get; set; }  // safe String binding – avoids VF Integer coercion failures on blank input
    public String cabinClass { get; set; }
    public String errorMessage { get; set; }
    public String successMessage { get; set; }
    public Boolean hasSearched { get; set; }

    // Pagination state
    private List<FlightOfferWrapper> allResults;
    public List<FlightOfferWrapper> pagedResults { get; private set; }
    public Integer currentPage { get; private set; }
    public Integer pageSize { get; private set; }
    public Integer totalPages { get; private set; }
    public Integer totalResults { get; private set; }

    public FlightSearchController() {
        passengerCountStr = '1';
        cabinClass = 'economy';
        pageSize = 20;
        currentPage = 1;
        totalResults = 0;
        totalPages = 1;
        allResults = new List<FlightOfferWrapper>();
        pagedResults = new List<FlightOfferWrapper>();
        hasSearched = false;
    }

    public List<SelectOption> getCabinClassOptions() {
        return new List<SelectOption>{
            new SelectOption('economy', 'Economy'),
            new SelectOption('premium_economy', 'Premium Economy'),
            new SelectOption('business', 'Business'),
            new SelectOption('first', 'First Class')
        };
    }

    public PageReference search() {
        errorMessage = null;
        successMessage = null;

        // Validate required fields
        List<String> errors = new List<String>();
        if (String.isBlank(origin)) {
            errors.add('Origin is required.');
        }
        if (String.isBlank(destination)) {
            errors.add('Destination is required.');
        }
        if (String.isBlank(departureDateStr)) {
            errors.add('Departure date is required.');
        }

        // Parse passenger count safely – String binding prevents VF view-state deserialization errors
        Integer pax = null;
        if (String.isBlank(passengerCountStr)) {
            errors.add('Passenger count must be greater than zero.');
        } else {
            try {
                pax = Integer.valueOf(passengerCountStr.trim());
            } catch (Exception e) {
                pax = null;
            }
            if (pax == null || pax <= 0) {
                errors.add('Passenger count must be greater than zero.');
            }
        }

        if (!errors.isEmpty()) {
            errorMessage = String.join(errors, ' ');
            return null;
        }

        // Parse string date from HTML input (format: yyyy-MM-dd)
        Date parsedDate;
        try {
            parsedDate = Date.valueOf(departureDateStr);
        } catch (Exception parseEx) {
            errorMessage = 'Invalid departure date format. Please use the date picker.';
            return null;
        }

        try {
            allResults = DuffelFlightSearchService.searchFlights(
                origin.trim().toUpperCase(),
                destination.trim().toUpperCase(),
                parsedDate,
                pax,
                cabinClass
            );
            totalResults = allResults.size();
            totalPages = (Integer) Math.ceil((Double) totalResults / pageSize);
            if (totalPages == 0) totalPages = 1;
            currentPage = 1;
            hasSearched = true;
            applyPagination();
            if (totalResults == 0) {
                successMessage = 'No flights found for the specified route and date.';
            } else {
                successMessage = 'Found ' + totalResults + ' flight(s).';
            }
        } catch (Exception ex) {
            errorMessage = 'Search failed: ' + ex.getMessage();
            allResults = new List<FlightOfferWrapper>();
            pagedResults = new List<FlightOfferWrapper>();
        }

        return null;
    }

    public PageReference nextPage() {
        if (currentPage < totalPages) {
            currentPage++;
            applyPagination();
        }
        return null;
    }

    public PageReference previousPage() {
        if (currentPage > 1) {
            currentPage--;
            applyPagination();
        }
        return null;
    }

    private void applyPagination() {
        Integer startIdx = (currentPage - 1) * pageSize;
        Integer endIdx = Math.min(startIdx + pageSize, allResults.size());
        pagedResults = new List<FlightOfferWrapper>();
        for (Integer i = startIdx; i < endIdx; i++) {
            pagedResults.add(allResults[i]);
        }
    }

    public Boolean getHasPrevious() {
        return currentPage > 1;
    }

    public Boolean getHasNext() {
        return currentPage < totalPages;
    }

    public Integer getPageStart() {
        if (totalResults == 0) return 0;
        return ((currentPage - 1) * pageSize) + 1;
    }

    public Integer getPageEnd() {
        return Math.min(currentPage * pageSize, totalResults);
    }

    public PageReference bookFlight() {
        String offerId = ApexPages.currentPage().getParameters().get('offerId');
        if (String.isBlank(offerId)) {
            errorMessage = 'No flight offer selected.';
            return null;
        }

        // Find the full wrapper in allResults so we can forward every display field
        FlightOfferWrapper selectedOffer = null;
        for (FlightOfferWrapper fo : allResults) {
            if (fo.offerId == offerId) {
                selectedOffer = fo;
                break;
            }
        }

        PageReference bookingPage = new PageReference('/apex/BookingCreate');

        // ── Always-available params ───────────────────────────────────────────
        bookingPage.getParameters().put('offerId',   offerId);
        bookingPage.getParameters().put('seats',     String.isBlank(passengerCountStr) ? '1' : passengerCountStr.trim());
        bookingPage.getParameters().put('seatClass', cabinClass);

        // ── Offer-specific params (populated from the matching wrapper) ────────
        if (selectedOffer != null) {
            bookingPage.getParameters().put('airline',
                selectedOffer.airline != null ? selectedOffer.airline : '');
            bookingPage.getParameters().put('origin',
                selectedOffer.origin != null ? selectedOffer.origin : '');
            bookingPage.getParameters().put('destination',
                selectedOffer.destination != null ? selectedOffer.destination : '');
            bookingPage.getParameters().put('price',
                selectedOffer.price != null ? String.valueOf(selectedOffer.price) : '0');
            bookingPage.getParameters().put('currency',
                selectedOffer.currencyIsoCode != null ? selectedOffer.currencyIsoCode : 'USD');
        }

        bookingPage.setRedirect(false);
        return bookingPage;
    }
}

