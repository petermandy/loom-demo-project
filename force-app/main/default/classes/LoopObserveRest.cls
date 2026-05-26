@RestResource(urlMapping='/loop/observe')
global class LoopObserveRest {
    @HttpPost
    global static void doPost() {
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            List<String> leadIds = new List<String>();
            List<String> actSnapshotIds = new List<String>();
            if (body.containsKey('leadIds') && body.get('leadIds') != null) {
                List<Object> ids = (List<Object>) body.get('leadIds');
                for (Object id : ids) leadIds.add((String) id);
            }
            if (body.containsKey('actSnapshotIds') && body.get('actSnapshotIds') != null) {
                List<Object> snapIds = (List<Object>) body.get('actSnapshotIds');
                for (Object snapId : snapIds) actSnapshotIds.add((String) snapId);
            }
            LoopObserveAction.ObserveRequest obsReq = new LoopObserveAction.ObserveRequest();
            obsReq.leadIds = leadIds;
            obsReq.actSnapshotIds = actSnapshotIds.isEmpty() ? null : actSnapshotIds;
            List<LoopObserveAction.ObserveResult> results = LoopObserveAction.execute(new List<LoopObserveAction.ObserveRequest>{ obsReq });
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(results[0]));
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'success' => false, 'message' => 'Error: ' + e.getMessage() }));
        }
    }
}
