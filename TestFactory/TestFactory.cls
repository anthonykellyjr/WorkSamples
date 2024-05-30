@isTest
public class TestFactory {

  public Cadence__c cadenceWithAllStepTypes;
  Map<String, Integer> stepNamesAndNums = new Map<String, Integer>();

  public TestFactory() {
    insertCadenceWithAllStepTypes();
  }

  void insertCadenceWithAllStepTypes() {
    // Insert Cadence
    this.cadenceWithAllStepTypes = (Cadence__c) createSObject(new Cadence__c(), true);

    // Get all Step Record Types.
    List<RecordType> recTypes = [Select Id, Name From RecordType Where SObjectType='DS_Packages__Cadence_Step__c' AND isActive = true];

    // Create a Cadence with a Step of each existing Record Type.
    List<Cadence_Step__c> steps = new List<Cadence_Step__c>();
    for(Integer i=0; i < recTypes.size(); i++) {
      steps.add(
        new Cadence_Step__c(
          Number__c = i + 1,
          RecordTypeId = recTypes[i].Id,
          Cadence__c = this.cadenceWithAllStepTypes.Id
        )
      );
      // Map Step Record Type to Step Number for Touchpoint generation by Type.
      stepNamesAndNums.put(
        recTypes[i].Name,
        i + 1
      );
    }
    insert steps;
  }

  public Touchpoint__c getTouchpointByType(String touchpointType) {
    return getTouchpointByType(
      touchpointType,
      UserInfo.getUserId()
    );
  }

  public Touchpoint__c getTouchpointByType(String touchpointType, Id uid) {
    // Get Id of an unenrolled Lead
    Id leadId;
    try {
      leadId = [SELECT Id FROM Lead WHERE Active_Cadence_Names__c = null LIMIT 1].Id;
    } catch(Exception e) {
      // Create a Lead if an unenrolled Lead doesn't currently exist
      createSObjectList(new Lead(), 1, true);
    }

    // Throw an error is creation/retrieval unsuccessful
    try {
      leadId = [SELECT Id FROM Lead WHERE Active_Cadence_Names__c = null LIMIT 1].Id;
    } catch(Exception e) {
      throw new TestFactoryException(
        'Unable to retrieve an unenrolled Lead. Please try again. Apex Error Message:\n'
        + e.getMessage() + '\n'
        + e.getStackTraceString()
      );
    }

    // Start the Cadence on the Step that corresponds to the desired Touchpoint Type
    Integer startingStep = stepNamesAndNums.get(touchpointType);
    StartCadence.startCadence(
      new List<StartCadence.Request>{
        new StartCadence.Request(
          leadId,
          cadenceWithAllStepTypes.Id,
          uid,
          startingStep
        )
      }
    );

    // Return the Touchpoint of the desired Type
    try {
      return [SELECT Id FROM Touchpoint__c WHERE Status__c = 'Open' AND Object_Id_Ex__c = :leadId LIMIT 1];
    } catch(Exception e) {
      throw new TestFactoryException(
        'Unable to create the requested ' + touchpointType + ' Touchpoint. Please try again. Apex Error Message:\n'
        + e.getMessage() + '\n'
        + e.getStackTraceString()
      );
    }
  }

  public static void createCadencesWithDecisionPoints() {
      //Create Objects needed for cadence and decision points
      createSObjectList(new Account(), 1, true);
      List<Cadence__c> cads = createSObjectList(new Cadence__c(), 2, true);
      Decision_Point__c dp = new Decision_Point__c(Name = 'Test Decision 1', Wait_Period__c = 1, Wait_Period_Measurement__c = 'Hours', Alternate_Cadence__c = cads[1].ID, Negative_Outcome_Action__c = 'Move to Another Cadence', Positive_Outcome_Action__c = 'Proceed to Next Step');
      insert dp;
      Decision_Point_Condition__c dpCondition = new Decision_Point_Condition__c(Decision_Point__c = dp.Id, Number__c = 1, Operator__c = 'Is', Event__c = 'Email Read', Event_Type__c = 'Step Related');
      insert dpCondition;

      List<RecordType> recordTypes = [Select Id, Name From RecordType Where SObjectType = 'DS_Packages__Cadence_Step__c' AND isActive = true AND Name = 'Email'];
      List<Cadence_Step__c> steps = new List<Cadence_Step__c>();

      for(Cadence__c c: cads) {
        //4 Steps for each Cadence - no variation
        for (integer i=0; i<4; i++) {
          Cadence_Step__c step = new Cadence_Step__c(Number__c=i+1, Cadence__c=c.Id, Decision_Point__c = dp.Id, RecordTypeId = recordTypes[0].ID);
          steps.add(step);
        }
      }
      insert steps;
  }

