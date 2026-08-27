/**
 * Provides read-only Case context to Agentforce for a Case ID or Case Number.
 */
public with sharing class GetCaseContextAction {
    private static final String NOT_FOUND_MESSAGE = 'No Case was found for the provided identifier.';
    private static final String INVALID_IDENTIFIER_MESSAGE = 'The provided Salesforce ID does not identify a Case.';
    private static final String BLANK_IDENTIFIER_MESSAGE = 'A Case ID or Case Number is required.';
    private static final String ACCESS_ERROR_MESSAGE = 'The Case context could not be retrieved.';

    /**
     * Defines the Case identifier supplied by an invocable action caller.
     */
    public class Request {
        @InvocableVariable(required=true label='Case ID or Case Number')
        public String caseIdentifier;
    }

    /**
     * Returns the permitted Case context or a sanitized failure result.
     */
    public class Response {
        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String errorMessage;

        @InvocableVariable
        public String caseId;

        @InvocableVariable
        public String caseNumber;

        @InvocableVariable
        public String subject;

        @InvocableVariable
        public String status;

        @InvocableVariable
        public String priority;

        @InvocableVariable
        public String accountName;

        @InvocableVariable
        public String contactName;

        @InvocableVariable
        public String description;

        @InvocableVariable
        public String caseSummary;
    }

    private class ParsedRequest {
        private Id caseId;
        private String caseNumber;
        private String validationError;
    }

    /**
     * Retrieves Case context in the same order as the supplied requests.
     *
     * @param requests Invocable requests containing Case IDs or Case Numbers.
     * @return One response for each supplied request, preserving input order.
     */
    @InvocableMethod(label='Get Case Context' description='Retrieves deterministic context for a Case ID or Case Number.')
    public static List<Response> getCaseContext(List<Request> requests) {
        if (requests == null) {
            return new List<Response>();
        }

        List<ParsedRequest> parsedRequests = new List<ParsedRequest>();
        Set<Id> caseIds = new Set<Id>();
        Set<String> caseNumbers = new Set<String>();
        collectRequestIdentifiers(requests, parsedRequests, caseIds, caseNumbers);

        Map<Id, Case> casesById = new Map<Id, Case>();
        Map<String, Case> casesByNumber = new Map<String, Case>();
        Boolean queryFailed = false;

        try {
            casesById = queryCasesById(caseIds);
            casesByNumber = queryCasesByNumber(caseNumbers);
        } catch (QueryException exceptionValue) {
            queryFailed = true;
        }

        return buildResponses(parsedRequests, casesById, casesByNumber, queryFailed);
    }

    private static void collectRequestIdentifiers(
        List<Request> requests,
        List<ParsedRequest> parsedRequests,
        Set<Id> caseIds,
        Set<String> caseNumbers
    ) {
        for (Request request : requests) {
            ParsedRequest parsed = parseRequest(request);
            parsedRequests.add(parsed);
            if (parsed.caseId != null) {
                caseIds.add(parsed.caseId);
            } else if (parsed.caseNumber != null) {
                caseNumbers.add(parsed.caseNumber);
            }
        }
    }

    private static Map<Id, Case> queryCasesById(Set<Id> caseIds) {
        if (caseIds.isEmpty()) {
            return new Map<Id, Case>();
        }
        return new Map<Id, Case>([
            SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, Contact.Name, Description
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ]);
    }

    private static Map<String, Case> queryCasesByNumber(Set<String> caseNumbers) {
        Map<String, Case> casesByNumber = new Map<String, Case>();
        if (caseNumbers.isEmpty()) {
            return casesByNumber;
        }
        for (Case caseRecord : [
            SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, Contact.Name, Description
            FROM Case
            WHERE CaseNumber IN :caseNumbers
            WITH USER_MODE
        ]) {
            casesByNumber.put(caseRecord.CaseNumber, caseRecord);
        }
        return casesByNumber;
    }

    private static List<Response> buildResponses(
        List<ParsedRequest> parsedRequests,
        Map<Id, Case> casesById,
        Map<String, Case> casesByNumber,
        Boolean queryFailed
    ) {
        List<Response> responses = new List<Response>();
        for (ParsedRequest parsed : parsedRequests) {
            if (parsed.validationError != null) {
                responses.add(failureResponse(parsed.validationError));
                continue;
            }
            if (queryFailed) {
                responses.add(failureResponse(ACCESS_ERROR_MESSAGE));
                continue;
            }

            Case caseRecord = parsed.caseId != null
                ? casesById.get(parsed.caseId)
                : casesByNumber.get(parsed.caseNumber);
            responses.add(
                caseRecord == null ? failureResponse(NOT_FOUND_MESSAGE) : successResponse(caseRecord)
            );
        }
        return responses;
    }

    private static ParsedRequest parseRequest(Request request) {
        ParsedRequest parsed = new ParsedRequest();
        String identifier = request == null ? null : request.caseIdentifier;
        if (String.isBlank(identifier)) {
            parsed.validationError = BLANK_IDENTIFIER_MESSAGE;
            return parsed;
        }

        identifier = identifier.trim();
        try {
            Id parsedId = Id.valueOf(identifier);
            if (parsedId.getSObjectType() != Case.SObjectType) {
                parsed.validationError = INVALID_IDENTIFIER_MESSAGE;
            } else {
                parsed.caseId = parsedId;
            }
        } catch (StringException exceptionValue) {
            parsed.caseNumber = identifier;
        }
        return parsed;
    }

    private static Response successResponse(Case caseRecord) {
        Response response = new Response();
        response.success = true;
        response.caseId = String.valueOf(caseRecord.Id);
        response.caseNumber = caseRecord.CaseNumber;
        response.subject = caseRecord.Subject;
        response.status = caseRecord.Status;
        response.priority = caseRecord.Priority;
        response.accountName = caseRecord.Account == null ? null : caseRecord.Account.Name;
        response.contactName = caseRecord.Contact == null ? null : caseRecord.Contact.Name;
        response.description = caseRecord.Description;
        response.caseSummary = buildSummary(caseRecord);
        return response;
    }

    private static Response failureResponse(String message) {
        Response response = new Response();
        response.success = false;
        response.errorMessage = message;
        return response;
    }

    private static String buildSummary(Case caseRecord) {
        List<String> parts = new List<String>{ 'Case ' + caseRecord.CaseNumber };
        if (!String.isBlank(caseRecord.Status)) {
            parts.add('Status: ' + caseRecord.Status);
        }
        if (!String.isBlank(caseRecord.Priority)) {
            parts.add('Priority: ' + caseRecord.Priority);
        }
        if (!String.isBlank(caseRecord.Subject)) {
            parts.add('Subject: ' + caseRecord.Subject);
        }
        return String.join(parts, ' | ');
    }
}
