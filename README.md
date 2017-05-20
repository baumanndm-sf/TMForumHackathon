# Salesforce TMForum OpenAPI Implementation
This is a draft implementation of the __TMForum Open API__ specs implemented in __Salesforce__
https://www.tmforum.org/open-apis/

The implementation is based on a Rest API fraemwork that allows mapping from an external facing interface defined in Open API resources to internal Salesforce Objects and Fields.

The mapping is maintained in a Custom Meta Data Object (_Open_API_Mapping__mdt_).
Maintaining mappings in custom Meta-Data allows for flexible addition or changing of the exposed interface.
To see the initial mapping to the Open API spec, please check out this TMForum Confluence page:
https://projects.tmforum.org/wiki/display/API/Salesforce+Open+API+Implementation

You can also see samples of REST calls with the appropriate JSON using this Postman Collection:
https://www.getpostman.com/collections/d003c76b10896c31b7b9

# Installing the Package
__Requirements__: A Salesforce Org (any org version will work, this demo was implemented in a DE Org), Salesforce _Force.com Migration Tool_ (https://developer.salesforce.com/page/Force.com_Migration_Tool)

After pulling this package to your local git repo, you will need to deploy the meta-data changes to your Salesforce org using ant (force.com migration tool)
