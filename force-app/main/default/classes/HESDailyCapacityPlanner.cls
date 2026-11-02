
public with sharing class HESDailyCapacityPlanner {
    private static final Decimal DAILY_CAPACITY = 8;
    private static final Integer LOOKAHEAD_DAYS = 30;
    private static final Decimal MAX_CASE_HOURS = 40;

    @AuraEnabled
    public static String schedule(Id caseId, Date firstDay, Decimal effortHours) {
        if (caseId == null || firstDay == null || effortHours == null) {
            throw new AuraHandledException('Choose a Case, a start date, and work hours.');
        }
        if (firstDay < Date.today()) {
            throw new AuraHandledException('Choose today or a future date.');
        }
        if (effortHours <= 0 || effortHours > MAX_CASE_HOURS ||
            effortHours * 4 != (effortHours * 4).setScale(0)) {
            throw new AuraHandledException(
                'Enter 0.25 to 40 hours in quarter-hour steps.'
            );
        }

        // Lock this Case to prevent duplicate runs for the same record.
        // Capacity for different Cases is checked against committed segments;
        // concurrent runs for different Cases are not serialized in this MVP.
        List<Case> cases = [
            SELECT Id, IsClosed
            FROM Case
            WHERE Id = :caseId
            FOR UPDATE
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException('This Case is unavailable.');
        }
        if (cases[0].IsClosed) {
            throw new AuraHandledException('Schedule an open Case.');
        }

        Id engineerId = UserInfo.getUserId();
        List<User> engineers = [
            SELECT Id, IsActive
            FROM User
            WHERE Id = :engineerId
        ];
        if (engineers.isEmpty() || !engineers[0].IsActive) {
            throw new AuraHandledException('The scheduling user must be active.');
        }

        List<HES_Work_Segment__c> existingSegments = [
            SELECT Id FROM HES_Work_Segment__c
            WHERE Case__c = :caseId WITH USER_MODE LIMIT 1
        ];
        if (!existingSegments.isEmpty()) {
            throw new AuraHandledException(
                'This Case already has a schedule. Review its Work Segments.'
            );
        }

        Date lastDay = firstDay.addDays(LOOKAHEAD_DAYS - 1);
        Map<Date, Decimal> bookedByDay = new Map<Date, Decimal>();
        for (AggregateResult row : [
            SELECT Work_Date__c dayKey, SUM(Planned_Hours__c) totalHours
            FROM HES_Work_Segment__c
            WHERE Engineer__c = :engineerId
                AND Work_Date__c >= :firstDay
                AND Work_Date__c <= :lastDay
            WITH USER_MODE
            GROUP BY Work_Date__c
        ]) {
            bookedByDay.put(
                (Date) row.get('dayKey'),
                (Decimal) row.get('totalHours')
            );
        }

        Decimal remaining = effortHours;
        List<HES_Work_Segment__c> additions = new List<HES_Work_Segment__c>();
        for (Integer offset = 0; offset < LOOKAHEAD_DAYS && remaining > 0; offset++) {
            Date workDay = firstDay.addDays(offset);
            if (isWeekend(workDay)) {
                continue;
            }
            Decimal alreadyBooked = bookedByDay.containsKey(workDay)
                ? bookedByDay.get(workDay) : 0;
            Decimal freeHours = DAILY_CAPACITY - alreadyBooked;
            if (freeHours <= 0) {
                continue;
            }

            Decimal placedHours = remaining < freeHours ? remaining : freeHours;
            additions.add(new HES_Work_Segment__c(
                Case__c = caseId,
                Engineer__c = engineerId,
                Work_Date__c = workDay,
                Planned_Hours__c = placedHours,
                Segment_Key__c = String.valueOf(caseId) + ':' + String.valueOf(workDay)
            ));
            remaining -= placedHours;
        }

        if (remaining > 0) {
            throw new AuraHandledException(
                'Not enough free weekdays in the next 30 days. No segments were saved.'
            );
        }

        // One DML operation: a validation or permission failure saves none of
        // this Case's segments. No Case update, email, or scheduled job occurs.
        try {
            insert as user additions;
        } catch (DmlException ex) {
            throw new AuraHandledException(
                'Could not save Work Segments. Check object access and required fields.'
            );
        }
        return 'Scheduled ' + String.valueOf(effortHours) + ' hours in ' +
            String.valueOf(additions.size()) + ' daily Work Segments.';
    }

    @AuraEnabled(cacheable=true)
    public static List<HES_Work_Segment__c> getSegments(Id caseId) {
        if (caseId == null) {
            return new List<HES_Work_Segment__c>();
        }
        return [
            SELECT Id, Name, Work_Date__c, Planned_Hours__c, Engineer__r.Name
            FROM HES_Work_Segment__c
            WHERE Case__c = :caseId
            WITH USER_MODE
            ORDER BY Work_Date__c ASC
        ];
    }

    // 1900-01-01 was a Monday; this avoids locale-dependent week numbering.
    private static Boolean isWeekend(Date workDay) {
        Integer weekday = Math.mod(Date.newInstance(1900, 1, 1).daysBetween(workDay), 7);
        return weekday == 5 || weekday == 6;
    }
}
