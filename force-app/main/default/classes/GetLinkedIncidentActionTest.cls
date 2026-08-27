@IsTest
private class GetLinkedIncidentActionTest {
    @TestSetup
    static void createCases() {
        List<Case> cases = new List<Case>();
        for (Integer index = 0; index < 52; index++) {
            cases.add(new Case(Subject = 'Linked incident test ' + index, Status = 'New'));
        }
        insert cases;
    }

    @IsTest
    static void rejectsNullBlankMalformedAndOtherObjectIds() {
        Account account = new Account(Name = 'Other object');
        insert account;

        List<GetLinkedIncidentAction.Request> requests = new List<GetLinkedIncidentAction.Request>{
            null,
            requestFor('   '),
            requestFor('not-an-id'),
            requestFor(String.valueOf(account.Id))
        };

        List<GetLinkedIncidentAction.Response> responses = invoke(requests, null);

        System.assertEquals(4, responses.size());
        for (GetLinkedIncidentAction.Response response : responses) {
            assertFailure(response, 'INVALID_CASE_ID');
        }
    }

    @IsTest
    static void mapsFoundIncidentAndVerifiesRequest() {
        Case caseRecord = testCases(1)[0];
        IncidentMock mock = new IncidentMock('FOUND');

        GetLinkedIncidentAction.Response response = invoke(
            requestsFor(new List<Id>{ caseRecord.Id }),
            mock
        )[0];

        System.assertEquals(true, response.success);
        System.assertEquals(true, response.found);
        System.assertEquals(String.valueOf(caseRecord.Id), response.caseId);
        System.assertEquals('INC-2026-0001', response.incidentId);
        System.assertEquals('Investigating', response.incidentStatus);
        System.assertEquals('High', response.incidentSeverity);
        System.assertEquals('External incident', response.incidentTitle);
        System.assertEquals('Sanitized external description.', response.incidentDescription);
        System.assertEquals(null, response.errorCode);
    }

    @IsTest
    static void mapsNotFoundWithoutFabricatingIncident() {
        Case caseRecord = testCases(1)[0];

        GetLinkedIncidentAction.Response response = invoke(
            requestsFor(new List<Id>{ caseRecord.Id }),
            new IncidentMock('NOT_FOUND')
        )[0];

        System.assertEquals(true, response.success);
        System.assertEquals(false, response.found);
        System.assertEquals(String.valueOf(caseRecord.Id), response.caseId);
        assertNoIncident(response);
    }

    @IsTest
    static void preservesOrderAndCreatesIndependentDuplicateResponses() {
        List<Case> cases = testCases(2);
        List<Id> ids = new List<Id>{ cases[1].Id, cases[0].Id, cases[1].Id };
        IncidentMock mock = new IncidentMock('FOUND');

        List<GetLinkedIncidentAction.Response> responses = invoke(requestsFor(ids), mock);

        System.assertEquals(3, responses.size());
        System.assertEquals(String.valueOf(ids[0]), responses[0].caseId);
        System.assertEquals(String.valueOf(ids[1]), responses[1].caseId);
        System.assertEquals(String.valueOf(ids[2]), responses[2].caseId);
        System.assert(responses[0] !== responses[2], 'Duplicate positions require independent DTOs.');
    }

    @IsTest
    static void classifiesHttp401() {
        Case caseRecord = testCases(1)[0];
        GetLinkedIncidentAction.Response unauthorized =
            invokeOne(caseRecord.Id, new IncidentMock('401'));
        System.assertEquals(false, unauthorized.success);
        assertFailure(unauthorized, 'EXTERNAL_AUTH_ERROR');
    }

    @IsTest
    static void classifiesHttp429() {
        Case caseRecord = testCases(1)[0];
        GetLinkedIncidentAction.Response rateLimited =
            invokeOne(caseRecord.Id, new IncidentMock('429'));
        System.assertEquals(false, rateLimited.success);
        assertFailure(rateLimited, 'EXTERNAL_RATE_LIMIT');
    }

    @IsTest
    static void classifiesHttp500() {
        Case caseRecord = testCases(1)[0];
        GetLinkedIncidentAction.Response serverError =
            invokeOne(caseRecord.Id, new IncidentMock('500'));
        System.assertEquals(false, serverError.success);
        assertFailure(serverError, 'EXTERNAL_SERVICE_ERROR');
    }

