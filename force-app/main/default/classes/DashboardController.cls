public with sharing class DashboardController {

    public Integer totalBookings { get; set; }
    public Integer confirmedBookings { get; set; }
    public Integer cancelledBookings { get; set; }
    public Integer draftBookings { get; set; }
    public Decimal totalRevenue { get; set; }
    public Integer todayBookingsCount { get; set; }
    public Decimal todayRevenue { get; set; }
    public Integer pendingGroupApprovals { get; set; }
    public Integer activeCancellationCases { get; set; }
    public List<Booking__c> recentBookings { get; set; }
    public List<RevenueSummaryWrapper> monthlyRevenue { get; set; }
    public List<Flight__c> upcomingFlights { get; set; }
    public String errorMessage { get; set; }
    public Boolean hasError { get; set; }

    @TestVisible private static Boolean forceException = false;

    public class RevenueSummaryWrapper {
        @AuraEnabled public String monthName { get; set; }
        @AuraEnabled public Decimal revenue { get; set; }
        @AuraEnabled public Integer percent { get; set; }
    }

    public DashboardController() {
        loadDashboard();
    }

    private void loadDashboard() {
        errorMessage = null;
        hasError = false;
        monthlyRevenue = new List<RevenueSummaryWrapper>();
        upcomingFlights = new List<Flight__c>();
        totalBookings = 0;
        confirmedBookings = 0;
        cancelledBookings = 0;
        draftBookings = 0;
        totalRevenue = 0.0;
        todayBookingsCount = 0;
        todayRevenue = 0.0;
        pendingGroupApprovals = 0;
        activeCancellationCases = 0;
        recentBookings = new List<Booking__c>();

        Id userId = UserInfo.getUserId();

        try {
            if (forceException) {
                throw new System.QueryException('Simulated query failure');
            }

            // 1. KPI Counts (Scoped to active User)
            totalBookings = [SELECT COUNT() FROM Booking__c WHERE User__c = :userId WITH USER_MODE];
            confirmedBookings = [SELECT COUNT() FROM Booking__c WHERE Booking_Status__c = 'Confirmed' AND User__c = :userId WITH USER_MODE];
            cancelledBookings = [SELECT COUNT() FROM Booking__c WHERE Booking_Status__c = 'Cancelled' AND User__c = :userId WITH USER_MODE];
            draftBookings = [SELECT COUNT() FROM Booking__c WHERE Booking_Status__c = 'Draft' AND User__c = :userId WITH USER_MODE];

            // 2. Total Revenue (from confirmed bookings scoped to active User)
            AggregateResult[] revResult = [
                SELECT SUM(Total_Amount__c) rev 
                FROM Booking__c 
                WHERE Booking_Status__c = 'Confirmed' 
                AND User__c = :userId
                WITH USER_MODE
            ];
            if (!revResult.isEmpty() && revResult[0].get('rev') != null) {
                totalRevenue = (Decimal)revResult[0].get('rev');
            }

            // 3. Today's Bookings Count
            todayBookingsCount = [
                SELECT COUNT() 
                FROM Booking__c 
                WHERE Booking_Date__c = TODAY 
                AND User__c = :userId
                WITH USER_MODE
            ];

            // 4. Today's Revenue (Confirmed only, scoped to active User)
            AggregateResult[] todayRevResult = [
                SELECT SUM(Total_Amount__c) rev 
                FROM Booking__c 
                WHERE Booking_Status__c = 'Confirmed' 
                AND Booking_Date__c = TODAY
                AND User__c = :userId
                WITH USER_MODE
            ];
            if (!todayRevResult.isEmpty() && todayRevResult[0].get('rev') != null) {
                todayRevenue = (Decimal)todayRevResult[0].get('rev');
            }

            // 5. Pending Group Approvals
            List<Booking__c> agentGroupBookings = [
                SELECT Id 
                FROM Booking__c 
                WHERE User__c = :userId 
                AND Is_Group_Booking__c = true
                WITH USER_MODE
            ];
            Set<Id> bookingIds = new Map<Id, Booking__c>(agentGroupBookings).keySet();
            
            List<ProcessInstance> pendingInstances = [
                SELECT Id 
                FROM ProcessInstance 
                WHERE TargetObjectId IN :bookingIds 
                AND Status = 'Pending'
            ];
            
            pendingGroupApprovals = [
                SELECT COUNT()
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstanceId IN :pendingInstances
            ];

            // 6. Active Cancellation Cases
            activeCancellationCases = [
                SELECT COUNT()
                FROM Refund__c
                WHERE Refund_Status__c IN ('Initiated', 'Processing')
                AND Booking__r.User__c = :userId
                WITH USER_MODE
            ];

            // 7. Recent 10 Bookings (Scoped to active User, sorted newest first)
            recentBookings = [
                SELECT Id, Name, Booking_Date__c, Total_Amount__c, Booking_Status__c,
                       Flight__r.Origin_Airport__c, Flight__r.Destination_Airport__c,
                       Flight__r.Airline_Name__c, Flight__r.Departure_DateTime__c,
                       Seat_Class__c
                FROM Booking__c
                WHERE User__c = :userId
                WITH USER_MODE
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 10
            ];

            // 8. Monthly Revenue Analytics (Scoped to active User)
            List<AggregateResult> groupedResults = [
                SELECT CALENDAR_YEAR(Booking_Date__c) yr, CALENDAR_MONTH(Booking_Date__c) mth, SUM(Total_Amount__c) rev
                FROM Booking__c
                WHERE Booking_Status__c = 'Confirmed'
                AND User__c = :userId
                WITH USER_MODE
                GROUP BY CALENDAR_YEAR(Booking_Date__c), CALENDAR_MONTH(Booking_Date__c)
                ORDER BY CALENDAR_YEAR(Booking_Date__c) ASC, CALENDAR_MONTH(Booking_Date__c) ASC
            ];

            // Calculate Max Revenue for scaling
            Decimal maxRevenue = 0.0;
            for (AggregateResult ar : groupedResults) {
                Decimal rev = ar.get('rev') != null ? (Decimal)ar.get('rev') : 0.0;
                if (rev > maxRevenue) {
                    maxRevenue = rev;
                }
            }

            List<String> monthNames = new List<String>{
                '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            };

            for (AggregateResult ar : groupedResults) {
                Integer yr = (Integer)ar.get('yr');
                Integer mth = (Integer)ar.get('mth');
                Decimal rev = ar.get('rev') != null ? (Decimal)ar.get('rev') : 0.0;

                RevenueSummaryWrapper wrapper = new RevenueSummaryWrapper();
                if (mth >= 1 && mth <= 12) {
                    wrapper.monthName = monthNames[mth] + ' ' + yr;
                } else {
                    wrapper.monthName = 'Month ' + mth + ' ' + yr;
                }
                wrapper.revenue = rev;
                
                if (maxRevenue > 0) {
                    wrapper.percent = Integer.valueOf(Math.round((rev / maxRevenue) * 100));
                } else {
                    wrapper.percent = 0;
                }
                monthlyRevenue.add(wrapper);
            }

            // 9. Upcoming Departures (Global/All Flights system-wide)
            upcomingFlights = [
                SELECT Id, Name, Airline_Name__c, Origin_Airport__c, Destination_Airport__c, Departure_DateTime__c
                FROM Flight__c
                WHERE Departure_DateTime__c >= TODAY
                WITH USER_MODE
                ORDER BY Departure_DateTime__c ASC
                LIMIT 10
            ];

        } catch (Exception ex) {
            errorMessage = 'Unable to load dashboard data.';
            hasError = true;
            monthlyRevenue = new List<RevenueSummaryWrapper>();
            upcomingFlights = new List<Flight__c>();
            totalBookings = 0;
            confirmedBookings = 0;
            cancelledBookings = 0;
            draftBookings = 0;
            totalRevenue = 0.0;
            todayBookingsCount = 0;
            todayRevenue = 0.0;
            pendingGroupApprovals = 0;
            activeCancellationCases = 0;
            recentBookings = new List<Booking__c>();
        }
    }

    public PageReference goToFlightSearch() {
        PageReference pr = new PageReference('/apex/FlightSearch');
        pr.setRedirect(true);
        return pr;
    }

    public PageReference goToBookingSearch() {
        PageReference pr = new PageReference('/apex/BookingSearch');
        pr.setRedirect(true);
        return pr;
    }

    public PageReference goToBookingCreate() {
        PageReference pr = new PageReference('/apex/BookingCreate');
        pr.setRedirect(true);
        return pr;
    }

    public class DashboardDataWrapper {
        @AuraEnabled public Integer totalBookings { get; set; }
        @AuraEnabled public Integer confirmedBookings { get; set; }
        @AuraEnabled public Integer cancelledBookings { get; set; }
        @AuraEnabled public Integer draftBookings { get; set; }
        @AuraEnabled public Decimal totalRevenue { get; set; }
        @AuraEnabled public Integer todayBookingsCount { get; set; }
        @AuraEnabled public Decimal todayRevenue { get; set; }
        @AuraEnabled public Integer pendingGroupApprovals { get; set; }
        @AuraEnabled public Integer activeCancellationCases { get; set; }
        @AuraEnabled public List<Booking__c> recentBookings { get; set; }
        @AuraEnabled public List<RevenueSummaryWrapper> monthlyRevenue { get; set; }
        @AuraEnabled public List<Flight__c> upcomingFlights { get; set; }
    }

    @AuraEnabled
    public static DashboardDataWrapper getDashboardData() {
        DashboardController ctrl = new DashboardController();
        DashboardDataWrapper wrapper = new DashboardDataWrapper();
        wrapper.totalBookings = ctrl.totalBookings;
        wrapper.confirmedBookings = ctrl.confirmedBookings;
        wrapper.cancelledBookings = ctrl.cancelledBookings;
        wrapper.draftBookings = ctrl.draftBookings;
        wrapper.totalRevenue = ctrl.totalRevenue;
        wrapper.todayBookingsCount = ctrl.todayBookingsCount;
        wrapper.todayRevenue = ctrl.todayRevenue;
        wrapper.pendingGroupApprovals = ctrl.pendingGroupApprovals;
        wrapper.activeCancellationCases = ctrl.activeCancellationCases;
        wrapper.recentBookings = ctrl.recentBookings;
        wrapper.monthlyRevenue = ctrl.monthlyRevenue;
        wrapper.upcomingFlights = ctrl.upcomingFlights;
        return wrapper;
    }
}
