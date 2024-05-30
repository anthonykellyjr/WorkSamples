public with sharing class conversationViewHistory {

    string recId;
    string endDate;
    integer offSet;
    string startDate;
    integer limitSize;
    string filterType;
    string filterDate;

    public conversationViewHistory(integer limitSize, integer offSet, string recId, string filterType, string filterDate, string startDate, string endDate) {
        this.recId = recId;
        this.offSet = offSet;
        this.endDate = endDate;
        this.limitSize = limitSize;
        this.startDate = startDate;
        this.filterType = filterType;
        this.filterDate = filterDate;
    }

    public List<conversationViewHistoryWrapper> getConvoHistory(){
        List<conversationViewHistoryWrapper> records = new List<conversationViewHistoryWrapper>();
        if(filterType == 'All' || filterType == 'Email') records = getRelatedEmails(records);
        if(filterType == 'All' || filterType == 'Call') records = getRelatedCalls(records);
        if(filterType == 'All' || filterType == 'Custom') records = getCustomTouchpoints(records);
        if(filterType == 'All' || filterType == 'SMS') getRelatedSMSes(records);
        return records;
    }
    //method returns email message related to the object id of the cadence member
    List<conversationViewHistoryWrapper> getRelatedEmails(List<conversationViewHistoryWrapper> records){
       
        Set<Id> convoIdSet = new Set<Id>();
        for(Conversation__c convo : [Select Id
                                     From Conversation__c
                                     Where Object_Id__c =: recId
                                     Order By CreatedDate desc]){
                                         convoIdSet.add(convo.Id);
                                     }
        
        if(convoIdSet.size() > 0){
            System.debug('convo id set: ' + convoIdSet);
            
            string queryString = 'Select Id, CreatedDate, Text_Body__c, Subject__c, Incoming__c, From_Address__c, Conversation__c';
            queryString += ' From Email_Message__c';
            queryString += ' Where Conversation__c IN: convoIdSet';
            if(createdDateStringAdd() != '') queryString += createdDateStringAdd();
            queryString += ' Order By CreatedDate desc';
            queryString += ' Limit : limitSize';
            queryString += ' Offset : offSet';
            for(Email_Message__c em : database.query(queryString)){
                records.add(new conversationViewHistoryWrapper(em.Id, em.Subject__c, em.Text_Body__c, em.CreatedDate,
                                                               null, null, null, 'standard:email', em.Incoming__c, null,
                                                               em.From_Address__c, 'Email', em.Conversation__c, true, false));
            }
        }  
        return records;
    }
    
    //method returns dsa records related to the record id
    List<conversationViewHistoryWrapper> getRelatedCalls(List<conversationViewHistoryWrapper> records) {
        if(Type.forName('DS_Denali__DialSource_Action__c') != null) {
            string inboundId;
            string denaliObject = 'DS_Denali__DialSource_Action__c';
            string recordTypeName = 'Inbound';
            for(RecordType rt : [Select Id
                                 From RecordType
                                 Where SObjectType =: denaliObject
                                 and DeveloperName =: recordTypeName]){
                                     inboundId = rt.Id;
                                 }

            string queryString = 'Select Id, DS_Denali__Subject__c, DS_Denali__Notes__c, CreatedDate, DS_Denali__Call_Started__c, DS_Denali__Call_Ended__c, DS_Denali__Phone__c';
            queryString += ', DS_Denali__Call_Duration__c,RecordTypeId,DS_Denali__Recording_ID__c';
            queryString += ' From DS_Denali__DialSource_Action__c';
            queryString += ' Where (DS_Denali__Account__c =: recId OR DS_Denali__Contact__c =: recId OR DS_Denali__Lead__c =: recId OR DS_Denali__Opportunity__c =: recId)';
            if(createdDateStringAdd() != '') queryString += createdDateStringAdd();
            queryString += ' Order By CreatedDate desc';
            queryString += ' Limit : limitSize Offset : offSet';
            for(sObject act : Database.query(queryString)){
                conversationViewHistoryWrapper newCVH = new conversationViewHistoryWrapper();
                newCVH.recId = act.get('Id') != null ? Id.valueOf(string.valueOf(act.get('Id'))) : null;
                newCVH.subject = act.get('DS_Denali__Subject__c') != null ? string.valueOf(act.get('DS_Denali__Subject__c')) : null;
                newCVH.body = act.get('DS_Denali__Notes__c') != null ? string.valueOf(act.get('DS_Denali__Notes__c')) : null;
                newCVH.createdDate = act.get('CreatedDate') != null ? datetime.valueOf(act.get('CreatedDate')) : null;
                newCVH.startDate = act.get('DS_Denali__Call_Started__c') != null ? datetime.valueOf(act.get('DS_Denali__Call_Started__c')) : null;
                newCVH.endDate = act.get('DS_Denali__Call_Ended__c') != null ? datetime.valueOf(act.get('DS_Denali__Call_Ended__c')) : null;
                newCVH.duration = act.get('DS_Denali__Call_Duration__c') != null ? decimal.valueOf(string.valueOf(act.get('DS_Denali__Call_Duration__c'))) : null ;
                newCVH.durationString = getDurationString(newCVH.duration);
                newCVH.icon = 'standard:voice_call';
                newCVH.phone = act.get('DS_Denali__Phone__c') != null ? string.valueOf(act.get('DS_Denali__Phone__c')) : null;
                newCVH.email = null;
                newCVH.type = 'Call';
                newCVH.convoId = null;
                newCVH.isEmail = false;
                if(string.valueOf(act.get('RecordTypeId')) == inboundId)
                    newCVH.incoming = true;
                else
                    newCVH.incoming = false;
                
                records.add(newCVH);
            }
        } else if(Type.forName('DialSource__DialSource_Action__c') != null) {
            String query = 'SELECT ' + getStanFields() + ' FROM Task';
            query += ' WHERE DialSource__Call_ID_DS__c <> null AND (WhoId = :recId OR WhatId = :recId)' + createdDateStringAdd();
            query += ' ORDER BY CreatedDate Desc LIMIT :limitSize OFFSET :offSet';

            for(Task t: Database.query(query)) {
                conversationViewHistoryWrapper newCVH = new conversationViewHistoryWrapper(
                    t.Id, t.Subject, t.Description, t.CreatedDate,
                    (Datetime)t.get('DialSource__Call_Started_DS__c'), (Datetime)t.get('DialSource__Call_Ended_DS__c'),
                    t.CallDurationInSeconds,
                    'standard:voice_call',
                    (String)t.get('DialSource__Call_Campaign_DS__c') == '*Inbound*' ? true : false,
                    t.Description?.subStringAfter('Dialed ')?.substringBefore('\n'), 
                    null, 'Call', null, false, false
                );
                
                records.add(newCVH);
            }
        }
        return records;
    }

    @testVisible
    private String getDurationString(Decimal duration) {
        if (duration == null) {
            return '0 seconds';
        } else if (duration == 0) {
            return '0 seconds';
        } else if (duration > 60) {
            return (Math.floor(duration / 60)) + ' minutes';
        }
        return duration + ' seconds';
    }

    public static String getStanFields() {
        return 'OwnerId, Owner.Name, CallDurationInSeconds, Description, ActivityDate, Subject, CreatedDate, CreatedById, CreatedBy.Name,' +
        'Status, WhoId, Who.Name, LastModifiedById, LastModifiedBy.Name, LastModifiedDate, WhatId, What.Name, ' +
        'DialSource__Call_Disposition_DS__c, DialSource__Call_Campaign_DS__c, DialSource__Call_Started_DS__c, DialSource__Call_Ended_DS__c, DialSource__Recording_ID_DS__c';
    }

    public static String getEntFields() {
        return 'Id, DS_Denali__Subject__c, DS_Denali__Notes__c, CreatedDate, DS_Denali__Call_Started__c, DS_Denali__Call_Ended__c, DS_Denali__Contact__c,'
        + ' DS_Denali__Contact__r.Name, DS_Denali__Phone__c, DS_Denali__Phone_Number__c, DS_Denali__Call_Duration__c, LastModifiedBy.Name, LastModifiedDate,'
        + ' DS_Denali__Recording_ID__c, DS_Denali__Lead__c, DS_Denali__Lead__r.Name, CreatedBy.Name, Name, DS_Denali__Date__c, DS_Denali__Owner__r.Name,'
        + ' DS_Denali__Status__c, DS_Denali__Account__c, DS_Denali__Account__r.Name, DS_Denali__Opportunity__c, DS_Denali__Opportunity__r.Name';
    }

    //method returns custom step touchpoints related to the object id on the cadence member
    List<conversationViewHistoryWrapper> getCustomTouchpoints(List<conversationViewHistoryWrapper> records){

        List<Cadence_Member__c> members = new List<Cadence_Member__c>();
        for(Cadence_Member__c cm : [SELECT Id From Cadence_Member__c Where Object_Id_Ex__c =: recId Order By CreatedDate Desc]){
            members.add(cm);
        }
        if(members.size() > 0){

            Id customTypeId = Schema.SObjectType.Touchpoint__c.getRecordTypeInfosByName().get('Custom Step').getRecordTypeId();
            List <Id> standardTypesList = getStdTypeIdsList();
            if(customTypeId != null){
                string queryString = 'Select Id, RecordTypeId, Name, Instructions__c, CreatedDate';
                queryString += ' From Touchpoint__c';
                queryString += ' Where Cadence_Member__c IN: members';
                queryString += ' And RecordTypeId NOT IN :standardTypesList AND (Status__c = \'Completed\' OR Status__c = \'Skipped\')';
                if(createdDateStringAdd() != '') queryString += createdDateStringAdd();
                queryString += ' Order By CreatedDate desc';
                queryString += ' Limit : limitSize Offset : offSet';
                for(Touchpoint__c tp : database.query(queryString)){           
                    records.add(new conversationViewHistoryWrapper(tp.Id, tp.Name, tp.Instructions__c, tp.CreatedDate,
                        null, null, null, 'standard:social', false, null,
                        null, 'Custom', null, false, false));             
                }
            }
        }
        return records;
    }

    static List <Id> getStdTypeIdsList() {
        List <Id> standardTypesList = new List <Id> ();
        for (String s : StepTypes.STANDARD_TYPES) {
            standardTypesList.add(
                Schema.SObjectType.Touchpoint__c.getRecordTypeInfosByName().get(s).getRecordTypeId()
            );
        }
        return standardTypesList;
    }
    
    /**
     * Constructs a SOQL date filter query string based on the specified filter criteria.
     * This method handles standard filters like 'Today', 'This Week', and 'This Month',
     * as well as custom date ranges defined by `startDate` and `endDate`.
     *
     * @return A string representing the additional SOQL query filter based on the `filterDate`.
     *         Returns an empty string if no filter is applicable or if filter criteria are invalid.
    */
    private String createdDateStringAdd() {
        if (filterDate == null) return ''; // Early return if filterDate is not set

        switch on (filterDate) {
            when 'Today' {
                return ' AND CreatedDate = TODAY';
            }
            when 'This Week' {
                return ' AND CreatedDate = THIS_WEEK';
            }
            when 'This Month' {
                return ' AND CreatedDate = THIS_MONTH';
            }
            when 'Custom' {
                return handleCustomDateFilter();
            }
            when else {
                return '';
            }
        }
    }
    /**
     * Handles the custom date filter logic for the `createdDateStringAdd` method.
     * Constructs a SOQL date filter query string based on `startDate` and `endDate`.
     *
     * @return A string representing the SOQL query filter for custom date ranges.
     *         If both `startDate` and `endDate` are blank, returns an empty string.
     *         If only one of `startDate` or `endDate` is provided, constructs a filter
     *         using the available date.
    */
    private String handleCustomDateFilter() {
        // Construct the query based on whether startDate and/or endDate are provided
        boolean hasStartDate = !String.isEmpty(startDate);
        boolean hasEndDate = !String.isEmpty(endDate);

        if (hasStartDate && hasEndDate) {
            return ' AND CreatedDate >= ' + startDate + ' AND CreatedDate <= ' + endDate;
        } else if (hasStartDate) {
            return ' AND CreatedDate >= ' + startDate;
        } else if (hasEndDate) {
            return ' AND CreatedDate <= ' + endDate;
        }
        return '';
    }
    
    //method adds related SMS records
    void getRelatedSMSes(List<conversationViewHistoryWrapper> records){
        Type smsHistory = Type.forName('tdc_tsw__Message__c');

        if(smsHistory == null) return;

        if(!schema.getGlobalDescribe().get('tdc_tsw__Message__c').getDescribe().isAccessible()) return;
        string incomingId;
        string recordTypeName = 'Incoming';
        string smsObject = 'tdc_tsw__Message__c';
        for(RecordType rt : [Select Id
                             From RecordType
                             Where SObjectType =: smsObject
                             and DeveloperName =: recordTypeName]){
                                incomingId = rt.Id;
                             }

        string query = 'Select Id, OwnerId, owner.name, CreatedDate, tdc_tsw__Message_Text_New__c, tdc_tsw__Message_Time__c, tdc_tsw__Sender_Number__c, tdc_tsw__ToNumber__c, tdc_tsw__Sender_Name__c, RecordTypeId';
        query += ' From tdc_tsw__Message__c';
        query += ' Where (tdc_tsw__Contact__c =: recId Or tdc_tsw__Lead__c =: recId)';
        if(createdDateStringAdd() != '') query += createdDateStringAdd();
        query += ' Order By CreatedDate desc';
        query += ' Limit : limitSize Offset : offSet';
        for(sObject sms : Database.query(query)){
            SObject owner = sms.getSobject('Owner');
            String ownerName = String.valueOf(owner.get('Name')); // use owner name for outbound, sender name for inbound
            String senderName = String.valueOf(sms.get('tdc_tsw__Sender_Name__c'));
            conversationViewHistoryWrapper newCVH = new conversationViewHistoryWrapper();
            newCVH.recId        = sms.get('Id') != null ? Id.valueOf(string.valueOf(sms.get('Id'))) : null;
            newCVH.body         = string.valueOf(sms.get('tdc_tsw__Message_Text_New__c'));
            newCVH.createdDate  = datetime.valueOf(sms.get('CreatedDate'));
            newCVH.icon         = 'standard:sms';
            newCVH.type         = 'SMS';
            newCVH.isSMS        = true;
            newCVH.incoming     = string.valueOf(sms.get('RecordTypeId')) == incomingId ? true : false;
            newCVH.phone        = string.valueOf(sms.get('RecordTypeId')) == incomingId ? string.valueOf(sms.get('tdc_tsw__Sender_Number__c')) : string.valueOf(sms.get('tdc_tsw__ToNumber__c'));
            newCVH.subject      = newCVH.incoming ? senderName : ownerName; // set subject as sender name for incoming or owner name for outgoing
            records.add(newCVH);
        }
    }
}