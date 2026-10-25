import { LightningElement, api } from 'lwc';
import { formatDateTime } from 'c/skyBookUtils';

export default class BookingSuccess extends LightningElement {
    @api bookingId;
    @api bookingRef;
    @api selectedFlight;
    @api passengerCount = 1;

    get routeText() {
        return this.selectedFlight ? `${this.selectedFlight.origin} → ${this.selectedFlight.destination}` : '';
    }

    get airlineName() {
        return this.selectedFlight ? this.selectedFlight.airline : '';
    }

    get flightNumber() {
        return this.selectedFlight ? this.selectedFlight.flightNumber : '';
    }

    get formattedDepartureTime() {
        return this.selectedFlight ? formatDateTime(this.selectedFlight.departureTime) : '';
    }

    get displayPassengerCount() {
        return this.passengerCount;
    }

    handleSearchAgain() {
        this.dispatchEvent(new CustomEvent('searchagain'));
    }

    handleViewDetails() {
        this.dispatchEvent(new CustomEvent('viewdetails', {
            detail: this.bookingId
        }));
    }

    handleViewDashboard() {
        this.dispatchEvent(new CustomEvent('viewdashboard'));
    }
}
