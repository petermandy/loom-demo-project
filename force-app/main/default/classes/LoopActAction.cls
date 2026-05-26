global class LoopActAction {
    @InvocableMethod(label='Loop: Act' description='Classify leads via LUMEN and write Act snapshot')
    global static List<ActResult> execute(List<ActRequest> requests) {
        List<ActResult> results = new List<ActResult>();

        // Get champion model version + decision policy — query once outside loop
        String championVersion = 'v2.7.0';
        Id championVersionId = null;
        List<Lead_Classifier_Model_Version__c> champions = [
            SELECT Id, Version_Id__c FROM Lead_Classifier_Model_Version__c
            WHERE Status__c = 'champion' LIMIT 1
        ];
        if (!champions.isEmpty()) {
            championVersion = champions[0].Version_Id__c;
            championVersionId = champions[0].Id;
        }

        Id decisionPolicyId = null;
        List<Lead_Classifier_Decision_Policy_Version__c> policies = [
            SELECT Id FROM Lead_Classifier_Decision_Policy_Version__c LIMIT 1
        ];
        if (!policies.isEmpty()) decisionPolicyId = policies[0].Id;

        for (ActRequest req : requests) {
            ActResult result = new ActResult();
            result.actSnapshotIds = new List<String>();
            result.leadIds = req.leadIds;
            try {
                List<Lead> leads = [
                    SELECT Id, Name, PostalCode, AnnualRevenue, NumberOfEmployees,
                           Aggregator_Filter_Match_Score__c, Aggregator_Position_Sold__c,
                           Aggregator_Price_Paid_USD__c, Aggregator_Source_Diversity__c,
                           At_Fault_Losses_5yr__c, Broker_Internal_Score__c,
                           Distance_To_Coast_Mi__c, Distance_To_Fireline_Mi__c,
                           Fields_Corrected_Count__c, Form_Completion_Time_Sec__c,
                           Garaged_ZIP__c, Num_Drivers__c, Prior_Tenure_Years__c,
                           Property_Year_Built__c, Quotes_Requested_Count__c,
                           Time_On_Broker_Site_Sec__c, Time_To_Submit_Sec__c,
                           Times_Seen_Across_Aggregators_30d__c, Loop1_Confidence__c,
                           Quote_LOB__c, StateCode
                    FROM Lead WHERE Id IN :req.leadIds
                ];

                List<Map<String, Object>> leadsPayload = new List<Map<String, Object>>();
                for (Lead l : leads) {
                    Map<String, Object> features = new Map<String, Object>{
                        'PostalCode'                           => toNum(l.PostalCode),
                        'AnnualRevenue'                        => l.AnnualRevenue != null ? l.AnnualRevenue : 0,
                        'NumberOfEmployees'                    => l.NumberOfEmployees != null ? l.NumberOfEmployees : 0,
                        'Aggregator_Filter_Match_Score__c'     => l.Aggregator_Filter_Match_Score__c != null ? l.Aggregator_Filter_Match_Score__c : 0,
                        'Aggregator_Position_Sold__c'          => l.Aggregator_Position_Sold__c != null ? l.Aggregator_Position_Sold__c : 0,
                        'Aggregator_Price_Paid_USD__c'         => l.Aggregator_Price_Paid_USD__c != null ? l.Aggregator_Price_Paid_USD__c : 0,
                        'Aggregator_Source_Diversity__c'       => l.Aggregator_Source_Diversity__c != null ? l.Aggregator_Source_Diversity__c : 0,
                        'At_Fault_Losses_5yr__c'               => l.At_Fault_Losses_5yr__c != null ? l.At_Fault_Losses_5yr__c : 0,
                        'Broker_Internal_Score__c'             => l.Broker_Internal_Score__c != null ? l.Broker_Internal_Score__c : 0,
                        'Distance_To_Coast_Mi__c'              => l.Distance_To_Coast_Mi__c != null ? l.Distance_To_Coast_Mi__c : 0,
                        'Distance_To_Fireline_Mi__c'           => l.Distance_To_Fireline_Mi__c != null ? l.Distance_To_Fireline_Mi__c : 0,
                        'Fields_Corrected_Count__c'            => l.Fields_Corrected_Count__c != null ? l.Fields_Corrected_Count__c : 0,
                        'Form_Completion_Time_Sec__c'          => l.Form_Completion_Time_Sec__c != null ? l.Form_Completion_Time_Sec__c : 0,
                        'Garaged_ZIP__c'                       => toNum(l.Garaged_ZIP__c),
                        'Num_Drivers__c'                       => l.Num_Drivers__c != null ? l.Num_Drivers__c : 0,
                        'Prior_Tenure_Years__c'                => l.Prior_Tenure_Years__c != null ? l.Prior_Tenure_Years__c : 0,
                        'Property_Year_Built__c'               => l.Property_Year_Built__c != null ? l.Property_Year_Built__c : 0,
                        'Quotes_Requested_Count__c'            => l.Quotes_Requested_Count__c != null ? l.Quotes_Requested_Count__c : 0,
                        'Time_On_Broker_Site_Sec__c'           => l.Time_On_Broker_Site_Sec__c != null ? l.Time_On_Broker_Site_Sec__c : 0,
                        'Time_To_Submit_Sec__c'                => l.Time_To_Submit_Sec__c != null ? l.Time_To_Submit_Sec__c : 0,
                        'Times_Seen_Across_Aggregators_30d__c' => l.Times_Seen_Across_Aggregators_30d__c != null ? l.Times_Seen_Across_Aggregators_30d__c : 0,
                        'Loop1_Confidence__c'                  => l.Loop1_Confidence__c != null ? l.Loop1_Confidence__c : 0
                    };
                    leadsPayload.add(new Map<String, Object>{
                        'id'       => l.Id,
                        'features' => features
                    });
                }

                HttpRequest httpReq = new HttpRequest();
                // Use version-aware endpoint if champion is v2.8.0+
                String endpoint = 'http://146.190.153.46:9000/act';
                if (championVersion == 'v2.8.0') endpoint = 'http://146.190.153.46:9000/act_v2';
                httpReq.setEndpoint(endpoint);
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setBody(JSON.serialize(new Map<String, Object>{
                    'leads'         => leadsPayload,
                    'model_version' => championVersion
                }));
                httpReq.setTimeout(30000);
                HttpResponse res = new Http().send(httpReq);

                if (res.getStatusCode() != 200) {
                    result.success = false;
                    result.message = 'LUMEN error: HTTP ' + res.getStatusCode();
                    results.add(result);
                    continue;
                }

                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> predictions = (List<Object>) response.get('predictions');

                Map<String, Map<String, Object>> byLeadId = new Map<String, Map<String, Object>>();
                for (Object p : predictions) {
                    Map<String, Object> pd = (Map<String, Object>) p;
                    byLeadId.put((String) pd.get('id'), pd);
                }

                List<Lead> leadsToUpdate = new List<Lead>();
                List<Lead_Act_Snapshot__c> snaps = new List<Lead_Act_Snapshot__c>();
                String summaryMsg = '';

                // Get read snapshot ID if passed
                String readSnapId = (req.readSnapshotIds != null && !req.readSnapshotIds.isEmpty())
                    ? req.readSnapshotIds[0] : null;

                for (Lead lead : leads) {
                    Map<String, Object> pred = byLeadId.get(lead.Id);
                    if (pred == null) continue;

                    String verdict = (String) pred.get('verdict');
                    Decimal confidence = Decimal.valueOf(String.valueOf(pred.get('confidence')));

                    lead.Loop1_Verdict__c = verdict;
                    lead.Loop1_Confidence__c = confidence > 1 ? 1 : confidence;
                    lead.Loop1_Predicted_Window__c = verdict == 'Pursue' ? 'Immediate' :
                                                     verdict == 'Nurture' ? 'Medium' :
                                                     verdict == 'Soft_Decline' ? 'Extended' : null;
                    leadsToUpdate.add(lead);

                    snaps.add(new Lead_Act_Snapshot__c(
                        Lead__c = lead.Id,
                        Status__c = 'landed',
                        Confidence__c = confidence > 1 ? 1 : confidence,
                        Classifier_Version__c = championVersionId,
                        Decision_Policy_Version__c = decisionPolicyId,
                        Read_Snapshot__c = readSnapId,
                        Created_At__c = DateTime.now(),
                        Snapshot_Id__c = 'act-' + lead.Id + '-' + DateTime.now().getTime()
                    ));

                    summaryMsg += lead.Name + ' → ' + verdict + ' (' + confidence.setScale(2) + ') [' + championVersion + ']\n';
                }

                update leadsToUpdate;
                insert snaps;
                for (Lead_Act_Snapshot__c s : snaps) result.actSnapshotIds.add(s.Id);
                result.success = true;
                result.message = summaryMsg;

            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage() + ' | ' + e.getStackTraceString();
            }
            results.add(result);
        }
        return results;
    }

    private static Decimal toNum(String val) {
        if (val == null) return 0;
        try { return Decimal.valueOf(val.replaceAll('[^0-9.]', '')); }
        catch (Exception e) { return 0; }
    }

    global class ActRequest {
        @InvocableVariable(label='Lead IDs' required=true)
        global List<String> leadIds;
        @InvocableVariable(label='Read Snapshot IDs')
        global List<String> readSnapshotIds;
    }

    global class ActResult {
        @InvocableVariable global Boolean success;
        @InvocableVariable global String message;
        @InvocableVariable global List<String> leadIds;
        @InvocableVariable global List<String> actSnapshotIds;
    }
}