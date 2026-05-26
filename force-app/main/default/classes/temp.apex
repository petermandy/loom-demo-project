    @AuraEnabled(cacheable=false)
    public static void clearLeadEnrichmentData(Id recordId) {
        try {
            Lead lead = new Lead(Id = recordId);
            lead.Data_Cloud_Existing_Customer__c = null;
            lead.Data_Cloud_Producer_Of_Record__c = null;
            lead.Data_Cloud_Suppression_Flag__c = null;
            lead.Data_Cloud_Bind_Rate__c = null;
            lead.Loop1_Outcome__c = null;
            lead.Loop1_Confidence__c = null;
            lead.Loop1_Verdict__c = null;
            lead.Loop1_Reason__c = null;
            update lead;
            
            // Delete campaign membership
            List<CampaignMember> campaignMembers = [SELECT Id FROM CampaignMember WHERE LeadId = :recordId];
            if (!campaignMembers.isEmpty()) {
                delete campaignMembers;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
