@RestResource(urlMapping='/loop/act')
global class LoopActRest {
    @HttpPost
    global static void doPost() {
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            List<String> leadIds = new List<String>();
            List<String> readSnapshotIds = new List<String>();
            if (body.containsKey('leadIds') && body.get('leadIds') != null) {
                List<Object> ids = (List<Object>) body.get('leadIds');
                for (Object id : ids) leadIds.add((String) id);
            }
            if (body.containsKey('readSnapshotIds') && body.get('readSnapshotIds') != null) {
                List<Object> snapIds = (List<Object>) body.get('readSnapshotIds');
                for (Object snapId : snapIds) readSnapshotIds.add((String) snapId);
            }
            LoopActAction.ActRequest actReq = new LoopActAction.ActRequest();
            actReq.leadIds = leadIds;
            actReq.readSnapshotIds = readSnapshotIds.isEmpty() ? null : readSnapshotIds;
            List<LoopActAction.ActResult> results = LoopActAction.execute(new List<LoopActAction.ActRequest>{ actReq });
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(results[0]));
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'success' => false, 'message' => 'Error: ' + e.getMessage() }));
        }
    }
}