  public static List<Cadence__c> getCadencesWithDecisionPoints() {
    //Create Objects needed for cadence and decision points
    createSObjectList(new Account(), 1, true);
    List<Cadence__c> cads = createSObjectList(new Cadence__c(), 2, true);
    Decision_Point__c dp = new Decision_Point__c(Name = 'Test Decision 1', Wait_Period__c = 1, Wait_Period_Measurement__c = 'Hours', Alternate_Cadence__c = cads[1].ID, Negative_Outcome_Action__c = 'Move to Another Cadence', Positive_Outcome_Action__c = 'Proceed to Next Step');
    insert dp;
    Decision_Point_Condition__c dpCondition = new Decision_Point_Condition__c(Decision_Point__c = dp.Id, Number__c = 1, Operator__c = 'Is', Event__c = 'Email Read', Event_Type__c = 'Step Related');
    insert dpCondition;

    List<RecordType> recordTypes = [Select Id, Name From RecordType Where SObjectType = 'DS_Packages__Cadence_Step__c' AND isActive = true AND Name = 'Email'];
    List<Cadence_Step__c> steps = new List<Cadence_Step__c>();

    for(Cadence__c c: cads) {
      //4 Steps for each Cadence - no variation
      for (integer i=0; i<4; i++) {
        Cadence_Step__c step = new Cadence_Step__c(Number__c=i+1, Cadence__c=c.Id, Decision_Point__c = dp.Id, RecordTypeId = recordTypes[0].ID);
        steps.add(step);
      }
    }
    insert steps;
    return cads;
  }

  public static List<Cadence__c> createCadenceSet(Integer count){
      resetUserFields( UserInfo.getUserId() );
      //Create Standard Objects and cadence with steps
      createSObjectList(new Lead(), count, true);
      createSObjectList(new Account(), count, true);
      createSObjectList(new Contact(), count, true);
      createSObjectList(new Opportunity(), count, true);
      List<Cadence__c> cads = createSObjectList(new Cadence__c(), count, true);
      system.debug(cads);
      
  
      //Create Cadence Steps
      List<RecordType> recordTypes = [Select Id, Name From RecordType Where SObjectType='DS_Packages__Cadence_Step__c' AND isActive = true];
      List<Cadence_Step__c> steps = new List<Cadence_Step__c>();
      for(Cadence__c c: cads)
      {
        //4 Steps for each Cadence - one of each variation
        for(integer i=0; i<4; i++)
        {
          Cadence_Step__c step = new Cadence_Step__c(Number__c=i+1, Cadence__c=c.Id, RecordTypeId = recordTypes[i].ID);
          steps.add(step);
        }
      }
      insert steps;
      return cads;
  }

  public static void setStage(Integer count){
    resetUserFields( UserInfo.getUserId() );

      createSObjectList(new Lead(), count, true);
      createSObjectList(new Account(), count, true);
      createSObjectList(new Contact(), count, true);
      createSObjectList(new Opportunity(), count, true);

      // make sure at least one cadence is created
      List<Cadence__c> cads = createSObjectList(
        new Cadence__c(),
        (Decimal.valueOf(count)/10).round(System.RoundingMode.CEILING).intValue(),
        true
      );

      // populate 6 steps per cadence - alternate emails / calls
      Id callId = [Select Id, Name From RecordType Where SObjectType='DS_Packages__Cadence_Step__c' AND isActive=true AND Name = 'Call' limit 1].Id;
      Id emailId = [Select Id, Name From RecordType Where SObjectType='DS_Packages__Cadence_Step__c' AND isActive=true AND Name = 'Email' limit 1].Id;

      List<Cadence_Step__c> steps = new List<Cadence_Step__c>();

      for(Cadence__c c: cads) {
        c.Number_of_Steps__c = 7;
        
        for(integer i=1; i<8;i++) {
          steps.add(
            new Cadence_Step__c(
              Number__c = i,
              Cadence__c = c.Id,
              RecordTypeId = Math.mod(i, 2) == 0 ? emailId : callId
            )
          );
        }
      }
      insert steps;
      update cads;
  }

