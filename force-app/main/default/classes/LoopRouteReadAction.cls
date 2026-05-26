global class LoopRouteReadAction {
    @InvocableMethod(label='Loop: Route Read' description='Capture lead state before Loop2 routing')
    global static List<RouteReadResult> execute(List<RouteReadRequest> requests) {
        List<RouteReadResult> results = new List<RouteReadResult>();
        for (RouteReadRequest req : requests) {
            RouteReadResult result = new RouteReadResult();
            result.routeReadSnapshotIds = new List<String>();
            result.leadIds = req.leadIds;
            try {
                List<Lead> leads = [
                    SELECT Id, Name, Loop1_Verdict__c, Loop1_Confidence__c,
                           Loop1_Predicted_Window__c, Quote_LOB__c,
                           StateCode, PostalCode, Aggregator_Price_Paid_USD__c
                    FROM Lead WHERE Id IN :req.leadIds
                ];
                List<Lead_Route_Read_Snapshot__c> snaps = new List<Lead_Route_Read_Snapshot__c>();
                for (Lead l : leads) {
                    snaps.add(new Lead_Route_Read_Snapshot__c(
                        Lead__c = l.Id,
                        Status__c = 'created',
                        Loop1_Verdict__c = l.Loop1_Verdict__c,
                        Product_Line__c = l.Quote_LOB__c,
                        State_Code__c = l.StateCode,
                        Confidence__c = l.Loop1_Confidence__c,
                        Created_At__c = DateTime.now(),
                        Snapshot_Id__c = 'route-read-' + l.Id + '-' + DateTime.now().getTime()
                    ));
                }
                insert snaps;
                for (Lead_Route_Read_Snapshot__c s : snaps) {
                    result.routeReadSnapshotIds.add(s.Id);
                }
                result.success = true;
                result.message = 'Route Read snapshots created: ' + snaps.size();
            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    global class RouteReadRequest {
        @InvocableVariable(label='Lead IDs' required=true)
        global List<String> leadIds;
    }

    global class RouteReadResult {
        @InvocableVariable global Boolean success;
        @InvocableVariable global String message;
        @InvocableVariable global List<String> leadIds;
        @InvocableVariable global List<String> routeReadSnapshotIds;
    }
}
