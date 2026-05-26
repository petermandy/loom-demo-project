@RestResource(urlMapping='/loop/tune')
global class LoopTuneRest {
    @HttpPost
    global static void doPost() {
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String observeSummary = null;
            if (body.containsKey('observeSummary') && body.get('observeSummary') != null) {
                observeSummary = (String) body.get('observeSummary');
            }
            LoopTuneAction.TuneRequest tuneReq = new LoopTuneAction.TuneRequest();
            tuneReq.observeSummary = observeSummary;
            List<LoopTuneAction.TuneResult> results = LoopTuneAction.execute(new List<LoopTuneAction.TuneRequest>{ tuneReq });
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(results[0]));
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'success' => false, 'message' => 'Error: ' + e.getMessage() }));
        }
    }
}
