// Read-only Appendix A counts. Run after the inserts; inspect the debug log.
Integer acc = [SELECT COUNT() FROM Account WHERE AccountNumber LIKE 'HES-SEED-%'];
Integer contacts = [SELECT COUNT() FROM Contact WHERE Email LIKE 'hes.seed.contact.%@example.invalid'];
Integer products = [SELECT COUNT() FROM Product2 WHERE ProductCode LIKE 'HES-SEED-%'];
Integer equipment = [SELECT COUNT() FROM Equipment__c WHERE Serial_Number__c LIKE 'HES-SEED-EQ-%'];
Integer plans = [SELECT COUNT() FROM Coverage_Plan__c WHERE Source_Opportunity_Key__c LIKE 'HESSEEDPLAN%'];
Integer opportunities = [SELECT COUNT() FROM Opportunity WHERE Name LIKE 'HES-SEED-OPP-%'];
Integer cases = [SELECT COUNT() FROM Case WHERE Subject LIKE '%HES-SEED-CASE-%'];
String orgKey = String.valueOf(UserInfo.getOrganizationId());
Set<String> expectedUsernames = new Set<String>();
for (Integer i = 1; i <= 8; i++) {
    expectedUsernames.add('hes.seed.engineer.' + ('00' + String.valueOf(i)).right(2)
        + '.' + orgKey + '@example.invalid');
}
Integer engineers = [SELECT COUNT() FROM User WHERE Username IN :expectedUsernames AND IsActive = false];
Integer knowledge = -1;
if (Schema.getGlobalDescribe().containsKey('Knowledge__kav')) {
    knowledge = Database.countQuery(
        'SELECT COUNT() FROM Knowledge__kav WHERE PublishStatus = \'Online\'');
}
System.debug('HES Appendix A totals: Accounts=' + acc + '/25, Contacts=' + contacts
    + '/60, Products=' + products + '/8, Equipment=' + equipment
    + '/120, Plans=' + plans + '/30, Opportunities=' + opportunities
    + '/40, Cases=' + cases + '/250, inactive engineer Users=' + engineers
    + '/8, published Knowledge=' + knowledge + '/10 (-1 means unavailable).');
