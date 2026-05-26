public class LoopStageActivitiesAction {
    @InvocableMethod(label='Loop: Stage Activities' description='Create sales activities on leads for Observe window')
    public static List<StageResult> execute(List<StageRequest> requests) {
        List<StageResult> results = new List<StageResult>();
        for (StageRequest req : requests) {
            StageResult result = new StageResult();
            result.leadIds = req.leadIds;
            result.actSnapshotIds = req.actSnapshotIds;
            try {
                Date activityDate = req.activityStartDate != null ? req.activityStartDate : Date.today().addDays(1);
                List<Task> tasks = new List<Task>();
                for (String leadId : req.leadIds) {
                    tasks.add(new Task(
                        WhoId = leadId,
                        Subject = 'Follow-up Call',
                        ActivityDate = activityDate,
                        Status = 'Completed'
                    ));
                    tasks.add(new Task(
                        WhoId = leadId,
                        Subject = 'Email Sent',
                        ActivityDate = activityDate.addDays(1),
                        Status = 'Completed'
                    ));
                }
                insert tasks;
                result.success = true;
                result.message = 'Created ' + tasks.size() + ' activities starting ' + activityDate;
            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    public class StageRequest {
        @InvocableVariable(label='Lead IDs' required=true)
        public List<String> leadIds;
        @InvocableVariable(label='Act Snapshot IDs')
        public List<String> actSnapshotIds;
        @InvocableVariable(label='Activity Start Date')
        public Date activityStartDate;
    }

    public class StageResult {
        @InvocableVariable
        public Boolean success;
        @InvocableVariable
        public String message;
        @InvocableVariable
        public List<String> leadIds;
        @InvocableVariable
        public List<String> actSnapshotIds;
    }
}