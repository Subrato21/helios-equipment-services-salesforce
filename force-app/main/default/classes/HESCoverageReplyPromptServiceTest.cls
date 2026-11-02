@IsTest
private class HESCoverageReplyPromptServiceTest {

    @TestSetup
    static void setupData() {
        insert new Account(
            Name = 'HES Coverage Test Account'
        );

        insert new Product2(
            Name = 'HES Coverage Test Product',
            IsActive = true
        );
    }

    private static HESCoverageReplyPromptService.Request makeRequest(
        Id caseId
    ) {
        HESCoverageReplyPromptService.Request request =
            new HESCoverageReplyPromptService.Request();

        request.caseId = caseId;
        return request;
    }

    private static void assertFailure(
        HESCoverageReplyPromptService.Response response,
        String expectedMessage
    ) {
        System.assertEquals(false, response.success);
        System.assertEquals(null, response.draftText);
        System.assertEquals(null, response.coverageContext);
        System.assertEquals(expectedMessage, response.message);
    }

    /*
     * Populate optional fields only when they exist and are writable.
     * Adjust the API names below if your lookup fields differ.
     */
    private static void setOptionalField(
        SObject record,
        String fieldName,
        Object fieldValue
    ) {
        Map<String, Schema.SObjectField> fields =
            record.getSObjectType().getDescribe().fields.getMap();

        if (
            fields.containsKey(fieldName) &&
            fields.get(fieldName).getDescribe().isCreateable()
        ) {
            record.put(fieldName, fieldValue);
        }
    }

    private static void setNameIfNeeded(
        SObject record,
        String nameValue
    ) {
        Map<String, Schema.SObjectField> fields =
            record.getSObjectType().getDescribe().fields.getMap();

        if (fields.containsKey('Name')) {
            Schema.DescribeFieldResult nameField =
                fields.get('Name').getDescribe();

            if (
                !nameField.isAutoNumber() &&
                nameField.isCreateable()
            ) {
                record.put('Name', nameValue);
            }
        }
    }

    private static Equipment__c createEquipment(String suffix) {
        Account account = [
            SELECT Id
            FROM Account
            WHERE Name = 'HES Coverage Test Account'
            LIMIT 1
        ];

        Product2 product = [
            SELECT Id
            FROM Product2
            WHERE Name = 'HES Coverage Test Product'
            LIMIT 1
        ];

        Equipment__c equipment = new Equipment__c(
            Serial_Number__c = 'HES-TEST-' + suffix
        );

        setNameIfNeeded(equipment, 'Test Equipment ' + suffix);

        setOptionalField(
            equipment,
            'Account__c',
            account.Id
        );

        setOptionalField(
            equipment,
            'Product__c',
            product.Id
        );

        setOptionalField(
            equipment,
            'Source_Line_Unit_Key__c',
            'HES-TEST-KEY-' + suffix
        );

        // Add any other fields required by your org here.

        insert equipment;
        return equipment;
    }

    private static Case createCase(Id equipmentId) {
        Case caseRecord = new Case(
            Subject = 'Test coverage reply',
            Description = 'Equipment requires service.',
            Status = 'New',
            Origin = 'Web',
            Equipment__c = equipmentId
        );

        // Add any other fields required by your org here.

        insert caseRecord;
        return caseRecord;
    }

    private static Coverage_Plan__c createPlan(
        Id equipmentId,
        String status,
        Date startDate,
        Date endDate
    ) {
        Coverage_Plan__c plan = new Coverage_Plan__c(
            Start_Date__c = startDate,
            End_Date__c = endDate
        );

        setNameIfNeeded(plan, 'Test Coverage Plan');

        setOptionalField(plan, 'Status__c', status);
        setOptionalField(plan, 'Equipment__c', equipmentId);

        Schema.DescribeFieldResult serviceLevelField =
            Coverage_Plan__c.Service_Level__c.getDescribe();

        if (serviceLevelField.isCreateable()) {
            if (
                serviceLevelField.getType() ==
                Schema.DisplayType.Picklist
            ) {
                for (
                    Schema.PicklistEntry entry :
                    serviceLevelField.getPicklistValues()
                ) {
                    if (entry.isActive()) {
                        plan.Service_Level__c = entry.getValue();
                        break;
                    }
                }
            } else {
                plan.Service_Level__c = 'Standard';
            }
        }

        // Add any other fields required by your org here.

        insert plan;

        update new Equipment__c(
            Id = equipmentId,
            Current_Coverage_Plan__c = plan.Id
        );

        return plan;
    }