  public Static OpenTouchpointsFilters openTpsQueryFilters() {
    Map < String, Object > filtMap = new Map < String, Object > {
        'recordId' => '',
        'searchKey' => '',
        'dueDate' => 'All',
        'groupBy' => 'cadence',
        'tpTypes' => new List < String > (),
        'userId' => UserInfo.getUserId(),
        'autoEmails' => false,
        'rescheduledTps' => false,
        'pendingDecisions' => false
    };
    String filterJson = JSON.serialize(filtMap);
    return OpenTouchpointsFilters.parse(filterJson);
  }
  // create user with standard profile and standard perms
  public static User createUser(String profName) {
    Profile p = [select id from profile where name =: profName];
    Integer randomNum1 = Integer.valueof((Math.random() * 100));
    Integer randomNum2 = Integer.valueof((Math.random() * 100));

    User u = new User(
        alias = 'standt',
        email = 'standarduser@testorg.com',
        emailencodingkey = 'UTF-8',
        lastname = 'Testing',
        languagelocalekey = 'en_US',
        localesidkey = 'en_US',
        profileid = p.Id,
        timezonesidkey = 'America/Los_Angeles',
        username = 'standardconqueror' + randomNum1 + randomNum2 + '@conquer.io.testorg.com'
    );
    try {
      insert u;
    } catch(Exception ex) {
      throw new TestFactoryException('Failed to insert Standard User: ' + ex.getmessage());
    }
    assignStdPermset(u.Id);
    return u;
  }

  @future public static void assignStdPermset(Id uid) {
    Id stdUserId;
    PermissionSet p;
    try {
      stdUserId = [SELECT id, username FROM User WHERE Id =: uid LIMIT 1].Id;
      p = [SELECT Id, Name FROM PermissionSet WHERE Name = 'DialSource_Cadence_User'];
    } catch (Exception ex) {
      throw new TestFactoryException('Failed to retrieve standard user and permission set: ' + ex.getMessage());
    }
    PermissionSetAssignment psa = new PermissionSetAssignment(
      PermissionSetId = p.Id, AssigneeId = stdUserId
    );
    try {
      insert psa;
    } catch(Exception ex) {
      throw new TestFactoryException('Failed to assign Cadence User perm set: ' + ex.getMessage());
    }
  }

  public static void enrollRecords(Integer count, String userId) {
    resetUserFields(userId);
    TestFactory.setStage(count); // create x number Leads, Accs, Opp, Contacts
    Id cadId = [Select Id From Cadence__c Where Excluded_Cadence__c = false limit 1].Id;
    List < StartCadence.Request > startReqs = new List < StartCadence.Request > ();
    for (lead l: [Select Id From Lead]) {
        startReqs.add(new StartCadence.Request(l.Id, cadId, userId));
    }
    for (Account a: [Select Id From Account]) {
        startReqs.add(new StartCadence.Request(a.Id, cadId, userId));
    }
    for (Contact c: [Select Id From Contact]) {
        startReqs.add(new StartCadence.Request(c.Id, cadId, userId));
    }
    for (Opportunity o: [Select Id From Opportunity]) {
        startReqs.add(new StartCadence.Request(o.Id, cadId, userId));
    }
    StartCadence.StartCadence(startReqs);
}

  static void resetUserFields(Id uid) {
    try {
      User u = [SELECT Active_Enrollment_Cap__c FROM User WHERE Id =: uid LIMIT 1];
      u.Active_Enrollment_Cap__c = null;
      update u;
    } catch(Exception e) {
      System.debug(
        'There was an error clearing fields from your test User. Error Message:\n' + e.getMessage()
      );
    }
  }
  public static SObject createSObject(SObject sObj) {
      
    // Check what type of object we are creating and add any defaults that are needed.
    String objectName = String.valueOf(sObj.getSObjectType());
    // Construct the default values class. Salesforce doesn't allow '__' in class names
    String defaultClassName = objectName.replaceAll('__(c|C)$|__', '') + 'Defaults';
    // If there is a class that exists for the default values, then use them
    if(Type.forName('TestFactoryDefaults.' + defaultClassName) != null) {
      sObj = createSObject(sObj, 'TestFactoryDefaults.' + defaultClassName);
    }
    return sObj;
  }

