global class LoopRouteActAction {
    @InvocableMethod(label='Loop: Route Act' description='Call LUMEN for routing decision and write Act snapshot')
    global static List<RouteActResult> execute(List<RouteActRequest> requests) {
        List<RouteActResult> results = new List<RouteActResult>();
        for (RouteActRequest req : requests) {
            RouteActResult result = new RouteActResult();
            result.routeActSnapshotIds = new List<String>();
            result.leadIds = req.leadIds;
            try {
                List<Lead> leads = [
                    SELECT Id, Name, Loop1_Verdict__c, Loop1_Confidence__c,
                           Loop1_Predicted_Window__c, Quote_LOB__c,
                           StateCode, PostalCode, Aggregator_Price_Paid_USD__c
                    FROM Lead WHERE Id IN :req.leadIds
                ];
                List<Agent__c> agents = [
                    SELECT Id, Name, User__c, Commission_Tier__c,
                           Lines_Appointed__c, Licensed_States__c,
                           Max_Lead_Capacity__c, Active__c
                    FROM Agent__c WHERE Active__c = true
                ];
                List<Map<String, Object>> leadsPayload = new List<Map<String, Object>>();
                for (Lead l : leads) {
                    String sc = String.isEmpty(l.StateCode) ? '' : l.StateCode;
                    leadsPayload.add(new Map<String, Object>{
                        'lead_id'               => l.Id,
                        'state'                 => sc,
                        'quote_lob'             => l.Quote_LOB__c != null ? l.Quote_LOB__c : 'Auto',
                        'loop1_verdict'         => l.Loop1_Verdict__c != null ? l.Loop1_Verdict__c : 'Nurture',
                        'aggregator_price_paid' => l.Aggregator_Price_Paid_USD__c != null ? l.Aggregator_Price_Paid_USD__c : 0
                    });
                }
                List<Map<String, Object>> agentsPayload = new List<Map<String, Object>>();
                for (Agent__c a : agents) {
                    agentsPayload.add(new Map<String, Object>{'Id' => a.Id, 'Name' => a.Name});
                }
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint('http://146.190.153.46:9001/loop2/route-bulk');
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setBody(JSON.serialize(new Map<String, Object>{
                    'leads' => leadsPayload, 'agents' => agentsPayload
                }));
                httpReq.setTimeout(30000);
                HttpResponse res = new Http().send(httpReq);
                if (res.getStatusCode() != 200) {
                    result.success = false;
                    result.message = 'LUMEN error: HTTP ' + res.getStatusCode();
                    results.add(result);
                    continue;
                }
                List<Object> routingResults = (List<Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Map<String, Object>> byLeadId = new Map<String, Map<String, Object>>();
                for (Object r : routingResults) {
                    Map<String, Object> rd = (Map<String, Object>) r;
                    byLeadId.put((String) rd.get('lead_id'), rd);
                }
                Map<Id, Agent__c> agentMap = new Map<Id, Agent__c>();
                for (Agent__c a : agents) agentMap.put(a.Id, a);
                List<Lead> leadsToUpdate = new List<Lead>();
                List<Task> tasks = new List<Task>();
                List<Lead_Route_Act_Snapshot__c> snaps = new List<Lead_Route_Act_Snapshot__c>();
                String summaryMsg = '';
                for (Lead lead : leads) {
                    Map<String, Object> decision = byLeadId.get(lead.Id);
                    String destType = 'None';
                    String destQueue = '';
                    String routingReason = '';
                    String agentId = null;
                    String commTier = null;
                    if (decision == null || decision.containsKey('error')) {
                        destType = 'Overflow';
                        destQueue = 'Overflow_Queue';
                        routingReason = decision != null ? (String) decision.get('error') : 'No decision from LUMEN';
                    } else {
                        agentId = (String) decision.get('agent_id');
                        String agentName = (String) decision.get('agent_name');
                        routingReason = (String) decision.get('routing_reason');
                        if (lead.Loop1_Verdict__c == 'Pursue' && agentId != null) {
                            Agent__c agent = agentMap.get(Id.valueOf(agentId));
                            if (agent != null) {
                                lead.OwnerId = agent.User__c;
                                lead.Loop2_Assigned_Agent__c = agent.Id;
                                destType = 'Agent';
                                destQueue = agentName;
                                commTier = agent.Commission_Tier__c;
                                tasks.add(new Task(
                                    WhoId = lead.Id,
                                    OwnerId = agent.User__c,
                                    Subject = 'Follow up: ' + lead.Name + ' (' + lead.Quote_LOB__c + ')',
                                    Description = 'Loop2 routed by LUMEN. Reason: ' + routingReason,
                                    ActivityDate = Date.today().addDays(1),
                                    Priority = 'Normal',
                                    Status = 'Open'
                                ));
                            }
                        } else if (lead.Loop1_Verdict__c == 'Nurture') {
                            String queueName = getNurtureQueueName(lead.Loop1_Predicted_Window__c);
                            try {
                                Group q = [SELECT Id FROM Group WHERE Name = :queueName AND Type = 'Queue' LIMIT 1];
                                lead.OwnerId = q.Id;
                            } catch (Exception e) { System.debug('Queue not found: ' + queueName); }
                            lead.Loop2_Nurture_Category__c = lead.Loop1_Predicted_Window__c;
                            destType = 'Queue';
                            destQueue = queueName;
                            routingReason = routingReason + ' → ' + queueName;
                            addLeadToCampaign(lead.Id, queueName.replace('_Queue', ''));
                        } else {
                            routingReason = 'No routing: ' + lead.Loop1_Verdict__c;
                        }
                    }
                    lead.Loop2_Destination_Type__c = destType;
                    lead.Loop2_Routed_Queue__c = destQueue;
                    lead.Loop2_Routing_Reason__c = routingReason;
                    lead.Loop2_Routed_Date__c = System.now();
                    leadsToUpdate.add(lead);
                    snaps.add(new Lead_Route_Act_Snapshot__c(
                        Lead__c = lead.Id,
                        Route_Read_Snapshot__c = (req.routeReadSnapshotIds != null && req.routeReadSnapshotIds.size() > 0) ? req.routeReadSnapshotIds[0] : null,
                        Status__c = 'routed',
                        Loop1_Verdict__c = lead.Loop1_Verdict__c,
                        Route_Destination__c = destQueue,
                        Route_Reason__c = routingReason,
                        Agent__c = (agentId != null) ? Id.valueOf(agentId) : null,
                        Commission_Tier__c = commTier,
                        Created_At__c = DateTime.now(),
                        Snapshot_Id__c = 'route-act-' + lead.Id + '-' + DateTime.now().getTime()
                    ));
                    summaryMsg += lead.Name + ' → ' + destType + ': ' + destQueue + '\n';
                }
                update leadsToUpdate;
                insert snaps;
                if (!tasks.isEmpty()) insert tasks;
                for (Lead_Route_Act_Snapshot__c s : snaps) result.routeActSnapshotIds.add(s.Id);
                result.success = true;
                result.message = summaryMsg;
            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    private static String getNurtureQueueName(String window) {
        if (window == 'immediate') return 'Immediate_Nurture_Queue';
        if (window == 'short') return 'Short_Window_Nurture_Queue';
        if (window == 'medium') return 'Medium_Window_Nurture_Queue';
        if (window == 'long') return 'Long_Window_Nurture_Queue';
        if (window == 'extended') return 'Extended_Window_Nurture_Queue';
        if (window == 'indefinite') return 'Indefinite_Nurture_Queue';
        return 'Medium_Window_Nurture_Queue';
    }

    private static void addLeadToCampaign(Id leadId, String campaignName) {
        try {
            Campaign c = [SELECT Id FROM Campaign WHERE Name = :campaignName LIMIT 1];
            insert new CampaignMember(LeadId=leadId, CampaignId=c.Id, Status='Responded');
        } catch (Exception e) { System.debug('Campaign error: ' + e.getMessage()); }
    }

    global class RouteActRequest {
        @InvocableVariable(label='Lead IDs' required=true)
        global List<String> leadIds;
        @InvocableVariable(label='Route Read Snapshot IDs')
        global List<String> routeReadSnapshotIds;
    }

    global class RouteActResult {
        @InvocableVariable global Boolean success;
        @InvocableVariable global String message;
        @InvocableVariable global List<String> leadIds;
        @InvocableVariable global List<String> routeActSnapshotIds;
    }
}
