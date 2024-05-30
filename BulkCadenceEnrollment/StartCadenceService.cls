global class StartCadenceService {
    
   	@InvocableMethod(label='Start Cadence Service' Description='Enrolls a record in a Cadence and creates the first Touchpoint.')
    global static List<Result> startCadence(List<StartCadence.Request> reqs) {
        
        List<Result> resList = new List<Result>();
        
        Result res = new Result();
        
        //If there are multiple Requests, process them asynchronously
        if(reqs.size() > 1 && !System.isBatch() && !System.isQueueable() && !system.isFuture() && (!test.isRunningTest())) {
            // Queue the job and return job Id
            res.setData(System.enqueueJob(new StartCadence.StartCadenceAsync(reqs)));
        }
        //Otherwise, process synchronously
        else {
            // Perform the service
            StartCadence service = new StartCadence(reqs, new CadenceAPIServices.CalloutRegister());
            
            if(reqs[0].isThrowable == null || (reqs[0].isThrowable != null && !reqs[0].isThrowable)) res = service.run(true);
            else res = service.run(false);
            
            // Run register logic to handle callouts and bulk assignment
            if(service.register.isValid()) {
                 if(reqs[0].isThrowable == null || (reqs[0].isThrowable != null && reqs[0].isThrowable)) service.register.run(true);
            	else service.register.run(false);
            }
        }
        
        for(integer i = 0; i < reqs.size(); i++)
        	resList.add(res);
        
        return resList;
        
    }

}