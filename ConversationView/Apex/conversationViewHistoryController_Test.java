@isTest
public with sharing class conversationViewHistoryController_Test {
    Static List<Cadence_Member__c> leadMembers = new List<Cadence_Member__c>();
    static List < Email_Message__c > emailList = new List < Email_Message__c > ();

    static final Datetime DUE_DATE_TIME = System.now();

    // Custom class to hold necessary data for tests
    private class TestSetupData {
        public Set<Id> leadIds = new Set<Id>();
        public String recId;
        public Conversation__c leadConvo;
    }

    @TestSetup
    static void createData() {
        TestFactory.enrollRecords(2, UserInfo.getUserId());

        List < Conversation__c > convoList = new List < Conversation__c > ();
        Id cadId = [Select Id, Active__c From Cadence__c WHERE Excluded_Cadence__c = false AND Active__c = true limit 1].Id;
        
        leadMembers = [
            Select Active__c, Id, Name, Lead__c, Cadence__c 
            From Cadence_Member__c 
            WHERE Lead__c != null AND Active__c = true
        ];

        for (Cadence_Member__c c: leadMembers) {
            Conversation__c newConvo = new Conversation__c();
            newConvo.Name = c.Name + ' Convo';
            newConvo.Lead__c = c.Lead__c;
            newConvo.Object_Id__c = c.Lead__c;
            convoList.add(newConvo);
        }

        insert convoList;

        List<Email_Message__c> leadEmails = new List<Email_Message__c>();

        for (Conversation__c convo : convoList) {
            Email_Message__c em1 = new Email_Message__c();
            em1.Subject__c = 'Test email 1';
            em1.Text_Body__c = 'First email for Testing';
            em1.From_Address__c = 'test@test.com';
            em1.Conversation__c = convo.Id;
            leadEmails.add(em1);
    
            Email_Message__c em2 = new Email_Message__c();
            em2.Subject__c = 'Test email 2';
            em2.Text_Body__c = 'Second email for Testing';
            em2.From_Address__c = 'test@test.com';
            em2.Conversation__c = convo.Id;
            leadEmails.add(em2);
    
            Email_Message__c em3 = new Email_Message__c();
            em3.Subject__c = 'Test email 3';
            em3.Text_Body__c = 'Third email for Testing';
            em3.From_Address__c = 'test@test.com';
            em3.Conversation__c = convo.Id;
            leadEmails.add(em3);
        }

        insert leadEmails;

        List<Touchpoint__c> insertTps = new List<Touchpoint__c>();

        for (Cadence_Member__c c : leadMembers) {
            Touchpoint__c emailTp = new Touchpoint__c(
                Name = 'Send Email',
                Number__c = 1,
                Cadence_Member__c = c.Id,
                Status__c = 'Completed',
                Instructions__c = 'Just send email',
                Object_ID_Ex__c = c.Lead__c,
                Due_Date_Time__c = DUE_DATE_TIME
            );
            insertTps.add(emailTp);
        }
        insert insertTps;

        DataFactoryAdvancement advancer = new DataFactoryAdvancement(leadMembers.size());
    }

    // Utility method for creating conversations and email messages
    private static TestSetupData createConversationsAndEmails() {
        TestSetupData data = new TestSetupData();

        List<Id> leadIds = new List<Id>();
        List<Id> convoIds = new list<Id>();
        List < Map < String, List < conversationViewHistoryWrapper >>> histories = new List < Map < String, List < conversationViewHistoryWrapper >>> ();

        List < Conversation__c > convos = new List < Conversation__c > ([
            SELECT Cadence_Member__c, Lead__c, Name, Total_Emails__c
            FROM Conversation__c WHERE Lead__c != null
        ]);
        
        for (Conversation__c con : convos) {
            convoIds.add(con.Id);
            leadIds.add(con.Lead__c);
        }

        List<Email_Message__c> messages = [
            SELECT Subject__c, Text_Body__c, From_Address__c, Conversation__c, Conversation__r.Lead__c 
            FROM Email_Message__c
            WHERE Conversation__c IN :convoIds
        ];

        String recId = String.valueOf(messages[0].Conversation__r.Lead__c);

        List<Email_Message__c> leadMessages = new List<Email_Message__c>();

        Id emailLeadId = [
            SELECT Lead__c 
            FROM Conversation__c 
            WHERE Lead__c IN :leadIds LIMIT 1
        ].Lead__c;

        Id leadMemberId = [
            SELECT Id, Active__c, Lead__c 
            FROM Cadence_Member__c 
            WHERE Active__c = true AND Lead__c != null LIMIT 1
        ].Id;

        Conversation__c leadConvo = new Conversation__c(
            Name = 'Conquer | Email Conversation',
            Lead__c = emailLeadId,
            Cadence_Member__c = leadMemberId,
            Object_ID__c = emailLeadId
        );
        insert leadConvo;
        data.leadConvo = leadConvo;

        Email_Message__c testEmail1 = new Email_Message__c();
        testEmail1.Subject__c = 'Lead Email One';
        testEmail1.Text_Body__c = 'Lead Email';
        testEmail1.From_Address__c = 'test@test.com';
        testEmail1.Conversation__c = leadConvo.Id;
        leadMessages.add(testEmail1);

        Email_Message__c testEmail2 = new Email_Message__c();
        testEmail2.Subject__c = 'Lead Email Two';
        testEmail2.Text_Body__c = 'Followup email';
        testEmail2.From_Address__c = 'test@test.com';
        testEmail2.Conversation__c = leadConvo.Id;
        leadMessages.add(testEmail2);

        insert leadMessages;

        for (Conversation__c c : [SELECT Id, Lead__c FROM Conversation__c WHERE Lead__c != null]) {
            data.leadIds.add(c.Lead__c);
        }
        return data;
    }

    @isTest 
    static void testGetConvoHistoryWithoutFilters() {
        TestSetupData setupData = createConversationsAndEmails();
        List < Map < String, List < conversationViewHistoryWrapper >>> histories = new List < Map < String, List < conversationViewHistoryWrapper >>> ();

        Test.startTest();

        for (Lead l : [SELECT id FROM Lead WHERE Id IN :setupData.leadIds]) {
            Map < String, List < conversationViewHistoryWrapper >> history = conversationViewHistoryController.getConvoHistory(
                10, 0, l.Id, 'All', 'All', '', ''
            );
            histories.add(history);
        }

        Test.stopTest();

        List<conversationViewHistoryWrapper> convoItems = new List<conversationViewHistoryWrapper>();

        // Iterate over each map in the histories list
        for (Map<String, List<conversationViewHistoryWrapper>> history : histories) {
            for (List<conversationViewHistoryWrapper> wrappers : history.values()) {
                // Add all wrappers to convoItems list
                convoItems.addAll(wrappers);
            }
        }

        for(conversationViewHistoryWrapper cvh : convoItems) {
            if (cvh.type == 'Email') {
                System.assertEquals(cvh.isEmail, true);
                System.assertNotEquals(cvh.convoId, null);
                System.assertEquals(cvh.icon, 'standard:email');
            }
        }
        // TODO: add more assertions for date and type filters
    }

    @isTest
    static void testConvoAndConvoItems() {
        
        Id leadId = [
            SELECT Id, Active__c, Lead__c 
            FROM Cadence_Member__c 
            WHERE Lead__c != null AND Active__c = true LIMIT 1
        ].Lead__c;

        Task testTask = new Task(
            Subject = 'Test Call',
            Status = 'Completed',
            WhoId = leadId
        );
        insert testTask;
        
        Lead testLead = [SELECT Id FROM Lead WHERE Id =: leadId LIMIT 1];
        List<conversationViewHistoryController.ConvoItem> items = new List<conversationViewHistoryController.ConvoItem>();
        
        items.add(new conversationViewHistoryController.convoItem(
            'Email', 'Test Lead Subject', 'Sending you a test email',
            false, 'test@test.com', System.now()
        ));

        
        Test.startTest();

        conversationViewHistoryController.Convo stdCallConvo = new conversationViewHistoryController.Convo(
            testTask, items
        );

        stdCallConvo.setStdCallProps();

        conversationViewHistoryController.convo testConvo = new conversationViewHistoryController.convo(
            testLead, items
        );


        Test.stopTest();
    }

    @isTest 
    static void testGetConvoHistoryWithFilters() {
        TestSetupData setupData = createConversationsAndEmails();
        List<ContinueCadence.Request> continueReqs = new List<ContinueCadence.Request>();
        CadenceAPIServices.CalloutRegister register = new CadenceAPIServices.CalloutRegister();
        List < Map < String, List < conversationViewHistoryWrapper >>> histories = new List < Map < String, List < conversationViewHistoryWrapper >>> ();

        Id touchpointId;
        String cadenceLeadId;
        for (Cadence_Member__c member : [
                                        SELECT Active__c, Id, Lead__c, Next_Touchpoint__c, Cadence__c 
                                        FROM Cadence_Member__c 
                                        WHERE Lead__c != null 
                                        AND Active__c = true
                                        AND Next_Touchpoint__c != null
                                        ]) {
            if (String.isBlank(cadenceLeadId)) {
                cadenceLeadId = member.Lead__c;
                touchpointId = member.Next_Touchpoint__c;
            } else {
                continue;
            }
        }

        if (touchpointId != null && !String.isBlank(cadenceLeadId)) {
            continueReqs.add(new ContinueCadence.Request(
                'Completed', new TouchpointOutcome('No Contact', 'Neutral'), touchpointId)
            );
        }

        if (continueReqs.size() > 0) {
            register = ContinueCadence.ContinueCadence(continueReqs, register);
        }

        setUpData.leadIds.add(cadenceLeadId);

        Test.startTest();

        for (Lead l : [SELECT id FROM Lead WHERE Id IN :setupData.leadIds]) {
            Map < String, List < conversationViewHistoryWrapper >> history = conversationViewHistoryController.getConvoHistory(
                10, 0, l.Id, 'Custom', 'All', '', ''
            );
            histories.add(history);
        }

        Test.stopTest();

        List<conversationViewHistoryWrapper> convoItems = new List<conversationViewHistoryWrapper>();

        // Iterate over each map in the histories list
        for (Map<String, List<conversationViewHistoryWrapper>> history : histories) {
            for (List<conversationViewHistoryWrapper> wrappers : history.values()) {
                // Add all wrappers to convoItems list
                convoItems.addAll(wrappers);
            }
        }

        for(conversationViewHistoryWrapper cvh : convoItems) {
            System.assertEquals(cvh.type, 'Custom');
            System.assertEquals(cvh.convoId, null);
            System.assertEquals(cvh.isEmail, false);
        }
        // TODO: add more assertions for date and type filters
    }

    @isTest
    static void testGetRecordInfoEmail() {
        TestSetupData setupData = createConversationsAndEmails();

        Test.startTest();
        // Retrieve the first inserted Email_Message__c Id for testing
        Id emailMessageId = [
            SELECT Id, Conversation__c 
            FROM Email_Message__c 
            WHERE Conversation__c = :setupData.leadConvo.Id LIMIT 1
        ].Id;

        // Call getRecordInfo method with 'Email' itemType
        conversationViewHistoryController.Convo result = conversationViewHistoryController.getRecordInfo(emailMessageId, 'Email');

        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null for Email itemType');
        System.assertEquals('email', result.items[0].itemType, 'Item type should be Email');

    }

    @isTest
    static void getConvoHistoryDSAs() {
        // validate the existence of Conquer Voice
        Map < String, Schema.SObjectType > globalDesc = Schema.getGlobalDescribe();
        if (!globalDesc.containsKey('DS_Denali__DialSource_Sessions_V3__c')) {
            return;
        }

        //Start the Cadence
        Id cadId = [Select Id From Cadence__c WHERE Excluded_Cadence__c = false limit 1].Id;
        List < StartCadence.Request > startReqs = new List < StartCadence.Request > ();
        for (lead l: [Select Id, OwnerId
                From Lead
            ]) {
            startReqs.add(new StartCadence.Request(l.Id, cadId, l.OwnerId));
        }
        StartCadence.StartCadence(startReqs);

        // Construct swession
        sObject dsaSession = globalDesc.get('DS_Denali__DialSource_Sessions_V3__c').newSObject();
        dsaSession.put('Name', 'Test Session');
        dsaSession.put('DS_Denali__DS_Session_Length_in_Seconds__c', 12000);
        insert dsaSession;

        List < sObject > records = new List < sObject > ();
        for ( lead l: [Select Id, OwnerId From Lead] ) {
            sObject dsa = schema.getGlobalDescribe().get('DS_Denali__DialSource_Action__c').newSObject();
            dsa.put('DS_Denali__Subject__c', 'Test Call');
            dsa.put('DS_Denali__Notes__c', 'Testing');
            dsa.put('DS_Denali__Call_Started__c', datetime.now());
            dsa.put('DS_Denali__Call_Ended__c', datetime.now().addHours(1));
            dsa.put('DS_Denali__Call_Duration__c', 60);
            dsa.put('DS_Denali__Phone_Number__c', '555-555-5555');
            dsa.put('DS_Denali__DialSource_Session__c', string.valueOf(dsaSession.get('Id')));
            dsa.put('DS_Denali__Lead__c', l.Id);
            records.add(dsa);

        }
        insert records;
        lead ld = [Select Id From Lead Limit 1];

        test.startTest();

        Map<String, List<DS_Packages.conversationViewHistoryWrapper>> rlt = conversationViewHistoryController.getConvoHistory(5, 0, ld.Id, 'All', 'This Week', null, null);
        List < conversationViewHistoryWrapper > convoItems = new List < conversationViewHistoryWrapper > ();

        for (List < conversationViewHistoryWrapper > wrappers: rlt.values()) {
            // Add all wrappers to convoItems list
            convoItems.addAll(wrappers);
        }

        test.stopTest();

        // test assertions for call type Convo Items
        for (ConversationViewHistoryWrapper cvhw : convoItems) {
            if (cvhw.type == 'Call') {
                System.assertEquals(cvhw.type, 'Call');
                System.assertEquals(cvhw.subject, 'Test Call');
                System.assertEquals(cvhw.duration, 60);
                System.assertEquals(cvhw.durationString, '60 seconds');
                System.assertEquals(cvhw.convoId, null);
            }
        }
    }

    @isTest
    static void getConvoHistoryDSADetail(){
        // validate the existence of Conquer Voice
        Map<String, Schema.SObjectType> globalDesc = Schema.getGlobalDescribe();
        if(!globalDesc.containsKey('DS_Denali__DialSource_Sessions_V3__c')) {
            return;
        }

         //Start the Cadence
        Id cadId = [Select Id From Cadence__c WHERE Excluded_Cadence__c = false limit 1].Id;
        List<StartCadence.Request> startReqs = new List<StartCadence.Request>();
        for(lead l: [Select Id, OwnerId 
                     From Lead]){
                         startReqs.add(new StartCadence.Request(l.Id, cadId, l.OwnerId));
                     }
        StartCadence.StartCadence(startReqs);

        // Construct session
        sObject dsaSession = globalDesc.get('DS_Denali__DialSource_Sessions_V3__c').newSObject();
        dsaSession.put('Name','Test Session');
        dsaSession.put('DS_Denali__DS_Session_Length_in_Seconds__c', 12000);
        insert dsaSession;

        List<sObject> records = new List<sObject>();
        for(lead l: [Select Id, OwnerId From Lead]){                 
            sObject dsa = schema.getGlobalDescribe().get('DS_Denali__DialSource_Action__c').newSObject();
            dsa.put('DS_Denali__Subject__c', 'Test Call');
            dsa.put('DS_Denali__Notes__c', 'Testing');
            dsa.put('DS_Denali__Call_Started__c', datetime.now());
            dsa.put('DS_Denali__Call_Ended__c', datetime.now().addHours(1));
            dsa.put('DS_Denali__Call_Duration__c', 60);
            dsa.put('DS_Denali__Phone_Number__c', '555-555-5555');
            dsa.put('DS_Denali__DialSource_Session__c', string.valueOf(dsaSession.get('Id')));
            dsa.put('DS_Denali__Lead__c',l.Id);
            records.add(dsa);
        }
        insert records;
        sObject dsaRecord;
        for(sObject so : ConquerQueries.query('Select Id From DS_Denali__DialSource_Action__c Limit 1')) {
            dsaRecord = so;
        }

        test.startTest();

        ConversationViewHistoryController.Convo emRecord = conversationViewHistoryController.getRecordInfo(string.valueOf(dsaRecord.get('Id')), 'Call');
        
        test.stopTest();

        system.assert(emRecord != null);
    }


    // TODO: Update with assertions in org with SMS installed
    @isTest
    static void getConvoHistorySMSs(){
        // validate the existence of 360 SMS
        Map<String, Schema.SObjectType> globalDesc = Schema.getGlobalDescribe();
        if(!globalDesc.containsKey('tdc_tsw__Message__c')) {
            return;
        }
        List<sObject> records = new List<sObject>();
        for( lead l: [Select Id, OwnerId From Lead] ){
            sObject sms = schema.getGlobalDescribe().get('tdc_tsw__Message__c').newSObject();
            sms.put('tdc_tsw__Message_Text_New__c', 'Test SMS');
            sms.put('tdc_tsw__ToNumber__c', '555-555-5555');
            sms.put('tdc_tsw__Sender_Number__c', '555-555-5556');
            sms.put('tdc_tsw__Lead__c',l.Id);
            records.add(sms);
        }
        insert records;
        lead ld = [Select Id From Lead Limit 1];
        
        test.startTest();
        
        Map<String, List<DS_Packages.conversationViewHistoryWrapper>> rlt = conversationViewHistoryController.getConvoHistory(5, 0, ld.Id, 'All', 'This Week', null, null);
        
        test.stopTest();

        List < conversationViewHistoryWrapper > convoItems = new List < conversationViewHistoryWrapper > ();

        for (List < conversationViewHistoryWrapper > wrappers: rlt.values()) {
            // Add all wrappers to convoItems list
            convoItems.addAll(wrappers);
        }
        //system.assert(convos.size() > 0, 'Related SMS record(s) returned');

    }

    @isTest
    static void sadDay(){
        conversationViewHistoryWrapper.sadDay();
    }

}