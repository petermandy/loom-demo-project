public class AgentPerformanceAggregator {
    public static void aggregateMonthlyMetrics() {
        List<Agent__c> agents = [SELECT Id, User__c FROM Agent__c WHERE Active__c = true];
        List<Agent_Performance__c> toInsert = new List<Agent_Performance__c>();
        Date periodStart = Date.today().addDays(-(Date.today().day() - 1));
        Date periodEnd = periodStart.addMonths(1).addDays(-1);
        for (Agent__c agent : agents) {
            List<Lead> leads = [SELECT Id, IsConverted, ConvertedDate, Aggregator_Price_Paid_USD__c FROM Lead WHERE OwnerId = :agent.User__c AND CreatedDate >= :periodStart AND CreatedDate <= :periodEnd];
            Integer assigned = leads.size();
            Integer converted = 0;
            Decimal totalPremium = 0;
            Integer totalDays = 0;
            for (Lead l : leads) {
                if (l.IsConverted && l.ConvertedDate != null) {
                    converted++;
                    totalDays += periodStart.daysBetween(l.ConvertedDate);
                    if (l.Aggregator_Price_Paid_USD__c != null) totalPremium += l.Aggregator_Price_Paid_USD__c;
                }
            }
            Agent_Performance__c perf = new Agent_Performance__c();
            perf.Agent__c = agent.Id;
            perf.Metric_Period__c = 'Monthly';
            perf.Period_Start__c = periodStart;
            perf.Period_End__c = periodEnd;
            perf.Leads_Assigned__c = assigned;
            perf.Leads_Converted__c = converted;
            perf.Conversion_Rate__c = assigned > 0 ? (converted * 100.0 / assigned) : 0;
            perf.Avg_Days_to_Close__c = converted > 0 ? (totalDays / converted) : 0;
            perf.Total_Premium_Written__c = totalPremium;
            perf.Avg_Premium_Per_Lead__c = assigned > 0 ? (totalPremium / assigned) : 0;
            toInsert.add(perf);
        }
        if (!toInsert.isEmpty()) insert toInsert;
        System.debug('Performance aggregated: ' + toInsert.size() + ' agents');
    }
}
