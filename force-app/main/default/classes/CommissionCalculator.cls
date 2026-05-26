public class CommissionCalculator {
    public static void calculateMonthlyCommissions() {
        Date monthStart = Date.today().addDays(-(Date.today().day() - 1));
        Date monthEnd = monthStart.addMonths(1).addDays(-1);
        List<Agent__c> agents = [SELECT Id, Name, Commission_Tier__c, User__c FROM Agent__c WHERE Active__c = true];
        List<Commission_Record__c> toCreate = new List<Commission_Record__c>();
        for (Agent__c agent : agents) {
            Integer leadCount = [SELECT COUNT() FROM Lead WHERE OwnerId = :agent.User__c AND CreatedDate >= :monthStart AND CreatedDate <= :monthEnd];
            if (leadCount == 0) continue;
            List<Lead> converted = [SELECT Id, Aggregator_Price_Paid_USD__c FROM Lead WHERE OwnerId = :agent.User__c AND IsConverted = true AND ConvertedDate >= :monthStart AND ConvertedDate <= :monthEnd];
            Decimal totalPremium = 0;
            for (Lead l : converted) {
                if (l.Aggregator_Price_Paid_USD__c != null) totalPremium += l.Aggregator_Price_Paid_USD__c;
            }
            Decimal pct = 8;
            if (agent.Commission_Tier__c == 'Tier 1') pct = 12;
            if (agent.Commission_Tier__c == 'Tier 2') pct = 10;
            Commission_Record__c rec = new Commission_Record__c();
            rec.Agent__c = agent.Id;
            rec.Month__c = monthStart;
            rec.Lead_Count__c = leadCount;
            rec.Closed_Count__c = converted.size();
            rec.Close_Rate__c = leadCount > 0 ? (converted.size() * 100.0 / leadCount) : 0;
            rec.Total_Premium__c = totalPremium;
            rec.Commission_Percent__c = pct;
            rec.Commission_Amount__c = totalPremium * pct / 100;
            rec.Status__c = 'Calculated';
            toCreate.add(rec);
        }
        if (!toCreate.isEmpty()) insert toCreate;
        System.debug('Commissions calculated: ' + toCreate.size());
    }
}
