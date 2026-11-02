public with sharing class HESCoverageReplyPromptService {

    // Verify this API name in Prompt Builder.
    private static final String TEMPLATE_API_NAME =
        'HES_Coverage_Aware_Reply_Draft';

    public class Request {
        @InvocableVariable(
            label='Case ID'
            description='ID of the Case for which to draft a coverage-aware reply.'
            required=true
        )
        public Id caseId;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the prompt produced a draft.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Draft Text'
            description='Generated subject and email body for human review.'
        )
        public String draftText;

        @InvocableVariable(
            label='Coverage Context'
            description='Current coverage position supplied to the prompt.'
        )
        public String coverageContext;

        @InvocableVariable(
            label='Message'
            description='Safe explanation when a draft cannot be produced.'
        )
        public String message;
    }

    @InvocableMethod(
        label='Draft HES Coverage Reply via Apex'
        description='Reads an accessible Case, its Equipment, and current Coverage Plan; calculates coverage as of today; and calls the HES Coverage Aware Reply Draft prompt template. Returns a draft without sending email.'
    )
    public static List<Response> draftReplies(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        Set<Id> caseIds = new Set<Id>();

        for (Request item : requests) {
            if (item != null && item.caseId != null) {
                caseIds.add(item.caseId);
            }
        }

        Map<Id, Case> casesById = new Map<Id, Case>();
        Map<Id, Equipment__c> equipmentById =
            new Map<Id, Equipment__c>();
        Map<Id, Coverage_Plan__c> plansById =
            new Map<Id, Coverage_Plan__c>();

        try {
            if (!caseIds.isEmpty()) {
                casesById = new Map<Id, Case>([
                    SELECT Id,
                           CaseNumber,
                           Subject,
                           Description,
                           Status,
                           Coverage_Status__c,
                           Equipment__c
                    FROM Case
                    WHERE Id IN :caseIds
                    WITH USER_MODE
                ]);
            }

            Set<Id> equipmentIds = new Set<Id>();

            for (Case caseRecord : casesById.values()) {
                if (caseRecord.Equipment__c != null) {
                    equipmentIds.add(caseRecord.Equipment__c);
                }
            }

            if (!equipmentIds.isEmpty()) {
                equipmentById = new Map<Id, Equipment__c>([
                    SELECT Id,
                           Serial_Number__c,
                           Current_Coverage_Plan__c
                    FROM Equipment__c
                    WHERE Id IN :equipmentIds
                    WITH USER_MODE
                ]);
            }

            Set<Id> planIds = new Set<Id>();

            for (Equipment__c equipment : equipmentById.values()) {
                if (equipment.Current_Coverage_Plan__c != null) {
                    planIds.add(
                        equipment.Current_Coverage_Plan__c
                    );
                }
            }

            if (!planIds.isEmpty()) {
                plansById = new Map<Id, Coverage_Plan__c>([
                    SELECT Id,
                           Status__c,
                           Start_Date__c,
                           End_Date__c,
                           Service_Level__c
                    FROM Coverage_Plan__c
                    WHERE Id IN :planIds
                    WITH USER_MODE
                ]);
            }

        } catch (Exception readError) {
            // Do not expose query errors or inaccessible data to the Flow.
            for (Request ignored : requests) {
                responses.add(failure(
                    'The required Case or coverage information is unavailable.'
                ));
            }
            return responses;
        }

        for (Request item : requests) {
            if (item == null || item.caseId == null) {
                responses.add(failure('A Case ID is required.'));
                continue;
            }

            Case caseRecord = casesById.get(item.caseId);

            if (caseRecord == null) {
                responses.add(failure(
                    'The Case is unavailable or you do not have access to it.'
                ));
                continue;
            }

            if (caseRecord.Equipment__c == null) {
                responses.add(failure(
                    'Link Equipment to this Case before drafting a coverage reply.'
                ));
                continue;
            }

            Equipment__c equipment =
                equipmentById.get(caseRecord.Equipment__c);

            if (equipment == null) {
                responses.add(failure(
                    'The linked Equipment is unavailable.'
                ));
                continue;
            }

            Coverage_Plan__c currentPlan = null;

            if (equipment.Current_Coverage_Plan__c != null) {
                currentPlan = plansById.get(
                    equipment.Current_Coverage_Plan__c
                );

                if (currentPlan == null) {
                    responses.add(failure(
                        'The current Coverage Plan is unavailable.'
                    ));
                    continue;
                }
            }

            String context = buildCoverageContext(currentPlan);

            try {
                Map<String, ConnectApi.WrappedValue> inputs =
                    new Map<String, ConnectApi.WrappedValue>();

                // Verify these three API names in the Flex template.
                inputs.put(
                    'Input:caseRecord',
                    wrapRecordId(caseRecord.Id)
                );

                inputs.put(
                    'Input:equipmentRecord',
                    wrapRecordId(equipment.Id)
                );

                inputs.put(
                    'Input:coverageContext',
                    wrapText(context)
                );

                ConnectApi.EinsteinPromptTemplateGenerationsInput
                    promptRequest =
                    new ConnectApi.EinsteinPromptTemplateGenerationsInput();

                promptRequest.additionalConfig =
                    new ConnectApi.EinsteinLlmAdditionalConfigInput();

                promptRequest.additionalConfig.applicationName =
                    'HESCoverageReply';

                promptRequest.isPreview = false;
                promptRequest.inputParams = inputs;

                ConnectApi.EinsteinPromptTemplateGenerationsRepresentation
                    generated =
                    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                        TEMPLATE_API_NAME,
                        promptRequest
                    );

                if (
                    generated == null ||
                    generated.generations == null ||
                    generated.generations.isEmpty() ||
                    String.isBlank(generated.generations[0].text)
                ) {
                    responses.add(failure(
                        'The prompt did not return a reply draft.'
                    ));
                    continue;
                }

                Response answer = new Response();
                answer.success = true;
                answer.draftText =
                    generated.generations[0].text;
                answer.coverageContext = context;
                answer.message =
                    'Draft generated. Review it before sending.';

                responses.add(answer);

            } catch (Exception promptError) {
                // Never expose the raw exception in a user-facing Flow.
                responses.add(failure(
                    'The reply draft could not be generated. Check prompt access and configuration.'
                ));
            }
        }

        return responses;
    }

    private static ConnectApi.WrappedValue wrapRecordId(
        Id recordId
    ) {
        ConnectApi.WrappedValue wrapped =
            new ConnectApi.WrappedValue();

        wrapped.value = new Map<String, String>{
            'id' => String.valueOf(recordId)
        };

        return wrapped;
    }

    private static ConnectApi.WrappedValue wrapText(
        String textValue
    ) {
        ConnectApi.WrappedValue wrapped =
            new ConnectApi.WrappedValue();

        wrapped.value = textValue;

        return wrapped;
    }

    private static String buildCoverageContext(
        Coverage_Plan__c plan
    ) {
        Date asOfDate = Date.today();
        String asOfText = asOfDate.format();

        if (plan == null) {
            return 'Not Covered as of ' + asOfText +
                '. This Equipment has no current Coverage Plan. ' +
                'Do not promise covered service.';
        }

        String planStatus = String.valueOf(plan.Status__c);

        if (
            planStatus == 'Expired' ||
            (
                plan.End_Date__c != null &&
                plan.End_Date__c < asOfDate
            )
        ) {
            return 'Expired as of ' + asOfText +
                '. The current Coverage Plan is expired or ' +
                'its end date has passed. The service team ' +
                'must confirm further entitlement.';
        }

        if (
            planStatus == 'Active' &&
            plan.Start_Date__c != null &&
            plan.End_Date__c != null &&
            plan.Start_Date__c <= asOfDate &&
            plan.End_Date__c >= asOfDate
        ) {
            String serviceLevel =
                String.valueOf(plan.Service_Level__c);

            if (String.isBlank(serviceLevel)) {
                serviceLevel = 'not specified';
            }

            return 'Covered as of ' + asOfText +
                '. The current Coverage Plan is Active. ' +
                'Service level: ' + serviceLevel +
                '. Plan end date: ' +
                plan.End_Date__c.format() + '.';
        }

        return 'Not Covered as of ' + asOfText +
            '. A Coverage Plan is linked, but it is not ' +
            'currently Active within its start and end dates. ' +
            'Do not promise covered service.';
    }

    private static Response failure(String safeMessage) {
        Response answer = new Response();
        answer.success = false;
        answer.draftText = null;
        answer.coverageContext = null;
        answer.message = safeMessage;
        return answer;
    }
}