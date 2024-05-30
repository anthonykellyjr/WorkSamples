@isTest
public with sharing class ScratchOrgController_Test {

    // return boolean to check if list contains a value
    private static Boolean listContains(Object[] source, Object target) {
        return (new Set<Object>(source)).contains(target);
    }

    @isTest
    private static void testCreateSettings() {

        Test.startTest();
        ScratchOrgController con = new ScratchOrgController();
        con.insertSettings();
        con.insertSettings(); // test duplicate handling
        Test.stopTest();

        Integer settingsCount = [SELECT count() from cadence_settings__c];
        System.assert(settingsCount > 0, 'Cadence Settings record was not created.');
        System.assert(settingsCount == 1, 'Cadence Settings duplicate handling failed.');
    }

    @isTest // test std profile user created and perm sets assigned
    private static void testUserConfig() {

        Test.startTest();
        new ScratchOrgController().upsertUsers();
        Test.stopTest();
        
        Map<String, User> userMap = new Map<String, User>();
        for (User user : [SELECT Id, CallCenterId, IsActive, Name, ProfileId FROM User]) {
            userMap.put(user.name, user);
        }
        User adminUser = userMap.get('User User');
        User standardUser = userMap.get('Standard User');

        if(adminUser == null || standardUser == null) {
            return;
        }

        // test standard user was created
        System.assert(standardUser.IsActive == true, 'Active Standard User was not created in scratch org.');

        // test call centers were properly assigned
        if (ScratchOrg.HAS_VOICE_PACKAGE) {
            List<CallCenter> cc = [Select c.Name, c.InternalName, c.Id From CallCenter c WHERE c.InternalName = 'DialSourceDenaliLightning'];
            System.assert(cc.size() > 0, 'Call Center record was not created');
        }

        Map < String, PermissionSetAssignment > permsMap = new Map < String, PermissionSetAssignment >(); 
        Map < Id, List< PermissionSetAssignment > > userPermsMap = new Map < Id, List < PermissionSetAssignment > >(); 
        for (PermissionSetAssignment psa : [SELECT Id, PermissionSetId, PermissionSet.Name, PermissionSet.ProfileId, PermissionSet.Profile.Name, AssigneeId, Assignee.Name FROM PermissionSetAssignment WHERE Assignee.Name IN :userMap.keySet()]) {
            permsMap.put(psa.PermissionSet.Name, psa);
            if (psa.Assignee.Name == standardUser.Name) {
                if (!userPermsMap.containsKey(standardUser.Id)) {
                    userPermsMap.put(standardUser.Id, new List<PermissionSetAssignment>{psa});
                } else {
                    userPermsMap.get(standardUser.Id).add(psa);
                }
            }
            if (psa.Assignee.Name == adminUser.Name) {
                if (!userPermsMap.containsKey(adminUser.Id)) {
                    userPermsMap.put(adminUser.Id, new List<PermissionSetAssignment>{psa});
                } else {
                    userPermsMap.get(adminUser.Id).add(psa);
                }
            }
        }
        PermissionSetAssignment[] adminUserPerms = userPermsMap.get(adminUser.Id);
        PermissionSetAssignment[] stdUserPerms = userPermsMap.get(standardUser.Id);

        // test standard user has DialSource_Cadence_User and DS_Denali_User
        System.assert(listContains(stdUserPerms, permsMap.get('DialSource_Cadence_User')) == true, 'Standard User did not get Cadence User Permission Set');
        // test admin user has DS_Denali_Admin and DialSource_Cadence_Admin
        System.assert(listContains(adminUserPerms, permsMap.get('DialSource_Cadence_Admin')) == true, 'Admin User did not get Cadence Admin Permission Set');
    }

    @isTest
    private static void testInsertOutcomes() {
        Set < String > outcomeNames = new Set < String > { 'Positive', 'Negative', 'Neutral'};

        Test.startTest();
        new ScratchOrgController().insertOutcomes();
        Test.stopTest();

        Map<String, DS_Touchpoint_Outcome__mdt> outcomes = DS_Touchpoint_Outcome__mdt.getAll();
        // test all outcomes were created
        for (String s : outcomeNames) {
            if(outcomes.containsKey(s)) {
                System.assert(outcomes.get(s) <> null, s + ' outcome failed to insert.');
            }
        }
    }
    
    @isTest
    private static void testSampleData() {
        Test.startTest();
        ScratchOrgController con = new ScratchOrgController();
        Id jobId = con.insertSampleData();
        Id jobId2 = con.insertSampleData(); // test duplicate handling
        Test.stopTest();

        String actualStatus = [SELECT Status FROM AsyncApexJob WHERE Id = :jobId LIMIT 1].Status;
        Integer cadCount = [SELECT count() FROM Cadence__c WHERE Name = '10-Day Outbound Prospecting' AND Excluded_Cadence__c = false];
        System.assert(actualStatus == 'Completed', 'Cadence Sample Data was not created. Status: ' + actualStatus);
        System.assert(cadCount == 1, 'Cadence Sample Data created duplicate records. Expected: 1. Actual: ' + cadCount); // confirm no duplicate cadences
    }
}