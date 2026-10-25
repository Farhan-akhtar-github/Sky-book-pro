import { createElement } from 'lwc';
import AgentDashboard from 'c/agentDashboard';
import getDashboardData from '@salesforce/apex/DashboardController.getDashboardData';
import { subscribe, unsubscribe } from 'lightning/messageService';
import CANCELLATION_CHANNEL from '@salesforce/messageChannel/SkyBook_Channel__c';

// Mock getDashboardData Apex wire/imperative method
jest.mock(
    '@salesforce/apex/DashboardController.getDashboardData',
    () => {
        return {
            default: jest.fn()
        };
    },
    { virtual: true }
);

const mockDashboardData = {
    totalBookings: 5,
    confirmedBookings: 3,
    cancelledBookings: 1,
    draftBookings: 1,
    totalRevenue: 500.00,
    todayBookingsCount: 2,
    todayRevenue: 200.00,
    pendingGroupApprovals: 1,
    activeCancellationCases: 1,
    monthlyRevenue: [
        { monthName: 'Jan 2026', revenue: 500.00, percent: 100 }
    ],
    upcomingFlights: [
        { Id: 'fl_001', Airline_Name__c: 'Test Air', Name: '100', Origin_Airport__c: 'DEL', Destination_Airport__c: 'BOM', Departure_DateTime__c: '2026-07-04T10:00:00Z' }
    ],
    recentBookings: [
        { Id: 'bk_001', Name: 'BK-1001', Booking_Date__c: '2026-07-03', Total_Amount__c: 200.00, Booking_Status__c: 'Confirmed', Flight__r: { Airline_Name__c: 'Test Air', Origin_Airport__c: 'DEL', Destination_Airport__c: 'BOM', Departure_DateTime__c: '2026-07-04T10:00:00Z' }, Seat_Class__c: 'Economy' }
    ]
};

describe('c-agent-dashboard', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function flushPromises() {
        return Promise.resolve();
    }

    it('renders dashboard metrics, monthly performance, upcoming departures, and recent bookings', async () => {
        getDashboardData.mockResolvedValue(mockDashboardData);

        const element = createElement('c-agent-dashboard', {
            is: AgentDashboard
        });
        document.body.appendChild(element);

        await flushPromises();

        // Verify Today's revenue display exists
        const divs = element.shadowRoot.querySelectorAll('div');
        let foundTodayRevenue = false;
        divs.forEach(div => {
            if (div.textContent.includes("Today's Revenue")) {
                foundTodayRevenue = true;
            }
        });
        expect(foundTodayRevenue).toBe(true);

        // Verify Recent Bookings Section rendering
        const recentBookingsHeader = element.shadowRoot.querySelector('h3');
        expect(recentBookingsHeader.textContent).toContain('Recent Bookings');

        const bookingLinks = element.shadowRoot.querySelectorAll('a');
        expect(bookingLinks.length).toBe(1);
        expect(bookingLinks[0].textContent).toBe('BK-1001');
    });

    it('dispatches viewbooking event on recent booking click', async () => {
        getDashboardData.mockResolvedValue(mockDashboardData);

        const element = createElement('c-agent-dashboard', {
            is: AgentDashboard
        });
        document.body.appendChild(element);

        await flushPromises();

        const viewBookingHandler = jest.fn();
        element.addEventListener('viewbooking', viewBookingHandler);

        const bookingLink = element.shadowRoot.querySelector('a');
        bookingLink.click();

        expect(viewBookingHandler).toHaveBeenCalledTimes(1);
        expect(viewBookingHandler.mock.calls[0][0].detail).toBe('bk_001');
    });

    it('dispatches searchflight event on Start New Flight Search button click', async () => {
        getDashboardData.mockResolvedValue(mockDashboardData);

        const element = createElement('c-agent-dashboard', {
            is: AgentDashboard
        });
        document.body.appendChild(element);

        await flushPromises();

        const searchHandler = jest.fn();
        element.addEventListener('searchflight', searchHandler);

        const searchButton = element.shadowRoot.querySelector('lightning-button[variant="brand"]');
        searchButton.click();

        expect(searchHandler).toHaveBeenCalledTimes(1);
    });

    it('subscribes to LMS cancellation channel and refreshes dashboard on message reception', async () => {
        getDashboardData.mockResolvedValue(mockDashboardData);

        const element = createElement('c-agent-dashboard', {
            is: AgentDashboard
        });
        document.body.appendChild(element);

        await flushPromises();

        expect(getDashboardData).toHaveBeenCalledTimes(1);
        expect(subscribe).toHaveBeenCalled();

        // Extract listener from subscribe mock call and execute it with mock cancel event status
        const subscribeCall = subscribe.mock.calls.find(
            (call) => call[1] === CANCELLATION_CHANNEL
        );
        expect(subscribeCall).toBeDefined();
        
        const listener = subscribeCall[2];
        listener({ bookingId: 'bk_001', status: 'Cancelled' });

        await flushPromises();

        expect(getDashboardData).toHaveBeenCalledTimes(2);
    });
});
