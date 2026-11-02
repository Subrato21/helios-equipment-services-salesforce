@IsTest
private class HESSerialCoverageActionTest {

    @TestSetup
    static void setupData() {
        insert new Account(
            Name = 'HES Serial Test Account'
        );

        insert new Product2(
            Name = 'HES Serial Test Product',
            IsActive = true
        );
    }

    private static HESSerialCoverageAction.Input makeInput(
        String serialNumber
    ) {
        HESSerialCoverageAction.Input item =
            new HESSerialCoverageAction.Input();

        item.serialNumber = serialNumber;
        return item;
    }

    private static void assertResult(
        HESSerialCoverageAction.Output result,
        String expectedStatus,
        String expectedMessage
    ) {
        System.assertEquals(
            expectedStatus,
            result.coverageStatus
        );

        System.assertEquals(
            Date.today(),
            result.asOfDate
        );

        System.assertEquals(
            expectedMessage,
            result.message
        );
    }

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

    private static Equipment__c createEquipment(
        String serialNumber
    ) {
        Account account = [
            SELECT Id
            FROM Account
            WHERE Name = 'HES Serial Test Account'
            LIMIT 1
        ];

        Product2 product = [
            SELECT Id
            FROM Product2
            WHERE Name = 'HES Serial Test Product'
            LIMIT 1
        ];

        Equipment__c equipment = new Equipment__c(
            Serial_Number__c = serialNumber
        );

        setNameIfNeeded(equipment, serialNumber);

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
            'TEST-' + serialNumber
        );

        // Add other org-required Equipment fields here.

