public class LoopObserveAction {
    private static final String OBSERVE_ENDPOINT = 'http://146.190.153.46:9000/observe';
    private static final String REASONING_AGENT_VERSION = 'claude-sonnet-4-20250514';
    private static final String TUNE_CONTEXT_VERSION = 'v4.2';

    @InvocableMethod(label='Loop: Observe' description='Call Lumen /observe with activity context')
    public static List<ObserveResult> execute(List<ObserveRequest> requests) {
        List<ObserveResult> results = new List<ObserveResult>();

        Lead_Classifier_Model_Version__c modelVersion;
        List<Lead_Classifier_Model_Version__c> mvList = [
            SELECT Id FROM Lead_Classifier_Model_Version__c
            WHERE Version_Id__c = 'v2.7.0' AND Status__c = 'champion' LIMIT 1
        ];
        if (!mvList.isEmpty()) modelVersion = mvList[0];

        for (ObserveRequest req : requests) {
            ObserveResult result = new ObserveResult();
            try {
                List<Lead> leads = [
                    SELECT Id, FirstName, LastName, Status, CreatedDate,
                           Loop1_Verdict__c, Loop1_Confidence__c
                    FROM Lead WHERE Id IN :req.leadIds
                ];

                Map<Id, Integer> taskCountMap = new Map<Id, Integer>();
                for (AggregateResult ar : [
                    SELECT WhoId, COUNT(Id) cnt
                    FROM Task WHERE WhoId IN :req.leadIds
                    GROUP BY WhoId
                ]) {
                    taskCountMap.put((Id) ar.get('WhoId'), (Integer) ar.get('cnt'));
                }

                Map<Id, Lead_Act_Snapshot__c> actSnapMap = new Map<Id, Lead_Act_Snapshot__c>();
                if (req.actSnapshotIds != null && !req.actSnapshotIds.isEmpty()) {
                    for (Lead_Act_Snapshot__c s : [
                        SELECT Id, Lead__c, Verdict__c, Confidence__c
                        FROM Lead_Act_Snapshot__c WHERE Id IN :req.actSnapshotIds
                    ]) {
                        actSnapMap.put(s.Lead__c, s);
                    }
                }

                List<Map<String, Object>> observations = new List<Map<String, Object>>();
                for (Lead l : leads) {
                    Lead_Act_Snapshot__c actSnap = actSnapMap.containsKey(l.Id) ? actSnapMap.get(l.Id) : null;
                    Integer taskCount = taskCountMap.containsKey(l.Id) ? taskCountMap.get(l.Id) : 0;
                    Integer daysElapsed = l.CreatedDate.date().daysBetween(Date.today());

                    observations.add(new Map<String, Object>{
                        'id' => l.Id,
                        'act_verdict' => actSnap != null ? actSnap.Verdict__c : l.Loop1_Verdict__c,
                        'act_confidence' => actSnap != null ? actSnap.Confidence__c : l.Loop1_Confidence__c,
                        'act_reason' => 'Loop1_classifier',
                        'predicted_window' => 'Medium',
                        'activity' => new Map<String, Object>{
                            'days_elapsed' => daysElapsed,
                            'status' => l.Status,
                            'tasks_completed' => taskCount,
                            'emails_sent' => 1,
                            'converted' => false,
                            'opportunity_stage' => null,
                            'opportunity_amount' => null,
                            'terminal_state' => null
                        }
                    });
                }

                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint(OBSERVE_ENDPOINT);
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setBody(JSON.serialize(new Map<String, Object>{ 'observations' => observations }));
                HttpResponse resp = new Http().send(httpReq);

                Map<String, Object> respBody = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
                List<Object> obsResults = (List<Object>) respBody.get('results');

                List<Lead_Observe_Snapshot__c> snaps = new List<Lead_Observe_Snapshot__c>();
                Integer idx = 0;
                for (Object obsResult : obsResults) {
                    Map<String, Object> o = (Map<String, Object>) obsResult;
                    String leadId = (String) o.get('id');
                    String verdict = (String) o.get('observe_verdict');
                    String reasoning = (String) o.get('reasoning');
                    String actSnapId = req.actSnapshotIds != null && req.actSnapshotIds.size() > idx ? req.actSnapshotIds[idx] : null;

                    String terminalState = 'window_timeout';
                    if (verdict == 'Decision_Confirmed') terminalState = 'bound';
                    else if (verdict == 'Decision_Wrong') terminalState = 'lost';

                    snaps.add(new Lead_Observe_Snapshot__c(
                        Lead__c = leadId,
                        Act_Snapshot__c = actSnapId,
                        Verdict__c = verdict,
                        Terminal_State__c = terminalState,
                        Status__c = 'created',
                        Classifier_Version_Evaluated__c = modelVersion != null ? modelVersion.Id : null,
                        Reasoning_Agent_Version__c = REASONING_AGENT_VERSION,
                        Tune_Context_Version__c = TUNE_CONTEXT_VERSION,
                        Created_At__c = DateTime.now(),
                        Snapshot_Id__c = 'obs-' + leadId + '-' + DateTime.now().getTime()
                    ));

                    String displayName = leadId;
                    for (Lead l : leads) {
                        if (l.Id == leadId) { displayName = l.FirstName + ' ' + l.LastName; break; }
                    }
                    result.message = (result.message == null ? '' : result.message) +
                        displayName + ': ' + verdict + ' — ' + reasoning + '\n';
                    idx++;
                }
                insert snaps;
                result.success = true;
            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    public class ObserveRequest {
        @InvocableVariable(label='Lead IDs' required=true)
        public List<String> leadIds;
        @InvocableVariable(label='Act Snapshot IDs')
        public List<String> actSnapshotIds;
    }

    public class ObserveResult {
        @InvocableVariable
        public Boolean success;
        @InvocableVariable
        public String message;
    }
}