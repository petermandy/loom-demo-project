public with sharing class LoopRollbackAction {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> rollback(List<String> leadIds) {
        try {
            if (leadIds == null || leadIds.isEmpty()) {
                return new Map<String, Object>{'success' => false, 'message' => 'No lead IDs provided'};
            }
            Integer deleted = 0;

            // ── Tasks + Campaign members first ──
            deleted += deleteRecords([SELECT Id FROM Task WHERE WhoId IN :leadIds]);
            deleted += deleteRecords([SELECT Id FROM CampaignMember WHERE LeadId IN :leadIds]);

            // ── Loop2 — children before parents ──
            deleted += deleteRecords([SELECT Id FROM Lead_Route_Tune_Snapshot__c]);
            deleted += deleteRecords([SELECT Id FROM Lead_Route_Observe_Snapshot__c WHERE Lead__c IN :leadIds]);
            deleted += deleteRecords([SELECT Id FROM Lead_Route_Act_Snapshot__c WHERE Lead__c IN :leadIds]);
            deleted += deleteRecords([SELECT Id FROM Lead_Route_Read_Snapshot__c WHERE Lead__c IN :leadIds]);

            // ── Loop1 — children before parents ──
            deleted += deleteRecords([SELECT Id FROM Lead_Classifier_Tune_Snapshot__c]);
            deleted += deleteRecords([SELECT Id FROM Lead_Observe_Snapshot__c WHERE Lead__c IN :leadIds]);
            deleted += deleteRecords([SELECT Id FROM Lead_Act_Snapshot__c WHERE Lead__c IN :leadIds]);
            deleted += deleteRecords([SELECT Id FROM Lead_Read_Snapshot__c WHERE Lead__c IN :leadIds]);

            // ── Reset lead fields ──
            Id currentUser = UserInfo.getUserId();
            List<Lead> leads = [SELECT Id FROM Lead WHERE Id IN :leadIds];
            for (Lead l : leads) {
                l.Loop1_Verdict__c = null;
                l.Loop1_Confidence__c = null;
                l.Loop1_Predicted_Window__c = null;
                l.Loop2_Destination_Type__c = null;
                l.Loop2_Routed_Queue__c = null;
                l.Loop2_Routed_Date__c = null;
                l.Loop2_Routing_Reason__c = null;
                l.Loop2_Assigned_Agent__c = null;
                l.Loop2_Nurture_Category__c = null;
                l.Loop2_Outcome__c = 'pending';
                l.OwnerId = currentUser;
            }
            update leads;

            // ── Reset model versions — champion=v2.7.0, shadow=v2.8.0 ──
            List<Lead_Classifier_Model_Version__c> versions = [
                SELECT Id, Version_Id__c, Status__c
                FROM Lead_Classifier_Model_Version__c
                WHERE Version_Id__c IN ('v2.7.0', 'v2.8.0')
            ];
            List<Lead_Classifier_Model_Version__c> toUpdate = new List<Lead_Classifier_Model_Version__c>();
            for (Lead_Classifier_Model_Version__c v : versions) {
                if (v.Version_Id__c == 'v2.7.0' && v.Status__c != 'champion') {
                    v.Status__c = 'champion'; toUpdate.add(v);
                }
                if (v.Version_Id__c == 'v2.8.0' && v.Status__c != 'shadow') {
                    v.Status__c = 'shadow'; toUpdate.add(v);
                }
            }
            if (!toUpdate.isEmpty()) update toUpdate;

            return new Map<String, Object>{
                'success' => true,
                'message' => '✓ Rollback complete — ' + deleted + ' records deleted, '
                    + leads.size() + ' leads reset, model versions restored'
            };

        } catch (Exception e) {
            return new Map<String, Object>{'success' => false, 'message' => 'Rollback error: ' + e.getMessage()};
        }
    }

    private static Integer deleteRecords(List<SObject> records) {
        if (records.isEmpty()) return 0;
        delete records;
        return records.size();
    }
}
