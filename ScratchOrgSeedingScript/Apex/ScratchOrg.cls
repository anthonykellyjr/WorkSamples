@RestResource(urlMapping='/ScratchOrg/*')
global with sharing class ScratchOrg {
    
    public static Savepoint sp;
    public final Boolean RUN_AUTO_ENROLL;
    public static final Boolean HAS_VOICE_PACKAGE = hasInstalledVoice();

    public ScratchOrg() {
        authToConquer(); // post to jenkins add acct endpoint. returns '200 ok' immediately
        sp = Database.setSavepoint(); //roll back everything if anything fails?
        setup();
    }
    // allow user to set false booelan and not auto enroll
    public ScratchOrg(Boolean r) {
        authToConquer(); // post to jenkins add acct endpoint. returns '200 ok' immediately
        sp = Database.setSavepoint(); //roll back everything if anything fails?
        this.RUN_AUTO_ENROLL = r;
        setup();
    }

    public static Boolean hasInstalledVoice() {
        String[] dsActionTypes = new String[] {
            'DS_Denali__DialSource_Action__c', // enterprise pkg namespace
            'DialSource__DialSource_Action__c' // standard pkg namespace
        };

        for (String actionType : dsActionTypes) {
            if (Type.forName(actionType) <> null) {
                return true;
            }
        }
        return false;
    }

    @HttpPost
    global static void createOrg() {
        new ScratchOrg();
    }


    @HttpGet
    global static String getStatus() {
        return checkStatus();
    }

    public void setup() {
        if([SELECT OrganizationType FROM Organization LIMIT 1].OrganizationType <> 'Developer Edition') {
            throw new SCRATCH_ORG_EXCEPTION('Scratch Org setup script not available outside of Developer Scratch Orgs');
        }
        ScratchOrgController ctrl;
        try {
            // do not proceed with lead creation + cadence enrollment if FALSE value passed to constructor
            Boolean shouldEnrollLeads = (RUN_AUTO_ENROLL == null || RUN_AUTO_ENROLL == true);
            
            ctrl = new ScratchOrgController(shouldEnrollLeads);
            Boolean upsertSuccess = ctrl.upsertUsers(); // method returns isSuccess if user setup completed
            
            if (!upsertSuccess) {
                Database.rollback(sp);
                System.debug('User Configurator failed. Scratch Org setup aborted');
                return;
            }

            logJob(ctrl.insertOutcomes(), 'Insert_Outcomes'); //queueable mdt deployment. create pos, neg, neutral outcomes
            logJob(ctrl.insertSettings(), 'Insert_Custom_Settings'); // queueable. create custom settings rec
            logJob(ctrl.insertSampleData(), 'Insert_Sample_Data'); // queueable. create sample cadences, leads, enroll records.

        } catch(Exception ex) {
            Database.rollback(sp);
            System.debug('Scratch Org setup failed: ' + ex.getMessage() + '. ' + ex.getStackTraceString());
            return;
        }
    }

    // serialize obj to JSON and post to auth endpoint
    public class OrgInfo {
        Id aid;
        Id uid;

        public OrgInfo() {
            this.aid = UserInfo.getOrganizationId();
            this.uid = UserInfo.getUserId();
        }
    }

    public static HttpResponse authToConquer() {
        String payload = JSON.serialize(new OrgInfo());
        HttpRequest req = new HttpRequest();
        Http http = new Http();
        req.setMethod('POST');
        req.setHeader('content-type', 'application/json');
        req.setEndpoint('https://ci.dialsource.com/generic-webhook-trigger/invoke?token=HpNzuQuKuet7RvBZ8T7P5758');
        req.setBody(payload);
        if(Test.isRunningTest()) return new HTTPResponse();
        HttpResponse res = http.send(req);
        return res;
    }

    // get url for call center that enabled C2D 
    public static string getPhoneUrl() {
        string vfOrigin = '';
        String myRegEx = '\\b.my.\\b'; // regex match to exactly get '.my.' string, with punctuation escaped
        string baseURL = ' ' + URL.getOrgDomainUrl().toExternalForm() + ' ';
        
        Organization oOrg = [SELECT InstanceName, IsSandbox, OrganizationType FROM Organization LIMIT 1];
        String instName = oOrg.InstanceName.toLowerCase();
        if(oOrg.OrganizationType == 'Developer Edition'){
            /*** 
             * Expected Format for Scratch & Trailhead Playground DE Orgs:
             * https://domain--[namespace].[instancename].visual.force.com
             * */
            if(baseURL.contains(instName)) {
                vfOrigin = baseURL.split('.' + oOrg.InstanceName.toLowercase() + '.')[0]+'--ds-denali.vf.force.com/apex/dialsourceCallCenterLightning';
            } else {
              vfOrigin = baseURL.split(myRegEx)[0]+'--ds-denali.vf.force.com/apex/dialsourceCallCenterLightning';
            }
        } else {
            /***
             * Expected Format for Production, Sandbox & personal DE Orgs:
             * https://domain--[namespace].visualforce.com
             */
            vfOrigin = baseURL.split(myRegEx)[0]+'--ds-packages.'+instName+'.visual.force.com/apex/dialsourceCallCenterLightning';
        }
        return vfOrigin;
    }
    
    public class JobStatus {
        public String jobName;
        public String jobStatus;
        public String jobDetail;

        public JobStatus(String n, String s, String d) {
            this.jobName = n;
            this.jobStatus = s;
            this.jobDetail = d;
        }
    }

    // get status of various queued jobs
    public static String checkStatus() {
        Set<id> jobsIds = new Set<Id>();
        Set<JobStatus> output = new Set<JobStatus>();
        Map<String, JobStatus> nameToJobStatus = new Map<String, JobStatus>();
        List<Conquer_Async_Job__c> updateJobs = new List<Conquer_Async_Job__c>();
        
        // check status of all jobs and output as JSON string
        Set<String> jobNames = new Set<String>{
            'ScratchOrgController.Insert_Cadences',
            'ScratchOrgController.Insert_Outcomes',
            'ScratchOrgController.Assign_Call_Centers',
            'ScratchOrgController.Insert_Custom_Settings'
        };
        Set<Conquer_Async_Job__c> conquerJobs = new Set<Conquer_Async_Job__c>([SELECT Id, Job_Status__c, Job_Id__c, Class_Name__c FROM Conquer_Async_Job__c WHERE Class_Name__c IN :jobNames]);

        for(Conquer_Async_Job__c c : conquerJobs) {
            jobsIds.add(c.Job_Id__c);
        }
        
        Map<Id, AsyncApexJob> idToAsyncJob = new Map<Id, AsyncApexJob>();
        Map<AsyncApexJob, Conquer_Async_Job__c> asyncToConqJobs = new Map<AsyncApexJob, Conquer_Async_Job__c>();
        Map<Id, AsyncApexJob> apexJobs = new Map<Id,AsyncApexJob>([SELECT Id, Status, ExtendedStatus, CreatedDate FROM AsyncApexJob WHERE Id IN :jobsIds ORDER BY CreatedDate DESC]);

        //check standard user created
        Integer stdUser = [SELECT count() FROM User WHERE Name = 'Standard User' AND IsActive = true];
        String uText = stdUser > 0 ? 'Completed' : 'Failed';
        output.add(new JobStatus('Insert_Standard_User', uText, null));
        
        

        for(Conquer_Async_Job__c c : conquerJobs) {
            idToAsyncJob.put(c.Job_Id__c, apexJobs.get(c.Job_Id__c));
        }

        for(Conquer_Async_Job__c c : conquerJobs) {
            if(idToAsyncJob.containsKey(c.Job_Id__c)) {
                AsyncApexJob job = idToAsyncJob.get(c.Job_Id__c);
                c.Job_Status__c = job.Status;
                c.Job_Result__c = job.ExtendedStatus;
                updateJobs.add(c);
                asyncToConqJobs.put(job, c);
            }
        }

        // create a new job status for each job collected
        for(AsyncApexJob j : asyncToConqJobs.keySet()) {
            Conquer_Async_Job__c c = asyncToConqJobs.get(j);
            String className = c.Class_Name__c.split('ScratchOrgController.')[1];

            if(!nameToJobStatus.containsKey(className)) {
                nameToJobStatus.put(className, new JobStatus(
                    className,
                    j.Status,
                    j.ExtendedStatus
                ));
            }
        }

        for(JobStatus s : nameToJobStatus.values()) {
            output.add(s);
        }

        try {
            update updateJobs;
        } catch(Exception ex) {
            System.debug(ex.getMessage());
        }
        return JSON.serializePretty(output);
    }

    @future(callout=false) // create Conquer Async Job record to query against for status updates
    public static void logJob(Id jobId, String methodName) {
        String error;
        Integer availableLimit = Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();
        List < Conquer_Async_Job__c > asyncRequestsToInsert = new List < Conquer_Async_Job__c > ();

        Conquer_Async_Job__c asyncRequest = new Conquer_Async_Job__c(
            Class_Name__c = 'ScratchOrgController.'+methodName
        );

        if (availableLimit > 0) {
            asyncRequest.Job_Id__c = jobId;
            asyncRequest.Job_Status__c = 'Enqueued';
            availableLimit--;
        } else {
            throw new SCRATCH_ORG_EXCEPTION('Attempted to log job: Async Request Limit Reached');
        }
        asyncRequestsToInsert.add(asyncRequest);

        try {
            insert asyncRequestsToInsert;
        } catch(DMLException ex) {
            System.debug('Error inserting async job recs: '+ex.getMessage());
        }
    }


    private class SCRATCH_ORG_EXCEPTION extends EXCEPTION {}
}
