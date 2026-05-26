public class Loop2RouterService {

    @future(callout=true)
    public static void routeLeadsAsync(List<Id> leadIds) {
        List<Lead> leads = [
            SELECT Id, Name, Quote_LOB__c, Loop1_Verdict__c,
                   Loop1_Predicted_Window__c, Loop1_Confidence__c,
                   Aggregator_Price_Paid_USD__c, StateCode, PostalCode
            FROM Lead WHERE Id IN :leadIds
        ];

        List<Agent__c> agents = [
            SELECT Id, Name, User__c, Commission_Tier__c,
                   Lines_Appointed__c, Licensed_States__c,
                   Max_Lead_Capacity__c, Active__c
            FROM Agent__c WHERE Active__c = true
        ];

        List<Map<String, Object>> leadsPayload = new List<Map<String, Object>>();
        for (Lead l : leads) {
            String stateCode = String.isEmpty(l.StateCode) ? extractStateCode(l.PostalCode) : l.StateCode;
            leadsPayload.add(new Map<String, Object>{
                'lead_id'               => l.Id,
                'state'                 => stateCode,
                'quote_lob'             => l.Quote_LOB__c != null ? l.Quote_LOB__c : 'Auto',
                'loop1_verdict'         => l.Loop1_Verdict__c != null ? l.Loop1_Verdict__c : 'Nurture',
                'aggregator_price_paid' => l.Aggregator_Price_Paid_USD__c != null ? l.Aggregator_Price_Paid_USD__c : 0
            });
        }

        List<Map<String, Object>> agentsPayload = new List<Map<String, Object>>();
        for (Agent__c a : agents) {
            agentsPayload.add(new Map<String, Object>{
                'Id'   => a.Id,
                'Name' => a.Name
            });
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('http://146.190.153.46:9001/loop2/route-bulk');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'leads'  => leadsPayload,
            'agents' => agentsPayload
        }));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            System.debug('LUMEN error: ' + res.getStatusCode() + ' ' + res.getBody());
            return;
        }

        List<Object> routingResults = (List<Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Map<String, Object>> resultsByLeadId = new Map<String, Map<String, Object>>();
        for (Object r : routingResults) {
            Map<String, Object> result = (Map<String, Object>) r;
            resultsByLeadId.put((String) result.get('lead_id'), result);
        }

        Map<Id, Agent__c> agentMap = new Map<Id, Agent__c>();
        for (Agent__c a : agents) agentMap.put(a.Id, a);

        List<Lead> leadsToUpdate = new List<Lead>();
        List<Task> tasksToCreate = new List<Task>();

        for (Lead lead : leads) {
            Map<String, Object> decision = resultsByLeadId.get(lead.Id);

            if (decision == null || decision.containsKey('error')) {
                lead.Loop2_Destination_Type__c = 'Overflow';
                lead.Loop2_Routed_Queue__c = 'Overflow_Queue';
                lead.Loop2_Routing_Reason__c = decision != null ? (String) decision.get('error') : 'No decision from LUMEN';
                lead.Loop2_Routed_Date__c = System.now();
                leadsToUpdate.add(lead);
                continue;
            }

            String agentId = (String) decision.get('agent_id');
            String agentName = (String) decision.get('agent_name');
            String routingReason = (String) decision.get('routing_reason');

            if (lead.Loop1_Verdict__c == 'Pursue' && agentId != null) {
                Agent__c agent = agentMap.get(Id.valueOf(agentId));
                if (agent != null) {
                    lead.OwnerId = agent.User__c;
                    lead.Loop2_Assigned_Agent__c = agent.Id;
                    lead.Loop2_Destination_Type__c = 'Agent';
                    lead.Loop2_Routed_Queue__c = agentName;
                    lead.Loop2_Routing_Reason__c = routingReason;
                    tasksToCreate.add(new Task(
                        WhoId = lead.Id,
                        OwnerId = agent.User__c,
                        Subject = 'Follow up: ' + lead.Name + ' (' + lead.Quote_LOB__c + ')',
                        Description = 'Loop2 routed by LUMEN. Reason: ' + routingReason,
                        ActivityDate = Date.today().addDays(1),
                        Priority = (lead.Aggregator_Price_Paid_USD__c != null && lead.Aggregator_Price_Paid_USD__c > 5000) ? 'High' : 'Normal',
                        Status = 'Open'
                    ));
                }
            } else if (lead.Loop1_Verdict__c == 'Nurture') {
                String queueName = getNurtureQueueName(lead.Loop1_Predicted_Window__c);
                try {
                    Group q = [SELECT Id FROM Group WHERE Name = :queueName AND Type = 'Queue' LIMIT 1];
                    lead.OwnerId = q.Id;
                } catch (Exception e) {
                    System.debug('Queue not found: ' + queueName);
                }
                lead.Loop2_Nurture_Category__c = lead.Loop1_Predicted_Window__c;
                lead.Loop2_Routed_Queue__c = queueName;
                lead.Loop2_Destination_Type__c = 'Queue';
                lead.Loop2_Routing_Reason__c = routingReason + ' → ' + queueName;
                addLeadToCampaign(lead.Id, queueName.replace('_Queue', ''));
            } else {
                lead.Loop2_Destination_Type__c = 'None';
                lead.Loop2_Routing_Reason__c = 'No routing: ' + lead.Loop1_Verdict__c;
            }

            lead.Loop2_Routed_Date__c = System.now();
            leadsToUpdate.add(lead);
        }

        update leadsToUpdate;
        if (!tasksToCreate.isEmpty()) insert tasksToCreate;
        System.debug('Loop2 routing complete: ' + leadsToUpdate.size() + ' leads processed');
    }

    private static String extractStateCode(String postalCode) {
        if (!String.isEmpty(postalCode) && postalCode.length() >= 2) {
            return postalCode.substring(0, 2).toUpperCase();
        }
        return '';
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
        } catch (Exception e) {
            System.debug('Campaign error: ' + e.getMessage());
        }
    }
}