    @IsTest
    static void testNullAndEmptyRequests() {
        Test.startTest();

        List<HESCoverageReplyPromptService.Response> nullResults =
            HESCoverageReplyPromptService.draftReplies(null);

        List<HESCoverageReplyPromptService.Response> emptyResults =
            HESCoverageReplyPromptService.draftReplies(
                new List<HESCoverageReplyPromptService.Request>()
            );

        Test.stopTest();

        System.assertEquals(0, nullResults.size());
        System.assertEquals(0, emptyResults.size());
    }

    @IsTest
    static void testMissingCaseIds() {
        Test.startTest();

        List<HESCoverageReplyPromptService.Response> results =
            HESCoverageReplyPromptService.draftReplies(
                new List<HESCoverageReplyPromptService.Request>{
                    null,
                    makeRequest(null)
                }
            );

        Test.stopTest();

        System.assertEquals(2, results.size());

        assertFailure(
            results[0],
            'A Case ID is required.'
        );

        assertFailure(
            results[1],
            'A Case ID is required.'
        );
    }

    @IsTest
    static void testIdDoesNotIdentifyACase() {
        Account account = [
            SELECT Id
            FROM Account
            WHERE Name = 'HES Coverage Test Account'
            LIMIT 1
        ];

        // An Account ID cannot match a Case record.
        Test.startTest();

        List<HESCoverageReplyPromptService.Response> results =
            HESCoverageReplyPromptService.draftReplies(
                new List<HESCoverageReplyPromptService.Request>{
                    makeRequest(account.Id)
                }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());

        assertFailure(
            results[0],
            'The Case is unavailable or you do not have access to it.'
        );
    }

    @IsTest
    static void testCaseWithoutEquipment() {
        Case caseRecord = createCase(null);

        Test.startTest();

        List<HESCoverageReplyPromptService.Response> results =
            HESCoverageReplyPromptService.draftReplies(
                new List<HESCoverageReplyPromptService.Request>{
                    makeRequest(caseRecord.Id)
                }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());

        assertFailure(
            results[0],
            'Link Equipment to this Case before drafting a coverage reply.'
        );
    }

    @IsTest
    static void testCoverageScenariosAndResponseOrder() {
        Date today = Date.today();

        Equipment__c noPlanEquipment =
            createEquipment('NO-PLAN');

        Equipment__c activeEquipment =
            createEquipment('ACTIVE');

        Equipment__c expiredEquipment =
            createEquipment('EXPIRED');

        Equipment__c futureEquipment =
            createEquipment('FUTURE');

        createPlan(
            activeEquipment.Id,
            'Active',
            today.addDays(-10),
            today.addDays(30)
        );

        createPlan(
            expiredEquipment.Id,
            'Expired',
            today.addDays(-60),
            today.addDays(-1)
        );

        createPlan(
            futureEquipment.Id,
            'Active',
            today.addDays(10),
            today.addDays(40)
        );

        Case noPlanCase = createCase(noPlanEquipment.Id);
        Case activeCase = createCase(activeEquipment.Id);
        Case expiredCase = createCase(expiredEquipment.Id);
        Case futureCase = createCase(futureEquipment.Id);

        List<HESCoverageReplyPromptService.Request> requests =
            new List<HESCoverageReplyPromptService.Request>{
                makeRequest(noPlanCase.Id),
                null,
                makeRequest(activeCase.Id),
                makeRequest(expiredCase.Id),
                makeRequest(futureCase.Id)
            };

        Test.startTest();

        List<HESCoverageReplyPromptService.Response> results =
            HESCoverageReplyPromptService.draftReplies(requests);

        Test.stopTest();

        System.assertEquals(5, results.size());

        assertFailure(
            results[1],
            'A Case ID is required.'
        );

        /*
         * The unchanged service calls Einstein directly.
         * Verify its response contract whether generation succeeds
         * or the platform rejects generation during the test.
         */
        List<Integer> validIndexes = new List<Integer>{
            0, 2, 3, 4
        };

        List<String> expectedPrefixes = new List<String>{
            'Not Covered as of ',
            'Covered as of ',
            'Expired as of ',
            'Not Covered as of '
        };

        for (Integer i = 0; i < validIndexes.size(); i++) {
            HESCoverageReplyPromptService.Response response =
                results[validIndexes[i]];

            if (response.success == true) {
                System.assert(
                    !String.isBlank(response.draftText),
                    'A successful response must contain a draft.'
                );

                System.assert(
                    response.coverageContext != null,
                    'A successful response must contain coverage context.'
                );

                System.assert(
                    response.coverageContext.startsWith(
                        expectedPrefixes[i] + today.format()
                    ),
                    'Unexpected coverage context: ' +
                    response.coverageContext
                );

                System.assertEquals(
                    'Draft generated. Review it before sending.',
                    response.message
                );
            } else {
                assertFailure(
                    response,
                    'The reply draft could not be generated. ' +
                    'Check prompt access and configuration.'
                );
            }
        }
    }
}