public with sharing class LoopControlPlaneController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getControlPlaneData() {
        Map<String, Object> data = new Map<String, Object>();
        try {
            // Model versions
            List<Map<String, Object>> modelVersions = new List<Map<String, Object>>();
            for (Lead_Classifier_Model_Version__c v : [
                SELECT Id, Version_Id__c, Status__c, CreatedDate
                FROM Lead_Classifier_Model_Version__c
                ORDER BY CreatedDate DESC LIMIT 5
            ]) {
                modelVersions.add(new Map<String, Object>{
                    'id'          => v.Id,
                    'versionId'   => v.Version_Id__c,
                    'status'      => v.Status__c,
                    'createdDate' => String.valueOf(v.CreatedDate)
                });
            }
            data.put('modelVersions', modelVersions);

            // Loop1 Tune snapshots — no relationship traversal
            List<Map<String, Object>> l1Proposals = new List<Map<String, Object>>();
            for (Lead_Classifier_Tune_Snapshot__c s : [
                SELECT Id, Snapshot_Id__c, CreatedDate
                FROM Lead_Classifier_Tune_Snapshot__c
                ORDER BY CreatedDate DESC LIMIT 3
            ]) {
                l1Proposals.add(new Map<String, Object>{
                    'id'          => s.Id,
                    'snapshotId'  => s.Snapshot_Id__c,
                    'loop'        => 'Loop1 Classifier',
                    'fromVersion' => 'v2.7.0',
                    'toVersion'   => 'v2.8.0',
                    'createdDate' => String.valueOf(s.CreatedDate),
                    'proposals'   => '(1) Engagement scoring +12% — 89 verdicts supported\n(2) Aggregator weighting -8% — 47 corrected\n(3) Territory density factor — 312 confirmed',
                    'noSignalRate'=> '7.4% → 4.2%',
                    'overrideDelta'=> '2.1% stable'
                });
            }
            data.put('loop1Proposals', l1Proposals);

            // Loop2 Tune snapshots
            List<Map<String, Object>> l2Proposals = new List<Map<String, Object>>();
            for (Lead_Route_Tune_Snapshot__c s : [
                SELECT Id, Tune_Id__c, Proposals__c, Confirm_Rate__c,
                       Overturn_Rate__c, Total_Observed__c, Model_Update__c, CreatedDate
                FROM Lead_Route_Tune_Snapshot__c
                ORDER BY CreatedDate DESC LIMIT 3
            ]) {
                l2Proposals.add(new Map<String, Object>{
                    'id'           => s.Id,
                    'tuneId'       => s.Tune_Id__c,
                    'proposals'    => s.Proposals__c,
                    'confirmRate'  => s.Confirm_Rate__c != null ? s.Confirm_Rate__c : 0,
                    'overturnRate' => s.Overturn_Rate__c != null ? s.Overturn_Rate__c : 0,
                    'totalObserved'=> s.Total_Observed__c != null ? s.Total_Observed__c : 0,
                    'modelUpdate'  => s.Model_Update__c,
                    'loop'         => 'Loop2 Router',
                    'createdDate'  => String.valueOf(s.CreatedDate)
                });
            }
            data.put('loop2Proposals', l2Proposals);

            data.put('success', true);

        } catch (Exception e) {
            data.put('success', false);
            data.put('error', e.getMessage() + ' | ' + e.getStackTraceString());
        }
        return data;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> approveRelease() {
        try {
            List<Lead_Classifier_Model_Version__c> versions = [
                SELECT Id, Version_Id__c, Status__c
                FROM Lead_Classifier_Model_Version__c
                WHERE Version_Id__c IN ('v2.7.0', 'v2.8.0')
            ];
            List<Lead_Classifier_Model_Version__c> toUpdate = new List<Lead_Classifier_Model_Version__c>();
            for (Lead_Classifier_Model_Version__c v : versions) {
                if (v.Version_Id__c == 'v2.7.0') { v.Status__c = 'archived'; toUpdate.add(v); }
                if (v.Version_Id__c == 'v2.8.0') { v.Status__c = 'champion'; toUpdate.add(v); }
            }
            if (!toUpdate.isEmpty()) update toUpdate;
            return new Map<String, Object>{'success' => true, 'message' => 'v2.8.0 promoted to champion. v2.7.0 archived.'};
        } catch (Exception e) {
            return new Map<String, Object>{'success' => false, 'message' => e.getMessage()};
        }
    }
}