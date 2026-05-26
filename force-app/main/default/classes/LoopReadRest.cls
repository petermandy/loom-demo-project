@RestResource(urlMapping='/loop/read')
global class LoopReadRest {
    @HttpPost
    global static void doPost() {
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            List<String> leadIds = new List<String>();
            if (body.containsKey('leadIds') && body.get('leadIds') != null) {
                List<Object> ids = (List<Object>) body.get('leadIds');
                for (Object id : ids) leadIds.add((String) id);
            }
            LoopReadAction.ReadRequest readReq = new LoopReadAction.ReadRequest();
            readReq.leadIds = leadIds;
            List<LoopReadAction.ReadResult> results = LoopReadAction.execute(new List<LoopReadAction.ReadRequest>{ readReq });
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(results[0]));
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'success' => false, 'message' => 'Error: ' + e.getMessage() }));
        }
    }
}
