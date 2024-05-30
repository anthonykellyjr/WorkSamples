@isTest
public with sharing class ScratchOrg_Test {


    @isTest
    private static void testScratchOrg() {
        Test.startTest();
        new ScratchOrg();
        Test.stopTest();
        ScratchOrg.checkStatus();
    }

    @isTest
    private static void testGetVfUrl() {
        String vfUrl;
        Organization oOrg = [SELECT InstanceName, IsSandbox, OrganizationType FROM Organization LIMIT 1];
        string vfOrigin = '';
        String myRegEx = '\\b.my.\\b'; // regex match to exactly get '.my.' string, with punctuation escaped
        string baseURL = ' ' + URL.getOrgDomainUrl().toExternalForm() + ' ';
        String instName = oOrg.InstanceName.toLowerCase();

        Test.startTest();
        vfUrl = ScratchOrg.getPhoneUrl();
        Test.stopTest();

        if (oOrg.OrganizationType == 'Developer Edition' && baseUrl.contains(instName)) {
            System.assert(vfUrl == baseURL.split('.' + oOrg.InstanceName.toLowercase() + '.')[0] + '--ds-denali.vf.force.com/apex/dialsourceCallCenterLightning');
        } else if (oOrg.OrganizationType == 'Developer Edition' && !baseUrl.contains(instName)) {
            System.assert(vfUrl == baseURL.split(myRegEx)[0] + '--ds-denali.vf.force.com/apex/dialsourceCallCenterLightning');
        } else {
            System.assert(vfUrl == baseURL.split(myRegEx)[0] + '--ds-packages.' + instName + '.visual.force.com/apex/dialsourceCallCenterLightning');
        }
    }


    public class AuthMock implements HttpCalloutMock {
        // Implement this interface method
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('https://ci.dialsource.com/generic-webhook-trigger/invoke?token=HpNzuQuKuet7RvBZ8T7P5758', req.getEndpoint());
            System.assertEquals('POST', req.getMethod());

            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new ScratchOrg.OrgInfo()));
            res.setStatusCode(200);
            return res;
        }
    }


    @isTest
    private static void testConquerAuth() {
        Test.setMock(HttpCalloutMock.class, new AuthMock());
        HttpResponse res = ScratchOrg.authToConquer();
    }

}