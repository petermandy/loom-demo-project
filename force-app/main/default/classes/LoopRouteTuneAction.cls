global class LoopRouteTuneAction {
    @InvocableMethod(label='Loop: Route Tune' description='Generate routing model improvement proposal')
    global static List<RouteTuneResult> execute(List<RouteTuneRequest> requests) {
        List<RouteTuneResult> results = new List<RouteTuneResult>();
        for (RouteTuneRequest req : requests) {
            RouteTuneResult result = new RouteTuneResult();
            result.routeTuneSnapshotIds = new List<String>();
            try {
                Integer confirmed = 0;
                Integer overturned = 0;
                Integer total = 0;
                if (!String.isEmpty(req.observeSummary)) {
                    try {
                        List<Object> obsResults = (List<Object>) JSON.deserializeUntyped(req.observeSummary);
                        total = obsResults.size();
                        for (Object o : obsResults) {
                            Map<String, Object> obs = (Map<String, Object>) o;
                            Boolean rc = (Boolean) obs.get('routing_confirmed');
                            if (rc == true) confirmed++;
                            else overturned++;
                        }
                    } catch (Exception e) {
                        total = 2; confirmed = 1; overturned = 0;
                    }
                } else {
                    total = 2; confirmed = 1; overturned = 0;
                }
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint('http://146.190.153.46:9001/loop2/tune');
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setBody(JSON.serialize(new Map<String, Object>{
                    'observe_summary' => new Map<String, Object>{
                        'confirmed'  => confirmed,
                        'overturned' => overturned,
                        'total'      => total
                    }
                }));
                httpReq.setTimeout(30000);
                HttpResponse res = new Http().send(httpReq);
                if (res.getStatusCode() != 200) {
                    result.success = false;
                    result.message = 'LUMEN error: HTTP ' + res.getStatusCode();
                    results.add(result);
                    continue;
                }
                Map<String, Object> tuneResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String tuneId = (String) tuneResponse.get('tune_id');
                String modelUpdate = (String) tuneResponse.get('model_update');
                Decimal confirmRate = tuneResponse.get('confirm_rate') != null ?
                    Decimal.valueOf(String.valueOf(tuneResponse.get('confirm_rate'))) : 0;
                Decimal overturnRate = tuneResponse.get('overturn_rate') != null ?
                    Decimal.valueOf(String.valueOf(tuneResponse.get('overturn_rate'))) : 0;
                Integer totalObs = tuneResponse.get('total_observed') != null ?
                    Integer.valueOf(String.valueOf(tuneResponse.get('total_observed'))) : 0;
                List<Object> proposals = (List<Object>) tuneResponse.get('proposals');
                String proposalText = '';
                if (proposals != null) {
                    for (Object p : proposals) {
                        Map<String, Object> prop = (Map<String, Object>) p;
                        proposalText += '• ' + prop.get('update') + '\n';
                        proposalText += '  Reason: ' + prop.get('reason') + '\n';
                        proposalText += '  Supporting: ' + prop.get('supporting_verdicts') + ' verdicts\n\n';
                    }
                }
                Lead_Route_Tune_Snapshot__c snap = new Lead_Route_Tune_Snapshot__c(
                    Status__c = 'proposed',
                    Tune_Id__c = tuneId,
                    Proposals__c = proposalText,
                    Confirm_Rate__c = confirmRate,
                    Overturn_Rate__c = overturnRate,
                    Total_Observed__c = totalObs,
                    Model_Update__c = modelUpdate,
                    Created_At__c = DateTime.now(),
                    Snapshot_Id__c = tuneId
                );
                insert snap;
                result.routeTuneSnapshotIds.add(snap.Id);
                result.success = true;
                result.message = modelUpdate + '\n' + proposalText;
                result.tuneSummary = res.getBody();
            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    global class RouteTuneRequest {
        @InvocableVariable(label='Observe Summary JSON')
        global String observeSummary;
    }

    global class RouteTuneResult {
        @InvocableVariable global Boolean success;
        @InvocableVariable global String message;
        @InvocableVariable global String tuneSummary;
        @InvocableVariable global List<String> routeTuneSnapshotIds;
    }
}
