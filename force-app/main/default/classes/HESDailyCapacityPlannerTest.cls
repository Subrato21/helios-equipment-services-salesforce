@IsTest
private class HESDailyCapacityPlannerTest {
    private static Date weekdayOnOrAfter(Date value) {
        Date result = value;
        while (Math.mod(Date.newInstance(1900, 1, 1).daysBetween(result), 7) > 4) {
            result = result.addDays(1);
        }
        return result;
    }

    private static Case newOpenCase(String subject) {
        // Phone avoids the Email/Web auto-response rules in the HES project.
        return new Case(
            Subject = subject,
            Status = 'New',
            Origin = 'Phone',
            Type = 'Technical',
            Region__c = 'Unknown'
        );
    }

    @IsTest
    static void fillsOnlyAvailableDailyHoursAndDoesNotDuplicate() {
        List<Case> cases = new List<Case>{
            newOpenCase('MVP Case A'),
            newOpenCase('MVP Case B')
        };
        insert cases;
        Id firstCaseId = cases[0].Id;
        Id secondCaseId = cases[1].Id;
        Date startDay = weekdayOnOrAfter(Date.today());

        Test.startTest();
        HESDailyCapacityPlanner.schedule(firstCaseId, startDay, 14);
        HESDailyCapacityPlanner.schedule(secondCaseId, startDay, 8);
        Test.stopTest();

        List<HES_Work_Segment__c> first = [
            SELECT Work_Date__c, Planned_Hours__c
            FROM HES_Work_Segment__c
            WHERE Case__c = :firstCaseId
            ORDER BY Work_Date__c
        ];
        System.assertEquals(2, first.size());
        System.assertEquals(startDay, first[0].Work_Date__c);
        System.assertEquals(8, first[0].Planned_Hours__c);
        System.assertEquals(6, first[1].Planned_Hours__c);

        List<HES_Work_Segment__c> second = [
            SELECT Work_Date__c, Planned_Hours__c
            FROM HES_Work_Segment__c
            WHERE Case__c = :secondCaseId
            ORDER BY Work_Date__c
        ];
        System.assertEquals(2, second.size());
        System.assertEquals(first[1].Work_Date__c, second[0].Work_Date__c);
        System.assertEquals(2, second[0].Planned_Hours__c);
        System.assertEquals(6, second[1].Planned_Hours__c);

        Boolean duplicateRejected = false;
        try {
            HESDailyCapacityPlanner.schedule(firstCaseId, startDay, 1);
        } catch (AuraHandledException ex) {
            duplicateRejected = true;
        }
        System.assert(duplicateRejected, 'The same Case must not be scheduled twice.');
        System.assertEquals(2, [
            SELECT COUNT() FROM HES_Work_Segment__c WHERE Case__c = :firstCaseId
        ]);
    }

    @IsTest
    static void skipsWeekendBetweenTwoDaysOfWork() {
        Case work = newOpenCase('MVP Friday Case');
        insert work;
        Date friday = Date.today();
        while (Math.mod(Date.newInstance(1900, 1, 1).daysBetween(friday), 7) != 4) {
            friday = friday.addDays(1);
        }
        HESDailyCapacityPlanner.schedule(work.Id, friday, 10);
        List<HES_Work_Segment__c> rows = [
            SELECT Work_Date__c, Planned_Hours__c
            FROM HES_Work_Segment__c
            WHERE Case__c = :work.Id
            ORDER BY Work_Date__c
        ];
        System.assertEquals(2, rows.size());
        System.assertEquals(friday, rows[0].Work_Date__c);
        System.assertEquals(friday.addDays(3), rows[1].Work_Date__c);
        System.assertEquals(8, rows[0].Planned_Hours__c);
        System.assertEquals(2, rows[1].Planned_Hours__c);
    }
}
