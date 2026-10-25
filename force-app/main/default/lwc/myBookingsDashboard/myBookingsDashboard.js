import { LightningElement, track, api } from 'lwc';
import currentUserId from '@salesforce/user/Id';
import getConfirmedBookingsByAgent from '@salesforce/apex/BookingSearchService.getConfirmedBookingsByAgent';
import searchPassengersAndBookings from '@salesforce/apex/BookingSearchService.searchPassengersAndBookings';
import { formatCurrency, formatDateTime } from 'c/skyBookUtils';

export default class MyBookingsDashboard extends LightningElement {
    @track searchKey = '';
    @track bookings = [];
    @track loading = false;
    @track sortByDateAsc = false;
    @track activeTab = 'all';

    connectedCallback() {
        this.loadAgentBookings();
    }

    loadAgentBookings() {
        this.loading = true;
        getConfirmedBookingsByAgent({ userId: currentUserId })
        .then(result => {
            this.bookings = result || [];
        })
        .catch(error => {
            console.error('Failed to load bookings:', error);
        })
        .finally(() => {
            this.loading = false;
        });
    }

    handleTabSelect(event) {
        event.preventDefault();
        const val = event.currentTarget.dataset.value;
        console.log('[DEBUG Dashboard] handleTabSelect value:', val);
        this.activeTab = val;
        console.log('[DEBUG Dashboard] activeTab updated to:', this.activeTab);
    }

    get tabClassAll() {
        return this.activeTab === 'all' ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }

    get tabClassUpcoming() {
        return this.activeTab === 'upcoming' ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }

    get tabClassPast() {
        return this.activeTab === 'past' ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }

    get tabClassCancelled() {
        return this.activeTab === 'cancelled' ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }

    get hasBookings() {
        return this.sortedBookings.length > 0;
    }

    get bookingsCount() {
        return this.sortedBookings.length;
    }

    get sortLabel() {
        return this.sortByDateAsc ? 'Date: Oldest First ➔' : 'Date: Newest First ➔';
    }

    get filteredBookings() {
        const today = new Date();
        console.log('[DEBUG Dashboard] filteredBookings calculation: activeTab =', this.activeTab, ', source count =', this.bookings.length);
        const result = this.bookings.filter(bk => {
            if (this.activeTab === 'cancelled') {
                return bk.Booking_Status__c === 'Cancelled';
            }
            // For non-cancelled tabs, exclude cancelled records
            if (bk.Booking_Status__c === 'Cancelled') {
                return false;
            }
            const depTimeStr = bk.Flight__r && bk.Flight__r.Departure_DateTime__c ? bk.Flight__r.Departure_DateTime__c : null;
            const depTime = depTimeStr ? new Date(depTimeStr) : null;
            
            if (this.activeTab === 'upcoming') {
                return depTime && depTime >= today;
            }
            if (this.activeTab === 'past') {
                return !depTime || depTime < today;
            }
            return true; // 'all' tab
        });
        console.log('[DEBUG Dashboard] filteredBookings result count =', result.length, ', statuses =', result.map(b => b.Booking_Status__c));
        return result;
    }

    get sortedBookings() {
        let items = [...this.filteredBookings];
        items.sort((a, b) => {
            const dateA = new Date(a.Booking_Date__c || 0);
            const dateB = new Date(b.Booking_Date__c || 0);
            return this.sortByDateAsc ? (dateA - dateB) : (dateB - dateA);
        });

        // Add formatted presentation properties to each record
        return items.map(bk => {
            let badgeClass = 'slds-badge ';
            if (bk.Booking_Status__c === 'Confirmed') {
                badgeClass += 'slds-badge_lightest slds-m-around_none';
            } else if (bk.Booking_Status__c === 'Draft') {
                badgeClass += 'slds-theme_warning';
            } else if (bk.Booking_Status__c === 'Cancelled') {
                badgeClass += 'slds-theme_error';
            } else {
                badgeClass += 'slds-theme_neutral';
            }

            let origin = bk.Flight__r && bk.Flight__r.Origin_Airport__c ? bk.Flight__r.Origin_Airport__c : '';
            let destination = bk.Flight__r && bk.Flight__r.Destination_Airport__c ? bk.Flight__r.Destination_Airport__c : '';
            let airline = bk.Flight__r && bk.Flight__r.Airline_Name__c ? bk.Flight__r.Airline_Name__c : 'N/A';

            return {
                ...bk,
                routeText: origin && destination ? `${origin} → ${destination}` : 'N/A',
                airlineText: airline,
                formattedDeparture: bk.Flight__r && bk.Flight__r.Departure_DateTime__c ? formatDateTime(bk.Flight__r.Departure_DateTime__c) : 'N/A',
                formattedAmount: formatCurrency(bk.Total_Amount__c, 'USD'),
                badgeClass: badgeClass
            };
        });
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;

        if (this.searchKey.trim().length >= 2) {
            this.loading = true;
            searchPassengersAndBookings({ searchTerm: this.searchKey })
            .then(result => {
                this.bookings = result ? result.bookings : [];
            })
            .catch(error => {
                console.error('Search error:', error);
            })
            .finally(() => {
                this.loading = false;
            });
        } else if (this.searchKey.trim().length === 0) {
            this.loadAgentBookings();
        }
    }

    handleRefresh() {
        this.searchKey = '';
        this.loadAgentBookings();
    }

    handleClearSearch() {
        this.searchKey = '';
        this.loadAgentBookings();
    }

    toggleSort() {
        this.sortByDateAsc = !this.sortByDateAsc;
    }

    handleViewDetails(event) {
        const bookingId = event.target.dataset.id;
        this.dispatchEvent(new CustomEvent('viewbooking', {
            detail: bookingId
        }));
    }
}
