// HES Appendix A seed, part 7. Case Skill reporting examples.
Map<String, Id> caseByMarker = new Map<String, Id>();
for (Case c : [SELECT Id, Subject FROM Case WHERE Subject LIKE '%HES-SEED-CASE-%']) {
    Integer at = c.Subject.indexOf('HES-SEED-CASE-');
    if (at >= 0 && c.Subject.length() >= at + 18) {
        caseByMarker.put(c.Subject.substring(at, at + 18), c.Id);
    }
}
List<String> names = new List<String>{'Electrical', 'Mechanical', 'Diagnostics',
    'Installation', 'Billing Systems'};
Map<String, Id> skills = new Map<String, Id>();
for (Skill__c s : [SELECT Id, Name FROM Skill__c WHERE Name IN :names]) skills.put(s.Name, s.Id);
System.assert(caseByMarker.size() >= 250 && skills.size() == 5, 'Run seeds 01 and 06a-06e first.');
Set<Id> demoCaseIds = new Set<Id>();
for (Id idValue : caseByMarker.values()) demoCaseIds.add(idValue);
Set<String> existing = new Set<String>();
for (Case_Skill__c cs : [SELECT Case__c, Skill__c FROM Case_Skill__c WHERE Case__c IN :demoCaseIds]) {
    existing.add(String.valueOf(cs.Case__c) + '-' + String.valueOf(cs.Skill__c));
}
List<Case_Skill__c> newLinks = new List<Case_Skill__c>();
for (Integer i = 1; i <= 100; i++) {
    Id caseId = caseByMarker.get('HES-SEED-CASE-' + ('0000' + String.valueOf(i)).right(4));
    Integer count = (i <= 25 ? 2 : 1);
    for (Integer j = 0; j < count; j++) {
        Id skillId = skills.get(names[Math.mod(i + j * 2, 5)]);
        String key = String.valueOf(caseId) + '-' + String.valueOf(skillId);
        if (!existing.contains(key)) newLinks.add(new Case_Skill__c(
            Case__c = caseId, Skill__c = skillId, Membership_Key__c = key));
    }
}
if (!newLinks.isEmpty()) insert newLinks;
System.debug('HES seed 07 done: created ' + newLinks.size() + ' Case Skill links.');