    @IsTest
    static void rejectsMalformedJson() {
        Case caseRecord = testCases(1)[0];
        GetLinkedIncidentAction.Response malformed =
            invokeOne(caseRecord.Id, new IncidentMock('MALFORMED'));
        System.assertEquals(false, malformed.success);
        assertFailure(malformed, 'INVALID_EXTERNAL_RESPONSE');
    }

    @IsTest
    static void rejectsIncompleteSuccessfulPayload() {
        Case caseRecord = testCases(1)[0];
        GetLinkedIncidentAction.Response incomplete =
            invokeOne(caseRecord.Id, new IncidentMock('INCOMPLETE'));
        System.assertEquals(false, incomplete.success);
        assertFailure(incomplete, 'INVALID_EXTERNAL_RESPONSE');
    }

    @IsTest
    static void classifiesNonTimeoutCalloutException() {
        GetLinkedIncidentAction.Response response = invokeOne(
            testCases(1)[0].Id,
            new IncidentMock('CALLOUT_ERROR')
        );
        System.assertEquals(false, response.success);
        assertFailure(response, 'EXTERNAL_CALLOUT_ERROR');
    }

    @IsTest
    static void rejectsEmptySuccessfulBody() {
        System.assertEquals(
            'INVALID_EXTERNAL_RESPONSE',
            invalidExternalResponse('EMPTY_BODY').errorCode
        );
    }

    @IsTest
    static void rejectsNullResults() {
        System.assertEquals(
            'INVALID_EXTERNAL_RESPONSE',
            invalidExternalResponse('NULL_RESULTS').errorCode
        );
    }

    @IsTest
    static void rejectsMissingFound() {
        System.assertEquals(
            'INVALID_EXTERNAL_RESPONSE',
            invalidExternalResponse('MISSING_FOUND').errorCode
        );
    }

    @IsTest
    static void rejectsDuplicateExternalResult() {
        System.assertEquals(
            'INVALID_EXTERNAL_RESPONSE',
            invalidExternalResponse('DUPLICATE_RESULT').errorCode
        );
    }

    @IsTest
    static void rejectsUnknownExternalCaseId() {
        List<Case> cases = testCases(2);
        GetLinkedIncidentAction.Response response = invokeOne(
            cases[0].Id,
            new IncidentMock('UNKNOWN_CASE_ID', String.valueOf(cases[1].Id))
        );
        System.assertEquals('INVALID_EXTERNAL_RESPONSE', response.errorCode);
        assertFailure(response, 'INVALID_EXTERNAL_RESPONSE');
    }

    @IsTest
    static void rejectsMalformedExternalCaseId() {
        System.assertEquals(
            'INVALID_EXTERNAL_RESPONSE',
            invalidExternalResponse('MALFORMED_CASE_ID').errorCode
        );
    }

    @IsTest
    static void classifiesUnrecognizedHttpStatus() {
        GetLinkedIncidentAction.Response response = invokeOne(
            testCases(1)[0].Id,
            new IncidentMock('418')
        );
        System.assertEquals(false, response.success);
        assertFailure(response, 'EXTERNAL_HTTP_ERROR');
    }

    @IsTest
    static void rejectsFoundIncidentMissingRequiredField() {
        System.assertEquals(
            'INVALID_EXTERNAL_RESPONSE',
            invalidExternalResponse('MISSING_REQUIRED_FIELD').errorCode
        );
    }

    @IsTest
    static void rejectsIncidentWhenNotFound() {
        System.assertEquals(
            'INVALID_EXTERNAL_RESPONSE',
            invalidExternalResponse('INCIDENT_WHEN_NOT_FOUND').errorCode
        );
    }

    @IsTest
    static void classifiesTimeoutWithoutExposingException() {
        Case caseRecord = testCases(1)[0];
        GetLinkedIncidentAction.simulateTimeout = true;

        GetLinkedIncidentAction.Response response = invokeOne(
            caseRecord.Id,
            new IncidentMock('TIMEOUT')
        );

        assertFailure(response, 'EXTERNAL_TIMEOUT');
        System.assert(!response.errorMessage.contains('internal-host'));
    }

