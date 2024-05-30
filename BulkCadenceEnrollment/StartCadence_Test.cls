@isTest
public with sharing class StartCadence_Test {
    @TestSetup
    static void makeData(){
        TestFactory.setStage(20);
        TestFactory.createUser('Standard User');

        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        opp.AccountId = acc.Id;
        con.AccountId = acc.Id;

        update opp;
        update con;
    }

    static List<Cadence_Member__c> getCadenceMemberList() {
        return [
            SELECT Id, Cadence_Lookup__c, Cadence_Lookup__r.Name, Next_Touchpoint__r.Number__c, Assigned__c, Lead__c, 
                Account__c, Contact__c, Opportunity__c, Status__c, Active__c, Object_Id_Ex__c, 
                Related_Object_Type__c, Team_Cadence__c 
            FROM Cadence_Member__c
        ];
    }

    // Runs common assert tests for standard enrollment
    static void runAssertsForStandardEnrollment(Id recordId, Id cadenceId, Id assignedUserId, String sObjectName, Cadence_Member__c cadMem) {
        String sObjectDevName = sObjectName + '__c';
        List<String> unrelatedSObjects = new List<String>{'Lead__c', 'Account__c', 'Contact__c', 'Opportunity__c'};
        
        // Removes the related sObject from the list
        unrelatedSObjects.remove(unrelatedSObjects.indexOf(sObjectDevName));

        // Ensures that the Account field is populated on Opportunity and Contact enrollments
        if (sObjectName != 'Lead' && sObjectName != 'Account') {
            unrelatedSObjects.remove(unrelatedSObjects.indexOf('Account__c'));
            System.assertNotEquals(null, cadMem.get('Account__c'), 'Cadence Member should have a related ' + 'Account__c' + ' sObject.');
        }

        // Assert standard assignments
        System.assertEquals(assignedUserId, cadMem.Assigned__c, 'Cadence Member should be assigned to standard user.');
        System.assertEquals(recordId, cadMem.Object_Id_Ex__c, 'Cadence member field Object_Id_Ex__c should equal the ' + sObjectName + ' Id.');
        System.assertEquals(cadenceId, cadMem.Cadence_Lookup__c, 'Cadence Member should be assigned to the \'' + cadMem.Cadence_Lookup__r.Name + '\' Cadence.');

        // Assert constant values
        System.assertEquals(true, cadMem.Active__c, 'Cadence member should be active');
        System.assertEquals(false, cadMem.Team_Cadence__c, 'Cadence member should not be flagged for a Team Cadence.');
        System.assertEquals(sObjectName, cadMem.Related_Object_Type__c, 'Cadence member field Related_Object_Type__c should equal \'' + sObjectName + '\'.');
        
        // Assert that the correct sobject relationship field is populated.
        System.assertEquals(recordId, cadMem.get(sObjectDevName), 'Cadence Member should have a related ' + sObjectName + ' sObject.');

        //Assert that the unrelated sobject fields are null.
        for (String devName : unrelatedSObjects) {
            String sObjName = devName.split('__c')[0];
            System.assertEquals(null, cadMem.get(devName), 'Cadence Member should not have a related ' + sObjName + ' sObject.');
        }
    }

    // Runs the common test for standard enrollment.
    static void runStandardEnrollmentTest(String sObjName, Boolean runAsStdUser, Boolean runAsync) {
        List <StartCadence.Request> enrollReqs = new List<StartCadence.Request>();

        User stdUser = [SELECT Id FROM USER WHERE LastName = 'Testing'];
        Id cadId = [SELECT Id FROM Cadence__c LIMIT 1].Id;
        Id testRecordId = Database.query('SELECT Id FROM ' + sObjName + ' LIMIT 1')[0].Id;

        // Create a list of requests for enrollment.
        enrollReqs.add(new StartCadence.Request(testRecordId, cadId, stdUser.Id));

        // Initialize async service
        StartCadence.StartCadenceAsync asyncCadService = new StartCadence.StartCadenceAsync(enrollReqs);

        Test.startTest();

        if (runAsync) {
            System.enqueueJob(asyncCadService);
        } else if (runAsStdUser) {
            System.runAs(stdUser) {
                StartCadence.StartCadence(enrollReqs);
            }
        } else {
            StartCadence.StartCadence(enrollReqs);
        }

        Test.stopTest();

        List<Cadence_Member__c> cadMemList = getCadenceMemberList();
        System.assertEquals(1, cadMemList.size(), 'One and only one cadence member should be created for this test.');
        
        Cadence_Member__c cadMem = cadMemList[0];
        runAssertsForStandardEnrollment(testRecordId, cadId, stdUser.Id, sObjName, cadMem);
    }

    // Runs common test for enrollments that have a specified start step and datetime
    static void runEnrollmentTestWithStartingStepAndDatetime(String sObjName, Boolean runAsStdUser, Boolean runAsync) {
        List <StartCadence.Request> enrollReqs = new List<StartCadence.Request>();

        User stdUser = [SELECT Id FROM USER WHERE LastName = 'Testing'];
        Id cadId = [SELECT Id FROM Cadence__c LIMIT 1].Id;
        Id testRecordId = Database.query('SELECT Id FROM ' + sObjName + ' LIMIT 1')[0].Id;

        Datetime startDateTime = Datetime.now();

        // Create a list of requests for enrollment.
        enrollReqs.add(new StartCadence.Request(testRecordId, cadId, stdUser.Id, 3, startDateTime));
        StartCadence.StartCadenceAsync asyncCadService = new StartCadence.StartCadenceAsync(enrollReqs);


        Test.startTest();

        if (runAsync) {
            System.enqueueJob(asyncCadService);
        } else if (runAsStdUser) {
            System.runAs(stdUser) {
                StartCadence.StartCadence(enrollReqs);
            }
        } else {
            StartCadence.StartCadence(enrollReqs);
        }

        Test.stopTest();

        List<Cadence_Member__c> cadMemList = getCadenceMemberList();
        System.assertEquals(1, cadMemList.size(), 'One and only one cadence member should be created.');
        
        Cadence_Member__c cadMem = cadMemList[0];
        runAssertsForStandardEnrollment(testRecordId, cadId, stdUser.Id, sObjName, cadMem);
        
        Decimal actualStartingStep = cadMem.Next_Touchpoint__r.Number__c;
        System.assertEquals(3, actualStartingStep, 'Cadence Member should have started at step 3.');
    }

    // Runs common test for invalid cadence assignments
    static void runInvalidCadenceAssignmentTest(String field) {
        Map<String, Object> invalidValues = new Map<String, Object>{
            'Start_Date__c' => Date.today() + 1,
            'End_Date__c' => Date.today() - 1,
            'Active__c' => false,
            'Number_Of_Steps__c' => 0
        };
        
        String sObjName = 'Lead';
        User stdUser = [SELECT Id FROM USER WHERE LastName = 'Testing'];
        List <StartCadence.Request> enrollReqs = new List<StartCadence.Request>();
        Cadence__c cad = [
            SELECT Id, Start_Date__c, End_Date__c, 
                Active__c, Number_Of_Steps__c 
            FROM Cadence__c 
            LIMIT 1
        ];
        Cadence__c invalidCad = cad.clone();
        
        Object invalidValue = invalidValues.get(field);
        invalidCad.put(field, invalidValue);

        insert invalidCad;

        Id testRecordId = Database.query('SELECT Id FROM ' + sObjName + ' LIMIT 1')[0].Id;

        // Create a list of requests for enrollment.
        enrollReqs.add(new StartCadence.Request(testRecordId, invalidCad.Id, stdUser.Id));
        
        try {
            Test.startTest();
            StartCadence.StartCadence(enrollReqs);
            Test.stopTest();

            // Fails test if no exception is thrown
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', null, 
                'An exception should be thrown! Testing invalid cadence assignment with ' + field + ' field.');
        } catch (Exception e) {

            // Fails test if the incorrect exception is thrown
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', e.getTypeName(), 
                'Unexpected exception thrown! Testing invalid cadence assignment with ' + field + ' field.');
            
            List<Cadence_Member__c> cadMemList = getCadenceMemberList();

            System.assertEquals(0, cadMemList.size(), 
                'No cadence members should be created. Testing invalid cadence assignment with ' + field + ' field.');
        }
    }

    // Run common tests that check for custom setting functionality
    static void runCustomSettingTest(String testSettingName, Map<String, Object> settings) {
        List<Cadence__c> cadList = [
            SELECT Id, Start_Date__c, End_Date__c, 
                Active__c, Number_Of_Steps__c, Business_Hours__c
            FROM Cadence__c 
            LIMIT 2
        ];

        Cadence__c cad = cadList[0];
        Cadence__c cad2 = cadList[1];

        User stdUser;
        stdUser = [SELECT Id FROM USER WHERE LastName = 'Testing'];

        /*
        if (testSettingName != 'Prevent_Read_Only_Enrollment__c') {
            stdUser = [SELECT Id FROM USER WHERE LastName = 'Testing'];
        } else {
            stdUser = Testfactory.createUser('Read Only');
        }
        */

        List <StartCadence.Request> enrollReqs = new List<StartCadence.Request>();
        List <StartCadence.Request> dupeEmailEnrollReqs = new List<StartCadence.Request>();
        List <StartCadence.Request> dupeCadEnrollReqs = new List<StartCadence.Request>();
        List <StartCadence.Request> multiEnrollReqs = new List<StartCadence.Request>();
        List <StartCadence.Request> globalCapEnrollReqs = new List<StartCadence.Request>();

        Lead leadRecord = [SELECT Id, Email, LastName, Company FROM Lead LIMIT 1];
        Lead leadRecord2 = leadRecord.clone();

        leadRecord.Email = 'Testing1@example.com';
        leadRecord2.Email  = 'Testing2@example.com';

        Lead leadRecordDupe = leadRecord.clone();
        leadRecordDupe.LastName = 'Test';
        
        update leadRecord;
        insert leadRecord2;
        insert leadRecordDupe;

        // Create a list of requests for enrollment.
        enrollReqs.add(new StartCadence.Request(leadRecord.Id, cad.Id, stdUser.Id));
        multiEnrollReqs.add(new StartCadence.Request(leadRecord.Id, cad2.Id, stdUser.Id));
        dupeCadEnrollReqs.add(new StartCadence.Request(leadRecord.Id, cad.Id, stdUser.Id));
        dupeEmailEnrollReqs.add(new StartCadence.Request(leadRecordDupe.Id, cad2.Id, stdUser.Id));
        globalCapEnrollReqs.add(new StartCadence.Request(leadRecord2.Id, cad.Id, stdUser.Id));

        // Make org default settings
        Cadence_Settings__c orgDefaultSettings = new Cadence_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );

        for (String setting : settings.keySet()) {
            orgDefaultSettings.put(setting, settings.get(setting));
        }

        insert orgDefaultSettings;
        
        Test.startTest();
        
        StartCadence.startCadence(enrollReqs);
        switch on testSettingName {
            when 'Prevent_Duplicate_Email_Addresses__c' {
                StartCadence.startCadence(dupeEmailEnrollReqs);
            }
            when 'Allow_Duplicate_Active_Cadences__c' {
                StartCadence.startCadence(dupeCadEnrollReqs);
            }
            when 'Allow_Multiple_Active_Cadences__c' {
                StartCadence.startCadence(multiEnrollReqs);
            }
            when 'Active_Enrollment_Cap__c' {
                StartCadence.startCadence(globalCapEnrollReqs);
            }
        }

        Test.stopTest();
    }

    // enrolls an unenrolled record
    static void enrollNewRecord(Id uid, Id cadId, String objName) {
        Id recId = Database.query('SELECT Id FROM ' + objName + ' WHERE Last_Cadence_Started_Date__c = null LIMIT 1')[0].Id;

        List<StartCadence.Request> reqs = new List<StartCadence.Request>{
            new StartCadence.Request( recId, cadId, uid )
        };

        StartCadence.startCadence(reqs);
    }

    @isTest
    static void testLeadStandardEnrollment() {
        runStandardEnrollmentTest('Lead', false, false);
    }
    
    @isTest
    static void testLeadStandardEnrollmentAsync() {
        runStandardEnrollmentTest('Lead', false, true);
    }
    
    @isTest
    static void testAccountStandardEnrollment() {
        runStandardEnrollmentTest('Account', false, false);
    }

    @isTest
    static void testAccountStandardEnrollmentAsync() {
        runStandardEnrollmentTest('Account', false, true);
    }

    @isTest
    static void testContactStandardEnrollment() {
        runStandardEnrollmentTest('Contact', false, false);
    }

    @isTest
    static void testContactStandardEnrollmentAsync() {
        runStandardEnrollmentTest('Contact', false, true);
    }

    @isTest
    static void testOpportunityStandardEnrollment() {
        runStandardEnrollmentTest('Opportunity', false, false);
    }

    @isTest
    static void testOpportunityStandardEnrollmentAsync() {
        runStandardEnrollmentTest('Opportunity', false, true);
    }

    @isTest
    static void testLeadEnrollmentWithStartingStepAndDatetime() {
        runEnrollmentTestWithStartingStepAndDatetime('Lead', false, false);
    }

    @isTest
    static void testLeadEnrollmentWithStartingStepAndDatetimeAsync() {
        runEnrollmentTestWithStartingStepAndDatetime('Lead', false, true);
    }

    @isTest
    static void testAccountEnrollmentWithStartingStepAndDatetime() {
        runEnrollmentTestWithStartingStepAndDatetime('Account', false, false);
    }

    @isTest
    static void testAccountEnrollmentWithStartingStepAndDatetimeAsync() {
        runEnrollmentTestWithStartingStepAndDatetime('Account', false, true);
    }

    @isTest
    static void testContactEnrollmentWithStartingStepAndDatetime() {
        runEnrollmentTestWithStartingStepAndDatetime('Contact', false, false);
    }

    @isTest
    static void testContactEnrollmentWithStartingStepAndDatetimeAsync() {
        runEnrollmentTestWithStartingStepAndDatetime('Contact', false, true);
    }

    @isTest
    static void testOpportunityEnrollmentWithStartingStepAndDatetime() {
        runEnrollmentTestWithStartingStepAndDatetime('Opportunity', false, false);
    }

    @isTest
    static void testOpportunityEnrollmentWithStartingStepAndDatetimeAsync() {
        runEnrollmentTestWithStartingStepAndDatetime('Opportunity', false, true);
    }

    @isTest
    static void testInvalidStartDate() {
        runInvalidCadenceAssignmentTest('Start_Date__c');
    }

    @isTest
    static void testInvalidEndDate() {
        runInvalidCadenceAssignmentTest('End_Date__c');
    }

    @isTest
    static void testInvalidActiveStatus() {
        runInvalidCadenceAssignmentTest('Active__c');
    }

    @isTest
    static void testInvalidNumOfSteps() {
        runInvalidCadenceAssignmentTest('Number_of_Steps__c');
    }

    @isTest
    static void testPreventDuplicateEmailAddress() {
        try {
            Map<String, Object> settings = new Map<String, Object> { 
                'Prevent_Duplicate_Email_Addresses__c' => true
            };
    
            runCustomSettingTest('Prevent_Duplicate_Email_Addresses__c', settings);
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', null, 
                'An exception should be thrown!');
        } catch (Exception e) {
            System.assertEquals(
                'There is already an Active Cadence Member with this email address and your Org Settings only allow one Active enrollment per email address.',
                e.getMessage(),
                'Unexpected exception thrown! Message: ' + e.getMessage()
            );
            
            List<Cadence_Member__c> cadMemList = getCadenceMemberList();
            System.assertEquals(1, cadMemList.size(), 'Only one cadence member should be created.');
        }
    }

    @isTest
    static void testAllowDuplicateEmailAddress() {
        Map<String, Object> settings = new Map<String, Object> { 
            'Prevent_Duplicate_Email_Addresses__c' => false
        };

        runCustomSettingTest('Prevent_Duplicate_Email_Addresses__c', settings);     
        List<Cadence_Member__c> cadMemList = getCadenceMemberList();
        System.assertEquals(2, cadMemList.size(), 'Two cadence members should be created.');
    }
    
    @isTest
    static void testPreventDuplicateActiveCadences() {
        Map<String, Object> settings = new Map<String, Object> {
            'Allow_Multiple_Active_Cadences__c' => true,
            'Allow_Duplicate_Active_Cadences__c' => false 
        };

        try {
            runCustomSettingTest('Allow_Duplicate_Active_Cadences__c', settings);
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', null, 
            'An exception should be thrown!');
        } catch (Exception e) {  
            System.assertEquals(
                'This record is already Active in that Cadence and cannot be enrolled twice in the same Cadence.',
                e.getMessage(),
                'Unexpected exception thrown! Message: ' + e.getMessage()
            );

            
            List<Cadence_Member__c> cadMemList = getCadenceMemberList();
            System.assertEquals(1, cadMemList.size(), 'Only 1 cadence member should be created.');
        }
    }

    @isTest
    static void testAllowDuplicateActiveCadences() {
        Map<String, Object> settings = new Map<String, Object> {
            'Allow_Multiple_Active_Cadences__c' => true,
            'Allow_Duplicate_Active_Cadences__c' => true 
        };
        runCustomSettingTest('Allow_Duplicate_Active_Cadences__c', settings);
        List<Cadence_Member__c> cadMemList = getCadenceMemberList();
        System.assertEquals(2, cadMemList.size(), 'Two cadence members should be created.');
    }

    @isTest
    static void testPreventMultipleActiveCadences() {
        Map<String, Object> settings = new Map<String, Object> {
            'Allow_Multiple_Active_Cadences__c' => false
        };

        try {
            runCustomSettingTest('Allow_Multiple_Active_Cadences__c', settings);
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', null, 
                'An exception should be thrown!');
        } catch (Exception e) {  
            System.assertEquals(
                'This record is already Active in a Cadence and your Org settings only allow one Active Cadence per record.',
                e.getMessage(),
                'Unexpected exception thrown! Message: ' + e.getMessage()
            );
            
            List<Cadence_Member__c> cadMemList = getCadenceMemberList();
            System.assertEquals(1, cadMemList.size(), 'Only 1 cadence member should be created.');
        }
    }

    @isTest
    static void testAllowMultipleActiveCadences() {
        Map<String, Object> settings = new Map<String, Object> {
            'Allow_Multiple_Active_Cadences__c' => true
        };

        runCustomSettingTest('Allow_Multiple_Active_Cadences__c', settings);
        List<Cadence_Member__c> cadMemList = getCadenceMemberList();
        System.assertEquals(2, cadMemList.size(), 'Two cadence members should be created.');
    }

    /*
    @isTest
    static void testPreventReadOnlyEnrollment() {
        Map<String, Object> settings = new Map<String, Object> {
            'Prevent_Read_Only_Enrollment__c' => true
        };

        try {
            runCustomSettingTest('Prevent_Read_Only_Enrollment__c', settings);
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', null, 
                'An exception should be thrown!');
        } catch (Exception e) {  
            System.assertEquals(
                'This record read-only for the assigned User. Please try enrolling a record you can edit.',
                e.getMessage(),
                'Unexpected exception thrown! Message: ' + e.getMessage()
            );
            
            List<Cadence_Member__c> cadMemList = getCadenceMemberList();
            System.assertEquals(0, cadMemList.size(), 'No cadence member should be created.');
        }
    }
    */

    @isTest
    static void testAllowReadOnlyEnrollment() {
        Map<String, Object> settings = new Map<String, Object> {
            'Prevent_Read_Only_Enrollment__c' => false
        };
        runCustomSettingTest('Prevent_Read_Only_Enrollment__c', settings);
        List<Cadence_Member__c> cadMemList = getCadenceMemberList();
        System.assertEquals(1, cadMemList.size(), 'One Cadence member should be created.');
    }

    @isTest
    static void testGlobalEnrollmentCapExceeded() {
        Map<String, Object> settings = new Map<String, Object> {
            'Active_Enrollment_Cap__c' => 1
        };

        try {
            runCustomSettingTest('Active_Enrollment_Cap__c', settings);
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', null, 
                'An exception should be thrown!');
        } catch (Exception e) {  
            System.assertEquals(
                'Global Cap for Active Enrollments Has Been Reached.',
                e.getMessage(),
                'Unexpected exception thrown! Message: ' + e.getMessage()
            );
            
            List<Cadence_Member__c> cadMemList = getCadenceMemberList();
            System.assertEquals(1, cadMemList.size(), 'Only one new cadence member should have been created.');
        }
    }

    @isTest
    static void testUserEnrollmentCapExceeded() {
        Id cadId = [SELECT Id FROM Cadence__c LIMIT 1].Id;
        User stdUser = [SELECT Id, Active_Enrollment_Cap__c FROM USER WHERE LastName = 'Testing'];
        stdUser.Active_Enrollment_Cap__c = 1;
        update stdUser;

        // enroll first record
        enrollNewRecord( stdUser.Id, cadId, 'Lead' );

        // enroll second and check failure message
        try {
            enrollNewRecord( stdUser.Id, cadId, 'Lead' );
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', null, 
                'An exception should be thrown!');
        } catch (Exception e) {  
            System.assertEquals(
                'User Cap for Active Enrollments Has Been Reached.',
                e.getMessage(),
                'Unexpected exception thrown! Message: ' + e.getMessage()
            );
            
            List<Cadence_Member__c> cadMemList = getCadenceMemberList();
            System.assertEquals(1, cadMemList.size(), 'Only one new cadence member should have been created.');
        }
    }

    @isTest
    static void testCadenceEnrollmentCapExceeded() {
        Id uid = [SELECT Id FROM USER WHERE LastName = 'Testing'].Id;
        Cadence__c cadence = [SELECT Id, Active_Enrollment_Cap__c FROM Cadence__c LIMIT 1];
        cadence.Active_Enrollment_Cap__c = 1;
        update cadence;

        // enroll first record
        enrollNewRecord( uid, cadence.Id, 'Lead' );

        // enroll second and check failure message
        try {
            enrollNewRecord( uid, cadence.Id, 'Lead' );
            System.assertEquals('DS_Packages.StartCadence.START_CADENCE_EXCEPTION', null, 
                'An exception should be thrown!');
        } catch (Exception e) {  
            System.assertEquals(
                'Cadence Cap for Active Enrollments Has Been Reached.',
                e.getMessage(),
                'Unexpected exception thrown! Message: ' + e.getMessage()
            );
            
            List<Cadence_Member__c> cadMemList = getCadenceMemberList();
            System.assertEquals(1, cadMemList.size(), 'Only one new cadence member should have been created.');
        }
    }

    /**
     * Note from Alex:
     * The following test methods are the same as above, but ran in a Standard User context.
     * Most Apex methods do not need this test, but since the startCadence method ran in these
     * tests is defined as an @invocableMethod, it can be executed from a flow, 
     * which will run this method in USER MODE. Hence why we need to test in USER MODE in the 
     * following test methods.
     */
    @isTest
    static void testLeadStandardEnrollmentUserMode() {
        runStandardEnrollmentTest('Lead', true, false);
    }

    @isTest
    static void testAccountStandardEnrollmentUserMode() {
        runStandardEnrollmentTest('Account', true, false);
    }

    @isTest
    static void testContactStandardEnrollmentUserMode() {
        runStandardEnrollmentTest('Contact', true, false);
    }

    @isTest
    static void testOpportunityStandardEnrollmentUserMode() {
        runStandardEnrollmentTest('Opportunity', true, false);
    }
}
