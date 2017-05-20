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
            System.debug('Get pathToField ' + pathToField);
            
            if (!mapFieldByLevel.containsKey(pathToField.size())) {
                mapFieldByLevel.put(pathToField.size(), new List<Open_API_Mapping__mdt>());
            }
            
            mapFieldByLevel.get(pathToField.size()).add(entry);
            system.debug('Get mapFieldByLevel ' + entry.Salesforce_Field_Name__c);
            
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

        System.debug('Get Query ' + query);

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
            
            system.debug('Subquery In loop ' + childObject.Salesforce_Field_Name__c);
            
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
        system.debug('SubQueryBuilder ' + query);
        return query;
    }

    @HttpPost
    global static void postService() {
        webserviceInit();

        genericPatchPost(false);

        RestContext.response.addHeader('Content-Type', 'application/json');
        
    }

    @HttpPatch
    global static void patchService() {
        webserviceInit();
        
        genericPatchPost(true);

        RestContext.response.addHeader('Content-Type', 'application/json');
    }

    private static void genericPatchPost(Boolean isUpdate) {
        String requestJson = RestContext.request.requestBody.toString();

        Map<String, String> mapObjectParentField = new Map<String, String>();
        String mainType = '';

        for (Open_API_Mapping__mdt entry : [SELECT Salesforce_Field_Name__c, Service__c, isSFChildObject__c, SFObjectType__c, isIdField__c, isSFParentObject__c, ParentField__c FROM Open_API_Mapping__mdt WHERE Service__c = :serviceName]) {
            if (entry.isSFChildObject__c) {
                mapObjectParentField.put(entry.SFObjectType__c, entry.ParentField__c);
            } else if (entry.isIdField__c) {
                mainType = entry.SFObjectType__c;
            }
        }


        Map<sObject, Object> result = OpenAPIUtils.deserialize(serviceName, requestJson, Type.forName(mainType));

        List<sObject> objectsToInsert = new List<sObject>();
        List<Object> childObjectsGeneric = new List<Object>();
        for (sObject parentObject : result.keySet()) {
            objectsToInsert.add(parentObject);
            childObjectsGeneric.add(result.get(parentObject));
        }
        
        if (isUpdate) {
            update objectsToInsert;
        } else {
            insert objectsToInsert;
        }
        genericInsertChild(objectsToInsert, childObjectsGeneric, mapObjectParentField, isUpdate);
    }

    private static void genericInsertChild(List<sObject> parentInserted, List<Object> objectsToInsertGeneric, Map<String, String> mapObjectParentField, Boolean isUpdate) {
        List<sObject> objectsToInsert = new List<sObject>();
        List<Object> childObjectsGeneric = new List<Object>();
        Iterator<Object> it = objectsToInsertGeneric.iterator();
        for (sObject parent : parentInserted) {
            Map<sObject, Object> childObjects = (Map<sObject, Object>) it.next();
            if (childObjects != null && !childObjects.keySet().isEmpty()) {
                for (sObject childObject : childObjects.keySet()) {
                    objectsToInsert.add(childObject);
                    String parentFieldName = mapObjectParentField.get(childObject.getSObjectType().getDescribe().getName());
                    childObject.put(parentFieldName, parent.Id); // To replace with query and generic population of parent field
                    childObjectsGeneric.add(childObjects.get(childObject));
                }
            }

        }

        if (objectsToInsert.size() > 0) {
            if (isUpdate) {
                update objectsToInsert;
            } else {
                insert objectsToInsert;
            }
            genericInsertChild(objectsToInsert, childObjectsGeneric, mapObjectParentField, isUpdate);
        } else {
            return;
        }
    }

    private static void webserviceInit() {
        String[] path = RestContext.request.requestURI.split('/');
        
        System.debug('RestContext.request.requestURI='+RestContext.request.requestURI);// + ';' + 'path[3]='+path[3]);
        System.debug('RestContext.request.httpMethod='+RestContext.request.httpMethod);
        System.debug('RestContext.request.requestBody='+ (RestContext.request.requestBody== null ? '': RestContext.request.requestBody.toString()));

        serviceName = path[2];
        recordId = path.size()>3 ? path[3] : null;
    }
}