    @IsTest
    static void batchesMoreThanFiftyUniqueCases() {
        List<Case> cases = testCases(52);
        List<Id> ids = new List<Id>();
        for (Case caseRecord : cases) {
            ids.add(caseRecord.Id);
        }
        IncidentMock mock = new IncidentMock('NOT_FOUND');

        List<GetLinkedIncidentAction.Response> responses = invoke(requestsFor(ids), mock);

        System.assertEquals(52, responses.size());
        System.assertEquals(2, mock.callCount);
        System.assertEquals(new List<Integer>{ 50, 2 }, mock.batchSizes);
        for (Integer index = 0; index < ids.size(); index++) {
            System.assertEquals(String.valueOf(ids[index]), responses[index].caseId);
            System.assertEquals(true, responses[index].success);
            System.assertEquals(false, responses[index].found);
        }
    }

    @IsTest
    static void deletedCaseIsNotExposedOrCalledOut() {
        Case removed = new Case(Subject = 'Deleted case', Status = 'New');
        insert removed;
        Id removedId = removed.Id;
        delete removed;
        IncidentMock mock = new IncidentMock('FOUND');

        GetLinkedIncidentAction.Response response = invokeOne(removedId, mock);

        assertFailure(response, 'CASE_NOT_ACCESSIBLE_OR_NOT_FOUND');
        System.assertEquals(String.valueOf(removedId), response.caseId);
    }

    private static GetLinkedIncidentAction.Response invokeOne(Id caseId, IncidentMock mock) {
        return invoke(requestsFor(new List<Id>{ caseId }), mock)[0];
    }

    private static GetLinkedIncidentAction.Response invalidExternalResponse(String mode) {
        GetLinkedIncidentAction.Response response = invokeOne(
            testCases(1)[0].Id,
            new IncidentMock(mode)
        );
        assertFailure(response, 'INVALID_EXTERNAL_RESPONSE');
        return response;
    }

    private static List<GetLinkedIncidentAction.Response> invoke(
        List<GetLinkedIncidentAction.Request> requests,
        IncidentMock mock
    ) {
        if (mock != null) {
            Test.setMock(HttpCalloutMock.class, mock);
        }
        Test.startTest();
        List<GetLinkedIncidentAction.Response> responses =
            GetLinkedIncidentAction.getLinkedIncident(requests);
        Test.stopTest();
        return responses;
    }

    private static GetLinkedIncidentAction.Request requestFor(String caseId) {
        GetLinkedIncidentAction.Request request = new GetLinkedIncidentAction.Request();
        request.caseId = caseId;
        return request;
    }

    private static List<GetLinkedIncidentAction.Request> requestsFor(List<Id> caseIds) {
        List<GetLinkedIncidentAction.Request> requests =
            new List<GetLinkedIncidentAction.Request>();
        for (Id caseId : caseIds) {
            requests.add(requestFor(String.valueOf(caseId)));
        }
        return requests;
    }

    private static List<Case> testCases(Integer count) {
        return [
            SELECT Id
            FROM Case
            WHERE Subject LIKE 'Linked incident test%'
            ORDER BY Subject
            LIMIT :count
        ];
    }

    private static void assertFailure(
        GetLinkedIncidentAction.Response response,
        String expectedCode
    ) {
        System.assertEquals(false, response.success);
        System.assertEquals(null, response.found);
        System.assertEquals(expectedCode, response.errorCode);
        System.assertNotEquals(null, response.errorMessage);
        assertNoIncident(response);
    }

    private static void assertNoIncident(GetLinkedIncidentAction.Response response) {
        System.assertEquals(null, response.incidentId);
        System.assertEquals(null, response.incidentStatus);
        System.assertEquals(null, response.incidentSeverity);
        System.assertEquals(null, response.incidentTitle);
        System.assertEquals(null, response.incidentDescription);
    }

    private class IncidentMock implements HttpCalloutMock {
        private String mode;
        private String externalCaseIdOverride;
        private Integer callCount = 0;
        private List<Integer> batchSizes = new List<Integer>();
        private Map<String, Integer> httpStatuses = new Map<String, Integer>{
            '401' => 401,
            '418' => 418,
            '429' => 429,
            '500' => 500
        };

