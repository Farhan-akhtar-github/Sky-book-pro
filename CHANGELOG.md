# Changelog

All notable changes to this project will be documented in this file.

## [Phase 3B - Sprint 4 & 5 Compliance Patch] - 2026-07-03

### Added
- Upgraded the Meal Preference picklist input to a `<lightning-checkbox-group>` to support true multi-select meal options matching Salesforce Picklist values.
- Implemented exhaustive validation in `passengerDetailsForm` that checks all passenger details without terminating early.
- Added dynamic styling to highlight invalid passenger cards with orange/red borders and clear visual error messages.
- Added real-time error clearance on user correction of passenger inputs.
- Joined multi-selected meal preferences with a comma separator in the `bookingConfirmation` view.

## [Phase 3B - Sprint 3 Compliance Patch] - 2026-07-03

### Added
- Added Price Descending (`price_desc`) sorting support in `flightResultsList` LWC.
- Integrated airline brand logo display dynamically using `logo_symbol_url` from segments or owners in the Duffel API response.
- Exposed nullable `logoUrl` property in `FlightOfferWrapper` class and populated it in `DuffelFlightSearchService`.
- Added unit test cases for all carrier/owner logo parsing permutations in `DuffelFlightSearchServiceTest`.

## [Phase 3B - Sprint 9 & 10] - 2026-07-02

### Added
- Created `cancellationModal` LWC:
  - Renders double cancellation confirmations, warning notices, and required cancellation reason textareas.
  - Fires LMS `CancellationEvent` over `SkyBook_Channel__c` message channel on success.
- Created `refundStatusTracker` LWC:
  - Wires `getRefundStatus` to update a multi-step path progress bar (`Initiated`, `Processing`, `Completed`, `Rejected`).
  - Supports imperative `@api refresh()` refreshApex triggers.
- Created `SkyBook_Channel.messageChannel-meta.xml` under `force-app/main/default/messageChannels/` to register the Lightning Message Channel.
- Created `CancellationService.cls`:
  - Exposes `@AuraEnabled` `cancelBooking` updating booking status to `'Cancelled'` and cancellation reasons.
  - Exposes `@AuraEnabled(cacheable=true)` `getRefundStatus` retrieving status of the most recent refund record.
  - Added full unit test suites in `CancellationServiceTest.cls`.

### Verified
- Executed all Apex unit tests: **14/14 passed**.
- Validated deployment compilation checks: **Succeeded**.

## [Phase 3B - Sprint 6, 7, 8] - 2026-07-02

### Added
- Completed `bookingSuccess` LWC (HTML template and JavaScript controller) showing itinerary summaries and dashboard redirect routes.
- Completed `myBookingsDashboard` LWC (HTML template and JavaScript controller) implementing search (SOSL via Apex), listing confirmed bookings, and date sort toggles.
- Completed `bookingDetailView` LWC (HTML template and JavaScript controller) showing itinerary segments, passengers, pricing summary tables, and cancel trigger hooks.
- Added `@AuraEnabled` static method `getBookingDetail` in `BookingDetailController` to fetch child segments, passenger lists, and refunds in one transaction.

### Verified
- Modified controller class and added unit tests in `BookingDetailControllerTest` achieving 100% pass rate.
- Verified metadata deployments successfully.

## [Phase 3B - Sprint 5] - 2026-07-02

### Added
- Completed `bookingConfirmation` LWC (HTML template and JavaScript controller).
- Implemented review panels for Flight details, Passenger lists, and Fare breakdowns.
- Integrated `<lightning-record-picker>` for Contact owner selection.
- Added Terms checkbox binding, loading spinner wrappers, and integrated imperative call to `BookingService.createBooking`.

## [Phase 3B - Sprint 4] - 2026-07-02

### Added
- Completed `passengerDetailsForm` LWC (HTML template and JavaScript controller).
- Implemented dynamic loops generating multiple passenger cards based on passenger count.
- Added conditional passport field display for international routes.
- Configured public `@api validateAllPassengers()` method ensuring past date of birth validation and international passport constraints.

### Verified
- Successful metadata deployment to target org.
- Correct dynamic rendering matching input passenger numbers.

## [Phase 3B - Sprint 3] - 2026-07-02

### Added
- Completed `flightResultsList` LWC (HTML template and JavaScript logic) managing sorting (Price, Duration, Departure) and filtering (Airline, Max Price range slider).
- Completed `flightResultCard` LWC (HTML template and JavaScript logic) rendering individual offer cards with times, logo, seats text, segment data, and booking buttons.

### Verified
- Sorting by Price (ascending), Duration (ascending), and Departure Time (ascending).
- Filtering logic for single airline and maximum price slider.
- Zero-results empty state display handler.
- Real deployment validation of both components.

## [Phase 3B - Sprint 2] - 2026-07-02

### Added
- Completed `flightSearchForm` LWC (HTML and JavaScript controller) with input bindings, comboboxes, and validation checks.

### Verified
- Form checks for airport mismatch (Origin != Destination).
- Form validates passenger count >= 1.
- Form checks that departure date is in the future.
- Form validates round-trip return date is after departure date.
- Successfully deployed component metadata to target org.

## [Phase 3B - Sprint 1] - 2026-07-02

### Added
- Shared utilities LWC `skyBookUtils` containing `constants.js`, `dateUtils.js`, and `currencyUtils.js`.
- Root application container `skyBookApp` LWC (managing navigation state and global variables).
- Stub/skeleton components for all Sprints 2-11 (including `agentDashboard`, `flightSearchForm`, `flightResultsList`, `flightResultCard`, `passengerDetailsForm`, `bookingConfirmation`, `bookingSuccess`, `myBookingsDashboard`, `bookingDetailView`, `cancellationModal`, and `refundStatusTracker`) to support compiling parent dependencies.

### Modified
- `DuffelFlightSearchService.cls`: Added `@AuraEnabled` to `searchFlights` to support imperative LWC search requests.
- `.forceignore`: Configured ignore rules to bypass profiles and settings errors during deployment checks.
