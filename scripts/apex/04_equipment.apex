// HES Appendix A seed, part 4: 120 units, unevenly distributed across 25 Accounts.
// 5 Accounts get 9 each, 15 get 4 each, and 5 get 3 each.
Map<String, Id> accounts = new Map<String, Id>();
for (Account a : [SELECT Id, AccountNumber FROM Account WHERE AccountNumber LIKE 'HES-SEED-%']) {
    accounts.put(a.AccountNumber, a.Id);
}
Map<String, Id> products = new Map<String, Id>();
for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'HES-SEED-%']) {
    products.put(p.ProductCode, p.Id);
}
Map<String, Id> plans = new Map<String, Id>();
for (Coverage_Plan__c p : [SELECT Id, Source_Opportunity_Key__c FROM Coverage_Plan__c
        WHERE Source_Opportunity_Key__c LIKE 'HESSEEDPLAN%']) {
    plans.put(p.Source_Opportunity_Key__c, p.Id);
}
System.assert(accounts.size() >= 25 && products.size() >= 8 && plans.size() >= 30,
    'Run seed 01 and 03 first.');
Set<String> existingSerials = new Set<String>();
for (Equipment__c e : [SELECT Serial_Number__c FROM Equipment__c
        WHERE Serial_Number__c LIKE 'HES-SEED-EQ-%']) {
    existingSerials.add(e.Serial_Number__c);
}
List<Equipment__c> units = new List<Equipment__c>();
for (Integer i = 0; i < 120; i++) {
    String serial = 'HES-SEED-EQ-' + ('0000' + String.valueOf(i + 1)).right(4);
    if (existingSerials.contains(serial)) continue;
    Integer accZero;
    Integer position;
    Integer unitsForAccount;
    if (i < 45) {
        accZero = i / 9; position = Math.mod(i, 9); unitsForAccount = 9;
    } else if (i < 105) {
        accZero = 5 + ((i - 45) / 4); position = Math.mod(i - 45, 4); unitsForAccount = 4;
    } else {
        accZero = 20 + ((i - 105) / 3); position = Math.mod(i - 105, 3); unitsForAccount = 3;
    }
    String accountKey = 'HES-SEED-' + ('0000' + String.valueOf(accZero + 1)).right(4);
    Equipment__c eq = new Equipment__c(Account__c = accounts.get(accountKey),
        Product__c = products.get('HES-SEED-' + String.valueOf(101 + Math.mod(i, 8))),
        Serial_Number__c = serial);
    if (Math.mod(i, 9) == 0) eq.Last_Service_Date__c = Date.today().addDays(-20 - Math.mod(i, 50));
    // Expired historical plans retain their pointers. Draft plans never become current.
    Integer historicalCount = 2 + Math.mod(accZero, 3);
    if (historicalCount > unitsForAccount) historicalCount = unitsForAccount;
    if (accZero >= 18 && accZero < 24 && position < historicalCount) {
        String key = 'HESSEEDPLAN' + ('0000000' + String.valueOf(accZero + 1)).right(7);
        eq.Current_Coverage_Plan__c = plans.get(key);
    }
    units.add(eq);
}
if (!units.isEmpty()) insert units;
System.debug('HES seed 04 done: 120 Equipment target, created ' + units.size()
    + '. Draft plans have no current-coverage pointer.');
