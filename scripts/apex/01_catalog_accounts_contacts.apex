// HES Appendix A seed, part 1. Run once or rerun safely.
// All addresses use the reserved .invalid domain. This script sends no mail.
Id standardBook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
List<String> modelNames = new List<String>{
    'HES Seed Compressor 25', 'HES Seed Compressor 50',
    'HES Seed Compressor 100', 'HES Seed Generator 80',
    'HES Seed Generator 160', 'HES Seed Pump 20',
    'HES Seed Pump 40', 'HES Seed HVAC 120'
};
List<Decimal> prices = new List<Decimal>{14000, 22000, 48000, 35000, 75000, 18000, 28000, 59000};
Map<String, Product2> productsByCode = new Map<String, Product2>();
for (Product2 p : [SELECT Id, ProductCode, IsActive FROM Product2 WHERE ProductCode LIKE 'HES-SEED-%']) {
    productsByCode.put(p.ProductCode, p);
}
List<Product2> newProducts = new List<Product2>();
List<Product2> activateProducts = new List<Product2>();
for (Integer i = 0; i < 8; i++) {
    String code = 'HES-SEED-' + String.valueOf(101 + i);
    if (!productsByCode.containsKey(code)) {
        newProducts.add(new Product2(Name = modelNames[i], ProductCode = code,
            IsActive = true, Description = 'HES demonstration equipment model.'));
    } else if (!productsByCode.get(code).IsActive) {
        activateProducts.add(new Product2(Id = productsByCode.get(code).Id, IsActive = true));
    }
}
if (!newProducts.isEmpty()) insert newProducts;
if (!activateProducts.isEmpty()) update activateProducts;
productsByCode.clear();
for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'HES-SEED-%']) {
    productsByCode.put(p.ProductCode, p);
}
Set<Id> productIds = new Set<Id>();
for (Product2 p : productsByCode.values()) productIds.add(p.Id);
Map<Id, PricebookEntry> entryByProduct = new Map<Id, PricebookEntry>();
for (PricebookEntry e : [SELECT Id, Product2Id, IsActive FROM PricebookEntry
        WHERE Pricebook2Id = :standardBook AND Product2Id IN :productIds]) {
    entryByProduct.put(e.Product2Id, e);
}
List<PricebookEntry> newEntries = new List<PricebookEntry>();
List<PricebookEntry> activateEntries = new List<PricebookEntry>();
for (Integer i = 0; i < 8; i++) {
    Id pid = productsByCode.get('HES-SEED-' + String.valueOf(101 + i)).Id;
    if (!entryByProduct.containsKey(pid)) {
        newEntries.add(new PricebookEntry(Pricebook2Id = standardBook,
            Product2Id = pid, UnitPrice = prices[i], IsActive = true));
    } else if (!entryByProduct.get(pid).IsActive) {
        activateEntries.add(new PricebookEntry(Id = entryByProduct.get(pid).Id, IsActive = true));
    }
}
if (!newEntries.isEmpty()) insert newEntries;
if (!activateEntries.isEmpty()) update activateEntries;

List<String> regions = new List<String>{'Benelux', 'DACH', 'Nordics', 'Other'};
List<String> cities = new List<String>{'Rotterdam', 'Berlin', 'Stockholm', 'Vienna'};
List<String> countries = new List<String>{'Netherlands', 'Germany', 'Sweden', 'Austria'};
Map<String, Account> accountByNumber = new Map<String, Account>();
for (Account a : [SELECT Id, AccountNumber FROM Account WHERE AccountNumber LIKE 'HES-SEED-%']) {
    accountByNumber.put(a.AccountNumber, a);
}
List<Account> newAccounts = new List<Account>();
for (Integer i = 1; i <= 25; i++) {
    String n = ('0000' + String.valueOf(i)).right(4);
    String key = 'HES-SEED-' + n;
    if (accountByNumber.containsKey(key)) continue;
    Integer r = Math.mod(i - 1, 4);
    newAccounts.add(new Account(Name = 'HES Demo Customer ' + n,
        AccountNumber = key, Region__c = (i == 25 ? 'Unknown' : regions[r]),
        BillingCity = cities[r], BillingCountry = countries[r],
        Industry = 'Manufacturing', Description = 'Appendix A reproducible sample customer.'));
}
if (!newAccounts.isEmpty()) insert newAccounts;
accountByNumber.clear();
for (Account a : [SELECT Id, AccountNumber FROM Account WHERE AccountNumber LIKE 'HES-SEED-%']) {
    accountByNumber.put(a.AccountNumber, a);
}

Set<String> existingEmails = new Set<String>();
for (Contact c : [SELECT Email FROM Contact WHERE Email LIKE 'hes.seed.contact.%@example.invalid']) {
    existingEmails.add(c.Email);
}
List<Contact> newContacts = new List<Contact>();
Map<String, Schema.SObjectField> contactFields =
    Schema.SObjectType.Contact.fields.getMap();
Integer contactIndex = 0;
for (Integer i = 1; i <= 25; i++) {
    Integer countForAccount = (i <= 10 ? 3 : 2);
    String accountKey = 'HES-SEED-' + ('0000' + String.valueOf(i)).right(4);
    for (Integer j = 0; j < countForAccount; j++) {
        contactIndex++;
        String n = ('000' + String.valueOf(contactIndex)).right(3);
        String address = 'hes.seed.contact.' + n + '@example.invalid';
        if (existingEmails.contains(address)) continue;
        Contact seedContact = new Contact(AccountId = accountByNumber.get(accountKey).Id,
            FirstName = 'Demo', LastName = 'Contact ' + n,
            Email = address,
            Title = (j == 0 ? 'Service Contact' : 'Purchasing Contact'));
        // Some running users cannot create Email Opt Out. Use a dynamic
        // field check so the script compiles without a static reference.
        if (contactFields.containsKey('HasOptedOutOfEmail') &&
            contactFields.get('HasOptedOutOfEmail').getDescribe().isCreateable()) {
            seedContact.put('HasOptedOutOfEmail', true);
        }
        newContacts.add(seedContact);
    }
}
if (!newContacts.isEmpty()) insert newContacts;

Set<String> existingSkills = new Set<String>();
for (Skill__c s : [SELECT Name FROM Skill__c WHERE Name IN
        ('Electrical', 'Mechanical', 'Diagnostics', 'Installation', 'Billing Systems')]) {
    existingSkills.add(s.Name);
}
List<Skill__c> skills = new List<Skill__c>();
for (String name : new List<String>{'Electrical', 'Mechanical', 'Diagnostics', 'Installation', 'Billing Systems'}) {
    if (!existingSkills.contains(name)) skills.add(new Skill__c(Name = name));
}
if (!skills.isEmpty()) insert skills;
System.debug('HES seed 01 done: 8 Products, 25 Accounts, 60 Contacts target; inserted '
    + newProducts.size() + ' products, ' + newAccounts.size() + ' accounts, '
    + newContacts.size() + ' contacts.');
