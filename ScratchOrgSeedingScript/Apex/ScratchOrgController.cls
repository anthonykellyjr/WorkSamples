public with sharing class ScratchOrgController {

    private Boolean runAutoEnroll;

    public ScratchOrgController() {
        this.runAutoEnroll = true;
    }
    public ScratchOrgController(Boolean r) {
        this.runAutoEnroll = r;
    }

    public Boolean upsertUsers() {
        return new UserConfigurator().isSuccess; // determines if the program aborts or proceeds
    }

    public Id insertOutcomes() {
        return System.enqueueJob(new CreateOutcomes());
    }

    public Id insertSettings() {
        return System.enqueueJob(new CreateSettings());
    }

    public Id insertSampleData() {
        return System.enqueueJob(new InsertSampleData(runAutoEnroll));
    }

    public class UserConfigurator {
        private User adminUser;
        private User standardUser;
        private Id callCenterId = null;
        public Boolean isSuccess = false;
        private boolean hasVoicePackage = ScratchOrg.hasInstalledVoice();
    
        public UserConfigurator() {
            adminUser = configureAdmin();
            if (adminUser == null) {
                System.debug(
                    'Admin user could not be located in org. Aborting job.'
                );
                return;
            }

            standardUser = getOrCreateStandardUser(adminUser);
            if (standardUser == null) {
                System.debug(
                    'Standard user could not be created or queried. Aborting job.'
                );
                return;
            }

            assignPermSets(standardUser.Id, adminUser.Id);
            // if all methods complete, report success. else, abort scratch org creation
            isSuccess = true;
        }
    
        private User configureAdmin() {
            List<User> admins = [
                SELECT Id, Name, Email, CallCenterId, CompanyName, Address, 
                TimeZoneSidKey, Username, Profile.UserLicense.Name, Alias, LocaleSidKey, 
                EmailEncodingKey, LanguageLocaleKey, UserPreferencesUserDebugModePref 
                FROM User WHERE Name = 'User User' LIMIT 1
            ];
            if (admins.isEmpty()) {
                return null;
            }
            User admin = admins[0];

            // cannot query for Call Centers in a test context
            if (!Test.isRunningTest() && hasVoicePackage) {
                CallCenter callCenter = [Select c.InternalName, c.Id, c.AdapterUrl From CallCenter c WHERE InternalName = 'DialSourceDenaliLightning'];
                callCenterId = callCenter.Id;
            }
            // if voice is not installed, callCenterId will remain null, which is harmless
            admin.CallCenterId = callCenterId;
            // enable debug mode for primary user
            admin.UserPreferencesUserDebugModePref = true;

            try {
                update admin;
            } catch (Exception ex) {
                throw new SCRATCH_ORG_CONTROLLER_EXCEPTION('Error updating admin user: ' + ex.getMessage());
            }
            return admin;
        }
    
        private User getOrCreateStandardUser(User admin) {
            Id standardProfileId = getStandardProfileId();

            if (standardProfileId == null) {
                return null;
            }
    
            User existingStandardUser = getExistingStandardUser();
    
            if (existingStandardUser != null) {
                return existingStandardUser;
            }
    
            return createStandardUser(admin, standardProfileId);
        }

        private User createStandardUser(User admin, Id standardProfileId) {
            String standardUsername = 'standard' + Crypto.getRandomInteger() + admin.Username;
    
            User standardUser = new User(
                FirstName = 'Standard',
                LastName = 'User',
                Email = admin.Email,
                Alias = 'standard',
                CallCenterId = callCenterId,
                CompanyName = admin.CompanyName,
                TimeZoneSidKey = admin.TimeZoneSidKey,
                Username = standardUsername,
                ProfileId = standardProfileId,
                IsActive = true,
                UserPermissionsMarketingUser = true,
                LocaleSidKey = admin.LocaleSidKey,
                EmailEncodingKey = admin.EmailEncodingKey,
                LanguageLocaleKey = admin.LanguageLocaleKey
            );
    
            try {
                insert standardUser;
                return standardUser;
            } catch (Exception ex) {
                throw new SCRATCH_ORG_CONTROLLER_EXCEPTION('Error creating standard user: ' + ex.getMessage());
            }
        }
    
        private Id getStandardProfileId() {
            Profile standardProfile = [
                SELECT Id FROM Profile
                WHERE Name = 'Standard User'
                LIMIT 1
            ];
            return standardProfile != null ? standardProfile.Id : null;
        }
    
        private User getExistingStandardUser() {
            List<User> standardUsers = [
                SELECT Id FROM User
                WHERE Name = 'Standard User'
                AND IsActive = true
            ];
            return standardUsers.isEmpty() ? null : standardUsers[0];
        }
    
        public void assignPermSets(Id standardUserId, Id adminUserId) {
            Set<String> standardPermissionSets = new Set<String>{
                'DS_Denali_User', 'DialSource_Cadence_User'
            };
            
            Set<String> adminPermissionSets = new Set<String>{
                'DS_Denali_Admin', 'DialSource_Cadence_Admin'
            };
        
            Set<Id> adminUserPermSets = getPermSetAssignments(adminUserId);
            Set<Id> standardUserPermSets = getPermSetAssignments(standardUserId);
        
            List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        
            for (String permSetName : standardPermissionSets) {
                Id permSetId = getPermSetId(permSetName);
                
                if (permSetId <> null && !standardUserPermSets.contains(permSetId)) {
                    assignments.add(new PermissionSetAssignment(
                        PermissionSetId = permSetId, AssigneeId = standardUserId
                    ));
                }
            }
        
            for (String permSetName : adminPermissionSets) {
                Id permSetId = getPermSetId(permSetName);
                
                if (permSetId <> null && !adminUserPermSets.contains(permSetId)) {
                    assignments.add(new PermissionSetAssignment(
                        PermissionSetId = permSetId, AssigneeId = adminUserId
                    ));
                }
            }
        
            if (!assignments.isEmpty()) {
                try {
                    insert assignments;
                } catch (Exception ex) {
                    throw new SCRATCH_ORG_CONTROLLER_EXCEPTION('Error assigning perm sets: ' + ex.getMessage());
                }
            }
        }
        // check existing assignments for an individual User
        private Set<Id> getPermSetAssignments(Id userId) {
            Set<Id> permissionSets = new Set<Id>();
            for (PermissionSetAssignment assignment : [
                SELECT PermissionSetId
                FROM PermissionSetAssignment
                WHERE AssigneeId = :userId
            ]) {
                permissionSets.add(assignment.PermissionSetId);
            }
    
            return permissionSets;
        }
    
        private Id getPermSetId(String permissionSetName) {
            Map<String, Id> nameToPermset = new Map<String, Id>();
    
            for (PermissionSet permSet : [
                SELECT Id, Name
                FROM PermissionSet
            ]) {
                nameToPermset.put(permSet.Name, permSet.Id);
            }

            return nameToPermset.get(permissionSetName);
        }
    }
    

    public class CreateSettings implements Queueable {
        private Boolean hasExecuted = false;
        public void execute(System.QueueableContext context) {
            // check for existing settings record
            if ([SELECT id FROM cadence_settings__c].size() > 0) {
                return;
            }

            cadence_settings__c settings = new cadence_settings__c(
                Create_Task_for_Completed_Calls__c = true,
                Create_Task_for_Completed_Custom_Steps__c = true,
                Create_Task_for_Completed_Emails__c = true,
                Create_Task_for_Completed_SMS__c = true,
                API_Threshold_for_Error_Logs__c = 10
            );

            try {
                if (!hasExecuted) {
                    insert settings;
                    hasExecuted = true;
                }
            } catch (DMLException e) {
                throw new SCRATCH_ORG_CONTROLLER_EXCEPTION('Error creating settings obj:', e);
            }
        }
    }


    public class CreateOutcomes implements Queueable {
        private Boolean hasExecuted = false;
        public void execute(System.QueueableContext context) {

            Set < MetadataUpsert.Record > defaults = new Set < MetadataUpsert.Record > ();
            Set < String > names = new Set < String > {
                'Neutral',
                'Positive',
                'Negative'
            };
            for (String name: names) {
                Map < String, Object > fieldsMap = new Map < String, Object > ();
                fieldsMap.put('Outcome_Weight__c', 1);
                fieldsMap.put('Sentiment__c', name);
                fieldsMap.put('Step_Type_Relationship__c', 'All');
                defaults.add(new MetadataUpsert.Record(name, 'DS_Touchpoint_Outcome__mdt', fieldsMap));
            }
            if (hasExecuted) return;
            MetadataUpsert.upsertMdt(defaults);
            hasExecuted = true;
        }
    }


    public class InsertSampleData implements Queueable {
        private Boolean hasExecuted = false;
        private final Boolean runAutoEnroll;

        public InsertSampleData() {
            this.runAutoEnroll = true;
        }
        public InsertSampleData(Boolean r) {
            this.runAutoEnroll = r;
        }

        //Load Lead data from MockLeads.CSV Static resource
        public void loadMockLeads() {
            StaticResource leadsSR = [SELECT Id, Body FROM StaticResource WHERE Name = 'MockLeads' LIMIT 1];
            String bodyLeadsSr = leadsSr.Body.toString();
            //Parse using chosen separator
            SSSCsvReader bodyLeadsSrcsvR = new SSSCsvReader(bodyLeadsSr, ',');
            //Removing header if you are using a title (optional)
            bodyLeadsSrcsvR.readLine();
            //Load the next line in a variable
            String[] bodyLeadsSRline = bodyLeadsSrcsvR.readLine();
            List < Lead > leadSampleList = new List < Lead > ();
            While(bodyLeadsSRline != null) {
                leadSampleList.add(
                    new Lead(FirstName = bodyLeadsSRline[0], LastName = bodyLeadsSRline[1], Title = bodyLeadsSRline[2], Company = bodyLeadsSRline[3], Street = bodyLeadsSRline[4], City = bodyLeadsSRline[5], State = bodyLeadsSRline[6], Phone = bodyLeadsSRline[7], Email = bodyLeadsSRline[8], LeadSource = bodyLeadsSRline[9])
                );
                bodyLeadsSRline = bodyLeadsSrcsvR.readLine();
            }
            // Last line if not null
            if (bodyLeadsSRline != null) {
                leadSampleList.add(
                    new Lead(FirstName = bodyLeadsSRline[0], LastName = bodyLeadsSRline[1], Title = bodyLeadsSRline[2], Company = bodyLeadsSRline[3], Street = bodyLeadsSRline[4], City = bodyLeadsSRline[5], State = bodyLeadsSRline[6], Phone = bodyLeadsSRline[7], Email = bodyLeadsSRline[8], LeadSource = bodyLeadsSRline[9])
                );
            }
            if (leadSampleList != null) {
                Insert leadSampleList;
            }
        }

        public void execute(System.QueueableContext context) {
            try {
                if (!hasExecuted) {
                    CadenceAPIEndpoint.createSampleData(); // create cadences
                    if(!Test.isRunningTest()) {
                        loadMockLeads(); // csv static resource loader has its own test coverage
                        if(runAutoEnroll) {
                            System.enqueueJob(new AutoEnrollLeads()); // tests do not allow 
                        }
                    }
                    hasExecuted = true;
                }
            } catch (Exception ex) {
                throw new SCRATCH_ORG_CONTROLLER_EXCEPTION('Error creating sample data: ' + ex.getMessage());
            }
        }
    }

    public class AutoEnrollLeads implements Queueable {
        private Boolean hasExecuted = false;

        private Boolean isEven(Integer i) {
            return math.mod(i, 2) == 0; // for splitting lead enrollment
        }
        // enroll some records in cadence a, some in cadence b
        private void enrollLeads() {
            Id userId = userInfo.getUserId();
            if (Lead.SObjectType.getDescribe().isAccessible()) {
                Integer leadCount = [SELECT count() FROM Lead];
                Integer leadCountHalved = leadCount / 2;
                Integer enrollLimit = leadCountHalved > 200 ? 200 : leadCountHalved; // max out at 200
                Id cadenceId1 = [SELECT id FROM Cadence__c WHERE Excluded_Cadence__c = false LIMIT 1].Id;
                Id cadenceId2 = [SELECT id FROM Cadence__c WHERE Id <> :cadenceId1 AND Excluded_Cadence__c = false LIMIT 1].Id;
                List<StartCadence.Request> listRequest = new List<StartCadence.Request>();

                Integer idx = 0;
                for (Lead l : [SELECT Id FROM Lead LIMIT :leadCountHalved]) {
                    if (isEven(idx)) {
                        listRequest.add(new StartCadence.Request(l.Id, cadenceId1, userId, 1, System.now()));
                    } else {
                        listRequest.add(new StartCadence.Request(l.Id, cadenceId2, userId, 1, System.now()));
                    }
                    idx++;
                }
                List<Result> results = StartCadenceService.startCadence(listRequest);
            }
        }
        public void execute(System.QueueableContext context) {
            try {
                if (!hasExecuted) {
                    enrollLeads();
                    hasExecuted = true;
                }
            } catch (Exception ex) {
                throw new SCRATCH_ORG_CONTROLLER_EXCEPTION('Error enrolling Leads into cadences: ' + ex.getMessage());
            }
        }
    }

    private class SCRATCH_ORG_CONTROLLER_EXCEPTION extends EXCEPTION {}
}