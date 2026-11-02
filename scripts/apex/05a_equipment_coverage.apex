// HES Appendix A seed, part 5a. Link plans 1-15 to multiple installed units.
Map<String, Coverage_Plan__c> plans = new Map<String, Coverage_Plan__c>();
for (Coverage_Plan__c p : [SELECT Id, Account__c, Source_Opportunity_Key__c
        FROM Coverage_Plan__c WHERE Source_Opportunity_Key__c LIKE 'HESSEEDPLAN%']) {
    plans.put(p.Source_Opportunity_Key__c, p);
}
Map<Id, List<Equipment__c>> equipmentByAccount = new Map<Id, List<Equipment__c>>();
Set<Id> equipmentIds = new Set<Id>();
for (Equipment__c e : [SELECT Id, Account__c, Serial_Number__c FROM Equipment__c
        WHERE Serial_Number__c LIKE 'HES-SEED-EQ-%' ORDER BY Serial_Number__c]) {
    equipmentIds.add(e.Id);
    if (!equipmentByAccount.containsKey(e.Account__c)) equipmentByAccount.put(e.Account__c, new List<Equipment__c>());
    equipmentByAccount.get(e.Account__c).add(e);
}
System.assert(plans.size() >= 30 && equipmentIds.size() >= 120, 'Run seed 03 and 04 first.');
Set<String> existingLinks = new Set<String>();
for (Equipment_Coverage__c ec : [SELECT Equipment__c, Coverage_Plan__c
        FROM Equipment_Coverage__c WHERE Equipment__c IN :equipmentIds]) {
    existingLinks.add(String.valueOf(ec.Equipment__c) + '-' + String.valueOf(ec.Coverage_Plan__c));
}
List<Equipment_Coverage__c> links = new List<Equipment_Coverage__c>();
for (Integer i = 0; i < 15; i++) {
    String planKey = 'HESSEEDPLAN' + ('0000000' + String.valueOf(i + 1)).right(7);
    Coverage_Plan__c p = plans.get(planKey);
    List<Equipment__c> installed = equipmentByAccount.get(p.Account__c);
    Integer count = 2 + Math.mod(i, 3);
    if (count > installed.size()) count = installed.size();
    for (Integer j = 0; j < count; j++) {
        Equipment__c e = installed[j];
        String key = String.valueOf(e.Id) + '-' + String.valueOf(p.Id);
        if (!existingLinks.contains(key)) links.add(new Equipment_Coverage__c(
            Equipment__c = e.Id, Coverage_Plan__c = p.Id, Membership_Key__c = key));
    }
}
if (!links.isEmpty()) insert links;
System.debug('HES seed 05a done: created ' + links.size() + ' memberships.');
