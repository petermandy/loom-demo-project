@isTest
public class LoopDemoTests {
    
    @testSetup
    static void setupTestData() {
        // Create Sarah Chen user
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User sarahChen = new User(
            FirstName = 'Sarah',
            LastName = 'Chen',
            Email = 'sarah.chen@test.com',
            Username = 'sarah.chen@test.com',
            ProfileId = sysAdminProfile.Id,
            Alias = 'schen',
            TimeZoneSidKey = 'America/Denver',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert sarahChen;
        
        // Create test leads
        List<Lead> testLeads = new List<Lead>{
            new Lead(FirstName = 'Jennifer', LastName = 'Park', Company = 'Self', LeadSource = 'Web'),
            new Lead(FirstName = 'Marcus', LastName = 'Reed', Company = 'Self', LeadSource = 'Web'),
            new Lead(FirstName = 'David', LastName = 'Kowalski', Company = 'Self', LeadSource = 'Web')
        };
        insert testLeads;
        
        // Create Loom Config custom setting
        Loom_Config__c config = new Loom_Config__c();
        config.Champion_Model_Version__c = 'v2.7.0';
        upsert config;
    }
    
    @isTest
    static void testDavidHardDisqualifyV270() {
        Lead david = [SELECT Id, FirstName, LastName FROM Lead WHERE FirstName = 'David' LIMIT 1];
        
        // Test Read phase
        Map<String, Object> readResult = Loop1OrchestratorController.readLeadSingleAsync(david.Id);
        System.assertEquals(true, readResult.get('success'));
        
        // Test Act phase with v2.7.0
        Map<String, Object> actResult = Loop1OrchestratorController.actLeadSingleAsync(david.Id, null);
        System.assertEquals('Hard Disqualify', actResult.get('outcome'));
        System.assertEquals(0.88, actResult.get('confidence'));
        System.assertEquals('v2.7.0', actResult.get('modelVersion'));
    }
    
    @isTest
    static void testDavidNurtureV280() {
        Lead david = [SELECT Id, FirstName, LastName FROM Lead WHERE FirstName = 'David' LIMIT 1];
        
        // Set champion to v2.8.0
        Loom_Config__c config = Loom_Config__c.getOrgDefaults();
        config.Champion_Model_Version__c = 'v2.8.0';
        upsert config;
        
        // Test Act phase with v2.8.0
        Map<String, Object> actResult = Loop1OrchestratorController.actLeadSingleAsync(david.Id, null);
        System.assertEquals('Nurture', actResult.get('outcome'));
        System.assertEquals(0.79, actResult.get('confidence'));
        System.assertEquals('v2.8.0', actResult.get('modelVersion'));
    }
    
    @isTest
    static void testJenniferPursue() {
        Lead jennifer = [SELECT Id, FirstName, LastName FROM Lead WHERE FirstName = 'Jennifer' LIMIT 1];
        
        // Test Read phase
        Map<String, Object> readResult = Loop1OrchestratorController.readLeadSingleAsync(jennifer.Id);
        System.assertEquals(true, readResult.get('success'));
        
        // Verify household account was created
        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name = 'Park Household'];
        System.assertEquals(1, accounts.size());
        
        // Test Act phase - Jennifer should always be Pursue
        Map<String, Object> actResult = Loop1OrchestratorController.actLeadSingleAsync(jennifer.Id, null);
        System.assertEquals('Pursue', actResult.get('outcome'));
        System.assertEquals(0.91, actResult.get('confidence'));
    }
    
    @isTest
    static void testJenniferLoop2Routing() {
        Lead jennifer = [SELECT Id, FirstName, LastName FROM Lead WHERE FirstName = 'Jennifer' LIMIT 1];
        User sarahChen = [SELECT Id FROM User WHERE FirstName = 'Sarah' AND LastName = 'Chen' LIMIT 1];
        
        // Set verdict
        jennifer.Loop1_Outcome__c = 'Pursue';
        update jennifer;
        
        // Test Loop 2 routing with Pursue verdict
        Map<String, Object> loop2Result = Loop1OrchestratorController.loop2AssignSingleAsync(jennifer.Id, 'Pursue');
        System.assertEquals(true, loop2Result.get('success'));
        
        // Verify lead was assigned to Sarah
        Lead updatedLead = [SELECT OwnerId, Loop2_Outcome__c FROM Lead WHERE Id = :jennifer.Id];
        System.assertEquals(sarahChen.Id, updatedLead.OwnerId);
        System.assertEquals('Pursue', updatedLead.Loop2_Outcome__c);
    }
    
    @isTest
    static void testObserveTuneDashboard() {
        Map<String, Object> tuneData = ObserveTuneController.getTuneData();
        System.assertEquals(true, tuneData.get('success'));
        
        Map<String, Object> cohortLeads = (Map<String, Object>) tuneData.get('cohortLeads');
        System.assertNotEquals(null, cohortLeads);
    }
    
    @isTest
    static void testPromoteV280() {
        // Verify starting at v2.7.0
        Loom_Config__c config = Loom_Config__c.getOrgDefaults();
        System.assertEquals('v2.7.0', config.Champion_Model_Version__c);
        
        // Approve and promote
        Map<String, Object> promoteResult = ObserveTuneController.approveTuneAndPromote();
        System.assertEquals(true, promoteResult.get('success'));
        System.assertEquals('v2.8.0', promoteResult.get('newModel'));
        
        // Verify config updated
        Loom_Config__c updatedConfig = Loom_Config__c.getOrgDefaults();
        System.assertEquals('v2.8.0', updatedConfig.Champion_Model_Version__c);
    }
    
    @isTest
    static void testRollbackV270() {
        // Set to v2.8.0 first
        Loom_Config__c config = Loom_Config__c.getOrgDefaults();
        config.Champion_Model_Version__c = 'v2.8.0';
        upsert config;
        
        // Reset to v2.7.0
        Map<String, Object> resetResult = ObserveTuneController.resetChampionModel();
        System.assertEquals(true, resetResult.get('success'));
        System.assertEquals('v2.7.0', resetResult.get('modelVersion'));
        
        // Verify config updated
        Loom_Config__c updatedConfig = Loom_Config__c.getOrgDefaults();
        System.assertEquals('v2.7.0', updatedConfig.Champion_Model_Version__c);
    }
    
    @isTest
    static void testClosedLoopDavid() {
        Lead david = [SELECT Id FROM Lead WHERE FirstName = 'David' LIMIT 1];
        
        // Run 1: v2.7.0 Hard Disqualify
        Map<String, Object> run1 = Loop1OrchestratorController.actLeadSingleAsync(david.Id, null);
        System.assertEquals('Hard Disqualify', run1.get('outcome'));
        
        // Promote to v2.8.0
        ObserveTuneController.approveTuneAndPromote();
        
        // Run 2: v2.8.0 Nurture (same lead, different outcome)
        Map<String, Object> run2 = Loop1OrchestratorController.actLeadSingleAsync(david.Id, null);
        System.assertEquals('Nurture', run2.get('outcome'));
        
        // Verify the model learned
        System.assertNotEquals(run1.get('outcome'), run2.get('outcome'), 'Model should produce different verdict on v2.8.0');
    }
}
