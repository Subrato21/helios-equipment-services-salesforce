// HES Appendix A seed, part 2: 40 Opportunities + 40 product lines.
// Negotiation/Review is reached only after its required product exists.
Id standardBook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
Map<String, Id> accounts = new Map<String, Id>();
for (Account a : [SELECT Id, AccountNumber FROM Account WHERE AccountNumber LIKE 'HES-SEED-%']) {
    accounts.put(a.AccountNumber, a.Id);
}
Map<String, PricebookEntry> entries = new Map<String, PricebookEntry>();
for (PricebookEntry e : [SELECT Id, Product2.ProductCode, UnitPrice FROM PricebookEntry
        WHERE Pricebook2Id = :standardBook AND Product2.ProductCode LIKE 'HES-SEED-%' AND IsActive = true]) {
    entries.put(e.Product2.ProductCode, e);
}
System.assert(accounts.size() >= 25 && entries.size() >= 8, 'Run seed 01 first.');

List<String> stages = new List<String>{'Prospecting', 'Qualification', 'Needs Analysis',
    'Value Proposition', 'Id. Decision Makers', 'Perception Analysis',
    'Proposal/Price Quote', 'Negotiation/Review', 'Closed Won', 'Closed Lost'};
List<String> types = new List<String>{'Compressor', 'Generator', 'Pump', 'HVAC Unit'};
List<Decimal> discounts = new List<Decimal>{0, 5, 10, 12, 16, 18, 22, 25};
Map<String, Opportunity> existing = new Map<String, Opportunity>();
for (Opportunity o : [SELECT Id, Name, StageName FROM Opportunity WHERE Name LIKE 'HES-SEED-OPP-%']) {
    existing.put(o.Name, o);
}
List<Opportunity> toInsert = new List<Opportunity>();
for (Integer i = 1; i <= 40; i++) {
    String key = 'HES-SEED-OPP-' + ('000' + String.valueOf(i)).right(3);
    if (existing.containsKey(key)) continue;
    Integer stageIndex = Math.mod(i - 1, 10);
    Integer accountIndex = 1 + Math.mod(i * 7, 25);
    String accountKey = 'HES-SEED-' + ('0000' + String.valueOf(accountIndex)).right(4);
    Opportunity o = new Opportunity(Name = key, AccountId = accounts.get(accountKey),
        StageName = (stageIndex == 7 ? 'Proposal/Price Quote' : stages[stageIndex]),
        CloseDate = Date.today().addDays((Math.mod(i, 7) - 2) * 30),
        Pricebook2Id = standardBook, Discount_Percent__c = discounts[Math.mod(i - 1, 8)],
        Equipment_Type__c = types[Math.mod(i - 1, 4)],
        Indicative_Budget__c = 20000 + i * 1800,
        Description = 'Appendix A seed sales scenario ' + String.valueOf(i));
    // If the org permits audit fields on insert, create realistic age variation.
    if (Schema.SObjectType.Opportunity.fields.getMap().get('CreatedDate').getDescribe().isCreateable()) {
        o.put('CreatedDate', Datetime.now().addDays(-Math.mod(i * 11, 100)));
    }
    toInsert.add(o);
}
if (!toInsert.isEmpty()) insert toInsert;
existing.clear();
Set<Id> oppIds = new Set<Id>();
for (Opportunity o : [SELECT Id, Name, StageName FROM Opportunity WHERE Name LIKE 'HES-SEED-OPP-%']) {
    existing.put(o.Name, o);
    oppIds.add(o.Id);
}
Set<Id> withLines = new Set<Id>();
for (OpportunityLineItem oli : [SELECT OpportunityId FROM OpportunityLineItem WHERE OpportunityId IN :oppIds]) {
    withLines.add(oli.OpportunityId);
}
List<OpportunityLineItem> newLines = new List<OpportunityLineItem>();
for (Integer i = 1; i <= 40; i++) {
    String key = 'HES-SEED-OPP-' + ('000' + String.valueOf(i)).right(3);
    Opportunity opp = existing.get(key);
    if (opp == null || withLines.contains(opp.Id)) continue;
    PricebookEntry entry = entries.get('HES-SEED-' + String.valueOf(101 + Math.mod(i - 1, 8)));
    newLines.add(new OpportunityLineItem(OpportunityId = opp.Id,
        PricebookEntryId = entry.Id, Quantity = 1 + Math.mod(i, 3),
        UnitPrice = entry.UnitPrice));
}
if (!newLines.isEmpty()) insert newLines;
List<Opportunity> setNegotiation = new List<Opportunity>();
for (Integer i = 1; i <= 40; i++) {
    if (Math.mod(i - 1, 10) != 7) continue;
    Opportunity opp = existing.get('HES-SEED-OPP-' + ('000' + String.valueOf(i)).right(3));
    if (opp != null && opp.StageName != 'Negotiation/Review') {
        setNegotiation.add(new Opportunity(Id = opp.Id, StageName = 'Negotiation/Review'));
    }
}
if (!setNegotiation.isEmpty()) update setNegotiation;
System.debug('HES seed 02 done: 40 Opportunities target (four per exact stage), '
    + 'one product line per Opportunity; added ' + toInsert.size() + ' deals and '
    + newLines.size() + ' lines. Discounts above 15% are intentionally not submitted.');
