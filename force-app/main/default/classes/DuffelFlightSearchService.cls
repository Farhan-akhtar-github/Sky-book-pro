public class DuffelFlightSearchService {

    @AuraEnabled
    public static List<FlightOfferWrapper> searchFlights(
        String origin, 
        String destination, 
        Date departureDate, 
        Integer passengerCount, 
        String cabinClass
    ) {
        if (String.isBlank(origin) || String.isBlank(destination) || departureDate == null) {
            return new List<FlightOfferWrapper>();
        }
        
        // Build request payload
        OfferRequestWrapper reqBody = new OfferRequestWrapper();
        reqBody.data = new OfferRequestWrapper.RequestData();
        reqBody.data.cabin_class = cabinClass;
        
        OfferRequestWrapper.Slice sl = new OfferRequestWrapper.Slice();
        sl.origin = origin;
        sl.destination = destination;
        sl.departure_date = DateTime.newInstance(departureDate.year(), departureDate.month(), departureDate.day()).format('yyyy-MM-dd');
        reqBody.data.slices = new List<OfferRequestWrapper.Slice>{ sl };
        
        List<OfferRequestWrapper.Passenger> passengers = new List<OfferRequestWrapper.Passenger>();
        Integer count = (passengerCount == null || passengerCount <= 0) ? 1 : passengerCount;
        for (Integer i = 0; i < count; i++) {
            OfferRequestWrapper.Passenger p = new OfferRequestWrapper.Passenger();
            p.type = 'adult';
            passengers.add(p);
        }
        reqBody.data.passengers = passengers;
        
        String jsonPayload = JSON.serialize(reqBody, true);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Duffel_Credential/air/offer_requests?return_offers=true');
        req.setMethod('POST');
        req.setHeader('Duffel-Version', 'v2');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonPayload);
        req.setTimeout(60000); // 60s timeout for external flight search API
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 201 && res.getStatusCode() != 200) {
            throw new CalloutException('Failed to search flights on Duffel. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
        }
        
        DuffelFlightSearchResponse response = (DuffelFlightSearchResponse) JSON.deserialize(res.getBody(), DuffelFlightSearchResponse.class);
        List<FlightOfferWrapper> wrappers = new List<FlightOfferWrapper>();
        
        if (response != null && response.data != null && response.data.offers != null) {
            for (DuffelOffer offer : response.data.offers) {
                FlightOfferWrapper w = new FlightOfferWrapper();
                w.offerId = offer.id;
                w.price = String.isNotBlank(offer.total_amount) ? Decimal.valueOf(offer.total_amount) : 0.0;
                w.currencyIsoCode = offer.total_currency;

                // Logo parsing rules
                String parsedLogoUrl = null;
                if (offer.slices != null && offer.slices.size() > 0) {
                    DuffelSlice slice = offer.slices[0];
                    if (slice.segments != null && slice.segments.size() > 0) {
                        DuffelSegment firstSeg = slice.segments[0];
                        if (firstSeg.marketing_carrier != null && String.isNotBlank(firstSeg.marketing_carrier.logo_symbol_url)) {
                            parsedLogoUrl = firstSeg.marketing_carrier.logo_symbol_url;
                        }
                    }
                }
                if (String.isBlank(parsedLogoUrl) && offer.owner != null && String.isNotBlank(offer.owner.logo_symbol_url)) {
                    parsedLogoUrl = offer.owner.logo_symbol_url;
                }
                w.logoUrl = parsedLogoUrl;
                
                if (offer.slices != null && offer.slices.size() > 0) {
                    DuffelSlice slice = offer.slices[0];
                    w.origin = slice.origin != null ? slice.origin.iata_code : null;
                    w.destination = slice.destination != null ? slice.destination.iata_code : null;
                    w.duration = parseIsoDuration(slice.duration);
                    
                    if (slice.segments != null && slice.segments.size() > 0) {
                        DuffelSegment firstSeg = slice.segments[0];
                        DuffelSegment lastSeg = slice.segments[slice.segments.size() - 1];
                        
                        w.airline = firstSeg.marketing_carrier != null ? firstSeg.marketing_carrier.name : (offer.owner != null ? offer.owner.name : null);
                        w.flightNumber = firstSeg.marketing_carrier_flight_number;
                        w.departureTime = parseIsoDateTime(firstSeg.departing_at);
                        w.arrivalTime = parseIsoDateTime(lastSeg.arriving_at);
                        
                        if (firstSeg.passengers != null && firstSeg.passengers.size() > 0) {
                            w.cabinClass = firstSeg.passengers[0].cabin_class;
                        }
                        
                        w.segments = new List<SegmentWrapper>();
                        for (DuffelSegment seg : slice.segments) {
                            SegmentWrapper s = new SegmentWrapper();
                            s.segmentId = seg.id;
                            s.origin = seg.origin != null ? seg.origin.iata_code : null;
                            s.destination = seg.destination != null ? seg.destination.iata_code : null;
                            s.departingAt = parseIsoDateTime(seg.departing_at);
                            s.arrivingAt = parseIsoDateTime(seg.arriving_at);
                            s.airlineName = seg.marketing_carrier != null ? seg.marketing_carrier.name : null;
                            s.flightNumber = seg.marketing_carrier_flight_number;
                            s.carrierCode = seg.marketing_carrier != null ? seg.marketing_carrier.iata_code : null;
                            s.duration = seg.duration;
                            w.segments.add(s);
                        }
                    }
                    
                    w.isInternational = (slice.origin != null && slice.destination != null && 
                                         slice.origin.iata_country_code != slice.destination.iata_country_code);
                }
                
                w.seatsAvailable = 9; // Default to 9 as Duffel NDC does not provide a seats count field directly on the offer
                wrappers.add(w);
            }
        }
        
        return wrappers;
    }
    
    // Parse PT2H30M -> 150
    public static Integer parseIsoDuration(String isoDuration) {
        if (String.isBlank(isoDuration)) {
            return 0;
        }
        Integer totalMinutes = 0;
        try {
            String clean = isoDuration.toUpperCase().replace('PT', '');
            if (clean.contains('D')) {
                String[] parts = clean.split('D');
                totalMinutes += Integer.valueOf(parts[0].replaceAll('[^0-9]', '')) * 24 * 60;
                clean = parts.size() > 1 ? parts[1] : '';
            }
            clean = clean.replace('T', '');
            if (clean.contains('H')) {
                String[] parts = clean.split('H');
                totalMinutes += Integer.valueOf(parts[0].replaceAll('[^0-9]', '')) * 60;
                clean = parts.size() > 1 ? parts[1] : '';
            }
            if (clean.contains('M')) {
                String[] parts = clean.split('M');
                totalMinutes += Integer.valueOf(parts[0].replaceAll('[^0-9]', ''));
            }
        } catch (Exception e) {
            System.debug('Error parsing duration ' + isoDuration + ': ' + e.getMessage());
        }
        return totalMinutes;
    }
    
    // Parse ISO datetime safely
    public static DateTime parseIsoDateTime(String isoDateTime) {
        if (String.isBlank(isoDateTime)) {
            return null;
        }
        try {
            String formatted = isoDateTime;
            if (!formatted.contains('Z') && !formatted.contains('+') && !(formatted.lastIndexOf('-') > 10)) {
                formatted += 'Z';
            }
            return (DateTime) JSON.deserialize('"' + formatted + '"', DateTime.class);
        } catch (Exception e) {
            try {
                return DateTime.valueOf(isoDateTime.replace('T', ' '));
            } catch (Exception ex) {
                return null;
            }
        }
    }
    
    // Strongly typed inner classes for fast and safe deserialization
    public class DuffelFlightSearchResponse {
        public ResponseData data { get; set; }
    }
    
    public class ResponseData {
        public List<DuffelOffer> offers { get; set; }
    }
    
    public class DuffelOffer {
        public String id { get; set; }
        public String total_amount { get; set; }
        public String total_currency { get; set; }
        public DuffelOwner owner { get; set; }
        public List<DuffelSlice> slices { get; set; }
    }
    
    public class DuffelOwner {
        public String name { get; set; }
        public String iata_code { get; set; }
        public String logo_symbol_url { get; set; }
    }
    
    public class DuffelSlice {
        public String id { get; set; }
        public String duration { get; set; }
        public DuffelLocation origin { get; set; }
        public DuffelLocation destination { get; set; }
        public List<DuffelSegment> segments { get; set; }
    }
    
    public class DuffelLocation {
        public String iata_code { get; set; }
        public String iata_country_code { get; set; }
    }
    
    public class DuffelSegment {
        public String id { get; set; }
        public String departing_at { get; set; }
        public String arriving_at { get; set; }
        public DuffelLocation origin { get; set; }
        public DuffelLocation destination { get; set; }
        public DuffelCarrier marketing_carrier { get; set; }
        public DuffelCarrier operating_carrier { get; set; }
        public String marketing_carrier_flight_number { get; set; }
        public String duration { get; set; }
        public List<DuffelSegmentPassenger> passengers { get; set; }
    }
    
    public class DuffelCarrier {
        public String name { get; set; }
        public String iata_code { get; set; }
        public String logo_symbol_url { get; set; }
    }
    
    public class DuffelSegmentPassenger {
        public String cabin_class { get; set; }
        public String cabin_class_marketing_name { get; set; }
    }
}
