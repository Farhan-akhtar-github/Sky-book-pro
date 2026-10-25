public class OfferRequestWrapper {
    public RequestData data { get; set; }
    
    public class RequestData {
        public List<Slice> slices { get; set; }
        public List<Passenger> passengers { get; set; }
        public String cabin_class { get; set; }
    }
    
    public class Slice {
        public String origin { get; set; }
        public String destination { get; set; }
        public String departure_date { get; set; }
    }
    
    public class Passenger {
        public String type { get; set; }
    }
}
