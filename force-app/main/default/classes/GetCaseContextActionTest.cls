@IsTest
private class GetCaseContextActionTest {
    @TestSetup
    static void createData() {
        Account account = new Account(Name = 'Senvora Test Account');
        insert account;

        Contact contact = new Contact(LastName = 'Test Contact', AccountId = account.Id);
        insert contact;

        insert new Case(
            AccountId = account.Id,
            ContactId = contact.Id,
            Subject = 'API integration failure',
            Status = 'Working',
            Priority = 'High',
            Description = 'Deterministic test description.'
        );
    }

    @IsTest
    static void lookupByCaseIdMapsSuccessfulResponse() {
        Case expected = testCase();

        List<GetCaseContextAction.Response> responses = invoke(new List<String>{ expected.Id });

        System.assertEquals(1, responses.size());
        GetCaseContextAction.Response response = responses[0];
        System.assertEquals(true, response.success);
        System.assertEquals(null, response.errorMessage);
        System.assertEquals(expected.Id, response.caseId);
        System.assertEquals(expected.CaseNumber, response.caseNumber);
        System.assertEquals('API integration failure', response.subject);
        System.assertEquals('Working', response.status);
        System.assertEquals('High', response.priority);
        System.assertEquals('Senvora Test Account', response.accountName);
        System.assertEquals('Test Contact', response.contactName);
        System.assertEquals('Deterministic test description.', response.description);
        System.assertEquals(
            'Case ' + expected.CaseNumber +
            ' | Status: Working | Priority: High | Subject: API integration failure',
            response.caseSummary
        );
    }

    @IsTest
    static void lookupByCaseNumberReturnsCaseWithAccountAndContact() {
        Case expected = testCase();

        GetCaseContextAction.Response response = invoke(
            new List<String>{ expected.CaseNumber }
        )[0];

        System.assertEquals(true, response.success);
        System.assertEquals(expected.Id, response.caseId);
        System.assertEquals('Senvora Test Account', response.accountName);
        System.assertEquals('Test Contact', response.contactName);
    }

    @IsTest
    static void rejectsIdBelongingToAnotherObjectWithoutFabricatedData() {
        Id accountId = [SELECT Id FROM Account LIMIT 1].Id;

        GetCaseContextAction.Response response = invoke(new List<String>{ accountId })[0];

        assertFailure(response, 'The provided Salesforce ID does not identify a Case.');
    }

    @IsTest
    static void nonexistentCaseNumberReturnsFailureWithoutFabricatedData() {
        GetCaseContextAction.Response response = invoke(new List<String>{ '99999999' })[0];

        assertFailure(response, 'No Case was found for the provided identifier.');
    }

    @IsTest
    static void blankInputReturnsFailureWithoutFabricatedData() {
        GetCaseContextAction.Response response = invoke(new List<String>{ '   ' })[0];

        assertFailure(response, 'A Case ID or Case Number is required.');
    }

    @IsTest
    static void handlesMultipleRequestsInInvocationAndPreservesOrder() {
        Case expected = testCase();
        List<GetCaseContextAction.Response> responses = invoke(
            new List<String>{ expected.Id, '99999999', expected.CaseNumber, null }
        );

        System.assertEquals(4, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertEquals(expected.Id, responses[0].caseId);
        System.assertEquals(false, responses[1].success);
        System.assertEquals(true, responses[2].success);
        System.assertEquals(expected.Id, responses[2].caseId);
        System.assertEquals(false, responses[3].success);
    }

    private static Case testCase() {
        return [
            SELECT Id, CaseNumber
            FROM Case
            WHERE Subject = 'API integration failure'
            LIMIT 1
        ];
    }

    private static List<GetCaseContextAction.Response> invoke(List<String> identifiers) {
        List<GetCaseContextAction.Request> requests = new List<GetCaseContextAction.Request>();
        for (String identifier : identifiers) {
            GetCaseContextAction.Request request = new GetCaseContextAction.Request();
            request.caseIdentifier = identifier;
            requests.add(request);
        }

        Test.startTest();
        List<GetCaseContextAction.Response> responses = GetCaseContextAction.getCaseContext(
            requests
        );
        Test.stopTest();
        return responses;
    }

    private static void assertFailure(
        GetCaseContextAction.Response response,
        String expectedMessage
    ) {
        System.assertEquals(false, response.success);
        System.assertEquals(expectedMessage, response.errorMessage);
        System.assertEquals(null, response.caseId);
        System.assertEquals(null, response.caseNumber);
        System.assertEquals(null, response.subject);
        System.assertEquals(null, response.status);
        System.assertEquals(null, response.priority);
        System.assertEquals(null, response.accountName);
        System.assertEquals(null, response.contactName);
        System.assertEquals(null, response.description);
        System.assertEquals(null, response.caseSummary);
    }
}