        private IncidentMock(String mode) {
            this.mode = mode;
        }

        private IncidentMock(String mode, String externalCaseIdOverride) {
            this.mode = mode;
            this.externalCaseIdOverride = externalCaseIdOverride;
        }

        /**
         * Returns a deterministic response and validates the outbound request.
         *
         * @param request outbound request created by the action
         * @return mocked response for the configured mode
         */
        public HttpResponse respond(HttpRequest request) {
            Map<String, Object> requestBody =
                (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            List<Object> caseIds = (List<Object>) requestBody.get('caseIds');
            callCount++;
            batchSizes.add(caseIds == null ? 0 : caseIds.size());
            if (!isValidRequest(request, caseIds)) {
                return responseWithStatus(400);
            }

            throwConfiguredCalloutException();
            Integer statusCode = httpStatuses.get(mode);
            if (statusCode != null) {
                return buildHttpErrorResponse(statusCode);
            }
            return buildSuccessfulLookupResponse(caseIds);
        }

        private void throwConfiguredCalloutException() {
            if (mode == 'TIMEOUT') {
                throw new CalloutException('Read timed out while contacting internal-host');
            }
            if (mode == 'CALLOUT_ERROR') {
                throw new CalloutException('Connection reset by remote host');
            }
        }

        private Boolean isValidRequest(HttpRequest request, List<Object> caseIds) {
            return request.getMethod() == 'POST' &&
                request.getEndpoint().contains(
                    'callout:SENVORA_Incident_API/api/v1/incidents/lookup'
                ) &&
                request.getHeader('Content-Type') == 'application/json' &&
                caseIds != null && !caseIds.isEmpty() && caseIds.size() <= 50;
        }

        private HttpResponse buildHttpErrorResponse(Integer statusCode) {
            HttpResponse response = responseWithStatus(statusCode);
            response.setBody('{"secret":"must not leak"}');
            return response;
        }

        private HttpResponse responseWithStatus(Integer statusCode) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            return response;
        }

        private HttpResponse buildSuccessfulLookupResponse(List<Object> caseIds) {
            HttpResponse response = responseWithStatus(200);
            if (mode == 'MALFORMED') {
                response.setBody('{not json');
                return response;
            }
            if (mode == 'EMPTY_BODY') {
                response.setBody('');
                return response;
            }
            if (mode == 'NULL_RESULTS') {
                response.setBody('{"results":null}');
                return response;
            }
            if (mode == 'INCOMPLETE') {
                response.setBody('{"results":[]}');
                return response;
            }

            List<Object> results = new List<Object>();
            for (Object caseId : caseIds) {
                results.add(buildLookupResult((String) caseId));
            }
            if (mode == 'DUPLICATE_RESULT') {
                results.add(results[0]);
            }
            response.setBody(JSON.serialize(new Map<String, Object>{ 'results' => results }));
            return response;
        }

        private Map<String, Object> buildLookupResult(String caseId) {
            Boolean found = mode == 'FOUND' || mode == 'MISSING_REQUIRED_FIELD';
            Map<String, Object> result = new Map<String, Object>{
                'caseId' => externalCaseId(caseId),
                'found' => found,
                'incident' => found ? buildIncident() : null
            };
            if (mode == 'MISSING_FOUND') {
                result.remove('found');
            } else if (mode == 'INCIDENT_WHEN_NOT_FOUND') {
                result.put('incident', buildIncident());
            }
            return result;
        }

        private String externalCaseId(String requestedCaseId) {
            if (mode == 'UNKNOWN_CASE_ID') {
                return externalCaseIdOverride;
            }
            return mode == 'MALFORMED_CASE_ID' ? 'not-an-id' : requestedCaseId;
        }

        private Map<String, Object> buildIncident() {
            Map<String, Object> incident = new Map<String, Object>{
                'id' => 'INC-2026-0001',
                'status' => 'Investigating',
                'severity' => 'High',
                'title' => 'External incident',
                'description' => 'Sanitized external description.'
            };
            if (mode == 'MISSING_REQUIRED_FIELD') {
                incident.remove('severity');
            }
            return incident;
        }
    }
}
