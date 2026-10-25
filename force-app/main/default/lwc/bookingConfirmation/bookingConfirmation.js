import { LightningElement, api, track } from 'lwc';
import createBookingWithPassengers from '@salesforce/apex/BookingService.createBookingWithPassengers';
import { formatCurrency, formatDateTime } from 'c/skyBookUtils';

export default class BookingConfirmation extends LightningElement {
    @api selectedFlight;
    @api passengerCount = 1;
    @api passengers = [];
    @api cabinClass = 'economy';

    @track contactId = '';
    @track termsAccepted = false;
    @track loading = false;
    @track errorMessage = '';

    get displayPassengerCount() {
        return this.passengerCount;
    }

    get formattedPassengers() {
        if (!this.passengers) {
            return [];
        }
        return this.passengers.map(p => {
            let meals = 'None';
            if (p.mealPreference && Array.isArray(p.mealPreference) && p.mealPreference.length > 0) {
                meals = p.mealPreference.join(', ');
            } else if (typeof p.mealPreference === 'string' && p.mealPreference !== 'None' && p.mealPreference !== '') {
                meals = p.mealPreference;
            }
            return {
                ...p,
                formattedMeals: meals
            };
        });
    }

    get routeText() {
        return this.selectedFlight ? `${this.selectedFlight.origin} → ${this.selectedFlight.destination}` : '';
    }

    get airlineName() {
        return this.selectedFlight ? this.selectedFlight.airline : '';
    }

    get flightNumber() {
        return this.selectedFlight ? this.selectedFlight.flightNumber : '';
    }

    get pricePerPassenger() {
        return this.selectedFlight && this.passengerCount ? this.selectedFlight.price / this.passengerCount : 0;
    }

    get totalAmount() {
        return this.selectedFlight ? this.selectedFlight.price : 0;
    }

    get formattedPricePerPassenger() {
        const currencyCode = this.selectedFlight ? this.selectedFlight.currencyIsoCode : 'USD';
        return formatCurrency(this.pricePerPassenger, currencyCode);
    }

    get formattedTotalAmount() {
        const currencyCode = this.selectedFlight ? this.selectedFlight.currencyIsoCode : 'USD';
        return formatCurrency(this.totalAmount, currencyCode);
    }

    get formattedTaxes() {
        const currencyCode = this.selectedFlight ? this.selectedFlight.currencyIsoCode : 'USD';
        return formatCurrency(0.00, currencyCode);
    }

    get formattedDepartureTime() {
        return this.selectedFlight ? formatDateTime(this.selectedFlight.departureTime) : '';
    }

    get formattedArrivalTime() {
        return this.selectedFlight ? formatDateTime(this.selectedFlight.arrivalTime) : '';
    }

    get isCreateDisabled() {
        return !this.termsAccepted || !this.contactId || this.loading;
    }

    handleContactChange(event) {
        this.contactId = event.detail.recordId;
        this.errorMessage = '';
    }

    handleTermsChange(event) {
        this.termsAccepted = event.target.checked;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('backtopassengers'));
    }

    handleConfirm() {
        if (!this.contactId) {
            this.errorMessage = 'Please select a primary booking contact.';
            return;
        }

        this.loading = true;
        this.errorMessage = '';

        createBookingWithPassengers({
            contactId: this.contactId,
            offer: this.selectedFlight,
            seats: parseInt(this.passengerCount, 10),
            seatClass: this.cabinClass,
            passengers: this.passengers
        })
        .then(result => {
            this.dispatchEvent(new CustomEvent('bookingcreated', {
                detail: {
                    bookingId: result.Id,
                    bookingRef: result.Name
                }
            }));
        })
        .catch(error => {
            console.error('Booking creation failed:', error);
            this.errorMessage = 'Booking creation failed: ' + (error.body ? error.body.message : error.message);
        })
        .finally(() => {
            this.loading = false;
        });
    }
}
