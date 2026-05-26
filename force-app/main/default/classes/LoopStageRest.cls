@RestResource(urlMapping='/loop/stage')
global class LoopStageRest {
    @HttpPost
    global static void doPost() {
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            List<String> leadIds = new List<String>();
            List<String> actSnapshotIds = new List<String>();
            Date activityStartDate = null;
            if (body.containsKey('leadIds') && body.get('leadIds') != null) {
                List<Object> ids = (List<Object>) body.get('leadIds');
                for (Object id : ids) leadIds.add((String) id);
            }
            if (body.containsKey('actSnapshotIds') && body.get('actSnapshotIds') != null) {
                List<Object> snapIds = (List<Object>) body.get('actSnapshotIds');
                for (Object snapId : snapIds) actSnapshotIds.add((String) snapId);
            }
            if (body.containsKey('activityStartDate') && body.get('activityStartDate') != null) {
                activityStartDate = Date.valueOf((String) body.get('activityStartDate'));
            }
            LoopStageActivitiesAction.StageRequest stageReq = new LoopStageActivitiesAction.StageRequest();
            stageReq.leadIds = leadIds;
            stageReq.actSnapshotIds = actSnapshotIds.isEmpty() ? null : actSnapshotIds;
            stageReq.activityStartDate = activityStartDate;
            List<LoopStageActivitiesAction.StageResult> results = LoopStageActivitiesAction.execute(new List<LoopStageActivitiesAction.StageRequest>{ stageReq });
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(results[0]));
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'success' => false, 'message' => 'Error: ' + e.getMessage() }));
        }
    }
}
