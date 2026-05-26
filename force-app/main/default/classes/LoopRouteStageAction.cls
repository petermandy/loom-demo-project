global class LoopRouteStageAction {
    @InvocableMethod(label='Loop: Route Stage' description='Fast-forward time and set outcomes for Loop2 Observe window')
    global static List<RouteStageResult> execute(List<RouteStageRequest> requests) {
        List<RouteStageResult> results = new List<RouteStageResult>();
        for (RouteStageRequest req : requests) {
            RouteStageResult result = new RouteStageResult();
            result.leadIds = req.leadIds;
            try {
                List<Lead> leads = [
                    SELECT Id, Name, Loop1_Verdict__c, Loop2_Destination_Type__c,
                           Loop2_Routed_Date__c, Loop2_Outcome__c
                    FROM Lead WHERE Id IN :req.leadIds
                ];

                List<Lead> toUpdate = new List<Lead>();
                String msg = '';

                for (Lead l : leads) {
                    if (l.Loop1_Verdict__c == 'Pursue' && l.Loop2_Destination_Type__c == 'Agent') {
                        // Pursue leads routed to agent — simulate bound after 3 days
                        l.Loop2_Outcome__c = 'bound';
                        l.Loop2_Routed_Date__c = DateTime.now().addDays(-3);
                        msg += l.Name + ' → bound (3 days ago)\n';
                    } else if (l.Loop1_Verdict__c == 'Nurture') {
                        // Nurture leads — still pending in window
                        l.Loop2_Outcome__c = 'pending';
                        l.Loop2_Routed_Date__c = DateTime.now().addDays(-1);
                        msg += l.Name + ' → pending (1 day ago, still in window)\n';
                    } else {
                        l.Loop2_Outcome__c = 'pending';
                        msg += l.Name + ' → pending\n';
                    }
                    toUpdate.add(l);
                }

                update toUpdate;
                result.success = true;
                result.message = 'Loop2 Stage complete — ' + toUpdate.size() + ' leads staged:\n' + msg;

            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    global class RouteStageRequest {
        @InvocableVariable(label='Lead IDs' required=true)
        global List<String> leadIds;
    }

    global class RouteStageResult {
        @InvocableVariable global Boolean success;
        @InvocableVariable global String message;
        @InvocableVariable global List<String> leadIds;
    }
}
