import { LightningElement, track, wire } from 'lwc';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import CANCELLATION_CHANNEL from '@salesforce/messageChannel/SkyBook_Channel__c';
import getDashboardData from '@salesforce/apex/DashboardController.getDashboardData';
import { formatCurrency, formatDateTime } from 'c/skyBookUtils';

export default class AgentDashboard extends LightningElement {
    @track metrics = null;
    @track loading = false;
    subscription = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.loadDashboardData();
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (this.subscription) {
            return;
        }
        this.subscription = subscribe(
            this.messageContext,
            CANCELLATION_CHANNEL,
            (message) => this.handleMessage(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    handleMessage(message) {
        console.log('[DEBUG AgentDashboard] Received LMS message:', message);
        if (message && message.status === 'Cancelled') {
            console.log('[DEBUG AgentDashboard] Valid cancellation event received. Refreshing metrics...');
            this.loadDashboardData();
        }
    }

    loadDashboardData() {
        this.loading = true;
        getDashboardData()
            .then(result => {
                this.metrics = result;
            })
            .catch(error => {
                console.error('Error loading dashboard data:', error);
            })
            .finally(() => {
                this.loading = false;
            });
    }

    get totalCount() {
        return this.metrics ? this.metrics.totalBookings : 0;
    }

    get confirmedCount() {
        return this.metrics ? this.metrics.confirmedBookings : 0;
    }

    get cancelledCount() {
        return this.metrics ? this.metrics.cancelledBookings : 0;
    }

    get draftCount() {
        return this.metrics ? this.metrics.draftBookings : 0;
    }

    get formattedRevenue() {
        const rev = this.metrics ? this.metrics.totalRevenue : 0.0;
        return formatCurrency(rev, 'USD');
    }

    get hasMonthlyRevenue() {
        return this.metrics && this.metrics.monthlyRevenue && this.metrics.monthlyRevenue.length > 0;
    }

    get monthlyRevenue() {
        if (!this.metrics || !this.metrics.monthlyRevenue) {
            return [];
        }
        return this.metrics.monthlyRevenue.map(item => ({
            ...item,
            formattedRevenue: formatCurrency(item.revenue, 'USD'),
            progressStyle: `width: ${item.percent}%; background-color: #1b3a4b;`
        }));
    }

    get hasUpcomingFlights() {
        return this.metrics && this.metrics.upcomingFlights && this.metrics.upcomingFlights.length > 0;
    }

    get upcomingFlights() {
        if (!this.metrics || !this.metrics.upcomingFlights) {
            return [];
        }
        return this.metrics.upcomingFlights.map(fl => ({
            ...fl,
            formattedDeparture: fl.Departure_DateTime__c ? formatDateTime(fl.Departure_DateTime__c) : 'N/A'
        }));
    }

    get todayBookingsCount() {
        return this.metrics ? this.metrics.todayBookingsCount : 0;
    }

    get formattedTodayRevenue() {
        const rev = this.metrics ? this.metrics.todayRevenue : 0.0;
        return formatCurrency(rev, 'USD');
    }

    get pendingGroupApprovals() {
        return this.metrics ? this.metrics.pendingGroupApprovals : 0;
    }

    get activeCancellationCases() {
        return this.metrics ? this.metrics.activeCancellationCases : 0;
    }

    get recentBookings() {
        if (!this.metrics || !this.metrics.recentBookings) {
            return [];
        }
        return this.metrics.recentBookings.map(b => {
            const departureTimeStr = b.Flight__r && b.Flight__r.Departure_DateTime__c ? b.Flight__r.Departure_DateTime__c : null;
            return {
                ...b,
                formattedDate: b.Booking_Date__c ? new Date(b.Booking_Date__c).toLocaleDateString() : 'N/A',
                formattedAmount: formatCurrency(b.Total_Amount__c || 0, 'USD'),
                flightRoute: b.Flight__r ? `${b.Flight__r.Airline_Name__c} (${b.Flight__r.Origin_Airport__c} ➔ ${b.Flight__r.Destination_Airport__c})` : 'N/A',
                formattedDeparture: departureTimeStr ? formatDateTime(departureTimeStr) : 'N/A',
                badgeClass: this.getBadgeClass(b.Booking_Status__c)
            };
        });
    }

    get hasRecentBookings() {
        return this.metrics && this.metrics.recentBookings && this.metrics.recentBookings.length > 0;
    }

    getBadgeClass(status) {
        if (status === 'Confirmed') {
            return 'slds-badge slds-theme_success slds-m-left_xx-small';
        } else if (status === 'Cancelled') {
            return 'slds-badge slds-theme_error slds-m-left_xx-small';
        }
        return 'slds-badge slds-theme_warning slds-m-left_xx-small';
    }

    handleSearchRedirect() {
        this.dispatchEvent(new CustomEvent('searchflight'));
    }

    handleViewBookings() {
        this.dispatchEvent(new CustomEvent('viewbookings'));
    }

    handleViewBooking(event) {
        event.preventDefault();
        const bookingId = event.currentTarget.dataset.id;
        console.log('[DEBUG AgentDashboard] Dispatching viewbooking for ID:', bookingId);
        this.dispatchEvent(new CustomEvent('viewbooking', {
            detail: bookingId
        }));
    }
}
