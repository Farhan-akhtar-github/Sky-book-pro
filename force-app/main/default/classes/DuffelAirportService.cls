public class DuffelAirportService {
    
    public static List<AirportWrapper> searchAirports(String keyword) {
        if (String.isBlank(keyword)) {
            return new List<AirportWrapper>();
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Duffel_Credential/air/airports?limit=200');
        req.setMethod('GET');
        req.setHeader('Duffel-Version', 'v2');
        req.setHeader('Content-Type', 'application/json');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to fetch airports from Duffel. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
        }
        
        DuffelAirportResponse response = (DuffelAirportResponse) JSON.deserialize(res.getBody(), DuffelAirportResponse.class);
        List<AirportWrapper> results = new List<AirportWrapper>();
        
        String lowerKeyword = keyword.toLowerCase();
        
        if (response != null && response.data != null) {
            for (DuffelAirportData data : response.data) {
                Boolean matches = false;
                if (data.iata_code != null && data.iata_code.toLowerCase().contains(lowerKeyword)) {
                    matches = true;
                } else if (data.name != null && data.name.toLowerCase().contains(lowerKeyword)) {
                    matches = true;
                } else if (data.city_name != null && data.city_name.toLowerCase().contains(lowerKeyword)) {
                    matches = true;
                }
                
                if (matches) {
                    AirportWrapper wrapper = new AirportWrapper();
                    wrapper.iataCode = data.iata_code;
                    wrapper.airportName = data.name;
                    wrapper.city = data.city_name;
                    wrapper.country = data.iata_country_code;
                    wrapper.timezone = data.time_zone;
                    results.add(wrapper);
                }
            }
        }
        
        return results;
    }
    
    public static AirportWrapper getAirport(String iataCode) {
        if (String.isBlank(iataCode)) {
            return null;
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Duffel_Credential/air/airports?limit=200');
        req.setMethod('GET');
        req.setHeader('Duffel-Version', 'v2');
        req.setHeader('Content-Type', 'application/json');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to fetch airports from Duffel. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
        }
        
        DuffelAirportResponse response = (DuffelAirportResponse) JSON.deserialize(res.getBody(), DuffelAirportResponse.class);
        
        if (response != null && response.data != null) {
            for (DuffelAirportData data : response.data) {
                if (data.iata_code != null && data.iata_code.equalsIgnoreCase(iataCode)) {
                    AirportWrapper wrapper = new AirportWrapper();
                    wrapper.iataCode = data.iata_code;
                    wrapper.airportName = data.name;
                    wrapper.city = data.city_name;
                    wrapper.country = data.iata_country_code;
                    wrapper.timezone = data.time_zone;
                    return wrapper;
                }
            }
        }
        
        return null;
    }
    
    public class DuffelAirportResponse {
        public List<DuffelAirportData> data { get; set; }
    }
    
    public class DuffelAirportData {
        public String iata_code { get; set; }
        public String name { get; set; }
        public String city_name { get; set; }
        public String iata_country_code { get; set; }
        public String time_zone { get; set; }
    }
}
