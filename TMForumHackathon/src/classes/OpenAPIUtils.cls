public class OpenAPIUtils {
    
    public static String serialize(List<sObject> objects, String service, sObject singleObject) {
        Map<String, Object> populatedFields = new Map<String, Object>();
        Map<String, Object> transformedObject = new Map<String, Object>();
        List<Map<String, Object>> finalResult = new List<Map<String, Object>>();
        
        Map<String, Open_API_Mapping__mdt> fieldMapping = new Map<String, Open_API_Mapping__mdt>();
        for (Open_API_Mapping__mdt entry : [SELECT Open_API_Field_Name__c, Salesforce_Field_Name__c, Service__c, isSFChildObject__c, isTMFChildObject__c, SFObjectType__c FROM Open_API_Mapping__mdt WHERE Service__c = :service]) {
            fieldMapping.put(entry.Salesforce_Field_Name__c, entry);
        }
        
        System.debug('translation map : ' + fieldMapping);
         
        if (objects != null) {
            for (sObject obj : objects) {
                populatedFields = obj.getPopulatedFieldsAsMap();
                transformedObject = customReplace(populatedFields, service, '', '', fieldMapping);
                finalResult.add(transformedObject);
            }
            return Json.serialize(finalResult);
        } else {
            populatedFields = singleObject.getPopulatedFieldsAsMap();
            return Json.serialize(customReplace(populatedFields, service, '', '', fieldMapping));
        }
    }
    
    private static Map<String, Object> customReplace(Map<String, Object> param, String service, String oldPath, String newPath, Map<String, Open_API_Mapping__mdt> fieldMapping) {
        
        System.debug('enter replaceCustom : ' + param + ' sfPathToObject: ' + oldPath + ' tmfPathToObject ' + newPath + '');
        
        Map<String, Object> transformedMap = new Map<String, Object>();

        for (String fieldName : param.keySet()) {
            Object fieldValue = param.get(fieldName);  //GenWatt
            String tmfFieldName = fieldName; //Name
            Boolean isChild = false;
            if (fieldMapping.containsKey(oldPath+fieldName)) {
                tmfFieldName = fieldMapping.get(oldPath+fieldName).Open_API_Field_Name__c; //orderItem.product.name
                tmfFieldName = tmfFieldName.replace(newPath, ''); //product.name
                isChild = fieldMapping.get(oldPath+fieldName).isTMFChildObject__c;
            }

            if (fieldValue instanceof Map<String, Object>) {
                System.debug('Child Field is map: ' + fieldValue);
                Map<String, Object> newSubMap = customReplace((Map<String, Object>) fieldValue, service, fieldName+'.', tmfFieldName+'.', fieldMapping);
                System.debug('Child Field after treatment: ' + newSubMap);
                if (!isChild) {
                    transformedMap.putAll(newSubMap);
                } else {
                    transformedMap.put(tmfFieldName, newSubMap);
                }
            } else if (fieldValue instanceof List<Object>) {
                List<Object> childList = new List<Object>();
                System.debug('Child Field is List: ' + fieldValue);
                for (Object subO : (List<Object>)fieldValue) {
                    if (subO instanceof Map<String, Object>) {
                        Map<String, Object> newSubMap = customReplace((Map<String, Object>) subO, service, fieldName+'.', tmfFieldName+'.', fieldMapping);
                        transformedMap.put(tmfFieldName, newSubMap);
                    } else if (subO instanceof sObject) {
                        sObject childObject = (sObject) subO;
                        Map<String, Object> newSubMap = customReplace((Map<String, Object>) childObject.getPopulatedFieldsAsMap(), service, fieldName+'.', tmfFieldName+'.', fieldMapping);
                        if (isChild) {
                            childList.add(newSubMap);
                        } else {
                            transformedMap.put(tmfFieldName, newSubMap);
                        }
                    } else {
                        if (fieldMapping.containsKey(oldPath+fieldName)) {
                            transformedMap.put(tmfFieldName, fieldValue);
                        }
                    }
                }
                System.debug('Child Field after List treatment: ' + childList);
                transformedMap.put(tmfFieldName,childList);
            } else if (fieldValue instanceof sObject) {
                System.debug('---------' + fieldName);
                sObject childObject = (sObject) fieldValue;
                Map<String, Object> newSubMap = customReplace((Map<String, Object>) childObject.getPopulatedFieldsAsMap(), service, oldPath+fieldName+'.', newPath+tmfFieldName+'.', fieldMapping);
                transformedMap.put(tmfFieldName, newSubMap);
            } else {
                if (fieldMapping.containsKey(oldPath+fieldName)) {
                    transformedMap.put(tmfFieldName, fieldValue);
                }
            }
        }


        for (String key : transformedMap.keySet()) {
            System.debug(key + ' : ' + transformedMap.get(key));
        }

        return transformedMap;
    }
    
    
    public static Map<sObject, Object> deserialize(String service, String body, System.Type objectType) {
        
        Map<String, Object> deserializedBody = (Map<String, Object>) Json.deserializeUntyped(body);
        Map<sObject, Object> newBody = new Map<sObject, Object>();
        
        newBody = replaceAllCustom(deserializedBody, '', service, '', objectType);
        
        System.debug('finalString : ' + newBody);
        
        return newBody;
    }
    
    /*
    private static List<sObject> replaceAllCustom(Map<String, Object> oldMap, String oldPath, String service, String newPath, System.Type objectType) {
        
        System.debug('enter replaceAll' + oldMap);
        List<sObject> listToReturn = new List<sObject>();
        Map<String, Open_API_Mapping__mdt> fieldMapping = new Map<String, Open_API_Mapping__mdt>();
        for (Open_API_Mapping__mdt entry : [SELECT Open_API_Field_Name__c, Salesforce_Field_Name__c, Service__c, isSFChildObject__c, SFObjectType__c FROM Open_API_Mapping__mdt WHERE Service__c = :service and Open_API_Field_Name__c like :oldPath+'%']) {
            fieldMapping.put(entry.Open_API_Field_Name__c, entry);
        }
        System.debug('translation map : ' + fieldMapping);
        Map<String, Object> newBody = new Map<String, Object>();
        for (String key : oldMap.keySet()) {
            Object o = oldMap.get(key);
            if (o instanceof Map<String, Object>) {
                String sfFieldName = fieldMapping.get(key).Salesforce_Field_Name__c;
                Boolean isChild = fieldMapping.get(key).isSFChildObject__c;
                String sObjectName = fieldMapping.get(key).SFObjectType__c;
                List<sObject> newSubMap = replaceAllCustom((Map<String, Object>) o, key+'.', service, sfFieldName+'.', sObjectName != null ? Type.forName(sObjectName) : objectType);
                if (!isChild) {
                    for (sObject childObject : newSubMap) {
                        if (childObject.getSObjectType().getDescribe().getName().equals(objectType.getName())) {
                            Map<String,Object> fieldToMerge = childObject.getPopulatedFieldsAsMap();
                            newBody.putAll(fieldToMerge);
                        } else {
                            listToReturn.add(childObject);
                        }
                    }
                } else {
                    listToReturn.addAll(newSubMap);
                }
                
            } else if (o instanceof List<Object>) {
                for (Object subO : (List<Object>)o) {
                    if (subO instanceof Map<String, Object>) {
                        String sfFieldName = fieldMapping.get(key).Salesforce_Field_Name__c;
                        Boolean isList = fieldMapping.get(key).isSFChildObject__c;
                        List<sObject> newSubMap = replaceAllCustom((Map<String, Object>) subO, key+'.', service, sfFieldName+'.', Type.forName(fieldMapping.get(key).SFObjectType__c));

                        listToReturn.addAll(newSubMap);
                    } else {
                        if (fieldMapping.containsKey(oldPath+key)) {
                            String s = (String)subO;
                            String sfFieldName = fieldMapping.get(oldPath+key).Salesforce_Field_Name__c;
                            
                            System.debug('replacing variables : oldkey : ' + key + ', SF field : ' + sfFieldName + ', newPath : ' + newPath);
                            
                            sfFieldName = sfFieldName.replace(newPath, '');
                            newBody.put(sfFieldName, s);
                        }
                    }
                }
            } else {
                if (fieldMapping.containsKey(oldPath+key)) {
                    String s = (String)oldMap.get(key);
                    String sfFieldName = fieldMapping.get(oldPath+key).Salesforce_Field_Name__c;
                    
                    System.debug('replacing variables : oldkey : ' + key + ', SF field : ' + sfFieldName + ', newPath : ' + newPath);
                    
                    sfFieldName = sfFieldName.replace(newPath, '');
                    newBody.put(sfFieldName, s);
                }
            }           
        }
        String newBodyString = Json.serialize(newBody);
        listToReturn.add((sobject)Json.deserialize(newBodyString, objectType));
        
        return listToReturn;
    }
*/




    private static Map<sObject, Object> replaceAllCustom(Map<String, Object> param, String oldPath, String service, String newPath, System.Type objectType) {
        
        System.debug('enter replaceAll' + param);
        Map<sObject, Object> mapToReturn = new Map<sObject, Object>();
        Map<sObject, Object> childMap = new Map<sObject, Object>();
        Map<String, Open_API_Mapping__mdt> fieldMapping = new Map<String, Open_API_Mapping__mdt>();
        for (Open_API_Mapping__mdt entry : [SELECT Open_API_Field_Name__c, Salesforce_Field_Name__c, Service__c, isSFChildObject__c, SFObjectType__c FROM Open_API_Mapping__mdt WHERE Service__c = :service and Open_API_Field_Name__c like :oldPath+'%']) {
            fieldMapping.put(entry.Open_API_Field_Name__c, entry);
        }
        System.debug('translation map : ' + fieldMapping);



        Map<String, Object> newBody = new Map<String, Object>();
        for (String key : param.keySet()) {

            Object o = param.get(key);

            if (o instanceof Map<String, Object>) {
                String sfFieldName = fieldMapping.get(key).Salesforce_Field_Name__c;
                Boolean isChild = fieldMapping.get(key).isSFChildObject__c;
                String sObjectName = fieldMapping.get(key).SFObjectType__c;
                Map<sObject, Object> newSubMap = replaceAllCustom((Map<String, Object>) o, key+'.', service, sfFieldName+'.', sObjectName != null ? Type.forName(sObjectName) : objectType);
                if (!isChild) {
                    for (sObject childObject : newSubMap.keySet()) {
                        if (childObject.getSObjectType().getDescribe().getName().equals(objectType.getName())) {
                            Map<String,Object> fieldToMerge = childObject.getPopulatedFieldsAsMap();
                            newBody.putAll(fieldToMerge);
                        } else {
                            childMap.put(childObject, newSubMap.get(childObject));
                        }
                    }
                } else {
                    childMap.putAll(newSubMap);
                }
                
            } 

            else if (o instanceof List<Object>) {
                for (Object subO : (List<Object>)o) {
                    if (subO instanceof Map<String, Object>) {
                        String sfFieldName = fieldMapping.get(key).Salesforce_Field_Name__c;
                        Boolean isList = fieldMapping.get(key).isSFChildObject__c;
                        Map<sObject, Object> newSubMap = replaceAllCustom((Map<String, Object>) subO, key+'.', service, sfFieldName+'.', Type.forName(fieldMapping.get(key).SFObjectType__c));
                        childMap.putAll(newSubMap);
                        System.debug('ChildMap populated with:' + newSubMap);
                        System.debug('result:' + childMap);
                    } else {
                        if (fieldMapping.containsKey(oldPath+key)) {
                            String s = (String)subO;
                            String sfFieldName = fieldMapping.get(oldPath+key).Salesforce_Field_Name__c;
                            
                            System.debug('replacing variables : oldkey : ' + key + ', SF field : ' + sfFieldName + ', newPath : ' + newPath);
                            
                            sfFieldName = sfFieldName.replace(newPath, '');
                            newBody.put(sfFieldName, s);
                        }
                    }
                }
            } 

            else {
                if (fieldMapping.containsKey(oldPath+key)) {
                    String s = (String)param.get(key);
                    String sfFieldName = fieldMapping.get(oldPath+key).Salesforce_Field_Name__c;
                    
                    System.debug('replacing variables : oldkey : ' + key + ', SF field : ' + sfFieldName + ', newPath : ' + newPath);
                    
                    sfFieldName = sfFieldName.replace(newPath, '');
                    newBody.put(sfFieldName, s);
                }
            }           
        }
        String newBodyString = Json.serialize(newBody);
        mapToReturn.put((sobject)Json.deserialize(newBodyString, objectType), childMap);
        System.debug('exiting with map: ' + mapToReturn);
        
        return mapToReturn;
    }
    
}