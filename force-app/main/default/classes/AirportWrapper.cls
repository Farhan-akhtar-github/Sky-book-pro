public class AirportWrapper {
    @AuraEnabled public String iataCode { get; set; }
    @AuraEnabled public String airportName { get; set; }
    @AuraEnabled public String city { get; set; }
    @AuraEnabled public String country { get; set; }
    @AuraEnabled public String timezone { get; set; }
}
