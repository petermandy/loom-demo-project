public with sharing class ObserveTuneController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getTuneData() {
        try {
            Map<String, Object> data = new Map<String, Object>();
            String currentChampion = getCurrentChampionVersion();
            System.debug('===== getCurrentChampionVersion returned: ' + currentChampion);
            
            List<Map<String, Object>> cohortLeads = new List<Map<String, Object>>{
                new Map<String, Object>{'name' => 'Jennifer Park', 'status' => 'Bound', 'daysAgo' => 3, 'verdict' => 'Decision Confirmed', 'reasoning' => 'Act classified Pursue with 0.91 confidence and Immediate window. Lead bound with carrier within four days. Bind channel matches assignment. Window match: true. Decision Confirmed.'},
                new Map<String, Object>{'name' => 'Marcus Reed', 'status' => 'Window Timeout', 'daysAgo' => 5, 'verdict' => 'No-Signal', 'reasoning' => 'Still in nurture window. Not in terminal state. Excluded from this observe cycle.'}
            };
            
            List<Map<String, Object>> proposals = new List<Map<String, Object>>{
                new Map<String, Object>{'title' => 'EverQuote source · Pursue threshold tightening for leads with prior at-fault claim within 36 months', 'impact' => '312 confirmed verdicts and 47 corrected wrongs', 'change' => 'Tighten Pursue threshold'},
                new Map<String, Object>{'title' => 'Household-match signal weighting increased by 0.12 for .com source leads', 'impact' => '89 verdicts confirmed', 'change' => 'Increase weighting +0.12'},
                new Map<String, Object>{'title' => 'New pattern: VINs > 10 years on aggregator sources with credit score below 650', 'impact' => 'Convert at 6.8% vs 19% baseline. Backed by 53 verdicts.', 'change' => 'Recommend Nurture default'}
            };
            
            Map<String, Object> tuneProposal = new Map<String, Object>{'cycleStart' => '2026-05-09', 'cycleEnd' => '2026-05-14', 'verdictCount' => 1847, 'proposals' => proposals, 'noSignalRate' => '7.4%', 'overrideRate' => '2.1%', 'overrideAlert' => 'Override rate on Nurture-classified leads up 2.1% — flag for review.'};
            
            data.put('cohortLeads', cohortLeads);
            data.put('tuneProposal', tuneProposal);
            data.put('currentChampion', currentChampion);
            data.put('success', true);
            
            return data;
        } catch (Exception e) {
            System.debug('getTuneData Exception: ' + e.getMessage());
            return new Map<String, Object>{'success' => false, 'error' => e.getMessage()};
        }
    }

    private static String getCurrentChampionVersion() {
        try {
            System.debug('===== Querying Loom_Config__c');
            List<SObject> configs = Database.query('SELECT Champion_Model_Version__c FROM Loom_Config__c LIMIT 1');
            System.debug('Query result count: ' + configs.size());
            if (!configs.isEmpty()) {
                Object fieldValue = configs[0].get('Champion_Model_Version__c');
                System.debug('Field value: ' + fieldValue);
                if (fieldValue != null) {
                    return (String) fieldValue;
                }
            }
            System.debug('Returning default v2.7.0');
            return 'v2.7.0';
        } catch (Exception e) {
            System.debug('getCurrentChampionVersion Exception: ' + e.getMessage());
            return 'v2.7.0';
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> approveTuneAndPromote() {
        try {
            String currentChampion = getCurrentChampionVersion();
            String newChampion = 'v2.8.0';
            String action = 'Promote';
            
            if (currentChampion.equals('v2.8.0')) {
                newChampion = 'v2.7.0';
                action = 'Rollback';
            }
            
            List<SObject> configs = Database.query('SELECT Id, Champion_Model_Version__c FROM Loom_Config__c LIMIT 1');
            SObject config;
            if (configs.isEmpty()) {
                config = (SObject) Type.forName('Loom_Config__c').newInstance();
            } else {
                config = configs[0];
            }
            config.put('Champion_Model_Version__c', newChampion);
            upsert config;
            
            return new Map<String, Object>{'success' => true, 'message' => newChampion + ' is now the Champion Model', 'action' => action, 'newModel' => newChampion, 'previousModel' => currentChampion};
        } catch (Exception e) {
            return new Map<String, Object>{'success' => false, 'message' => e.getMessage()};
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> resetChampionModel() {
        try {
            List<SObject> configs = Database.query('SELECT Id, Champion_Model_Version__c FROM Loom_Config__c LIMIT 1');
            SObject config;
            if (configs.isEmpty()) {
                config = (SObject) Type.forName('Loom_Config__c').newInstance();
            } else {
                config = configs[0];
            }
            config.put('Champion_Model_Version__c', 'v2.7.0');
            upsert config;
            return new Map<String, Object>{'success' => true, 'message' => 'Champion model reset to v2.7.0', 'modelVersion' => 'v2.7.0'};
        } catch (Exception e) {
            return new Map<String, Object>{'success' => false, 'message' => e.getMessage()};
        }
    }
}
