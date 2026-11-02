// HES Appendix A seed, Case batch 1-50 of 250.
// Direct inserts: the closure email Flow runs only on update to Closed.
// Addresses use .invalid; DML email flags and assignment rules are disabled.
Map<String, Account> accounts = new Map<String, Account>();
for (Account a : [SELECT Id, AccountNumber, Region__c FROM Account
        WHERE AccountNumber LIKE 'HES-SEED-%']) accounts.put(a.AccountNumber, a);
Map<Id, List<Contact>> contactsByAccount = new Map<Id, List<Contact>>();
for (Contact c : [SELECT Id, AccountId, Email FROM Contact
        WHERE Email LIKE 'hes.seed.contact.%@example.invalid' ORDER BY Email]) {
    if (!contactsByAccount.containsKey(c.AccountId)) contactsByAccount.put(c.AccountId, new List<Contact>());
    contactsByAccount.get(c.AccountId).add(c);
}
Map<Id, List<Equipment__c>> equipmentByAccount = new Map<Id, List<Equipment__c>>();
for (Equipment__c e : [SELECT Id, Account__c FROM Equipment__c
        WHERE Serial_Number__c LIKE 'HES-SEED-EQ-%' ORDER BY Serial_Number__c]) {
    if (!equipmentByAccount.containsKey(e.Account__c)) equipmentByAccount.put(e.Account__c, new List<Equipment__c>());
    equipmentByAccount.get(e.Account__c).add(e);
}
Map<String, Id> queues = new Map<String, Id>();
for (Group g : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue'
        AND DeveloperName LIKE 'HES_%']) queues.put(g.DeveloperName, g.Id);
System.assert(accounts.size() >= 25 && queues.containsKey('HES_Region_Review')
    && queues.containsKey('HES_Junk_Review'), 'Run earlier seeds and confirm the Case queues.');
List<String> statuses = new List<String>{'Closed', 'New', 'Working', 'Escalated',
    'New', 'Closed', 'Working', 'New', 'Closed', 'Working'};
List<Decimal> efforts = new List<Decimal>{0.5, 1, 2, 4, 6, 8, 12, 16, 24};
List<String> subjectPool = new List<String>{'Compressor vibration', 'Pump inspection',
    'Cooling performance', 'Invoice question', 'Pressure warning',
    'Maintenance visit', 'Generator start', 'Plan charges'};
Set<String> wantedSubjects = new Set<String>();
for (Integer i = 1; i <= 50; i++) {
    String marker = 'HES-SEED-CASE-' + ('0000' + String.valueOf(i)).right(4);
    wantedSubjects.add((Math.mod(i, 25) == 0 ? '[JUNK] ' : '') + marker +
        ' | ' + subjectPool[Math.mod(i - 1, 8)]);
}
Set<String> presentSubjects = new Set<String>();
for (Case c : [SELECT Subject FROM Case WHERE Subject IN :wantedSubjects]) presentSubjects.add(c.Subject);
Database.DMLOptions noMail = new Database.DMLOptions();
noMail.emailHeader.triggerAutoResponseEmail = false;
noMail.emailHeader.triggerUserEmail = false;
noMail.emailHeader.triggerOtherEmail = false;
noMail.assignmentRuleHeader.useDefaultRule = false;
List<Case> newCases = new List<Case>();
for (Integer i = 1; i <= 50; i++) {
    String marker = 'HES-SEED-CASE-' + ('0000' + String.valueOf(i)).right(4);
    Boolean junk = Math.mod(i, 25) == 0;
    String subject = (junk ? '[JUNK] ' : '') + marker + ' | '
        + subjectPool[Math.mod(i - 1, 8)];
    if (presentSubjects.contains(subject)) continue;
    Integer aNumber = 1 + Math.mod(i * 7, 25);
    String aKey = 'HES-SEED-' + ('0000' + String.valueOf(aNumber)).right(4);
    Account account = accounts.get(aKey);
    System.assert(account != null && contactsByAccount.containsKey(account.Id)
        && equipmentByAccount.containsKey(account.Id), 'Earlier seed data is incomplete: ' + aKey);
    List<Contact> people = contactsByAccount.get(account.Id);
    Contact person = people[Math.mod(i, people.size())];
    String region = (Math.mod(i, 13) == 0 ? 'Unknown' : account.Region__c);
    String caseType = (Math.mod(i, 4) == 0 ? 'Billing' : 'Technical');
    String ownerKey = (junk ? 'HES_Junk_Review'
        : (region == 'Unknown' || region == 'Other'
            ? 'HES_Region_Review' : 'HES_' + region + '_' + caseType));
    System.assert(queues.containsKey(ownerKey), 'Missing Case queue ' + ownerKey);
    Case c = new Case(AccountId = account.Id, ContactId = person.Id,
        OwnerId = queues.get(ownerKey), Subject = subject,
        Description = 'Appendix A service scenario ' + String.valueOf(i)
            + '. This is fictional demo data; no customer email is required.',
        Origin = (Math.mod(i, 2) == 0 ? 'Email' : 'Web'),
        Status = statuses[Math.mod(i - 1, 10)], Region__c = region,
        Type = caseType, Estimated_Effort_Hours__c = efforts[Math.mod(i - 1, 9)]);
    if (Math.mod(i, 5) != 0) {
        List<Equipment__c> installed = equipmentByAccount.get(account.Id);
        c.Equipment__c = installed[Math.mod(i, installed.size())].Id;
    }
    // Only an authorized audit-field loader can backdate CreatedDate.
    if (Schema.SObjectType.Case.fields.getMap().get('CreatedDate').getDescribe().isCreateable()) {
        c.put('CreatedDate', Datetime.now().addDays(-Math.mod(i * 3, 150)));
    }
    c.setOptions(noMail);
    newCases.add(c);
}
if (!newCases.isEmpty()) insert newCases;
System.debug('HES seed Cases 1-50: inserted ' + newCases.size()
    + '. No real addresses, closure transitions, or auto-response emails.');
