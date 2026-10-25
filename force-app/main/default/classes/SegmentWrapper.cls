public class SegmentWrapper {
    @AuraEnabled public String segmentId { get; set; }
    @AuraEnabled public String origin { get; set; }
    @AuraEnabled public String destination { get; set; }
    @AuraEnabled public DateTime departingAt { get; set; }
    @AuraEnabled public DateTime arrivingAt { get; set; }
    @AuraEnabled public String airlineName { get; set; }
    @AuraEnabled public String flightNumber { get; set; }
    @AuraEnabled public String carrierCode { get; set; }
    @AuraEnabled public String duration { get; set; }
}
