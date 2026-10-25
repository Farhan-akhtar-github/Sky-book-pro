public with sharing class DailyDepartureReminderScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        System.enqueueJob(new DepartureReminderQueueable());
    }
}