        insert equipment;
        return equipment;
    }

    private static Equipment__c createEquipmentWithPlan(
        String serialNumber,
        String status,
        Date startDate,
        Date endDate
    ) {
        Equipment__c equipment =
            createEquipment(serialNumber);

        Coverage_Plan__c plan = new Coverage_Plan__c(
            Start_Date__c = startDate,
            End_Date__c = endDate
        );

        setNameIfNeeded(plan, 'Plan ' + serialNumber);

        setOptionalField(
            plan,
            'Equipment__c',
            equipment.Id
        );

        setOptionalField(
            plan,
            'Status__c',
            status
        );

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

        // Add other org-required Coverage Plan fields here.

        insert plan;

        equipment.Current_Coverage_Plan__c = plan.Id;
        update equipment;

        return equipment;
    }

    @IsTest
    static void testNullAndEmptyInputs() {
        Test.startTest();

        List<HESSerialCoverageAction.Output> nullResults =
            HESSerialCoverageAction.checkCoverage(null);

        List<HESSerialCoverageAction.Output> emptyResults =
            HESSerialCoverageAction.checkCoverage(
                new List<HESSerialCoverageAction.Input>()
            );

        Test.stopTest();

        System.assertEquals(0, nullResults.size());
        System.assertEquals(0, emptyResults.size());
    }

    @IsTest
    static void testMissingSerialNumbers() {
        Test.startTest();

        List<HESSerialCoverageAction.Output> results =
            HESSerialCoverageAction.checkCoverage(
                new List<HESSerialCoverageAction.Input>{
                    null,
                    makeInput(null),
                    makeInput(''),
                    makeInput('   ')
                }
            );

        Test.stopTest();

        System.assertEquals(4, results.size());

        for (HESSerialCoverageAction.Output result : results) {
            assertResult(
                result,
                'Unavailable',
                'Please provide an Equipment serial number.'
            );
        }
    }

    @IsTest
    static void testUnknownSerialNumber() {
        Test.startTest();

        List<HESSerialCoverageAction.Output> results =
            HESSerialCoverageAction.checkCoverage(
                new List<HESSerialCoverageAction.Input>{
                    makeInput('HES-NOT-FOUND-999')
                }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());

        assertResult(
            results[0],
            'Unavailable',
            'Coverage could not be checked for this serial number.'
        );
    }

    @IsTest
    static void testExactMatchTrimmingAndCaseSensitivity() {
        createEquipment('HES-Exact-001');

        Test.startTest();

        List<HESSerialCoverageAction.Output> results =
            HESSerialCoverageAction.checkCoverage(
                new List<HESSerialCoverageAction.Input>{
                    makeInput('HES-Exact-001'),
                    makeInput('  HES-Exact-001  '),
                    makeInput('hes-exact-001')
                }
            );

        Test.stopTest();

        System.assertEquals(3, results.size());

        assertResult(
            results[0],
            'Not Covered',
            'No current Coverage Plan is linked to this Equipment.'
        );

        assertResult(
            results[1],
            'Not Covered',
            'No current Coverage Plan is linked to this Equipment.'
        );

        assertResult(
            results[2],
            'Unavailable',
            'Coverage could not be checked for this serial number.'
        );
    }

    @IsTest
    static void testActiveCoverageAndInclusiveDateBoundaries() {
        Date today = Date.today();

        createEquipmentWithPlan(
            'HES-ACTIVE',
            'Active',
            today.addDays(-10),
            today.addDays(30)
        );

        createEquipmentWithPlan(
            'HES-START-TODAY',
            'Active',
            today,
            today.addDays(30)
        );

        createEquipmentWithPlan(
            'HES-END-TODAY',
            'Active',
            today.addDays(-30),
            today
        );

        Test.startTest();

        List<HESSerialCoverageAction.Output> results =
            HESSerialCoverageAction.checkCoverage(
                new List<HESSerialCoverageAction.Input>{
                    makeInput('HES-ACTIVE'),
                    makeInput('HES-START-TODAY'),
                    makeInput('HES-END-TODAY')
                }
            );

        Test.stopTest();

        System.assertEquals(3, results.size());

        for (HESSerialCoverageAction.Output result : results) {
            assertResult(
                result,
                'Covered',
                'The Equipment has active coverage as of this date.'
            );
        }
    }

    @IsTest
    static void testExpiredCoverage() {
        Date today = Date.today();

        createEquipmentWithPlan(
            'HES-EXPIRED',
            'Expired',
            today.addDays(-60),
            today.addDays(-1)
        );

        Test.startTest();

        List<HESSerialCoverageAction.Output> results =
            HESSerialCoverageAction.checkCoverage(
                new List<HESSerialCoverageAction.Input>{
                    makeInput('HES-EXPIRED')
                }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());

        assertResult(
            results[0],
            'Expired',
            'The current Coverage Plan is expired.'
        );
    }

    @IsTest
    static void testFutureCoverageIsNotCovered() {
        Date today = Date.today();

        createEquipmentWithPlan(
            'HES-FUTURE',
            'Active',
            today.addDays(10),
            today.addDays(40)
        );

        Test.startTest();

        List<HESSerialCoverageAction.Output> results =
            HESSerialCoverageAction.checkCoverage(
                new List<HESSerialCoverageAction.Input>{
                    makeInput('HES-FUTURE')
                }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());

        assertResult(
            results[0],
            'Not Covered',
            'The current plan is not active within its coverage dates.'
        );
    }

    @IsTest
    static void testMixedBatchPreservesOrderAndDuplicates() {
        Date today = Date.today();

        createEquipment('HES-BATCH-NO-PLAN');

        createEquipmentWithPlan(
            'HES-BATCH-ACTIVE',
            'Active',
            today.addDays(-5),
            today.addDays(30)
        );

        Test.startTest();

        List<HESSerialCoverageAction.Output> results =
            HESSerialCoverageAction.checkCoverage(
                new List<HESSerialCoverageAction.Input>{
                    makeInput('HES-BATCH-ACTIVE'),
                    null,
                    makeInput('HES-BATCH-NO-PLAN'),
                    makeInput('HES-BATCH-MISSING'),
                    makeInput('HES-BATCH-ACTIVE')
                }
            );

        Test.stopTest();

        System.assertEquals(5, results.size());

        assertResult(
            results[0],
            'Covered',
            'The Equipment has active coverage as of this date.'
        );

        assertResult(
            results[1],
            'Unavailable',
            'Please provide an Equipment serial number.'
        );

        assertResult(
            results[2],
            'Not Covered',
            'No current Coverage Plan is linked to this Equipment.'
        );

        assertResult(
            results[3],
            'Unavailable',
            'Coverage could not be checked for this serial number.'
        );

        assertResult(
            results[4],
            'Covered',
            'The Equipment has active coverage as of this date.'
        );
    }
}