import { LightningElement, api, track } from 'lwc';
import { formatDateTime, formatDuration, formatCurrency } from 'c/skyBookUtils';

export default class FlightResultCard extends LightningElement {
    @api offer;
    @track imageFailed = false;

    connectedCallback() {
        console.log('[DEBUG flightResultCard] Flight result card instantiated for offer ID:', this.offer ? this.offer.offerId : 'undefined');
    }

    get airlineName() {
        return this.offer ? this.offer.airline : 'N/A';
    }

    get logoUrl() {
        if (this.imageFailed) {
            return null;
        }
        return this.offer && this.offer.logoUrl ? this.offer.logoUrl : null;
    }

    handleImageError() {
        this.imageFailed = true;
    }

    get flightNumber() {
        return this.offer ? this.offer.flightNumber : '–';
    }

    get origin() {
        return this.offer ? this.offer.origin : '';
    }

    get destination() {
        return this.offer ? this.offer.destination : '';
    }

    get formattedDepartureTime() {
        return this.offer ? formatDateTime(this.offer.departureTime) : '';
    }

    get formattedArrivalTime() {
        return this.offer ? formatDateTime(this.offer.arrivalTime) : '';
    }

    get formattedDuration() {
        return this.offer ? formatDuration(this.offer.duration) : '0m';
    }

    get formattedPrice() {
        return this.offer ? formatCurrency(this.offer.price, this.offer.currencyIsoCode) : '';
    }

    get formattedCabinClass() {
        if (!this.offer || !this.offer.cabinClass) return '';
        const cabin = this.offer.cabinClass.toLowerCase();
        if (cabin === 'economy') return 'Economy';
        if (cabin === 'premium_economy') return 'Premium Economy';
        if (cabin === 'business') return 'Business';
        if (cabin === 'first' || cabin === 'first_class') return 'First Class';
        return this.offer.cabinClass;
    }

    get seatsText() {
        const count = this.offer && this.offer.seatsAvailable !== undefined ? this.offer.seatsAvailable : 9;
        return `${count} seat(s) left`;
    }

    handleSelectOffer() {
        this.dispatchEvent(new CustomEvent('offerselected', {
            detail: this.offer
        }));
    }
}
