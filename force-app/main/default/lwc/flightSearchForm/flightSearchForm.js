import { LightningElement, track } from 'lwc';
import { CABIN_CLASSES, getTodayDateString, isFutureDate } from 'c/skyBookUtils';

export default class FlightSearchForm extends LightningElement {
    @track tripType = 'one-way';
    @track cabinClass = 'economy';
    @track adults = 1;
    @track origin = '';
    @track destination = '';
    @track departureDate = getTodayDateString();
    @track returnDate = '';
    @track validationError = '';

    get tripTypeOptions() {
        return [
            { label: 'One-way', value: 'one-way' },
            { label: 'Round-trip', value: 'round-trip' }
        ];
    }

    get cabinClassOptions() {
        return CABIN_CLASSES;
    }

    get isRoundTrip() {
        return this.tripType === 'round-trip';
    }

    get dateColumnClass() {
        return this.isRoundTrip 
            ? 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-m-bottom_medium'
            : 'slds-col slds-size_1-of-1 slds-m-bottom_medium';
    }

    handleChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        this[field] = value;
        this.validationError = ''; // Clear error on change
    }

    handleSearch() {
        this.validationError = '';
        
        // 1. Run standard HTML5 validations
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
        const allValid = inputs.reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (!allValid) {
            this.validationError = 'Please fix the highlighted errors on the form.';
            return;
        }

        // 2. Custom Validations
        const originVal = this.origin.trim().toUpperCase();
        const destVal = this.destination.trim().toUpperCase();

        if (originVal === destVal) {
            this.validationError = 'Origin and Destination airports cannot be the same.';
            return;
        }

        if (parseInt(this.adults, 10) < 1) {
            this.validationError = 'Number of passengers must be at least 1.';
            return;
        }

        if (!isFutureDate(this.departureDate)) {
            this.validationError = 'Departure date must be today or in the future.';
            return;
        }

        if (this.isRoundTrip) {
            if (!this.returnDate) {
                this.validationError = 'Return date is required for a round-trip.';
                return;
            }
            if (new Date(this.returnDate) < new Date(this.departureDate)) {
                this.validationError = 'Return date must be on or after the departure date.';
                return;
            }
        }

        // 3. Dispatch Search Event
        this.dispatchEvent(new CustomEvent('flightsearch', {
            detail: {
                origin: originVal,
                destination: destVal,
                departureDate: this.departureDate,
                returnDate: this.isRoundTrip ? this.returnDate : null,
                passengerCount: parseInt(this.adults, 10),
                cabinClass: this.cabinClass,
                tripType: this.tripType
            }
        }));
    }
}
