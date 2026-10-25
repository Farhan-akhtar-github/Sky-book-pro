# SkyBook Pro Migration Walkthrough

This document contains demo screenshots, videos, and step-by-step walkthrough instructions for the Salesforce LWC implementation of SkyBook Pro.

## Sprint 3 Compliance Patch — Specification 13.2

This patch brings the flight search results list and flight result card into full compliance with specification 13.2.

### Implemented Features
1. **Price Descending Sorting**:
   - Added sorting choice "Price: High to Low" (`price_desc`) to the combobox in `flightResultsList`.
   - Clones the results list before sorting to avoid mutating the original API array.
2. **Airline Logo Rendering**:
   - Added a nullable `logoUrl` property to `FlightOfferWrapper`.
   - Populated `logoUrl` in `DuffelFlightSearchService` using the marketing carrier's `logo_symbol_url`, with a fallback to the owner carrier's `logo_symbol_url` from the JSON response.
   - Updated `flightResultCard` to display the logo image if present, and gracefully fall back to the styled airplane emoji card icon if no logo exists.

### Verification Results
- All 101 Apex unit tests compiled and passed in the org successfully.
- LWC components compile and deploy without error.

## Sprint 4 / Sprint 5 Validation and Multi-Select Meal Preference Patch

This patch addresses gaps in the Passenger Details screen validation and Meal Preference options under Specification 13.3.

### Implemented Features
1. **Multi-Select Meal Preferences**:
   - Upgraded the Meal Preference picklist input from a single-select combobox to a `<lightning-checkbox-group>` enabling multiple selections per passenger.
   - Limited meal choices to valid, restricted Salesforce picklist options: `Vegetarian`, `Non-Veg`, `Vegan`, and `Jain`.
   - Joined multi-selected values with a comma separator in the `bookingConfirmation` view screen (e.g., `Vegetarian, Vegan`), defaulting to `None` if empty.
2. **Exhaustive Per-Passenger Validation**:
   - The validation routine now evaluates all passenger sub-forms completely instead of terminating early at the first invalid record.
   - Displays clear, individual error messages inside the specific passenger card container that failed validation.
3. **Visual SLDS Error Highlighting**:
   - Dynamically highlights invalid passenger sub-forms with orange/red borders, warm warning backgrounds, and orange drop shadows.
   - Live-clears card error states once the user edits/corrects any field inside that specific traveler card.

### Validation Results
- Deployed components and backend service metadata successfully to target org.
- Ran all related unit tests: **100% Passed (14/14 tests)**.
- **Outcome**: Pass.

---

## Sprint 7 Patch - My Bookings Dashboard Enhancement

### Summary of Changes
- Updated `BookingSearchService.cls` queries to fetch `Seat_Class__c`, `Flight__r.Airline_Name__c`, `Flight__r.Origin_Airport__c`, `Flight__r.Destination_Airport__c`, and `Flight__r.Departure_DateTime__c`.
- Removed `cacheable=true` from `getConfirmedBookingsByAgent` in `BookingSearchService.cls` to ensure that data fetches hit the database live and reflect cancellations/updates immediately.
- Refactored `myBookingsDashboard` LWC to support tabset scoped filters: **All**, **Upcoming**, **Past**, and **Cancelled**.
- Implemented client-side filtering and sorting composition: `bookings` (raw list) -> `filteredBookings` (tab select) -> `sortedBookings` (sort and details text/badge formatting).
- Updated row rendering template to display the flight route, airline name, actual departure date, and seat class.
- Added a disabled "Download Itinerary" action button inside `bookingDetailView` header toolbar for visibility.
- Expanded assertions in `BookingSearchServiceTest.cls` to cover relationship properties and Draft status exclusion.

### Validation Results
- Deployed files successfully to the org.
- Ran all unit tests (105/105 tests passed with 100% success rate).
- **Outcome**: Pass.

---

## My Bookings Dashboard Tab Fix

### Root Cause
- Standard LWC `lightning-tabset` custom select event wraps the selected value inside `event.detail.value` rather than standard `event.target.value`. 
- Accessing `event.target.value` evaluated to `undefined`, resulting in the `activeTab` value resetting to `undefined` and displaying the full bookings list regardless of the clicked tab.

### Changes Made
- Updated `handleTabSelect(event)` in `myBookingsDashboard.js` to assign `this.activeTab = event.detail.value;` which resolves the correct tab selection state.
- Deployed the components and ran the full suite. All 105 tests pass successfully.

### Outcome
- Passed (105/105 tests successful).

---

## Specification 13.6 — Cancellation & Refund Dashboard LMS Subscriber Integration

### Summary of Changes
- Integrated Lightning Message Service (LMS) subscription in `agentDashboard` LWC component.
- Imported `subscribe`, `unsubscribe`, `APPLICATION_SCOPE`, and `MessageContext` from `lightning/messageService`.
- Wired the message context and registered the subscription to `SkyBook_Channel__c` message channel using `APPLICATION_SCOPE`.
- Programmed subscription cleanup inside `disconnectedCallback` to prevent event listener memory leaks.
- Registered message callback handler that calls `this.loadDashboardData()` reactively when a message is received with status `'Cancelled'`.

### Validation Results
- Deployed files successfully to the org.
- Ran all unit tests (105/105 tests passed with 100% success rate).
- **Outcome**: Pass.

---

## Specification 13.7 — Agent Dashboard Metrics & Actions

### Summary of Changes
- Refactored `DashboardController.cls` to filter metrics contextually by the logged-in agent: `User__c = :UserInfo.getUserId()`.
- Implemented and mapped new KPI metric values:
  * **Today's Bookings**: Count of bookings made by the active agent today.
  * **Today's Revenue**: Sum of confirmed booking total amounts made by the active agent today (excluding Cancelled/Refunded).
  * **Pending Group Approvals**: Dynamic count of active agent group bookings pending approval.
  * **Active Cancellation Cases**: Dynamic count of refunds in progress (`Initiated` or `Processing`) for the agent's bookings.
- Added a **Recent Bookings** section rendering the 10 most recent agent bookings (ordered newest first) directly inside the LWC with navigation links and details trigger buttons.
- Bound `onviewbooking` custom detail navigation in `skyBookApp.html`.
- Added disabled quick action button for "Create Walk-in Booking (Coming Soon)".
- Implemented LWC Jest tests under `force-app/main/default/lwc/agentDashboard/__tests__/agentDashboard.test.js` validating metrics rendering, action redirects, event dispatches, and message service subscription behaviors.
- Added unit tests in `DashboardControllerTest.cls` verifying manager hierarchy approvals, ownership isolation, status exclusions, and chronological ordering.

### Validation Results
- Deployed files successfully to the org.
- Ran all unit tests (106/106 tests passed with 100% success rate).
- **Outcome**: Pass.
