public class FlightService {

    public static Flight__c getFlightByOfferId(String offerId) {
        if (String.isBlank(offerId)) {
            return null;
        }
        List<Flight__c> existingFlights = [
            SELECT Id, Name, Airline_Name__c, Amadeus_Offer__c, Arrival_DateTime__c, 
                   Departure_DateTime__c, Destination_Airport__c, Duration_Minutes__c, 
                   Is_International__c, Origin_Airport__c, Status__c
            FROM Flight__c
            WHERE Amadeus_Offer__c = :offerId
            WITH USER_MODE
            LIMIT 1
        ];
        return existingFlights.isEmpty() ? null : existingFlights[0];
    }

    public static Flight__c createFlight(FlightOfferWrapper offer) {
        if (offer == null || String.isBlank(offer.offerId)) {
            throw new IllegalArgumentException('Offer and OfferId cannot be blank.');
        }
        
        // Duplicate check
        Flight__c existingFlight = getFlightByOfferId(offer.offerId);
        if (existingFlight != null) {
            return existingFlight;
        }
        
        // Create new flight record
        Flight__c newFlight = new Flight__c();
        newFlight.Airline_Name__c = offer.airline;
        newFlight.Amadeus_Offer__c = offer.offerId;
        newFlight.Arrival_DateTime__c = offer.arrivalTime;
        newFlight.Departure_DateTime__c = offer.departureTime;
        newFlight.Destination_Airport__c = offer.destination;
        newFlight.Duration_Minutes__c = offer.duration;
        newFlight.Is_International__c = offer.isInternational == null ? false : offer.isInternational;
        newFlight.Origin_Airport__c = offer.origin;
        newFlight.Status__c = 'Active'; // Required picklist field
        
        insert newFlight;
        
        return getFlight(newFlight.Id);
    }
    
    public static void updateFlight(Flight__c flight) {
        if (flight == null || String.isBlank(flight.Id)) {
            throw new IllegalArgumentException('Flight and FlightId cannot be blank.');
        }
        update flight;
    }
    
    public static Flight__c getFlight(String flightId) {
        if (String.isBlank(flightId)) {
            return null;
        }
        return [
            SELECT Id, Name, Airline_Name__c, Amadeus_Offer__c, Arrival_DateTime__c, 
                   Departure_DateTime__c, Destination_Airport__c, Duration_Minutes__c, 
                   Is_International__c, Origin_Airport__c, Status__c
            FROM Flight__c
            WHERE Id = :flightId
            LIMIT 1
        ];
    }
}
