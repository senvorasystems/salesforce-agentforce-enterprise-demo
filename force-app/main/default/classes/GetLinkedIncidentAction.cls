/**
 * Retrieves external incident details linked to Salesforce Cases visible to the caller.
 */
public with sharing class GetLinkedIncidentAction {
    private static final String ENDPOINT =
        'callout:SENVORA_Incident_API/api/v1/incidents/lookup';
    private static final Integer BATCH_SIZE = 50;
    private static final Integer TIMEOUT_MS = 10000;
    @TestVisible private static Boolean simulateTimeout = false;

    private static final String INVALID_CASE_ID = 'INVALID_CASE_ID';
    private static final String CASE_NOT_ACCESSIBLE = 'CASE_NOT_ACCESSIBLE_OR_NOT_FOUND';
    private static final String INVALID_RESPONSE = 'INVALID_EXTERNAL_RESPONSE';
    private static final Map<Integer, String> HTTP_ERROR_CODES = new Map<Integer, String>{
        400 => 'EXTERNAL_INVALID_REQUEST',
        401 => 'EXTERNAL_AUTH_ERROR',
        403 => 'EXTERNAL_AUTH_ERROR',
        429 => 'EXTERNAL_RATE_LIMIT'
    };
    private static final Map<String, String> ERROR_MESSAGES = new Map<String, String>{
        INVALID_CASE_ID => 'A valid Salesforce Case ID is required.',
        CASE_NOT_ACCESSIBLE => 'The Case could not be accessed or found.',
        INVALID_RESPONSE => 'The incident service returned an invalid response.',
        'EXTERNAL_INVALID_REQUEST' => 'The incident lookup request was rejected.',
        'EXTERNAL_AUTH_ERROR' => 'The incident service could not be authorized.',
        'EXTERNAL_RATE_LIMIT' => 'The incident service is temporarily busy.',
        'EXTERNAL_SERVICE_ERROR' => 'The incident service is temporarily unavailable.',
        'EXTERNAL_TIMEOUT' => 'The incident service did not respond in time.',
        'EXTERNAL_CALLOUT_ERROR' => 'The incident service could not be reached.',
        'EXTERNAL_HTTP_ERROR' => 'The incident lookup failed with an unexpected HTTP response.'
    };

    /** Input supplied by an invocable action caller. */
    public class Request {
        @InvocableVariable(
            required=true
            label='Case ID'
            description='Salesforce Case ID used to retrieve a linked external incident.'
        )
        public String caseId;
    }

    /** Result of the external incident lookup. */
    public class Response {
        @InvocableVariable public Boolean success;
        @InvocableVariable public Boolean found;
        @InvocableVariable public String errorCode;
        @InvocableVariable public String errorMessage;
        @InvocableVariable public String caseId;
        @InvocableVariable public String incidentId;
        @InvocableVariable public String incidentStatus;
        @InvocableVariable public String incidentSeverity;
        @InvocableVariable public String incidentTitle;
        @InvocableVariable public String incidentDescription;
    }

    private class ParsedRequest {
        private Id caseId;
        private String errorCode;
    }

    private class LookupRequestDto {
        private List<String> caseIds;

        private LookupRequestDto(List<String> caseIds) {
            this.caseIds = caseIds;
        }
    }

    private class LookupResponseDto {
        private List<LookupResultDto> results;
    }

    private class LookupResultDto {
        private String caseId;
        private Boolean found;
        private IncidentDto incident;
    }

    private class IncidentDto {
        private String id;
        private String status;
        private String severity;
        private String title;
        private String description;
    }

    private class ValidatedLookupResults {
        private Map<Id, Response> responsesByCaseId = new Map<Id, Response>();
        private Boolean valid = true;
    }

    /**
     * Looks up linked incidents in batches while preserving the input order.
     *
     * @param requests requests containing Salesforce Case IDs
     * @return one response per request in the original order
     */
    @InvocableMethod(
        label='Get Linked Incident'
        description='Retrieves an external incident linked to a Salesforce Case.'
        callout=true
    )
    public static List<Response> getLinkedIncident(List<Request> requests) {
        if (requests == null) {
            return new List<Response>();
        }

        List<ParsedRequest> parsedRequests = new List<ParsedRequest>();
        Set<Id> requestedIds = new Set<Id>();
        for (Request request : requests) {
            ParsedRequest parsed = parseRequest(request);
            parsedRequests.add(parsed);
            if (parsed.caseId != null) {
                requestedIds.add(parsed.caseId);
            }
        }

        Map<Id, Case> accessibleCases;
        try {
            accessibleCases = queryAccessibleCases(requestedIds);
        } catch (QueryException exceptionValue) {
            return buildQueryFailureResponses(parsedRequests);
        }

        List<Id> outboundIds = uniqueAccessibleIdsInInputOrder(parsedRequests, accessibleCases);
        Map<Id, Response> resultsByCaseId = performLookups(outboundIds);
        return buildOrderedResponses(parsedRequests, accessibleCases, resultsByCaseId);
    }

    private static ParsedRequest parseRequest(Request request) {
        ParsedRequest parsed = new ParsedRequest();
        String value = request == null ? null : request.caseId;
        if (String.isBlank(value)) {
            parsed.errorCode = INVALID_CASE_ID;
            return parsed;
        }

        value = value.trim();
        if (value.length() != 15 && value.length() != 18) {
            parsed.errorCode = INVALID_CASE_ID;
            return parsed;
        }

        try {
            Id candidate = Id.valueOf(value);
            if (candidate.getSObjectType() == Case.SObjectType) {
                parsed.caseId = candidate;
            } else {
                parsed.errorCode = INVALID_CASE_ID;
            }
        } catch (StringException exceptionValue) {
            parsed.errorCode = INVALID_CASE_ID;
        }
        return parsed;
    }

    private static Map<Id, Case> queryAccessibleCases(Set<Id> caseIds) {
        if (caseIds.isEmpty()) {
            return new Map<Id, Case>();
        }
        return new Map<Id, Case>([
            SELECT Id
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ]);
    }

    private static List<Id> uniqueAccessibleIdsInInputOrder(
        List<ParsedRequest> parsedRequests,
        Map<Id, Case> accessibleCases
    ) {
        List<Id> orderedIds = new List<Id>();
        Set<Id> seen = new Set<Id>();
        for (ParsedRequest parsed : parsedRequests) {
            if (parsed.caseId != null && accessibleCases.containsKey(parsed.caseId) &&
                !seen.contains(parsed.caseId)) {
                seen.add(parsed.caseId);
                orderedIds.add(parsed.caseId);
            }
        }
        return orderedIds;
    }

    private static Map<Id, Response> performLookups(List<Id> caseIds) {
        Map<Id, Response> results = new Map<Id, Response>();
        for (Integer startIndex = 0; startIndex < caseIds.size(); startIndex += BATCH_SIZE) {
            Integer endIndex = Math.min(startIndex + BATCH_SIZE, caseIds.size());
            List<Id> batch = new List<Id>();
            for (Integer index = startIndex; index < endIndex; index++) {
                batch.add(caseIds[index]);
            }
            results.putAll(performLookup(batch));
        }
        return results;
    }

    private static Map<Id, Response> performLookup(List<Id> batch) {
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(ENDPOINT);
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MS);

        List<String> caseIds = new List<String>();
        for (Id caseId : batch) {
            caseIds.add(String.valueOf(caseId));
        }
        request.setBody(JSON.serialize(new LookupRequestDto(caseIds)));

        try {
            HttpResponse response = new Http().send(request);
            return response.getStatusCode() == 200
                ? parseSuccessfulResponse(response.getBody(), batch)
                : batchFailures(batch, classifyHttpStatus(response.getStatusCode()));
        } catch (CalloutException exceptionValue) {
            String message = exceptionValue.getMessage();
            String normalized = message == null ? '' : message.toLowerCase();
            String code = normalized.contains('timed out') || normalized.contains('timeout') ||
                simulateTimeout
                ? 'EXTERNAL_TIMEOUT'
                : 'EXTERNAL_CALLOUT_ERROR';
            return batchFailures(batch, code);
        }
    }

    private static Map<Id, Response> parseSuccessfulResponse(String body, List<Id> batch) {
        if (String.isBlank(body)) {
            return batchFailures(batch, INVALID_RESPONSE);
        }

        try {
            LookupResponseDto payload = deserializeLookupResponse(body);
            return validateLookupResponse(payload, batch);
        } catch (Exception exceptionValue) {
            return batchFailures(batch, INVALID_RESPONSE);
        }
    }

    private static LookupResponseDto deserializeLookupResponse(String body) {
        return (LookupResponseDto) JSON.deserialize(body, LookupResponseDto.class);
    }

    private static Map<Id, Response> validateLookupResponse(
        LookupResponseDto payload,
        List<Id> batch
    ) {
        if (payload == null || payload.results == null) {
            return batchFailures(batch, INVALID_RESPONSE);
        }

        Set<Id> expected = new Set<Id>(batch);
        ValidatedLookupResults validated = validateLookupResults(payload.results, expected);
        return validated.valid && validated.responsesByCaseId.size() == expected.size()
            ? validated.responsesByCaseId
            : batchFailures(batch, INVALID_RESPONSE);
    }

    private static ValidatedLookupResults validateLookupResults(
        List<LookupResultDto> results,
        Set<Id> expected
    ) {
        ValidatedLookupResults validated = new ValidatedLookupResults();
        for (LookupResultDto result : results) {
            Id resultCaseId = parseExpectedCaseId(result, expected);
            if (!addValidatedResult(validated, resultCaseId, result)) {
                validated.valid = false;
                return validated;
            }
        }
        return validated;
    }

    private static Boolean addValidatedResult(
        ValidatedLookupResults validated,
        Id resultCaseId,
        LookupResultDto result
    ) {
        if (resultCaseId == null || validated.responsesByCaseId.containsKey(resultCaseId) ||
            !isValidResult(result)) {
            return false;
        }
        validated.responsesByCaseId.put(resultCaseId, successResponse(resultCaseId, result));
        return true;
    }

    private static Id parseExpectedCaseId(LookupResultDto result, Set<Id> expected) {
        if (result == null || String.isBlank(result.caseId)) {
            return null;
        }
        try {
            Id caseId = Id.valueOf(result.caseId.trim());
            return expected.contains(caseId) ? caseId : null;
        } catch (StringException exceptionValue) {
            return null;
        }
    }

    private static Boolean isValidResult(LookupResultDto result) {
        if (result.found == null) {
            return false;
        }
        if (!result.found) {
            return result.incident == null;
        }
        return result.incident != null &&
            !String.isBlank(result.incident.id) &&
            !String.isBlank(result.incident.status) &&
            !String.isBlank(result.incident.severity) &&
            !String.isBlank(result.incident.title);
    }

    private static Response successResponse(Id caseId, LookupResultDto result) {
        Response response = new Response();
        response.success = true;
        response.found = result.found;
        response.caseId = String.valueOf(caseId);
        if (result.found) {
            response.incidentId = result.incident.id;
            response.incidentStatus = result.incident.status;
            response.incidentSeverity = result.incident.severity;
            response.incidentTitle = result.incident.title;
            response.incidentDescription = result.incident.description;
        }
        return response;
    }

    private static List<Response> buildOrderedResponses(
        List<ParsedRequest> parsedRequests,
        Map<Id, Case> accessibleCases,
        Map<Id, Response> resultsByCaseId
    ) {
        List<Response> responses = new List<Response>();
        for (ParsedRequest parsed : parsedRequests) {
            if (parsed.errorCode != null) {
                responses.add(failureResponse(null, parsed.errorCode));
            } else if (!accessibleCases.containsKey(parsed.caseId)) {
                responses.add(failureResponse(parsed.caseId, CASE_NOT_ACCESSIBLE));
            } else {
                responses.add(copyResponse(resultsByCaseId.get(parsed.caseId)));
            }
        }
        return responses;
    }

    private static List<Response> buildQueryFailureResponses(List<ParsedRequest> parsedRequests) {
        List<Response> responses = new List<Response>();
        for (ParsedRequest parsed : parsedRequests) {
            responses.add(
                failureResponse(
                    parsed.caseId,
                    parsed.errorCode == null ? CASE_NOT_ACCESSIBLE : parsed.errorCode
                )
            );
        }
        return responses;
    }

    private static Map<Id, Response> batchFailures(List<Id> batch, String code) {
        Map<Id, Response> failures = new Map<Id, Response>();
        for (Id caseId : batch) {
            failures.put(caseId, failureResponse(caseId, code));
        }
        return failures;
    }

    private static Response failureResponse(Id caseId, String code) {
        Response response = new Response();
        response.success = false;
        response.caseId = caseId == null ? null : String.valueOf(caseId);
        response.errorCode = code;
        response.errorMessage = errorMessageFor(code);
        return response;
    }

    private static Response copyResponse(Response source) {
        Response copy = new Response();
        copy.success = source.success;
        copy.found = source.found;
        copy.errorCode = source.errorCode;
        copy.errorMessage = source.errorMessage;
        copy.caseId = source.caseId;
        copy.incidentId = source.incidentId;
        copy.incidentStatus = source.incidentStatus;
        copy.incidentSeverity = source.incidentSeverity;
        copy.incidentTitle = source.incidentTitle;
        copy.incidentDescription = source.incidentDescription;
        return copy;
    }

    private static String classifyHttpStatus(Integer statusCode) {
        String exactCode = HTTP_ERROR_CODES.get(statusCode);
        if (exactCode != null) {
            return exactCode;
        }
        return statusCode >= 500 && statusCode <= 599
            ? 'EXTERNAL_SERVICE_ERROR'
            : 'EXTERNAL_HTTP_ERROR';
    }

    private static String errorMessageFor(String code) {
        return ERROR_MESSAGES.get(code);
    }
}
