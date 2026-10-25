import { LightningElement, track } from 'lwc';
import { SCREENS } from 'c/skyBookUtils';
import searchFlights from '@salesforce/apex/DuffelFlightSearchService.searchFlights';

export default class SkyBookApp extends LightningElement {
    @track currentScreen = SCREENS.AGENT_DASHBOARD;
    @track flightOffers = [];
    @track selectedFlight = null;
    
    // Form and Booking parameters
    @track passengerCount = 1;
    @track cabinClass = 'economy';
    @track passengers = [];
    
    // Outputs
    @track bookingId = '';
    @track bookingRef = '';
    @track viewingBookingId = '';
    
    // Global UI state
    @track loading = false;
    @track errorMessage = '';
    @track successMessage = '';

    // Screen conditional checkers
    get isAgentDashboard() {
        return this.currentScreen === SCREENS.AGENT_DASHBOARD;
    }

    get isFlightSearch() {
        return this.currentScreen === SCREENS.FLIGHT_SEARCH;
    }

    get isFlightResults() {
        return this.currentScreen === SCREENS.FLIGHT_RESULTS;
    }

    get isPassengerDetails() {
        return this.currentScreen === SCREENS.PASSENGER_DETAILS;
    }

    get isBookingConfirm() {
        return this.currentScreen === SCREENS.BOOKING_CONFIRM;
    }

    get isBookingSuccess() {
        return this.currentScreen === SCREENS.BOOKING_SUCCESS;
    }

    get isMyBookings() {
        return this.currentScreen === SCREENS.MY_BOOKINGS;
    }

    get isBookingDetail() {
        return this.currentScreen === SCREENS.BOOKING_DETAIL;
    }

    get isInternationalFlight() {
        return this.selectedFlight ? this.selectedFlight.isInternational : false;
    }

    // Active Navigation Highlighting Class Getters
    get dashboardNavClass() {
        return this.navClassFor(SCREENS.AGENT_DASHBOARD);
    }

    get searchNavClass() {
        return this.navClassFor(SCREENS.FLIGHT_SEARCH, [
            SCREENS.FLIGHT_RESULTS,
            SCREENS.PASSENGER_DETAILS,
            SCREENS.BOOKING_CONFIRM,
            SCREENS.BOOKING_SUCCESS
        ]);
    }

    get bookingsNavClass() {
        return this.navClassFor(SCREENS.MY_BOOKINGS, [SCREENS.BOOKING_DETAIL]);
    }

    navClassFor(screen, altScreens = []) {
        const isActive = this.currentScreen === screen || altScreens.includes(this.currentScreen);
        return isActive 
            ? 'slds-button slds-m-horizontal_xx-small navigation-btn-active' 
            : 'slds-button slds-m-horizontal_xx-small navigation-btn-inactive';
    }

    // Navigation triggers
    navigateToDashboard() {
        this.clearMessages();
        this.currentScreen = SCREENS.AGENT_DASHBOARD;
    }

    navigateToSearch() {
        this.clearMessages();
        this.flightOffers = [];
        this.selectedFlight = null;
        this.passengers = [];
        this.bookingId = '';
        this.bookingRef = '';
        this.currentScreen = SCREENS.FLIGHT_SEARCH;
    }

    navigateToMyBookings() {
        this.clearMessages();
        this.currentScreen = SCREENS.MY_BOOKINGS;
    }

    navigateToResults() {
        this.clearMessages();
        this.currentScreen = SCREENS.FLIGHT_RESULTS;
    }

    navigateToPassengers() {
        this.clearMessages();
        this.currentScreen = SCREENS.PASSENGER_DETAILS;
    }

    // Event Handlers
    handleFlightSearch(event) {
        this.clearMessages();
        this.loading = true;
        
        const { origin, destination, departureDate, passengerCount, cabinClass } = event.detail;
        this.passengerCount = passengerCount;
        this.cabinClass = cabinClass;

        searchFlights({
            origin: origin,
            destination: destination,
            departureDate: departureDate,
            passengerCount: passengerCount,
            cabinClass: cabinClass
        })
        .then(result => {
            console.log('[DEBUG skyBookApp] Number of offers returned from Apex:', result ? result.length : 0);
            this.flightOffers = result;
            console.log('[DEBUG skyBookApp] Number of offers assigned to property:', this.flightOffers ? this.flightOffers.length : 0);
            this.currentScreen = SCREENS.FLIGHT_RESULTS;
            if (this.flightOffers.length === 0) {
                this.errorMessage = 'No flights found for this route and date.';
            } else {
                this.successMessage = `Found ${this.flightOffers.length} available flight offer(s).`;
            }
        })
        .catch(error => {
            console.error('Search error:', error);
            this.errorMessage = 'Search failed: ' + (error.body ? error.body.message : error.message);
            this.flightOffers = [];
        })
        .finally(() => {
            this.loading = false;
        });
    }

    handleOfferSelected(event) {
        this.clearMessages();
        this.selectedFlight = event.detail;
        this.currentScreen = SCREENS.PASSENGER_DETAILS;
    }

    handlePassengersSubmit(event) {
        this.clearMessages();
        this.passengers = event.detail;
        this.currentScreen = SCREENS.BOOKING_CONFIRM;
    }

    handleBookingCreated(event) {
        this.clearMessages();
        const { bookingId, bookingRef } = event.detail;
        this.bookingId = bookingId;
        this.bookingRef = bookingRef;
        this.currentScreen = SCREENS.BOOKING_SUCCESS;
        this.successMessage = `Booking created successfully! Reference: ${bookingRef}`;
    }

    handleViewBooking(event) {
        this.clearMessages();
        this.viewingBookingId = event.detail;
        this.currentScreen = SCREENS.BOOKING_DETAIL;
    }

    // Banner Utilities
    clearError() {
        this.errorMessage = '';
    }

    clearSuccess() {
        this.successMessage = '';
    }

    clearMessages() {
        this.errorMessage = '';
        this.successMessage = '';
    }
}
