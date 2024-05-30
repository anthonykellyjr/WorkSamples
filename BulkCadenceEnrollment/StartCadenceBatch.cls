public class StartCadenceBatch implements database.Batchable<StartCadence.Request>{

    public List<StartCadence.Request> records;
    private ConquerAsyncLogger logger = new ConquerAsyncLogger('StartCadenceBatch');

    
    public StartCadenceBatch(List<StartCadence.Request> records){
        this.records = records;
    }
    
    public iterable<StartCadence.Request> start(database.BatchableContext bc){
        logger.insertJob(bc.getJobId());
        return records;
    }
    
    public void execute(database.BatchableContext bc, List<StartCadence.Request> scope){
        // Map database values to logger obj
        logger.setExistingJob(bc.getJobId());

        Id batchJobId = bc.getJobId();
        Id jobLogRecId = logger.jobLog.Id;

        // Start Cadence for the current batch
        ConquerAsyncLogger results = StartCadence.startCadence(
            scope,
            new ConquerAsyncLogger('StartCadence'),
            batchJobId,
            jobLogRecId
        );

        // Update logger with results from this batch
        logger.updateJob(results);
    }
    
    public void finish(database.BatchableContext bc){
       logger.finishJob(bc.getJobId());
    }
}