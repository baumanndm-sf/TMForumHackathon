@RestResource(urlMapping='/openAPI/*')
global class RestOpenAPI {
	
	private static String serviceName;
	private static String recordId;


	@HttpGet
    global static void getService() {
    	webserviceInit();


    	Map<String, Open_API_Mapping__mdt> fieldMapping = new Map<String, Open_API_Mapping__mdt>();
    	Map<Integer, List<Open_API_Mapping__mdt>> mapFieldByLevel = new Map<Integer, List<Open_API_Mapping__mdt>>();
    	Set<String> childList = new Set<String>();
    	String idField = null;
    	String query = 'SELECT ';
        for (Open_API_Mapping__mdt entry : [SELECT Salesforce_Field_Name__c, Service__c, isSFChildObject__c, SFObjectType__c, isIdField__c, isSFParentObject__c FROM Open_API_Mapping__mdt WHERE Service__c = :serviceName]) {

            List<String> pathToField = entry.Salesforce_Field_Name__c.split('\\.');

            if (!mapFieldByLevel.containsKey(pathToField.size())) {
            	mapFieldByLevel.put(pathToField.size(), new List<Open_API_Mapping__mdt>());
            }
            mapFieldByLevel.get(pathToField.size()).add(entry);

            if (entry.isSFChildObject__c) {
            	childList.add(entry.Salesforce_Field_Name__c);
            }

            fieldMapping.put(entry.Salesforce_Field_Name__c, entry);

            if (entry.isIdField__c) {
            	idField = entry.Salesforce_Field_Name__c;
            }
        }

        query += buildSubQuery('', 0, fieldMapping, mapFieldByLevel);

        query += ' FROM ' + mapFieldByLevel.get(1).get(0).SFObjectType__c;
        
        if (recordId != null) {
        	query += ' WHERE ' + idField + ' = \'' + recordId + '\'';
        }

        System.debug(query);

        List<sObject> resultObjects = Database.query(query);

        //List<Order> orders = [SELECT ExternalId__c, ExpectedCompletionDate__c, Contract.Name, Priority__c, description, Type, Status, EffectiveDate, EndDate, ActivatedDate, Contract.EndDate FROM Order WHERE ExternalId__c = :recordId];

    	if (resultObjects.size() == 0) {
    		return;
    	}
		
		String result = '';

		if (recordId != null) {
			result = OpenAPIUtils.serialize(null, serviceName, resultObjects[0]);
		} else {
			result = OpenAPIUtils.serialize(resultObjects, serviceName, null);
		}
        

        //System.debug('Serialized Json: ' + result);

        RestContext.response.responseBody = blob.valueOf(result);
        RestContext.response.addHeader('Content-Type', 'application/json');
        
    }

    private static String buildSubQuery(String relatedFieldName, Integer currentLevel, Map<String, Open_API_Mapping__mdt> fieldMapping, Map<Integer, List<Open_API_Mapping__mdt>> mapFieldByLevel) {
    	String query = '';
		if (currentLevel != 0) {
    		query = '(SELECT ';
    	}

    	for (Open_API_Mapping__mdt childObject : mapFieldByLevel.get(currentLevel+1)) {
    		if (childObject.Salesforce_Field_Name__c.startsWith(relatedFieldName)) {
    			if (childObject.isSFChildObject__c) {
	        		query += buildSubQuery(childObject.Salesforce_Field_Name__c + '.', currentLevel+1, fieldMapping, mapFieldByLevel) + ', ';
	    		} else {
	    			if (childObject.isSFParentObject__c) {
	    				for (Open_API_Mapping__mdt parentObject : mapFieldByLevel.get(currentLevel+2)) {
	    					if (parentObject.Salesforce_Field_Name__c.startsWith(childObject.Salesforce_Field_Name__c)) {
	    						query += parentObject.Salesforce_Field_Name__c.remove(relatedFieldName) + ', ';
	    					}
	    				}
	    			} else {
	    				query += childObject.Salesforce_Field_Name__c.remove(relatedFieldName) + ', ';
	    			}
	    		}
    		}
    	}

    	query = query.removeEnd(', ');
    	if (currentLevel != 0) {
    		List<String> relatedFieldNameSplitted = relatedFieldName.split('\\.');
    		query += ' FROM ' + relatedFieldNameSplitted.get(relatedFieldNameSplitted.size()-1) + ')';
    	}

    	return query;
    }

	@HttpPost
    global static void postService() {
    	webserviceInit();
		String requestJson = RestContext.request.requestBody.toString();
        Map<sObject, Object> result = OpenAPIUtils.deserialize(serviceName, requestJson, Order.class);

        System.debug(result);
        
        insert new List<sObject>(result.keySet());

        System.debug(result);

        List<sObject> childToInsert = new List<sObject>();
        for (sObject obj : result.keySet()) {
        	System.debug('Id inserted object ' + obj.Id);
        	Map<sObject, Object> childObjects = (Map<sObject, Object>) result.get(obj);

        	System.debug(childObjects);

        	for (sObject childObject : childObjects.keySet()) {
        		childObject.put('ParentId', obj.Id);
        	}
        	childToInsert.addAll(childObjects.keySet());
        }

        insert childToInsert;
        

        RestContext.response.addHeader('Content-Type', 'application/json');
        
    }

    private static void webserviceInit() {
        String[] path = RestContext.request.requestURI.split('/');

    	serviceName = path[3];
        recordId = path.size()>4 ? path[4] : null;
    }
}