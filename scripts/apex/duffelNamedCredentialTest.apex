HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Duffle_Credential/air/airports');
req.setMethod('GET');

HttpResponse res = new Http().send(req);
System.debug('DUFFEL_NC_STATUS=' + res.getStatusCode());
System.debug('DUFFEL_NC_BODY_PREFIX=' + res.getBody().left(Math.min(300, res.getBody().length())));
