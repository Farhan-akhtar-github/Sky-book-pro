import { LightningElement, api, track } from 'lwc';
import getBookingDetail from '@salesforce/apex/BookingDetailController.getBookingDetail';
import { formatCurrency, formatDateTime } from 'c/skyBookUtils';

export default class BookingDetailView extends LightningElement {
    @api bookingId;
    @track booking = null;
    @track passengerDetails = [];
    @track flightSegments = [];
    @track refunds = [];
    @track loading = false;
    @track errorMessage = '';
    @track showCancelModal = false;

    connectedCallback() {
        this.fetchBookingDetails();
    }

    fetchBookingDetails() {
        this.loading = true;
        this.errorMessage = '';
        getBookingDetail({ bookingId: this.bookingId })
        .then(result => {
            if (result) {
                this.booking = result.booking;
                this.passengerDetails = (result.passengerDetails || []).map(p => ({
                    ...p,
                    formattedDob: p.Date_of_Birth__c ? new Date(p.Date_of_Birth__c).toLocaleDateString() : 'N/A',
                    formattedMeal: p.Meal_Preference__c ? p.Meal_Preference__c.split(';').join(', ') : 'None'
                }));
                this.flightSegments = (result.flightSegments || []).map(seg => ({
                    ...seg,
                    formattedDeparture: seg.Departure_DateTime__c ? formatDateTime(seg.Departure_DateTime__c) : 'N/A'
                }));
                this.refunds = result.refunds || [];
            } else {
                this.errorMessage = 'Booking details could not be loaded.';
            }
        })
        .catch(error => {
            console.error('Error fetching booking details:', error);
            this.errorMessage = 'Error loading details: ' + (error.body ? error.body.message : error.message);
        })
        .finally(() => {
            this.loading = false;
        });
    }

    get bookingRef() {
        return this.booking ? this.booking.Name : '';
    }

    get bookingStatus() {
        return this.booking ? this.booking.Booking_Status__c : '';
    }

    get formattedBookingDate() {
        return this.booking && this.booking.Booking_Date__c 
            ? new Date(this.booking.Booking_Date__c).toLocaleDateString() 
            : '';
    }

    get flightRoute() {
        return this.booking && this.booking.Flight__r 
            ? `${this.booking.Flight__r.Origin_Airport__c} → ${this.booking.Flight__r.Destination_Airport__c}` 
            : '';
    }

    get airlineName() {
        return this.booking && this.booking.Flight__r ? this.booking.Flight__r.Airline_Name__c : '';
    }

    get flightNumber() {
        return this.booking && this.booking.Flight__r ? this.booking.Flight__r.Flight_Number__c : '';
    }

    get cabinClass() {
        return this.booking ? this.booking.Seat_Class__c : '';
    }

    get numberOfSeats() {
        return this.booking ? this.booking.Number_of_Seats__c : 0;
    }

    get paymentRef() {
        return this.booking ? this.booking.Payment_Reference__c : '';
    }

    get formattedDepartureTime() {
        return this.booking && this.booking.Flight__r ? formatDateTime(this.booking.Flight__r.Departure_DateTime__c) : '';
    }

    get formattedArrivalTime() {
        return this.booking && this.booking.Flight__r ? formatDateTime(this.booking.Flight__r.Arrival_DateTime__c) : '';
    }

    get formattedBaseFare() {
        return formatCurrency(this.booking ? this.booking.Base_Fare__c : 0, 'USD');
    }

    get formattedTaxes() {
        return formatCurrency(this.booking ? this.booking.Taxes_Fees__c : 0, 'USD');
    }

    get formattedTotalAmount() {
        return formatCurrency(this.booking ? this.booking.Total_Amount__c : 0, 'USD');
    }

    get canCancel() {
        return this.bookingStatus && this.bookingStatus !== 'Cancelled';
    }

    get hasSegments() {
        return this.flightSegments.length > 0;
    }

    get statusBadgeClass() {
        let badgeClass = 'slds-badge ';
        const status = this.bookingStatus;
        if (status === 'Confirmed') {
            badgeClass += 'slds-badge_lightest slds-m-around_none';
        } else if (status === 'Draft') {
            badgeClass += 'slds-theme_warning';
        } else if (status === 'Cancelled') {
            badgeClass += 'slds-theme_error';
        } else {
            badgeClass += 'slds-theme_neutral';
        }
        return badgeClass;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('backtobookings'));
    }

    handleCancelTrigger() {
        this.showCancelModal = true;
    }

    closeCancelModal() {
        this.showCancelModal = false;
    }

    handleCancellationSuccess() {
        this.showCancelModal = false;
        this.fetchBookingDetails(); // Refresh booking state

        const tracker = this.template.querySelector('c-refund-status-tracker');
        if (tracker) {
            tracker.refresh();
        }
    }
}