  public static SObject createSObject(SObject sObj, Boolean doInsert) {
    SObject retObject = createSObject(sObj);
    if(doInsert) {
      insert retObject;
    }
    return retObject;
  }

  public static SObject createSObject(SObject sObj, String defaultClassName) {
      
    // Create an instance of the defaults class so we can get the Map of field defaults
    Type t = Type.forName(defaultClassName);
    if(t == null) {
      Throw new TestFactoryException('Invalid defaults class.');
    }
    FieldDefaults defaults = (FieldDefaults)t.newInstance();
    addFieldDefaults(sObj, defaults.getFieldDefaults());
    return sObj;
  }

  public static SObject createSObject(SObject sObj, String defaultClassName, Boolean doInsert) {
    SObject retObject = createSObject(sObj, defaultClassName);
    if(doInsert) {
      insert retObject;
    }
    return retObject;
  }

  public static SObject[] createSObjectList(Sobject sObj, Integer numberOfObjects) {
    return createSObjectList(sObj, numberOfObjects, (String)null);
  }

  public static SObject[] createSObjectList(SObject sObj, Integer numberOfObjects, Boolean doInsert) {
    SObject[] retList = createSObjectList(sObj, numberOfObjects, (String)null);
    if(doInsert) {
      insert retList;
    }
    return retList;
  }

  public static SObject[] createSObjectList(SObject sObj, Integer numberOfObjects, String defaultClassName, Boolean doInsert) {
    SObject[] retList = createSObjectList(sObj, numberOfObjects, defaultClassName);
    if(doInsert) {
      insert retList;
    }
    return retList;
  }

  public static SObject[] createSObjectList(Sobject sObj, Integer numberOfObjects, String defaultClassName) {
    SObject[] sObjs = new SObject[] {};
    SObject newObj;

    // Get one copy of the object
    if(defaultClassName == null) {
      newObj = createSObject(sObj);
    } else {
      newObj = createSObject(sObj, defaultClassName);
    }

    // Get the name field for the object
      
      String nameField;
      
      if(sObj.getSObjectType().getDescribe().getName() == 'Lead'){
          nameField = 'LastName';
      }
      else{
          nameField = String.valueOf(nameFieldMap.get(sObj.getSObjectType()));
      }
    //system.debug('Name Field: '+nameField);
    if(nameField == null) {
      nameField = 'Name';
    }
    Boolean nameIsAutoNumber = sObj.getSobjectType().getDescribe().fields.getMap().get(nameField).getDescribe().isAutoNumber();

    // Clone the object the number of times requested. Increment the name field so each record is unique
    for(Integer i = 0; i < numberOfObjects; i++) {
      SObject clonedSObj = newObj.clone(false, true);
      if(!nameIsAutoNumber) {
        clonedSObj.put(nameField, (String)clonedSObj.get(nameField) + ' ' + i);
      }
      sObjs.add(clonedSObj);
    }
    return sObjs;
  }

  private static void addFieldDefaults(SObject sObj, Map<Schema.SObjectField, Object> defaults) {
    // Loop through the map of fields and if they weren't specifically assigned, fill them.
    Map<String, Object> populatedFields = sObj.getPopulatedFieldsAsMap();
    for(Schema.SObjectField field : defaults.keySet()) {
      if(!populatedFields.containsKey(String.valueOf(field))) {
        sObj.put(field, defaults.get(field));
      }
    }
  }

  // When we create a list of SObjects, we need to have a unique field for the insert if there isn't an autonumber field.
  // Usually we use the Name field, but some objects don't have a name field.
  private static Map<Schema.SObjectType, Schema.SObjectField> nameFieldMap = new Map<Schema.SObjectType, Schema.SObjectField> {
    Contact.sObjectType => Contact.LastName,
    Case.sObjectType => Case.CaseNumber //this is the autonumber field
  };

  public class TestFactoryException extends Exception {}

  // Use the FieldDefaults interface to set up values you want to default in for all objects.
  public interface FieldDefaults {
    Map<Schema.SObjectField, Object> getFieldDefaults();
  }
}