import { LightningElement, api, track } from 'lwc';
import { PASSENGER_TYPES } from 'c/skyBookUtils';

export default class PassengerDetailsForm extends LightningElement {
    @track _passengerCount = 1;
    @api isInternational = false;
    @track travelers = [];
    @track validationError = '';

    @api
    get passengerCount() {
        return this._passengerCount;
    }
    set passengerCount(value) {
        this._passengerCount = parseInt(value, 10) || 1;
        this.initializeTravelers();
    }

    initializeTravelers() {
        const list = [];
        for (let i = 0; i < this._passengerCount; i++) {
            list.push({
                index: i,
                displayNumber: i + 1,
                key: `traveler-${i}`,
                firstName: '',
                lastName: '',
                dob: '',
                passengerType: 'Adult',
                passport: '',
                mealPreference: [],
                hasError: false,
                errorMessage: ''
            });
        }
        this.travelers = list;
    }

    get travelersWithClasses() {
        return this.travelers.map(t => {
            let cardStyle = "border: 1px solid #e2e8f0; border-radius: 8px; background: #f8fafc;";
            if (t.hasError) {
                cardStyle = "border: 2px solid #ea580c; border-radius: 8px; background: #fff7ed; box-shadow: 0 0 8px rgba(234,88,12,0.15);";
            }
            return {
                ...t,
                cardStyle: cardStyle,
                cardHeaderStyle: t.hasError ? "font-weight: 700; color: #ea580c; border-bottom: 1px solid #fed7aa; padding-bottom: 8px;" : "font-weight: 700; color: #1b3a4b; border-bottom: 1px solid #e2e8f0; padding-bottom: 8px;"
            };
        });
    }

    get passengerTypeOptions() {
        return PASSENGER_TYPES;
    }

    get mealPreferenceOptions() {
        return [
            { label: 'Vegetarian', value: 'Vegetarian' },
            { label: 'Non-Veg', value: 'Non-Veg' },
            { label: 'Vegan', value: 'Vegan' },
            { label: 'Jain', value: 'Jain' }
        ];
    }

    handleInputChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const field = event.target.name;
        const value = event.target.value;

        this.travelers = this.travelers.map(t => {
            if (t.index === index) {
                return { 
                    ...t, 
                    [field]: value,
                    hasError: false,
                    errorMessage: ''
                };
            }
            return t;
        });
        this.validationError = '';
    }

    @api
    validateAllPassengers() {
        this.validationError = '';
        
        let overallValid = true;
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        this.travelers = this.travelers.map(t => {
            let error = '';
            
            if (!t.firstName || !t.firstName.trim()) {
                error = 'First Name is required.';
            } else if (!t.lastName || !t.lastName.trim()) {
                error = 'Last Name is required.';
            } else if (!t.dob) {
                error = 'Date of Birth is required.';
            } else {
                const dobDate = new Date(t.dob);
                if (dobDate >= today) {
                    error = 'Date of Birth must be in the past.';
                }
            }

            if (!error && this.isInternational && (!t.passport || !t.passport.trim())) {
                error = 'Passport Number is required for international flights.';
            }

            if (error) {
                overallValid = false;
                return { ...t, hasError: true, errorMessage: error };
            }
            return { ...t, hasError: false, errorMessage: '' };
        });

        // Run standard HTML5 reportValidity checks on individual input elements
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-checkbox-group')];
        const allInputsValid = inputs.reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (!overallValid || !allInputsValid) {
            this.validationError = 'Please fix the highlighted errors on the form.';
            return false;
        }

        this.validationError = '';
        return true;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('backtoresults'));
    }

    handleSubmit() {
        if (this.validateAllPassengers()) {
            this.dispatchEvent(new CustomEvent('passengerssubmit', {
                detail: this.travelers
            }));
        }
    }
}
