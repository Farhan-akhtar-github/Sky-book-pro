import { LightningElement, api, track } from 'lwc';
import { formatCurrency } from 'c/skyBookUtils';

export default class FlightResultsList extends LightningElement {
    @track _flightOffers = [];
    @track sortBy = 'price_asc';
    @track filterAirline = 'All';
    @track filterMaxPrice = null;

    @api
    get flightOffers() {
        return this._flightOffers;
    }
    set flightOffers(value) {
        console.log('[DEBUG flightResultsList] Number of offers passed to flightResultsList:', value ? value.length : 0);
        this._flightOffers = value || [];
        this.resetFilters();
    }

    get sortOptions() {
        return [
            { label: 'Price: Low to High', value: 'price_asc' },
            { label: 'Price: High to Low', value: 'price_desc' },
            { label: 'Duration: Shortest First', value: 'duration_asc' },
            { label: 'Departure: Earliest First', value: 'departure_asc' }
        ];
    }

    get airlineOptions() {
        const airlines = new Set();
        this._flightOffers.forEach(offer => {
            if (offer.airline) {
                airlines.add(offer.airline);
            }
        });
        const options = [{ label: 'All Airlines', value: 'All' }];
        Array.from(airlines).sort().forEach(airline => {
            options.push({ label: airline, value: airline });
        });
        return options;
    }

    get minPrice() {
        if (this._flightOffers.length === 0) return 0;
        const prices = this._flightOffers.map(o => o.price);
        return Math.floor(Math.min(...prices));
    }

    get maxPrice() {
        if (this._flightOffers.length === 0) return 1000;
        const prices = this._flightOffers.map(o => o.price);
        return Math.ceil(Math.max(...prices));
    }

    get maxPriceLabel() {
        const priceVal = this.filterMaxPrice !== null ? this.filterMaxPrice : this.maxPrice;
        const currencyCode = this._flightOffers.length > 0 ? this._flightOffers[0].currencyIsoCode : 'USD';
        return `Max Price: ${formatCurrency(priceVal, currencyCode)}`;
    }

    get totalCount() {
        return this._flightOffers.length;
    }

    get displayCountText() {
        const processedCount = this.processedOffers.length;
        if (processedCount === this.totalCount) {
            return `Showing all results`;
        }
        return `Showing ${processedCount} of ${this.totalCount} results`;
    }

    get hasOffers() {
        return this._flightOffers.length > 0;
    }

    get hasProcessedOffers() {
        return this.processedOffers.length > 0;
    }

    get isFiltersClear() {
        return this.sortBy === 'price_asc' && 
               this.filterAirline === 'All' && 
               (this.filterMaxPrice === null || this.filterMaxPrice === this.maxPrice);
    }

    get processedOffers() {
        let results = [...this._flightOffers];
        console.log('[DEBUG flightResultsList] processedOffers initial count:', results.length);

        // 1. Apply Airline Filter
        if (this.filterAirline !== 'All') {
            results = results.filter(offer => offer.airline === this.filterAirline);
        }

        // 2. Apply Max Price Filter
        if (this.filterMaxPrice !== null && this.filterMaxPrice !== undefined) {
            results = results.filter(offer => offer.price <= this.filterMaxPrice);
        }

        // 3. Apply Sorting
        if (this.sortBy === 'price_asc') {
            results.sort((a, b) => a.price - b.price);
        } else if (this.sortBy === 'price_desc') {
            results.sort((a, b) => b.price - a.price);
        } else if (this.sortBy === 'duration_asc') {
            results.sort((a, b) => a.duration - b.duration);
        } else if (this.sortBy === 'departure_asc') {
            results.sort((a, b) => new Date(a.departureTime) - new Date(b.departureTime));
        }

        console.log('[DEBUG flightResultsList] Number of offers rendered (after filters):', results.length);
        return results;
    }

    handleSortChange(event) {
        this.sortBy = event.target.value;
    }

    handleAirlineChange(event) {
        this.filterAirline = event.target.value;
    }

    handleMaxPriceChange(event) {
        this.filterMaxPrice = parseFloat(event.target.value);
    }

    handleClearFilters() {
        this.resetFilters();
    }

    resetFilters() {
        this.sortBy = 'price_asc';
        this.filterAirline = 'All';
        this.filterMaxPrice = this.maxPrice;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('backtosearch'));
    }

    handleOfferSelected(event) {
        this.dispatchEvent(new CustomEvent('offerselected', {
            detail: event.detail
        }));
    }
}
