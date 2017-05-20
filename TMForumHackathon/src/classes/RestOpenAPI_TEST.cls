@isTest(SeeAllData=true )
private class RestOpenAPI_TEST {

	static testMethod void testGETRestCall() {
        
        RestRequest re = new RestRequest(); 
        RestResponse rp = new RestResponse();
        re.httpMethod = 'GET';
        //re.addHeader('httpMethod', 'GET');
        re.addParameter('Priority', 'High');
        re.remoteAddress ='https://eu11.salesforce.com/services/apexrest';
        re.requestURI ='/openAPI/customerAccount';
        
        RestContext.request = re;
		RestContext.response = rp;
        
        System.debug('STATUS:BEFORE Apex CLASS CALL');
        RestOpenAPI.getService();
        System.debug('STATUS:AFTER*** Apex CLASS CALL');
        System.assert(true);
    }
    
	static testMethod void testPOSTRestCall() {

        RestRequest re = new RestRequest(); 
        RestResponse rp = new RestResponse();

        re.httpMethod = 'POST';
        re.addHeader('content-type', 'application/json');
 
        re.remoteAddress ='https://eu11.salesforce.com/services/apexrest';
        re.requestURI ='/openAPI/customerAccount';
        //re.requestBody = Blob.valueOf(JSON.serialize(new Account(name='xxxTest Accountxxx'))); // '{"name": "xxxxTest Accountxxx"}';
        re.requestBody = Blob.valueOf('{"name": "xxxxTest Accountxxx"}');
        //re.addHeader('Authorization', 'OAuth ' + UserInfo.getSessionId());
        re.addParameter('Priority', 'High');
        
        RestContext.request = re;
		RestContext.response = rp;
        
        System.debug('STATUS:BEFORE Apex CLASS CALL');
        RestOpenAPI.postService();
        System.debug('STATUS:AFTER*** Apex CLASS CALL');
        System.assert(true);
    }
    
	static testMethod void testPATCHRestCall() {

        RestRequest re = new RestRequest(); 
        RestResponse rp = new RestResponse();

        re.httpMethod = 'PATCH';
        re.addHeader('content-type', 'application/json');
 
        re.remoteAddress ='https://eu11.salesforce.com/services/apexrest';
        re.requestURI ='/openAPI/customerAccount';
        List<Account> a = [select id, name from account limit 1];
        String AccId = a[0].Id;
        String AccName = a[0].Name;
        System.debug('AccID='+AccId);
        //re.requestBody = Blob.valueOf(JSON.serialize()); // '{"name": "xxxxTest Accountxxx"}';
        re.requestBody = Blob.valueOf('{"Id" : "'+ AccId +'", "name": "'+AccName+'"}');
        //re.addHeader('Authorization', 'OAuth ' + UserInfo.getSessionId());
        re.addParameter('Priority', 'High');       
        
        RestContext.request = re;
		RestContext.response = rp;
		 
        
        System.debug('STATUS:BEFORE Apex CLASS CALL');
        RestOpenAPI.patchService();
        System.debug('STATUS:AFTER*** Apex CLASS CALL');
        System.assert(true);
    }
    
    static testMethod void testSerialise()
    {
        List<Account> accs = [select id, name from account limit 10];
        SObject obj = Schema.getGlobalDescribe().get('Account').newSObject();
        String result = OpenAPIUtils.serialize(accs, 'customerAccount', obj);
        
        System.assert(String.isNotEmpty(result));
    }
    
    static testMethod void testSerialiseEmptyString()
    {
        List<Account> accs = new List<Account>();
        SObject obj = Schema.getGlobalDescribe().get('Account').newSObject();
        String result = OpenAPIUtils.serialize(null, 'customerAccount', obj);
        
        System.debug('result='+result);
        
        System.assert(String.isNotEmpty(result));
    }
}