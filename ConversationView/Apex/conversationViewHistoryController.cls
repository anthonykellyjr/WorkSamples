public class conversationViewHistoryController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String,List<conversationViewHistoryWrapper>> getConvoHistory(integer limitSize, integer offSet,  string recId, 
                                         string filterType, string filterDate, string startDate, string endDate){

        try {
            List<conversationViewHistoryWrapper> records = new List<conversationViewHistoryWrapper>();
            conversationViewHistory conViewHistory = new conversationViewHistory(limitSize, offSet, recId, filterType, filterDate, startDate, endDate);
            records = conViewHistory.getConvoHistory();
            records.sort();
            Map<String, List<conversationViewHistoryWrapper>> recordsMap = new Map<String, List<conversationViewHistoryWrapper>>();
            for (conversationViewHistoryWrapper record : records) {
                // Generate a key based on the date portion of createdDate
                String key = createConvoKey(record.createdDate);
                
                // If the key exists in the map, add the record to the existing list
                if (recordsMap.containsKey(key)) {
                    recordsMap.get(key).add(record);
                } else {
                    // If the key doesn't exist, create a new list with the current record
                    List<conversationViewHistoryWrapper> newList = new List<conversationViewHistoryWrapper>{record};
                    recordsMap.put(key, newList);
                }
            }
            
            return recordsMap;
        } catch(Exception ex){
            throw new AuraHandledException(
                'Error retrieving Conversation History: ' + ex.getMessage()
            );
        }
    }
    // Return an iso string representing created date, at midnight, for grouping convo items
    public static String createConvoKey(Datetime createdDate) {
        Datetime keyDatetime = createdDate;
        Timezone tz = UserInfo.getTimeZone();
        keyDatetime = keyDatetime.addSeconds(tz.getOffset(keyDatetime)/1000); // Adjust for time zone offset
        String key = String.valueOfGmt(keyDatetime.dateGMT()) + 'T00:00:00.000Z';
        DateTime dtWithOffset = DateTime.valueOf(key);
        String isoString = dtWithOffset.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

        return isoString;
    }


    // get drilled down conversation thread data
    @AuraEnabled(cacheable=true)
    public static Convo getRecordInfo(string recId, string itemType){

        List < ConvoItem > items = new List < ConvoItem > ();

        if (itemType == 'Email') {
            Email_Message__c em = [Select Id, Conversation__c
                                   From Email_Message__c
                                   Where Id =: recId];
            Conversation__c convo = [Select Id, 
                                     (Select Id, CreatedDate, Text_Body__c, Subject__c, Incoming__c, From_Address__c, From_Name__c
                                      From Email_Messages__r
                                      Order By CreatedDate Desc LIMIT 200)
                                     From Conversation__c
                                     Where Id =: em.Conversation__c];
            if (convo.Email_Messages__r.size() > 0) {
                for (Email_Message__c email : convo.Email_Messages__r) {
                    items.add (
                        new ConvoItem (
                            'email', email.Subject__c, email.Text_Body__c, email.Incoming__c, email.From_Address__c, email.CreatedDate
                        )
                    );
                }
            }
            return new Convo(
                convo,
                items
            );
        } else if (itemType == 'Call') {
            Convo val;

            if(Type.forName('DS_Denali__DialSource_Action__c') != null) {
                val = new Convo(
                    Database.query('Select ' + ConversationViewHistory.getEntFields() + ' From DS_Denali__DialSource_Action__c Where Id =: recId LIMIT 1')
                );
                val.setEntCallProps();
            } else if(Type.forName('DialSource__DialSource_Action__c') != null) {
                val = new Convo(
                    Database.query('SELECT ' + ConversationViewHistory.getStanFields() + ' FROM Task WHERE Id = :recId LIMIT 1')
                );
                val.setStdCallProps();
            }

            return val;
        } else if (itemType == 'SMS') { // check for sms package install
            Type smsHistory = Type.forName('tdc_tsw__Message__c');
            if (smsHistory == null) {
                return null;
            }
            // get Lead or Contact Id from SMS and query for all messages related to it
            sObject msg = Database.query('SELECT tdc_tsw__Lead__c, tdc_tsw__Contact__c FROM tdc_tsw__Message__c WHERE Id = :recId LIMIT 1');
            //tdc_tsw__Message__c msg = [SELECT tdc_tsw__Lead__c, tdc_tsw__Contact__c FROM tdc_tsw__Message__c WHERE Id = :recId LIMIT 1];
            Id parentObjId = msg.get('tdc_tsw__Lead__c') == null ? (Id)msg.get('tdc_tsw__Contact__c') : (Id)msg.get('tdc_tsw__Lead__c');
            String smsQuery = 'SELECT Id, OwnerId, Name, owner.name, CreatedDate, tdc_tsw__Contact__c, tdc_tsw__Lead__c, tdc_tsw__Message_Text_New__c, tdc_tsw__Message_Time__c, tdc_tsw__Sender_Number__c, tdc_tsw__ToNumber__c, tdc_tsw__Sender_Name__c, RecordTypeId From tdc_tsw__Message__c WHERE (tdc_tsw__Contact__c =: parentObjId Or tdc_tsw__Lead__c =: parentObjId) ORDER BY CreatedDate DESC';
            for (sObject m : Database.query(smsQuery)) {
                Datetime createdDate = (Datetime)m.get('CreatedDate');
                Boolean incoming = m.get('name') == 'Incoming' ? true : false;
                String textBody = String.valueOf(m.get('tdc_tsw__Message_Text_New__c'));
                String subject = incoming == true ? String.valueOf(m.get('tdc_tsw__Sender_Name__c')) : String.valueOf(m.getSObject('owner').get('name'));
                items.add ( 
                    new ConvoItem ( 
                        'sms', subject, textBody, incoming, String.valueOf(m.get('tdc_tsw__Sender_Number__c')), createdDate
                    )
                );
            }
            return new Convo(
                msg,
                items
            );
        } else {
            Map<Id, Touchpoint__c> tps = Touchpoints.getTPsById(
                new Set<Id>{ recId },
                'LastModifiedBy.Name, CreatedBy.Name'
            );

            if(tps.isEmpty()) {
                return null;
            }

            return new Convo(tps.values()[0]);
        }
    }

    public class Convo {
        @AuraEnabled public SObject record;
        @AuraEnabled public List < ConvoItem > items;

        // call-specific props
        @AuraEnabled public Id callRecId;
        @AuraEnabled public String callRecType;
        @AuraEnabled public String callRecName;
        @AuraEnabled public Boolean isEnterprise = true;

        public Convo (SObject record) {
            this.record = record;
        }
        public Convo (SObject record, List < ConvoItem > items) {
            this.items = items;
            this.record = record;
        }

        public void setEntCallProps() {
            List<String> fields = new List<String>{
                'DS_Denali__Contact__c',
                'DS_Denali__Lead__c',
                'DS_Denali__Opportunity__c',
                'DS_Denali__Account__c',
                'DS_Denali__Case__c',
                'DS_Denali__Custom_Object_Id__c'
            };

            for(String fld : fields) {
                if(this.record.isSet(fld) && this.record.get(fld) <> null) {
                    this.callRecId = (Id) record.get(fld);
                    SObject parent = (SObject) record.getSObject( fld.replace('__c', '__r') );
                    this.callRecName = (String) parent.get('Name');
                    this.callRecType = this.callRecId.getSobjectType().getDescribe().getName();
                    break;
                }
            }
        }

        public void setStdCallProps() {
            this.isEnterprise = false;

            List<String> fields = new List<String>{
                'WhoId',
                'WhatId'
            };

            for(String fld : fields) {
                if(this.record.isSet(fld) && this.record.get(fld) <> null) {
                    this.callRecId = (Id) record.get(fld);
                    break;
                }
            }
            
            this.callRecType = this.callRecId.getSobjectType().getDescribe().getName();

            try {
                SObject parent = Database.query(
                    'SELECT Name FROM ' + this.callRecType + ' WHERE Id =: callRecId'
                );
                this.callRecName = (String) parent.get('Name');
            } catch(Exception e) {
                System.debug(
                    'Unable to retrieve parent record for this call. '
                    + '\n Error: ' + e.getMessage() + '\n' + e.getStackTraceString()
                );
            }
        }
    }
    // represents a single item in a convo group, e.g. an email or SMS message
    public class ConvoItem {
        @AuraEnabled public String itemType;
        @AuraEnabled public String subject;
        @AuraEnabled public String textBody;
        @AuraEnabled public Boolean incoming; // outgoing message vs reply
        @AuraEnabled public String fromAddress;
        @AuraEnabled public Datetime createdDate;

        public ConvoItem (String t, String s, String txt, Boolean i, String fromAddress, Datetime c) {
            this.itemType = t;
            this.subject = s;
            this.incoming = i;
            this.textBody = txt;
            this.createdDate = c;
            this.fromAddress = fromAddress;
        }
    }

}