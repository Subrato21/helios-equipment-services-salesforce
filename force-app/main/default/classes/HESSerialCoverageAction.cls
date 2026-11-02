public with sharing class HESSerialCoverageAction {
    public class Input {
        @InvocableVariable(
            label='Serial Number'
            description='Exact Equipment serial number supplied by the employee.'
            required=true
        )
        public String serialNumber;
    }

    public class Output {
        @InvocableVariable(
            label='Coverage Status'
            description='Covered, Expired, Not Covered, or Unavailable.'
        )
        public String coverageStatus;

        @InvocableVariable(
            label='As Of Date'
            description='Date on which the coverage position was checked.'
        )
        public Date asOfDate;

        @InvocableVariable(
            label='Message'
            description='Short explanation safe to show in the conversation.'
        )
        public String message;
    }

    @InvocableMethod(
        label='Check HES Equipment Coverage'
        description='Checks an exact Equipment serial number and returns its current coverage position as of today.'
    )
    public static List<Output> checkCoverage(List<Input> inputs) {
        List<Output> results = new List<Output>();

        if (inputs == null || inputs.isEmpty()) {
            return results;
        }

        Date today = Date.today();
        Set<String> serials = new Set<String>();

        for (Input item : inputs) {
            if (item != null && !String.isBlank(item.serialNumber)) {
                serials.add(item.serialNumber.trim());
            }
        }

        List<Equipment__c> equipmentRecords = new List<Equipment__c>();
        Boolean equipmentReadFailed = false;

        if (!serials.isEmpty()) {
            try {
                equipmentRecords = [
                    SELECT Id, Serial_Number__c, Current_Coverage_Plan__c
                    FROM Equipment__c
                    WHERE Serial_Number__c IN :serials
                    WITH USER_MODE
                ];
            } catch (Exception ex) {
                equipmentReadFailed = true;
            }
        }

        Set<Id> planIds = new Set<Id>();

        if (!equipmentReadFailed) {
            for (Equipment__c unit : equipmentRecords) {
                if (unit.Current_Coverage_Plan__c != null) {
                    planIds.add(unit.Current_Coverage_Plan__c);
                }
            }
        }

        Map<Id, Coverage_Plan__c> plansById =
            new Map<Id, Coverage_Plan__c>();
        Boolean planReadFailed = false;

        if (!planIds.isEmpty()) {
            try {
                plansById = new Map<Id, Coverage_Plan__c>([
                    SELECT Id, Status__c, Start_Date__c, End_Date__c
                    FROM Coverage_Plan__c
                    WHERE Id IN :planIds
                    WITH USER_MODE
                ]);
            } catch (Exception ex) {
                planReadFailed = true;
            }
        }

        for (Input item : inputs) {
            if (item == null || String.isBlank(item.serialNumber)) {
                results.add(makeResult(
                    'Unavailable',
                    today,
                    'Please provide an Equipment serial number.'
                ));
                continue;
            }

            if (equipmentReadFailed) {
                results.add(makeResult(
                    'Unavailable',
                    today,
                    'Coverage could not be checked for this serial number.'
                ));
                continue;
            }

            String requestedSerial = item.serialNumber.trim();
            Equipment__c matchedUnit;

            // Confirm the stored serial matches exactly even if the SOQL
            // text comparison in this org is case-insensitive.
            for (Equipment__c candidate : equipmentRecords) {
                if (candidate.Serial_Number__c != null &&
                    candidate.Serial_Number__c.equals(requestedSerial)) {
                    matchedUnit = candidate;
                    break;
                }
            }

            if (matchedUnit == null) {
                results.add(makeResult(
                    'Unavailable',
                    today,
                    'Coverage could not be checked for this serial number.'
                ));
                continue;
            }

            if (matchedUnit.Current_Coverage_Plan__c == null) {
                results.add(makeResult(
                    'Not Covered',
                    today,
                    'No current Coverage Plan is linked to this Equipment.'
                ));
                continue;
            }

            if (planReadFailed ||
                !plansById.containsKey(
                    matchedUnit.Current_Coverage_Plan__c
                )) {
                results.add(makeResult(
                    'Unavailable',
                    today,
                    'Coverage could not be checked for this serial number.'
                ));
                continue;
            }

            Coverage_Plan__c plan =
                plansById.get(matchedUnit.Current_Coverage_Plan__c);

            if (plan.Status__c == 'Expired' ||
                (plan.End_Date__c != null &&
                 plan.End_Date__c < today)) {
                results.add(makeResult(
                    'Expired',
                    today,
                    'The current Coverage Plan is expired.'
                ));
            } else if (plan.Status__c == 'Active' &&
                       plan.Start_Date__c != null &&
                       plan.End_Date__c != null &&
                       plan.Start_Date__c <= today &&
                       plan.End_Date__c >= today) {
                results.add(makeResult(
                    'Covered',
                    today,
                    'The Equipment has active coverage as of this date.'
                ));
            } else {
                results.add(makeResult(
                    'Not Covered',
                    today,
                    'The current plan is not active within its coverage dates.'
                ));
            }
        }

        return results;
    }

    private static Output makeResult(
        String status,
        Date checkedDate,
        String explanation
    ) {
        Output result = new Output();
        result.coverageStatus = status;
        result.asOfDate = checkedDate;
        result.message = explanation;
        return result;
    }
}