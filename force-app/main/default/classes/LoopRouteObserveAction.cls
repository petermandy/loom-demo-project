global class LoopRouteObserveAction {
    @InvocableMethod(label='Loop: Route Observe' description='Observe routing outcomes and write Observe snapshot')
    global static List<RouteObserveResult> execute(List<RouteObserveRequest> requests) {
        List<RouteObserveResult> results = new List<RouteObserveResult>();
        for (RouteObserveRequest req : requests) {
            RouteObserveResult result = new RouteObserveResult();
            result.routeObserveSnapshotIds = new List<String>();
            result.leadIds = req.leadIds;
            try {
                List<Lead> leads = [
                    SELECT Id, Name, Loop1_Verdict__c, Loop2_Destination_Type__c,
                           Loop2_Routed_Queue__c, Loop2_Routed_Date__c,
                           Loop2_Outcome__c, StateCode, Quote_LOB__c,
                           POR_Agent__c, POR_Agent_Name__c, POR_Since__c,
                           Loop2_Assigned_Agent__c
                    FROM Lead WHERE Id IN :req.leadIds
                ];

                Map<Id, Agent__c> agentMap = new Map<Id, Agent__c>();
                Set<Id> agentIds = new Set<Id>();
                for (Lead l : leads) {
                    if (l.Loop2_Assigned_Agent__c != null) agentIds.add(l.Loop2_Assigned_Agent__c);
                    if (l.POR_Agent__c != null) agentIds.add(l.POR_Agent__c);
                }
                if (!agentIds.isEmpty()) {
                    for (Agent__c a : [
                        SELECT Id, Name, Licensed_States__c, Lines_Appointed__c,
                               Conversion_Rate_High_Value_Home__c, POR_Since__c
                        FROM Agent__c WHERE Id IN :agentIds
                    ]) {
                        agentMap.put(a.Id, a);
                    }
                }

                List<Map<String, Object>> leadsPayload = new List<Map<String, Object>>();
                for (Lead l : leads) {
                    Integer daysSince = 0;
                    if (l.Loop2_Routed_Date__c != null) {
                        daysSince = (Integer) (DateTime.now().getTime() - l.Loop2_Routed_Date__c.getTime()) / 86400000;
                    }

                    Boolean porMatch = l.POR_Agent__c != null && l.POR_Agent__c == l.Loop2_Assigned_Agent__c;
                    String porAgentName = l.POR_Agent_Name__c != null ? l.POR_Agent_Name__c : '';
                    String porSince = l.POR_Since__c != null ? String.valueOf(l.POR_Since__c.year()) : '';

                    Boolean territoryMatch = false;
                    Boolean licenseMatch = false;
                    Decimal conversionRate = 0;

                    Agent__c assignedAgent = l.Loop2_Assigned_Agent__c != null ? agentMap.get(l.Loop2_Assigned_Agent__c) : null;
                    if (assignedAgent != null) {
                        if (assignedAgent.Licensed_States__c != null && l.StateCode != null) {
                            territoryMatch = assignedAgent.Licensed_States__c.contains(l.StateCode);
                        }
                        if (assignedAgent.Lines_Appointed__c != null && l.Quote_LOB__c != null) {
                            // Smart matching: Homeowners matches Home, Auto matches Auto, etc.
                            String quoteLOB = l.Quote_LOB__c.toLowerCase();
                            String lines = assignedAgent.Lines_Appointed__c.toLowerCase();
                            licenseMatch = lines.contains(quoteLOB) ||
                                (quoteLOB == 'homeowners' && lines.contains('home')) ||
                                (quoteLOB == 'home' && lines.contains('homeowners')) ||
                                (quoteLOB == 'bop' && lines.contains('commercial')) ||
                                (quoteLOB == 'commercial' && lines.contains('bop'));
                        }
                        if (assignedAgent.Conversion_Rate_High_Value_Home__c != null) {
                            conversionRate = assignedAgent.Conversion_Rate_High_Value_Home__c / 100;
                        }
                    }

                    // Use Loop2_Outcome__c for demo control, fall back to IsConverted
                    String outcome = 'pending';
                    if (!String.isEmpty(l.Loop2_Outcome__c)) {
                        outcome = l.Loop2_Outcome__c.toLowerCase();
                    }

                    leadsPayload.add(new Map<String, Object>{
                        'lead_id'               => l.Id,
                        'loop1_verdict'         => l.Loop1_Verdict__c,
                        'routed_to'             => l.Loop2_Routed_Queue__c,
                        'days_since_route'      => daysSince,
                        'outcome'               => outcome,
                        'por_match'             => porMatch,
                        'por_agent_name'        => porAgentName,
                        'por_since'             => porSince,
                        'territory_match'       => territoryMatch,
                        'license_match'         => licenseMatch,
                        'agent_conversion_rate' => conversionRate
                    });
                }

                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint('http://146.190.153.46:9001/loop2/observe');
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setBody(JSON.serialize(new Map<String, Object>{'leads' => leadsPayload}));
                httpReq.setTimeout(30000);
                HttpResponse res = new Http().send(httpReq);

                if (res.getStatusCode() != 200) {
                    result.success = false;
                    result.message = 'LUMEN error: HTTP ' + res.getStatusCode();
                    results.add(result);
                    continue;
                }

                List<Object> observeResults = (List<Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Map<String, Object>> byLeadId = new Map<String, Map<String, Object>>();
                for (Object r : observeResults) {
                    Map<String, Object> rd = (Map<String, Object>) r;
                    byLeadId.put((String) rd.get('lead_id'), rd);
                }

                List<Lead_Route_Observe_Snapshot__c> snaps = new List<Lead_Route_Observe_Snapshot__c>();
                String summaryMsg = '';

                for (Lead lead : leads) {
                    Map<String, Object> obs = byLeadId.get(lead.Id);
                    String verdict = obs != null ? (String) obs.get('observe_verdict') : 'Inconclusive';
                    String reason = obs != null ? (String) obs.get('reason') : 'No observation data';
                    Boolean confirmed = obs != null ? (Boolean) obs.get('routing_confirmed') : false;
                    Integer days = obs != null ? Integer.valueOf(String.valueOf(obs.get('days_in_window'))) : 0;

                    snaps.add(new Lead_Route_Observe_Snapshot__c(
                        Lead__c = lead.Id,
                        Route_Act_Snapshot__c = (req.routeActSnapshotIds != null && req.routeActSnapshotIds.size() > 0) ? req.routeActSnapshotIds[0] : null,
                        Status__c = 'observed',
                        Observe_Verdict__c = verdict,
                        Observe_Reason__c = reason,
                        Routing_Confirmed__c = confirmed,
                        Days_In_Window__c = days,
                        Created_At__c = DateTime.now(),
                        Snapshot_Id__c = 'route-obs-' + lead.Id + '-' + DateTime.now().getTime()
                    ));
                    summaryMsg += lead.Name + ' → ' + verdict + '\n' + reason + '\n\n';
                }

                insert snaps;
                for (Lead_Route_Observe_Snapshot__c s : snaps) result.routeObserveSnapshotIds.add(s.Id);
                result.success = true;
                result.message = summaryMsg;
                result.observeSummary = res.getBody();

            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    global class RouteObserveRequest {
        @InvocableVariable(label='Lead IDs' required=true)
        global List<String> leadIds;
        @InvocableVariable(label='Route Act Snapshot IDs')
        global List<String> routeActSnapshotIds;
    }

    global class RouteObserveResult {
        @InvocableVariable global Boolean success;
        @InvocableVariable global String message;
        @InvocableVariable global String observeSummary;
        @InvocableVariable global List<String> leadIds;
        @InvocableVariable global List<String> routeObserveSnapshotIds;
    }
}
