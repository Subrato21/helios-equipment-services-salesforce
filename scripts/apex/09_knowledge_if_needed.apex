// HES Appendix A seed, part 9. Existing published Knowledge is never changed.
// Run this only if fewer than ten published articles exist and Knowledge
// publishing in this org has no separate notification automation.
Schema.SObjectType articleType = Schema.getGlobalDescribe().get('Knowledge__kav');
System.assert(articleType != null, 'Enable Salesforce Knowledge and retrieve its Day 6 metadata first.');
Integer published = Database.countQuery(
    'SELECT COUNT() FROM Knowledge__kav WHERE PublishStatus = \'Online\'');
if (published >= 10) {
    System.debug('HES seed 09: ' + published + ' published articles already exist. No changes.');
} else {
    List<String> titles = new List<String>{
        'Submitting a Helios Service Request', 'Using Your Helios Case Number',
        'Providing an Equipment Serial Number', 'Understanding Draft Coverage',
        'Understanding Active Coverage', 'Understanding Expired Coverage',
        'Helios Service Regions', 'Technical and Billing Cases',
        'Replying to a Support Email', 'Requesting a Coverage Check'
    };
    List<String> answers = new List<String>{
        'Submit a support request through the Helios web form or support email. Include the issue, contact details, and equipment serial number when available.',
        'Use the Case Number from the acknowledgement when contacting the service team. It identifies the request for follow-up.',
        'Find the serial number on the equipment and provide it exactly as shown. The service team uses it to locate the installed unit.',
        'A Draft Coverage Plan is a proposal. It is not current coverage until activated and within its dates.',
        'An Active Coverage Plan is current only from its Start Date through its End Date. The team checks the linked unit and dates.',
        'A plan marked Expired, or with an End Date before today, is expired. Ask the service team about next steps.',
        'Helios records Benelux, DACH, Nordics, Other, and Unknown regions. Unknown requests go to a region review queue.',
        'Technical Cases concern equipment service. Billing Cases concern invoices or plan charges. Describe the issue clearly.',
        'Reply to the existing support email thread so the follow-up can stay with the original Case. Keep the subject and headers.',
        'Provide your equipment serial number and Case Number when requesting a coverage check. The team checks the current plan and its dates.'
    };
    Map<String, Schema.SObjectField> fields = articleType.getDescribe().fields.getMap();
    String bodyField;
    for (String candidate : new List<String>{'Answer__c', 'Article_Body__c', 'Body__c', 'Content__c'}) {
        if (fields.containsKey(candidate) && fields.get(candidate).getDescribe().isCreateable()) {
            bodyField = candidate;
            break;
        }
    }
    Set<String> existingUrls = new Set<String>();
    List<Id> draftIds = new List<Id>();
    for (SObject article : Database.query(
            'SELECT Id, UrlName, PublishStatus FROM Knowledge__kav '
            + 'WHERE PublishStatus IN (\'Draft\', \'Online\') AND UrlName LIKE \'hes-seed-%\'')) {
        existingUrls.add((String) article.get('UrlName'));
        if ((String) article.get('PublishStatus') == 'Draft') draftIds.add((Id) article.get('Id'));
    }
    List<SObject> newArticles = new List<SObject>();
    for (Integer i = 0; i < 10; i++) {
        String url = 'hes-seed-' + ('00' + String.valueOf(i + 1)).right(2);
        if (existingUrls.contains(url)) continue;
        SObject a = articleType.newSObject();
        a.put('Title', titles[i]);
        a.put('UrlName', url);
        a.put('Language', 'en_US');
        a.put('Summary', answers[i]);
        if (bodyField != null) a.put(bodyField, answers[i]);
        if (fields.containsKey('IsVisibleInApp') && fields.get('IsVisibleInApp').getDescribe().isCreateable()) {
            a.put('IsVisibleInApp', true);
        }
        newArticles.add(a);
    }
    if (!newArticles.isEmpty()) {
        insert newArticles;
        for (SObject a : newArticles) draftIds.add((Id) a.get('Id'));
    }
    if (!draftIds.isEmpty()) {
        for (SObject a : Database.query('SELECT Id, KnowledgeArticleId '
                + 'FROM Knowledge__kav WHERE PublishStatus = \'Draft\' AND Id IN :draftIds')) {
            KbManagement.PublishingService.publishArticle(
                String.valueOf(a.get('KnowledgeArticleId')), true);
        }
    }
    System.debug('HES seed 09: published original articles remain untouched; '
        + 'created ' + newArticles.size() + ' seed articles. Recheck published count and Knowledge visibility.');
}
