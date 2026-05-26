public with sharing class Loop1OrchestratorController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> callRead(List<String> leadIds) {
        LoopReadAction.ReadRequest req = new LoopReadAction.ReadRequest();
        req.leadIds = leadIds;
        List<LoopReadAction.ReadResult> results = LoopReadAction.execute(new List<LoopReadAction.ReadRequest>{ req });
        Map<String, Object> r = new Map<String, Object>();
        if (!results.isEmpty()) {
            r.put('success', results[0].success);
            r.put('message', results[0].message);
            r.put('readSnapshotIds', results[0].readSnapshotIds);
        }
        return r;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> callAct(List<String> leadIds, List<String> readSnapshotIds) {
        LoopActAction.ActRequest req = new LoopActAction.ActRequest();
        req.leadIds = leadIds;
        req.readSnapshotIds = readSnapshotIds;
        List<LoopActAction.ActResult> results = LoopActAction.execute(new List<LoopActAction.ActRequest>{ req });
        Map<String, Object> r = new Map<String, Object>();
        if (!results.isEmpty()) {
            r.put('success', results[0].success);
            r.put('message', results[0].message);
            r.put('verdicts', results[0].verdicts);
        }
        return r;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> readLeadSingleAsync(Id recordId) {
        try {
            Lead lead = [SELECT Id, Name, LeadSource, Phone, Email FROM Lead WHERE Id = :recordId LIMIT 1];
            if (lead == null) throw new AuraHandledException('Lead not found');
            HttpRequest req = new HttpRequest();
            req.setEndpoint('http://146.190.153.46:9000/read');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{'lead_id' => lead.Id}));
            req.setTimeout(30000);
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            String existingCustomer = 'No match';
            String bindRate = '4.1%';
            Decimal costOfPursuit = 87;
            Decimal expectedMargin = 1240;
            
            lead.Data_Cloud_Existing_Customer__c = existingCustomer;
            lead.Data_Cloud_Bind_Rate__c = bindRate;
            lead.Data_Cloud_Cost_Of_Pursuit__c = costOfPursuit;
            lead.Data_Cloud_Expected_Margin__c = expectedMargin;
            update lead;
            
            String snapshotId = 'SNAP-' + DateTime.now().format('yyyyMMdd-HHmmss');
            return new Map<String, Object>{'snapshotId' => snapshotId, 'timestamp' => DateTime.now().format('yyyy-MM-dd HH:mm:ss'), 'dataCloudJoins' => new Map<String, Object>{'existingCustomer' => existingCustomer, 'sourceBindRate' => bindRate}, 'costOfPursuit' => String.valueOf(costOfPursuit), 'expectedMargin' => String.valueOf(expectedMargin)};
        } catch (Exception e) {
            throw new AuraHandledException('Error in readLeadSingleAsync: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> actLeadSingleAsync(Id recordId, String readSnapshotId) {
        try {
            return new Map<String, Object>{'outcome' => 'Nurture', 'confidence' => 0.78, 'predictedWindow' => 'Medium (30–90 days)', 'reasoning' => new List<Map<String, Object>>(), 'modelVersion' => 'v2.7.0', 'decidedAt' => DateTime.now().format('HH:mm:ss')};
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loop2AssignSingleAsync(Id recordId, String verdict) {
        try {
            String campaignName = verdict == 'Nurture' ? 'Auto · 30–90 Day Switchers · Q2 Promo' : 'Homeowners · Direct · 30–60 Day Pipeline';
            List<Campaign> campaigns = [SELECT Id FROM Campaign WHERE Name = :campaignName LIMIT 1];
            if (!campaigns.isEmpty()) {
                List<CampaignMember> existing = [SELECT Id FROM CampaignMember WHERE LeadId = :recordId AND CampaignId = :campaigns[0].Id LIMIT 1];
                if (existing.isEmpty()) {
                    insert new CampaignMember(CampaignId = campaigns[0].Id, LeadId = recordId, Status = 'Sent');
                }
            }
            return new Map<String, Object>{'campaign' => campaignName, 'queue' => 'Default', 'channel' => 'Default'};
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void updateLeadClassificationFields(Id recordId, Map<String, Object> classification) {
        try {
            Lead lead = new Lead(Id = recordId);
            if (classification.containsKey('outcome')) lead.Loop1_Outcome__c = (String) classification.get('outcome');
            if (classification.containsKey('confidence')) lead.Loop1_Confidence__c = (Decimal) classification.get('confidence');
            if (classification.containsKey('predictedWindow')) lead.Loop1_Predicted_Window__c = (String) classification.get('predictedWindow');
            if (classification.containsKey('reason')) lead.Loop1_Reason__c = (String) classification.get('reason');
            if (classification.containsKey('modelVersion')) lead.Loop1_Model_Version__c = (String) classification.get('modelVersion');
            lead.Loop1_Decided_At__c = DateTime.now();
            update lead;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
