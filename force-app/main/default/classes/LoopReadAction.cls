public class LoopReadAction {
    @InvocableMethod(label='Loop: Read' description='Capture lead state and create Read Snapshots')
    public static List<ReadResult> execute(List<ReadRequest> requests) {
        List<ReadResult> results = new List<ReadResult>();
        for (ReadRequest req : requests) {
            ReadResult result = new ReadResult();
            result.readSnapshotIds = new List<String>();
            result.leadIds = req.leadIds;
            try {
                List<Lead> leads = [
                    SELECT Id, FirstName, LastName, Status,
                           PostalCode, AnnualRevenue, NumberOfEmployees,
                           Aggregator_Filter_Match_Score__c, Aggregator_Position_Sold__c,
                           Aggregator_Price_Paid_USD__c, Aggregator_Source_Diversity__c,
                           At_Fault_Losses_5yr__c, Broker_Internal_Score__c,
                           Distance_To_Coast_Mi__c, Distance_To_Fireline_Mi__c,
                           Fields_Corrected_Count__c, Form_Completion_Time_Sec__c,
                           Garaged_ZIP__c, Num_Drivers__c, Prior_Tenure_Years__c,
                           Property_Year_Built__c, Quotes_Requested_Count__c,
                           Time_On_Broker_Site_Sec__c, Time_To_Submit_Sec__c,
                           Times_Seen_Across_Aggregators_30d__c, Loop1_Confidence__c,
                           CreatedDate
                    FROM Lead WHERE Id IN :req.leadIds
                ];
                List<Lead_Read_Snapshot__c> snaps = new List<Lead_Read_Snapshot__c>();
                for (Lead l : leads) {
                    snaps.add(new Lead_Read_Snapshot__c(
                        Lead__c = l.Id,
                        Status__c = 'created',
                        Created_At__c = DateTime.now(),
                        Snapshot_Id__c = 'read-' + l.Id + '-' + DateTime.now().getTime()
                    ));
                }
                insert snaps;
                for (Lead_Read_Snapshot__c s : snaps) {
                    result.readSnapshotIds.add(s.Id);
                }
                result.success = true;
                result.message = 'Read snapshots created: ' + snaps.size();
            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    public class ReadRequest {
        @InvocableVariable(label='Lead IDs' required=true)
        public List<String> leadIds;
    }

    public class ReadResult {
        @InvocableVariable
        public Boolean success;
        @InvocableVariable
        public String message;
        @InvocableVariable
        public List<String> leadIds;
        @InvocableVariable
        public List<String> readSnapshotIds;
    }
}