global with sharing class StartCadence {

    // counts enrollments/user and checks eligiblity of new assignments
    MemberCounter counter;

    // collects callout requests for this service and either performs / returns them at the end
    public CadenceAPIServices.CalloutRegister register;

    // requests that are eligible for enrollment based on cadence caps and record access
    Map<Id, StartCadence.Request> eligibleRequests = new Map<Id, StartCadence.Request>();
    // pairs User Ids with each assigned record Id
    Map<Id, Set<Id>> userAssignments = new Map<Id, Set<Id>>();

    // creates members and checks for duplicate email addresses/enrollments based on org settings
    CadenceMembers.CreateMembersReturn memberReturnObj = new CadenceMembers.CreateMembersReturn();

    // coordinates touchpoint creation and due date calculation
    CreateTouchpoint createService;

    // objs to coordinate user notifications after successful enrollment(s)
    Map<Id, List<Cadence_Member__c>> userMap = new Map<Id, List<Cadence_Member__c>>(); // Map for sending User notifications
    Notifications notifier = new Notifications(); // Object to send notifications for StartCadence

    List<Request> requestList;
    Map<Id, List<StartCadence.Request>> cadIdToReqMap = new Map<Id, List<StartCadence.Request>>();
    Map<Id, Set<Id>> cadIdToRecIdMap = new Map<Id, Set<Id>>();
    cadence_settings__c settings = cadence_settings__c.getInstance();

    Set<Id> cadenceIds = new Set<Id>(); 
    public static Set<Id> inactiveCadIds = new Set<Id>();
    Map<Id, Cadence__c> cadenceMap = new Map<Id, Cadence__c>();

    // logging props
    Id asyncId;
    String batchId;
    public ConquerAsyncLogger logger;
    Set<Id> readOnlyRecs = new Set<Id>();
    Set<Id> invalidRecordIds = new Set<Id>();
    Set<Id> recsWithInvalidUserId = new Set<Id>();
    Map<String, Set<Id>> enrollCapErrors = new Map<String, Set<Id>>();
    List<Conquer_Debug_Log__c> cdLogList = new List<Conquer_Debug_Log__c>();

    // Error Service
    private CadenceErrorService errorService;

    public StartCadence() {
        this.logger = new ConquerAsyncLogger('StartCadence.StartCadenceAsync');
    }

    public StartCadence(List<Request> reqs, CadenceAPIServices.CalloutRegister reg) {
        this.requestList = reqs;
        this.register = reg;
        this.logger = new ConquerAsyncLogger('StartCadence.StartCadenceAsync');
    }
    
    public StartCadence(List<Request> reqs, CadenceAPIServices.CalloutRegister reg, string batchId) {
        this.requestList = reqs;
        this.register = reg;
        logger = new ConquerAsyncLogger('StartCadence');
        this.batchId = batchId;
    }

    public StartCadence(List<Request> reqs, CadenceAPIServices.CalloutRegister reg, ConquerAsyncLogger logger) {
        this.requestList = reqs;
        this.register = reg;
        this.logger = logger;
    }

    public StartCadence(List<Request> reqs, CadenceAPIServices.CalloutRegister reg, ConquerAsyncLogger logger, string batchId, id asyncId) {
        this.requestList = reqs;
        this.register = reg;
        this.logger = logger;
        this.batchId = batchId;
        this.asyncId = asyncId;
    }

    /**
     * Data type for individual requests
     */
    global class Request {

        @InvocableVariable(required=true)
        global id objectID;

        @InvocableVariable
        global id relatedObjectID;
        
        @InvocableVariable(required=true)
        global id cadenceID;
        
        @InvocableVariable
        global id assignedID;

        @InvocableVariable
        global decimal startingStep;

        @InvocableVariable
        global datetime startingDatetime;
        
        @deprecated
        @InvocableVariable
        global boolean isQueueable;
        
        @InvocableVariable
        global id movedfromCadence;
        
        @InvocableVariable
        global boolean isThrowable;

        @InvocableVariable
        global Id movedFromTouchpoint;

        public id memberID;
        private String firstTpNotes;

        //No Argument Constructor for Process Builder invocations
        // Not referenced in package
        global Request(){
            if(this.startingStep == null){
                this.startingStep = 1;
            }
            if(this.startingDatetime == null) {
                this.startingDatetime = System.now();
            }
        }

        /**
         * Constructors for Standard Assignment Cadences
         */
        // Referenced in 4 files
        global Request(id objectId, id cadenceId, id assignedId){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = 1;
            this.startingDatetime = System.now();
        }

        // Not referenced in package
        global Request(id objectId, id cadenceId, id assignedId, boolean isThrowable, id movedFromTouchpoint){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = 1;
            this.startingDatetime = System.now();
            this.movedFromTouchpoint = movedFromTouchpoint;
            this.isThrowable = isThrowable;
        }

        // Not referenced in package
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = System.now();
        }
        
        // Not referenced in package
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep, id movedFromTouchpoint){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = System.now();
            this.movedFromTouchpoint = movedFromTouchpoint;
        }
        
        @deprecated
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep,boolean isQueueable){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = System.now();
            this.isQueueable = isQueueable;
        }

        // Referenced in 8 files
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep, datetime startingDatetime){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = startingDatetime;
        }

        // Referenced in 3 files
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep, datetime startingDatetime, id relatedObjectID){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = startingDatetime;
            this.relatedObjectID = relatedObjectID;
        }
        
        // Not referenced in package
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep, datetime startingDatetime, id relatedObjectID, boolean isThrowable){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = startingDatetime;
            this.relatedObjectID = relatedObjectID;
            this.isThrowable = isThrowable;
        }

        // Not referenced in package
        global request(id objectid, id cadenceid, id assignedid, id movedfromcadence){
            this.objectid = objectid;
            this.cadenceid = cadenceid;
            this.assignedid = assignedid;
            this.startingStep = 1;
            this.startingDatetime = System.now();
            this.movedFromCadence = movedFromCadence;
        }

        // Switch Cadence from Decision
        global request(id objectid, id cadenceid, id assignedid, id movedfromcadence, Id movedFromTouchpoint){
            this.objectid = objectid;
            this.cadenceid = cadenceid;
            this.assignedid = assignedid;
            this.startingStep = 1;
            this.startingDatetime = System.now();
            this.movedFromCadence = movedFromCadence;
            this.movedFromTouchpoint = movedFromTouchpoint;
        }

        // Not referenced in package
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep, id movedFromCadence, Id movedFromTouchpoint){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = System.now();
            this.movedFromCadence = movedFromCadence;
            this.movedFromTouchpoint = movedFromTouchpoint;
        }

        @deprecated
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep,boolean isQueueable, id movedFromCadence){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = System.now();
            this.isQueueable = isQueueable;
            this.movedFromCadence = movedFromCadence;
            this.movedFromTouchpoint = movedFromTouchpoint;
        }

        // Not referenced in package
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep, datetime startingDatetime, id relatedObjectID, id movedFromCadence){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = startingDatetime;
            this.relatedObjectID = relatedObjectID;
            this.movedFromCadence = movedFromCadence;
        }

        // Referenced in 1 file
        global Request(id objectId, id cadenceId, id assignedId, decimal startingStep, datetime startingDatetime, id relatedObjectID, id movedFromCadence, Id movedFromTouchpoint){
            this.objectId = objectId;
            this.cadenceId = cadenceId;
            this.assignedId = assignedId;
            this.startingStep = startingStep;
            this.startingDatetime = startingDatetime;
            this.relatedObjectID = relatedObjectID;
            this.movedFromCadence = movedFromCadence;
            this.movedFromTouchpoint = movedFromTouchpoint;
        }

        public String getNotes() {
            return this.firstTpNotes;
        }

        public void setNotes(String firstTpNotes) {
            this.firstTpNotes = firstTpNotes;
        }
    }

    public CadenceErrorService getCadenceErrorService() {
        return this.errorService;
    }

    /**
     * Globally exposed method (accessible outside DS_Packages namespace) for starting Cadences
     * Returns the Id of the Queueable job if there was one, or null if not
     * This method performs it's own callouts from this service
     */
    // Referenced in 28 files
    // Runs in USER MODE when executed from flow
    @deprecated
    @InvocableMethod(label='Start Cadence' Description='Enrolls a record in a Cadence and creates the first Touchpoint.')
    global static List<Id> startCadence(List<Request> reqs) {
        System.debug('Entering Start Cadence Invocable Method -- '+reqs.size()+' Incoming Requests ==> ' + reqs);

        if (reqs.isEmpty()) {
            return null;
        }

        Boolean isQueueable = reqs[0].isQueueable;

        // Determines if a new async job should be created.  
        // Only consider req size if isQueueable is not defined.
        Boolean startJob = isQueueable == true || (reqs.size() > 1 && isQueueable == null);

        // Process reqs asynchronously
        if(startJob && !System.isBatch() && !System.isQueueable() && !test.isRunningTest()) {
            // Queue the job and return job Id
            return new List<Id>{ System.enqueueJob(new StartCadenceAsync(reqs)) };
        }
            
        // Perform the service synchronously
        StartCadence service = new StartCadence(reqs, new CadenceAPIServices.CalloutRegister());
        service.run();
        
        // Run register logic to handle callouts and bulk assignment
        if(service.register.isValid()) {
            service.register.run();
        }

        // Return null for sync execution
        return null;
    }
    
    // Not referenced in package
    public static ConquerAsyncLogger startCadence(List<Request> reqs, ConquerAsyncLogger logger) {
        System.debug('Entering Start Cadence Invocable Method -- '+reqs.size()+' Incoming Requests');

        // Perform the service
        StartCadence service = new StartCadence(reqs, new CadenceAPIServices.CalloutRegister(), logger);
        Boolean isResult = reqs[0].isThrowable == null || (reqs[0].isThrowable != null && reqs[0].isThrowable);
        service.run(isResult);

        // Run register logic to handle callouts and bulk assignment
        if(service.register.isValid()) {
            service.register.run(isResult);
        }

        // Return null for sync execution
        return service.logger;
    }

    public static ConquerAsyncLogger startCadence(List<Request> reqs, ConquerAsyncLogger logger, String batchId, Id asyncId) {
        System.debug('Entering Start Cadence Invocable Method -- '+reqs.size()+' Incoming Requests');
        system.debug('from batch');

        // Perform the service
        StartCadence service = new StartCadence(reqs, new CadenceAPIServices.CalloutRegister(), logger, batchId, asyncId);
        Boolean isResult = reqs[0].isThrowable == null || (reqs[0].isThrowable != null && reqs[0].isThrowable);
        service.run(isResult);

        // Run register logic to handle callouts and bulk assignment
        if(service.register.isValid()) {
            service.register.run(isResult);
        }

        // Return null for sync execution
        return service.logger;
    }
    
    // Not referenced in package
    public static void startCadence(List<Request> reqs, string batchId){
        StartCadence service = new StartCadence(reqs, new CadenceAPIServices.CalloutRegister(), batchId);            
        service.run();
        
        // Run register logic to handle callouts and bulk assignment
        if(service.register.isValid()) {
            service.register.run();
        }
    }

    /**
     * Non-globally exposed method (only accessible from classes within the package) for ending a list of Cadences
     * This method returns a callout register with a list of callouts to be performed by the calling service
     * This method assumes the calling context is already Queueable so it will not Queue itself
     */
    // Referenced in 1 file
    public static CadenceAPIServices.CalloutRegister startCadence(List<Request> reqs, CadenceAPIServices.CalloutRegister registerParam) {
        System.debug('Entering Start Cadence non-Invocable Method -- '+reqs.size()+' Incoming Requests');

        // Perform the service and return the register
        StartCadence service = new StartCadence(reqs, registerParam);
        Boolean isResult = reqs[0].isThrowable == null || (reqs[0].isThrowable != null && reqs[0].isThrowable);
        service.run(isResult);

        return service.register;
    }

    // Referenced in 1 file
    public static StartCadence startCadence(List<Request> reqs, CadenceAPIServices.CalloutRegister registerParam, ConquerAsyncLogger logger) {
        System.debug('Entering Start Cadence non-Invocable Method -- '+reqs.size()+' Incoming Requests');

        // Perform the service and return the register
        StartCadence service = new StartCadence(reqs, registerParam, logger);
        Boolean isResult = reqs[0].isThrowable == null || (reqs[0].isThrowable != null && reqs[0].isThrowable);
        service.run(isResult);

        return service;
    }
    
    public void run() {
        // exit service if there are no requests
        if(requestList == null || requestList.isEmpty()) {
            System.debug('No Requests, exiting StartCadence.');
            return;
        }

        try {
            executeLogic();
        } catch(Exception e) {
            if(System.isQueueable() || System.isBatch()) {
                logger.logError(e);
            }
            throw e;
        }
    }
    
    public Result run(boolean isResult){
        Result res = new Result();
        try {
            executeLogic();
        } catch(Exception e) {
            if(System.isQueueable() || System.isBatch()) {
                logger.logError(e);
            }

            if(isResult) {
                res.setError(e);
            } else {
                throw e;
            }
        }
        return res;
    }
    
    private void executeLogic(){
        init();

        // Iterate thru requests and populate data structures
        processInitialRequests();

        handleInvalidUserIds();
        handleInvalidRecordIds();

        /**
		* HANDLE INVALID CADENCES
		* "Invalid" Cadence is Inactive or has no Steps
		* */
        if(!cadenceIds.isEmpty()) {
            handleInvalidCadences();
        }

        // get current active enrollment counts for each User
        populateUserCounts();

        // Remove records that are not eligible for enrollment
        checkAccess();
        // Create Members
        if(!cadenceMap.isEmpty()) {
            memberReturnObj = CadenceMembers.createMember(eligibleRequests.values(), cadenceMap);
        }


        //Verify success creation of at least some Members
        processNewMembers();

        // tally any log any enrollment errors
        logEnrollmentErrorRows();
        
        // Logs errors if transaction is asynchronous
        // Else, throw errors if any exist
        if(System.isQueueable() || System.isBatch()) {
            // Log cadence errors
            errorService.logCadenceErrors();

            // Set total successes and failures
            logResults();
        } else if (errorService.hasErrors()) {
            List<CadenceError> cadErrors = errorService.getCadenceErrors();

            if (requestList.size() == 1) {
                throw new START_CADENCE_EXCEPTION(cadErrors[0].getErrorMsg());
            }

            throw new START_CADENCE_EXCEPTION('One or more errors occurred in your requests.  Please use CadenceErrorService to view them.');
        }
    }

    void init() {
        this.errorService = new CadenceErrorService(cadIdToRecIdMap, logger, batchId, asyncId);
        this.createService = new CreateTouchpoint(logger);
    }
    
    private void processInitialRequests() {
        for(StartCadence.Request req: requestList) {
            //Create + populate inner map
            this.eligibleRequests.put(req.objectId, req);

            // Relates a cadence to all relevant requests (needed for async jobs).
            if (!this.cadIdToReqMap.containsKey(req.cadenceId)) {
                this.cadIdToReqMap.put(req.cadenceId, new List<StartCadence.Request>());
                this.cadIdToRecIdMap.put(req.cadenceId, new Set<Id>());
            } 

            List<StartCadence.Request> cadIdReqs = this.cadIdToReqMap.get(req.cadenceId);
            Set<Id> recIds = this.cadIdToRecIdMap.get(req.cadenceId);
            
            cadIdReqs.add(req);
            recIds.add(req.objectId);

            // for team cadences, set assigned id to the current user for determining record access
            String assignedId = String.isBlank(req.assignedId) ? UserInfo.getUserId() : req.assignedId;
            
            if(!this.userAssignments.containsKey(assignedId)) {
                this.userAssignments.put(assignedId, new Set<Id>());
            }
            
            // populate map of each user id to that user's assignments
            Set<Id> assignmentIds = this.userAssignments.get(assignedId);
            
            //Populate list to validate Cadences
            assignmentIds.add(req.objectId);
            cadenceIds.add(req.cadenceId);
        }
    }

    private void handleInvalidUserIds() {
        Set<Id> userIds = this.userAssignments.keySet();
        Map<Id, User> validUsers = new Map<Id, User>([SELECT Id FROM User WHERE Id IN :userIds]);

        // Check to see if user ids were queried / valid
        for (Id uId : userIds) {
            if (validUsers.containsKey(uId)) {
                continue;
            }

            Set<Id> invalidRecIds = this.userAssignments.get(uId);
            this.recsWithInvalidUserId.addAll(invalidRecIds);

            for (Id recId : invalidRecIds) {
                this.eligibleRequests.remove(recId);
            }

            this.userAssignments.remove(uId);
        }
    }

    private void handleInvalidRecordIds() {
        List<Set<Id>> recIdSets = this.userAssignments.values();
        Map<Id, Set<Id>> recIdToSetMap = new Map<Id, Set<Id>>();
        Map<String, Set<Id>> recTypeToIds = new Map<String, Set<Id>>();
        List<String> validRecordTypeList = new List<String>{ 'Lead', 'Contact', 'Account', 'Opportunity', 'Case' };
        
        // Populate name between rec type (ei, lead) to related ids.
        for (Set<Id> recIdSet : recIdSets) {
            for (Id recId : recIdSet) {
                String recType = ConquerUtility.getSObjName(recId);
                if (!recTypeToIds.containsKey(recType)) {
                    recTypeToIds.put(recType, new Set<Id>());
                }

                recTypeToIds.get(recType).add(recId);
                recIdToSetMap.put(recId, recIdSet);
            }
        }

        // Check to see if the ids are valid by checking returned records.
        for (String recType : recTypeToIds.keySet()) {
            // Invalid record type, invalidate all relevant ids
            if (!validRecordTypeList.contains(recType)) {
                this.invalidRecordIds.addAll(recTypeToIds.get(recType));
                continue;
            }

            Set<Id> recIds = recTypeToIds.get(recType);

            String q = 'SELECT Id FROM ' + recType + ' WHERE Id IN :recIds';
            Map<Id, SObject> validRecs = new Map<Id, SObject>((SObject[]) Database.query(q));

            // Check to see if ids were queried / valid
            for (Id recId : recIds) {
                if (!validRecs.containsKey(recId)) {
                    this.invalidRecordIds.add(recId);
                }
            }
        }

        // Remove invalid ids from eligible requests and from userAssignments
        for (Id recId : this.invalidRecordIds) {
            this.eligibleRequests.remove(recId);
            Set<Id> recIdSet = recIdToSetMap.get(recId);
            recIdSet.remove(recId);
        }
    }

    private void populateUserCounts() {
        Set<Id> ids = userAssignments.keySet();
        counter = new MemberCounter(
            ids,
            cadenceMap
        );

        counter.countActive();
    }

    private void checkAccess() {
        // populate a list of accessible records for each user
        Set<Id> accessibleRecords = getAccessibleRecords();

        // Remove any inaccessible records from the assignment list
        for(Id recordId : eligibleRequests.keySet()) {

            // read only records
            if(!accessibleRecords.contains(recordId)) {
                eligibleRequests.remove(recordId);
                readOnlyRecs.add(recordId);
                continue;
            }

            // records that have exceeded enrollment caps
            Request req = eligibleRequests.get( recordId );
            checkCaps( req );
        }
    }

    Set<Id> getAccessibleRecords() {
        Set<Id> accessibleRecords = new Set<Id>();

        for(Id uid: userAssignments.keySet()) {
            System.debug(userAssignments.get(uid).size() + ' Records for User ==> ' + uid);

            accessibleRecords.addAll(
                ConquerUtility.getAccessibleRecords(
                    userAssignments.get(uid),
                    uid,
                    settings.Prevent_Read_Only_Enrollment__c
                )
            );
        }

        return accessibleRecords;
    }

    void checkCaps(Request req) {
        String err = counter.isEligible(
            req.assignedId,
            req.cadenceId
        );

        // continue if eligible
        if(err == null) {
            return;
        }

        // remove ineligible requests and log reason
        eligibleRequests.remove( req.objectId );

        Set<Id> ids = enrollCapErrors.containsKey( err ) 
            ? enrollCapErrors.get( err ) 
            : new Set<Id>();

        ids.add( req.objectId );
        enrollCapErrors.put( err, ids );
    }

    private String buildCadenceErrorMessage(List<Cadence__c> cadenceList, String singularMsg, String pluralMsg) {
        //Single Cadence
        if(cadenceList.size() == 1) {
            return singularMsg;
        }

        //Concatenate Cadence Names to append to message
        String cadNames = '';
        for(Cadence__c c: cadenceList) {
            cadNames = cadNames + '"' + c.Name + '", ';
        }

        //Remove trailing charaters
        cadNames.removeEnd(', ');

        //Populate message and appended Cadence names
        return cadenceList.size() + pluralMsg + cadNames;
    }

    private void handleInvalidCadences() {
        //Check for invalid Cadences
        List<Cadence__c> cads = [
            SELECT Id, Active__c, Number_of_Steps__c, Start_Date__c, End_Date__c, Name 
            FROM Cadence__c 
            WHERE Id IN :cadenceIds
            AND Excluded_Cadence__c = false
        ];

        //Error message to throw
        String errorMsg = '';

        //Lists for invalid Cadences
        List<Cadence__c> inactive = new List<Cadence__c>();
        List<Cadence__c> noSteps = new List<Cadence__c>();
        List<Cadence__c> beforeStartDateList = new List<Cadence__c>();
        List<Cadence__c> afterEndDateList = new List<Cadence__c>();

        Set<Id> cadenceIds = new Set<Id>();

        // Removes Cadences that are invalid and sorts them into lists.
        for(Cadence__c c: cads) {
            //Inactive
            if(c.Active__c == false) {
                inactive.add(c);
                inactiveCadIds.add(c.Id);
            }

            //No Steps
            else if(c.Number_of_Steps__c < 1) {
                noSteps.add(c);
            } 
            
            else if(c.Start_Date__c <> null && Date.Today() < c.Start_Date__c) {
                beforeStartDateList.add(c);
            }

            else if(c.End_Date__c <> null && Date.Today() > c.End_Date__c) {
                afterEndDateList.add(c);
            } 
            
            else {
                cadenceIds.add(c.Id);
            }
        }

        if(!inactive.isEmpty()) {
            String singularMsg = 'The Cadence you\'ve selected is Inactive. Please activate it or select a different Cadence.';
            String pluralMsg = ' of the Cadences you\'ve selected are Inactive. Please activate them or select different Cadences. Inactive Cadences: ';
            errorMsg = this.buildCadenceErrorMessage(inactive, singularMsg, pluralMsg);
            errorService.addCadenceError(inactive, errorMsg);
        }

        if(!noSteps.isEmpty()) {
            String singularMsg = 'The Cadence you\'ve selected does not have any Steps. Please add Steps or select a different Cadence.';
            String pluralMsg = ' of the Cadences you\'ve selected do not have any Steps. Please add Steps or select different Cadences. Cadences without Steps: ';
            errorMsg = this.buildCadenceErrorMessage(noSteps, singularMsg, pluralMsg);
            errorService.addCadenceError(noSteps, errorMsg);
        }

        if(!beforeStartDateList.isEmpty()) {
            Datetime startDate = (Datetime) beforeStartDateList[0].Start_Date__c;
            String singularMsg = 'The Cadence you\'ve selected has not started yet.  Expected start date: ' + startDate.format('MM/dd/yyyy', 'GMT');
            String pluralMsg = ' of the Cadences you\'ve selected have not started yet. Cadences not started: ';
            errorMsg = this.buildCadenceErrorMessage(beforeStartDateList, singularMsg, pluralMsg);
            errorService.addCadenceError(beforeStartDateList, errorMsg);
        }

        if(!afterEndDateList.isEmpty()) {
            Datetime endDate = (Datetime) afterEndDateList[0].End_Date__c;
            String singularMsg = 'The Cadence you\'ve selected has expired. Expiration date: ' + endDate.format('MM/dd/yyyy', 'GMT');
            String pluralMsg = ' of the Cadences you\'ve selected have expired. Cadences expired: ';
            errorMsg = this.buildCadenceErrorMessage(afterEndDateList, singularMsg, pluralMsg);
            errorService.addCadenceError(afterEndDateList, errorMsg);
        }
        
        // Populate Cadence Map
        cadenceMap = Cadences.getCadenceMap(cadenceIds);
    }

    private void populateTouchpointRequests() {
        for(Cadence_Member__c mem: memberReturnObj.newMemberMap.values()) {
            StartCadence.Request req = this.eligibleRequests.get(mem.Object_Id_Ex__c);

            Id assignedId = mem.Assigned__c;

            if(mem.Assigned_Queue_Id__c <> null) {
                assignedId = Id.valueOf(mem.Assigned_Queue_Id__c);
            }

            CreateTouchpoint.Request createTpReq = new CreateTouchpoint.Request(
                mem.Object_Id_Ex__c, 
                mem.Cadence_Lookup__c,
                assignedId,
                mem.Id,
                mem.Related_Object_Type__c,
                req.startingStep == null ? 1 : req.startingStep.intValue(),
                req.startingDatetime == null ? System.now() : req.startingDatetime,
                req.relatedObjectID,
                req.movedFromTouchpoint,
                true
            );

            createTpReq.setNotes(req.getNotes());
            
            createService.add(createTpReq);
            
            // Collect Members that were assigned to Users rather than Queues
            if(!String.isBlank(mem.Assigned__c)) {
                if(userMap.containsKey(mem.Assigned__c)) {
                    userMap.get(mem.Assigned__c).add(mem);
                }
                else {
                    userMap.put(mem.Assigned__c, new List<Cadence_Member__c>{mem});
                }
            }
        }
    }

    private void populateNotifications() {
        //Create start cadence notifications
        Id typeId = [Select Id From CustomNotificationType Where DeveloperName = 'Start_Cadence'].Id;
        for(Id id : this.userMap.keySet()) {
            List<Cadence_Member__c> mems = this.userMap.get(id);
            Notification noti = new Notification(typeId, mems[0].Object_Id_Ex__c).addRecipient(id);

            //only send to notification center if not one-off enrollment
            if(mems.size() > 1) {
                noti.setTitle('You Have '+mems.size()+' New Cadence Records!');
                noti.setBody(mems.size()+' new Records have been added to your Cadences.');
                notifier.add(noti);
            }
        }
    }

    private void processNewMembers() {
        if(memberReturnObj.newMemberMap != null && !memberReturnObj.newMemberMap.isEmpty()) {
            //Create a new Request for each successfully created Member
            populateTouchpointRequests();

            // Populate Start Cadence Notifications
            populateNotifications();

            if(this.createService.isValid()) {
                this.createService.run();
    
                if(this.notifier.isValid()) {
                    this.notifier.send();
                }

                CreateTouchpoint.Result createResult = createService.getResults();

                CadenceMembers.handleAutoSkippedMembers(createResult.autoSkippedMemberMap);
    
                this.register.addAll(createResult.register);
            }
        }
    }

    private void logEnrollmentErrorRows() {
        if (!memberReturnObj.unauthorizedEnrollments.isEmpty()) {
            errorService.addCadenceMemberError(
                memberReturnObj.unauthorizedEnrollments,
                'The assigned user is not authenticated with Conquer.'
            );
        }

        // Active Cadence Member already exists with this email address
        if(!memberReturnObj.dupeEmailAddresses.isEmpty()){
            errorService.addCadenceMemberError(
                memberReturnObj.dupeEmailAddresses, 
                'There is already an Active Cadence Member with this email address and your Org Settings only allow one Active enrollment per email address.'
            );
        }

        // Record is already enrolled in this Cadence
        if(!memberReturnObj.dupeObjectIds.isEmpty()){
            errorService.addCadenceMemberError(
                memberReturnObj.dupeObjectIds,
                'This record is already Active in that Cadence and cannot be enrolled twice in the same Cadence.'
            );
        }

        // Record is already enrolled in a different Cadence
        if(!memberReturnObj.preventedMultipleEnrollments.isEmpty()){
            errorService.addCadenceMemberError(
                memberReturnObj.preventedMultipleEnrollments,
                'This record is already Active in a Cadence and your Org settings only allow one Active Cadence per record.'
            );
        }

        if(!memberReturnObj.invalidStartingStepEnrollments.isEmpty()) {
            errorService.addCadenceMemberError(
                memberReturnObj.invalidStartingStepEnrollments,
                'Invalid Starting Step.'
            );
        }

        if (!recsWithInvalidUserId.isEmpty()) {
            errorService.addErrorWithRecordIds(
                recsWithInvalidUserId,
                'Invalid User Id.'
            );
        }

        if (!invalidRecordIds.isEmpty()) {
            errorService.addErrorWithRecordIds(
                invalidRecordIds,
                'Invalid Record Id.'
            );
        }

        // Read only record
        if(!readOnlyRecs.isEmpty()) {
            errorService.addErrorWithRecordIds(
                readOnlyRecs,
                'This record read-only for the assigned User. Please try enrolling a record you can edit.'
            );
        }

        // cap exceeded errors
        if(!enrollCapErrors.isEmpty()) {
            for(String msg : enrollCapErrors.keySet()) {
                errorService.addErrorWithRecordIds(
                    enrollCapErrors.get(msg),
                    msg
                );
            }
        }
        
        //insert errors
        if(!memberReturnObj.insertErrors.isEmpty()){
            for (String errMsg : memberReturnObj.insertErrors.keySet()) {
                List<Cadence_Member__c> cadMems = memberReturnObj.insertErrors.get(errMsg);
                errorService.addCadenceMemberError(cadMems, errMsg);
            }
        }
    }

    private void logResults() {
        // aggregate data
        logger.addFailures( requestList.size() - memberReturnObj.newMemberMap.size() );
        logger.addSuccesses( memberReturnObj.newMemberMap.size() );

        // specific error totals
        logger.addReadOnly( readOnlyRecs.size() );
        logger.addDupeEmails( memberReturnObj.dupeEmailAddresses.size() );
        logger.addActiveEnrollments(
            memberReturnObj.dupeObjectIds.size() + memberReturnObj.preventedMultipleEnrollments.size()
        );
        for(String s : enrollCapErrors.keySet()) {
            logger.addCapExceeded(
                s,
                enrollCapErrors.get(s).size()
            );
        }
    }

    public class StartCadenceAsync implements Queueable, RetryTracker, Database.AllowsCallouts {
        public List<StartCadence.Request> reqs;
        integer retryCounter;
        
        public StartCadenceAsync(){}

        public StartCadenceAsync(List<StartCadence.Request> reqs){
            this.reqs = reqs;
            this.retryCounter = 0;
        }
        
        public void setRetryCount(integer retry){
            this.retryCounter = retry;
        }
        
        public void setCollections(ConquerCollections cc){
            this.reqs = cc.startReqs;
        }

        public void execute(QueueableContext queueable){
            ConquerAsyncLogger logger = new ConquerAsyncLogger('StartCadence.StartCadenceAsync', retryCounter, reqs);
            system.attachFinalizer(logger);
            logger.debug('Executing StartCadence for these requests ==> ' + reqs.toString());
            
            // Construct the service
            StartCadence service = new StartCadence(reqs, new CadenceAPIServices.CalloutRegister(), logger);
            Boolean isResult = reqs[0].isThrowable == null || (reqs[0].isThrowable != null && reqs[0].isThrowable);

            // Perform the service
            service.run(isResult);

            // Run register logic to handle callouts and bulk assignment
            if(service.register.isValid()) {
                service.register.run(isResult);
            }
        }
    }

    @AuraEnabled @InvocableVariable
    global string objectID;

    @AuraEnabled @InvocableVariable
    global id relatedObjectID;
    
    @AuraEnabled @InvocableVariable
    global string cadenceID;
    
    @AuraEnabled @InvocableVariable
    global string assignedID;

    @AuraEnabled @InvocableVariable
    global decimal startingStep;

    @AuraEnabled @InvocableVariable
    global datetime startingDatetime;
    
    private class START_CADENCE_EXCEPTION extends Exception {}
}