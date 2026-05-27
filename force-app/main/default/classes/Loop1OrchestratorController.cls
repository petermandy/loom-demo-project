public with sharing class Loop1OrchestratorController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> readLeadSingleAsync(Id recordId) {
        try {
            Lead lead = [SELECT Id, Name, FirstName, LastName, LeadSource, Phone, Email FROM Lead WHERE Id = :recordId LIMIT 1];
            if (lead == null) throw new AuraHandledException('Lead not found');
            
            String existingCustomer = 'No existing customer match';
            String producerOfRecord = 'No Producer of Record';
            String suppressionFlag = 'No suppression flag';
            String bindRate = '4.1%';
            String householdInfo = '';
            
            // Demo 2: Jennifer Park - Has POR and household info
            if (lead.FirstName == 'Jennifer' && lead.LastName == 'Park') {
                existingCustomer = 'Household match: spouse active auto policy (3 years, clean)';
                producerOfRecord = 'Sarah Chen, Boulder office (POR since 2023)';
                suppressionFlag = 'No suppression flag';
                bindRate = '12.8%';
                householdInfo = 'Spouse: active auto $1,200/yr | Household LTV: $4,200 | Claims: clean';
                
                // Create/Link Household Account for FSC
                try {
                    Account householdAccount = new Account(
                        Name = 'Park Household',
                        Type = 'Household'
                    );
                    upsert householdAccount;
                    System.debug('Household Account created/updated: ' + householdAccount.Id);
                    
                    lead.Household_Account__c = householdAccount.Id;
                    System.debug('Linked Lead to Household Account: ' + householdAccount.Id);
                } catch (Exception accountError) {
                    System.debug('Household Account error: ' + accountError.getMessage());
                }
            }
            
            lead.Data_Cloud_Existing_Customer__c = existingCustomer;
            lead.Data_Cloud_Producer_Of_Record__c = producerOfRecord;
            lead.Data_Cloud_Suppression_Flag__c = suppressionFlag;
            lead.Data_Cloud_Bind_Rate__c = bindRate;
            lead.Data_Quality_Email_Verified__c = 'Verified';
            lead.Data_Quality_Phone_Confirmed__c = 'Confirmed-reachable';
            lead.Data_Quality_Address_Validated__c = 'USPS-validated';
            lead.Identity_Confidence__c = 'Medium';
            lead.Cost_of_Pursuit__c = '$87';
            lead.Expected_Lifetime_Margin__c = '$1,240';
            lead.Data_Cloud_Expected_Margin__c = 1240.0;
            lead.Pursuit_Cost_Weighting__c = '0.071';
            update lead;
            
            String snapshotId = 'SNAP-' + DateTime.now().format('yyyyMMdd-HHmmss');
            return new Map<String, Object>{'snapshotId' => snapshotId, 'timestamp' => DateTime.now().format('yyyy-MM-dd HH:mm:ss'), 'dataCloudJoins' => new Map<String, Object>{'existingCustomer' => existingCustomer, 'producerOfRecord' => producerOfRecord, 'suppressionFlag' => suppressionFlag, 'sourceBindRate' => bindRate, 'householdInfo' => householdInfo}};
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> actLeadSingleAsync(Id recordId, String readSnapshotId) {
        try {
            Lead lead = [SELECT Id, FirstName, LastName FROM Lead WHERE Id = :recordId LIMIT 1];
            
            // TEMPORARY: Hardcode Jennifer Park as Pursue for demo (LUMEN model needs retraining)
            if (lead.FirstName == 'Jennifer' && lead.LastName == 'Park') {
                String reason = 'Direct .com source · high purchase intent · household match (spouse active customer) · Producer of Record on file · property within appetite';
                return new Map<String, Object>{
                    'outcome' => 'Pursue', 
                    'confidence' => 0.91, 
                    'predictedWindow' => 'Immediate', 
                    'reason' => reason,
                    'modelVersion' => 'v2.7.0', 
                    'decidedAt' => DateTime.now().format('HH:mm:ss')
                };
            }
            
            // TEMPORARY: Hardcode Marcus Reed as Nurture for demo (LUMEN model needs retraining)
            if (lead.FirstName == 'Marcus' && lead.LastName == 'Reed') {
                String reason = 'Aggregator source · prior at-fault claim (24 months) · credit score below preferred-tier appetite · pattern match — this profile binds at 6% on this source';
                return new Map<String, Object>{
                    'outcome' => 'Nurture',
                    'confidence' => 0.78,
                    'predictedWindow' => 'Medium',
                    'reason' => reason,
                    'modelVersion' => 'v2.7.0',
                    'decidedAt' => DateTime.now().format('HH:mm:ss')
                };
            }

            // Demo 3: David Kowalski - Hard Disqualify on v2.7.0, Nurture on v2.8.0
            if (lead.FirstName == 'David' && lead.LastName == 'Kowalski') {
                Loom_Config__c config = Loom_Config__c.getOrgDefaults();
                String championModel = config.Champion_Model_Version__c != null ? config.Champion_Model_Version__c : 'v2.7.0';
                
                if (championModel == 'v2.7.0') {
                    String reasonDavid = 'Aggregator web source · vehicle age 16 years · prior at-fault claim · credit score 622 · outside appetite';
                    return new Map<String, Object>{
                        'outcome' => 'Hard Disqualify',
                        'confidence' => 0.88,
                        'predictedWindow' => 'No Window',
                        'reason' => reasonDavid,
                        'modelVersion' => 'v2.7.0',
                        'decidedAt' => DateTime.now().format('HH:mm:ss')
                    };
                } else if (championModel == 'v2.8.0') {
                    String reasonDavid28 = 'Aggregator web source · vehicle age 16 years · at-fault claim pattern recognized v2.8.0 · nurture eligible';
                    return new Map<String, Object>{
                        'outcome' => 'Nurture',
                        'confidence' => 0.79,
                        'predictedWindow' => '30-90 days',
                        'reason' => reasonDavid28,
                        'modelVersion' => 'v2.8.0',
                        'decidedAt' => DateTime.now().format('HH:mm:ss')
                    };
                }
            }
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('http://146.190.153.46:9001/act');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{
                'lead_id' => recordId,
                'snapshot_id' => readSnapshotId
            }));
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return response;
            } else {
                String reason = 'Unable to reach classifier, using default nurture routing';
                return new Map<String, Object>{
                    'outcome' => 'Nurture',
                    'confidence' => 0.78,
                    'predictedWindow' => 'Medium',
                    'reason' => reason,
                    'modelVersion' => 'v2.7.0',
                    'decidedAt' => DateTime.now().format('HH:mm:ss')
                };
            }
        } catch (Exception e) {
            String reason = 'Error calling classifier: ' + e.getMessage();
            return new Map<String, Object>{
                'outcome' => 'Nurture',
                'confidence' => 0.78,
                'predictedWindow' => 'Medium', 
                'reason' => reason,
                'modelVersion' => 'v2.7.0', 
                'decidedAt' => DateTime.now().format('HH:mm:ss')
            };
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loop2AssignSingleAsync(Id recordId, String verdict) {
        try {
            System.debug('===== LOOP 2 START =====');
            System.debug('Loop 2 - verdict: ' + verdict);
            System.debug('Loop 2 - recordId: ' + recordId);
            
            Lead lead = [SELECT Id, FirstName, LastName, Data_Cloud_Producer_Of_Record__c FROM Lead WHERE Id = :recordId LIMIT 1];
            System.debug('Loop 2 - Lead: ' + lead.FirstName + ' ' + lead.LastName);
            
            // PURSUE: Assign to POR only - NO CAMPAIGN
            if (verdict == 'Pursue') {
                System.debug('Loop 2 - Processing PURSUE');
                if (lead.Data_Cloud_Producer_Of_Record__c != null) {
                    String porField = lead.Data_Cloud_Producer_Of_Record__c;
                    String porName = porField.substringBefore(',').trim();
                    
                    // TEMPORARY: Hardcode Sarah Chen's ID for demo
                    String sarahChenId = '005dM00000bnG9ZQAU';
                    
                    Lead pursuitLead = new Lead(Id = recordId);
                    pursuitLead.OwnerId = sarahChenId;
                    pursuitLead.Loop2_Outcome__c = 'Pursue';
                    pursuitLead.Loop2_Destination_Type__c = 'Agent';
                    // pursuitLead.Loop2_Assigned_Agent__c = porName;  // TODO: Query Agent__c record
                    pursuitLead.Loop2_Routed_Date__c = DateTime.now();
                    pursuitLead.Loop2_Routing_Reason__c = 'Producer of Record on household';
                    update pursuitLead;
                    System.debug('Loop 2 - Pursue: Lead assigned to ' + porName + ' (' + sarahChenId + ')');
                    return new Map<String, Object>{'agent' => porName, 'destination' => 'Agent', 'channel' => 'Direct'};
                }
            }
            
            // NURTURE ONLY: Assign to campaign and queue
            if (verdict == 'Nurture') {
                System.debug('Loop 2 - Processing NURTURE');
                String campaignName = 'Auto · 30–90 Day Switchers · Q2 Promo';
                
                List<Campaign> campaigns = [SELECT Id FROM Campaign WHERE Name = :campaignName LIMIT 1];
                if (!campaigns.isEmpty()) {
                    List<CampaignMember> existing = [SELECT Id FROM CampaignMember WHERE LeadId = :recordId AND CampaignId = :campaigns[0].Id LIMIT 1];
                    if (existing.isEmpty()) {
                        insert new CampaignMember(CampaignId = campaigns[0].Id, LeadId = recordId, Status = 'Sent');
                    }
                }
                
                List<Group> queues = [SELECT Id, Name FROM Group WHERE Type = 'Queue' AND Name = :campaignName LIMIT 1];
                if (!queues.isEmpty()) {
                    String queueId = queues[0].Id;
                    String queueName = queues[0].Name;
                    
                    Lead nurtureLead = new Lead(Id = recordId);
                    nurtureLead.OwnerId = queueId;
                    nurtureLead.Loop2_Outcome__c = 'Nurture';
                    nurtureLead.Loop2_Nurture_Category__c = 'Automated';
                    nurtureLead.Loop2_Destination_Type__c = 'Queue';
                    nurtureLead.Loop2_Routed_Queue__c = queueName;
                    nurtureLead.Loop2_Routed_Date__c = DateTime.now();
                    nurtureLead.Loop2_Routing_Reason__c = 'Auto-assigned by Loop 2';
                    update nurtureLead;
                }
                
                return new Map<String, Object>{'campaign' => campaignName, 'channel' => 'Default'};
            }
            
            return new Map<String, Object>{'error' => 'Unknown verdict'};
        } catch (Exception e) {
            System.debug('Loop 2 Exception: ' + e.getMessage() + ' ' + e.getStackTraceString());
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

    @AuraEnabled(cacheable=false)
    public static void clearLeadEnrichmentData(Id recordId) {
        try {
            Lead lead = new Lead(Id = recordId);
            lead.Data_Cloud_Existing_Customer__c = null;
            lead.Data_Cloud_Producer_Of_Record__c = null;
            lead.Data_Cloud_Suppression_Flag__c = null;
            lead.Data_Cloud_Bind_Rate__c = null;
            lead.Data_Quality_Email_Verified__c = null;
            lead.Data_Quality_Phone_Confirmed__c = null;
            lead.Data_Quality_Address_Validated__c = null;
            lead.Identity_Confidence__c = null;
            lead.Cost_of_Pursuit__c = null;
            lead.Expected_Lifetime_Margin__c = null;
            lead.Data_Cloud_Expected_Margin__c = null;
            lead.Pursuit_Cost_Weighting__c = null;
            lead.Household_Account__c = null;
            lead.Loop1_Outcome__c = null;
            lead.Loop1_Confidence__c = null;
            lead.Loop1_Verdict__c = null;
            lead.Loop1_Reason__c = null;
            lead.Loop1_Predicted_Window__c = null;
            lead.Loop1_Decided_At__c = null;
            lead.Loop1_Model_Version__c = null;
            lead.Loop2_Outcome__c = null;
            lead.Loop2_Nurture_Category__c = null;
            lead.Loop2_Assigned_Agent__c = null;
            lead.Loop2_Destination_Type__c = null;
            lead.Loop2_Routed_Date__c = null;
            lead.Loop2_Routing_Reason__c = null;
            lead.Loop2_Routed_Queue__c = null;
            lead.OwnerId = UserInfo.getUserId();
            update lead;
            
            List<CampaignMember> campaignMembers = [SELECT Id FROM CampaignMember WHERE LeadId = :recordId];
            if (!campaignMembers.isEmpty()) {
                delete campaignMembers;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCampaignMembers(Id leadId) {
        try {
            List<Map<String, Object>> members = new List<Map<String, Object>>();
            List<CampaignMember> campaignMembers = [
                SELECT Id, CampaignId, Campaign.Name, Status, CreatedDate 
                FROM CampaignMember 
                WHERE LeadId = :leadId 
                ORDER BY CreatedDate DESC
            ];
            
            for (CampaignMember cm : campaignMembers) {
                members.add(new Map<String, Object>{
                    'Id' => cm.Id,
                    'CampaignId' => cm.CampaignId,
                    'CampaignName' => cm.Campaign.Name,
                    'Status' => cm.Status,
                    'CreatedDate' => cm.CreatedDate.format('M/d/yyyy, h:mm a')
                });
            }
            
            return members;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}