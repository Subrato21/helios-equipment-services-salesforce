// HES Appendix A seed, part 3: 30 plans on 25 customers.
// HESSEEDPLAN0000001..0030 is a reserved seed key in the existing unique
// Source_Opportunity_Key__c field; these plans do not claim a source sale.
Map<String, Id> accounts = new Map<String, Id>();
for (Account a : [SELECT Id, AccountNumber FROM Account WHERE AccountNumber LIKE 'HES-SEED-%']) {
    accounts.put(a.AccountNumber, a.Id);
}
System.assert(accounts.size() >= 25, 'Run seed 01 first.');
Set<String> existingKeys = new Set<String>();
for (Coverage_Plan__c p : [SELECT Source_Opportunity_Key__c FROM Coverage_Plan__c
        WHERE Source_Opportunity_Key__c LIKE 'HESSEEDPLAN%']) {
    existingKeys.add(p.Source_Opportunity_Key__c);
}
List<Coverage_Plan__c> plans = new List<Coverage_Plan__c>();
Date today = Date.today();
List<String> levels = new List<String>{'Basic', 'Standard', 'Premium'};
for (Integer i = 0; i < 30; i++) {
    String key = 'HESSEEDPLAN' + ('0000000' + String.valueOf(i + 1)).right(7);
    if (existingKeys.contains(key)) continue;
    Integer accountIndex = 1 + Math.mod(i, 25);
    String accountKey = 'HES-SEED-' + ('0000' + String.valueOf(accountIndex)).right(4);
    String status;
    Date startDate;
    Date endDate;
    if (i < 10) {
        status = 'Active'; startDate = today.addDays(-60 - i); endDate = today.addDays(180 + i);
    } else if (i < 18) {
        status = 'Active'; startDate = today.addDays(-150); endDate = today.addDays(7 + i - 10);
    } else if (i < 24) {
        status = 'Expired'; startDate = today.addDays(-420); endDate = today.addDays(-5 - i);
    } else {
        status = 'Draft'; startDate = today.addDays(10 + i); endDate = today.addDays(375 + i);
    }
    plans.add(new Coverage_Plan__c(Account__c = accounts.get(accountKey),
        Source_Opportunity_Key__c = key, Status__c = status,
        Service_Level__c = levels[Math.mod(i, 3)],
        Start_Date__c = startDate, End_Date__c = endDate));
}
if (!plans.isEmpty()) insert plans;
System.debug('HES seed 03 done: 30 plans target, including 18 active, '
    + '6 expired, and 6 draft; created ' + plans.size() + '.');
