---
title: Azure Function triggered by Azure Alert
description: This is a post about how to trigger an Azure Function via an Azure Alert
date: 2021-03-21
tags:
- azure
---

![Use Case](/img/cptdfun-alert/overview.01.png "Use Case")

We like to restrict access to the Azure Function App [funalert-func] only to the Azure Container Instances [funalert-aci].

- We run an Azure Container Instances Service called "funalert-aci".
- Whenever the Azure Container Instances "funalert-aci" goes down and does restart successfully we like to tigger an Azure Alert.
- The Azure Alert does trigger an Azure Function App called "funalert-func".
- The Azure Function App "funalert-func" does something else which is not relavent here.

We will need to create the following three components inside Azure:

- Azure Container Instances
- ![Azure Container Instances](/img/cptdfun-alert/aci.png "Azure Container Instances")
- Azure Function App
- ![Azure Function App](/img/cptdfun-alert/afa.png "Azure Function App")
- Azure Alert
- ![Azure Alert](/img/cptdfun-alert/alert.png "Azure Alert")

## Azure Function App Authorization & Authentication

IMPORTANT: During the next steps you will need to register an App under your current Azure AD. Therefore your Azure account needs permissions to register AAD apps.
In case you do not have the needed permission, request the tenant/global admin to assign the required permission. Alternately, the tenant/global admin can assign the Application Developer role to an account to allow the registration of AAD App. [Learn more](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-users-assign-role-azure-portal).

To restrict access to our Azure Function App "funalert-func" we will use the concept of an Identity Provider, in our case we will make use of Azure Active Directory [AAD].

In a first step we need to create a representation of our Azure Function App "funalert-func" inside the AAD. This is done via a so called "Application Registration" inside the AAD.

Registering an application with Azure AD allows you to leverage the Microsoft identity platform’s secure sign-in and authorization features for use with that application.

This will allow us to control who should have access to our Azure Function App "funalert-func".

The "Application Registration" process will create the following two object in your Azure Active Directory tenant:

### An application object 
Application objects are stored within the Azure AD instance and define the application. The schema for an application object’s properties is defined by the Microsoft Graph application entity resource type. Application objects are a global representation of an application across all Azure AD tenancies. The application object functions as a template from which common and default properties are determined when Azure AD creates the corresponding service principal object. Application objects have a one-to-one relationship with the software application and a one-to-many relationship with corresponding service principal objects.

### service principal object
A user principal in Azure AD is an object that represents a user. A service principal is an Azure AD object that represents an application. The ServicePrincipal object allows you to specify the access policy and permissions for the application and the user of that application within your organization’s Azure AD tenant. A service principal is required for each tenancy where the application is used. A single-tenant application will only have one service principal, and a multitenant application will have a service principal for each tenancy where a user from that tenancy has consented to the application’s use. The Microsoft Graph service principal entity defines the schema used for a ServicePrincipal object’s properties. The service principal is the representation of the application in a specific Azure AD tenancy.

More Info Application and Service Principal Objects
You can learn more about application and service principal objects at https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals.

Service principals are analogous to an on-premises Active Directory service account in that both allow an application to have an identity and security context.

To create an "Application Registration" for our Azure Function App "funalert-func" we will use the Azure Function "Authorization and Authentication" setting:

- Go to the Azure Function App overview page.
- Select "Authentication / Authorization".
- Turn on "App Service Authentication".
- Make sure to select "Log in with Azure Active Directory" at "Action to take when request is not authenticated".
- Select "Azure Active Directory" from "Authentication Provider".

![Overview](/img/cptdfun-alert/afa.auth.01.png "Overview")

Inside the "Authentication Provider" dialog:

- Select "Express".
- Let the wizard create an "Azure AD App" or select an existing Azure AD App.
- Select "OK" to confirm your settings.

![Overview](/img/cptdfun-alert/afa.auth.02.png "Overview")

Back on the initial "Authentication / Authorizaton" Screen confirm your settings by clicking on "Save":

![Overview](/img/cptdfun-alert/afa.auth.03.png "Overview")

### "AAD App" & AAD

Next we need to verify if all the "Azure AD App" setting of the last step have been applied.

NOTE: In case you do not have the needed Azure AD Permission the Express Setup of the "Azure AD App" will only successed partly.
To verify this we need to find the corresponding "Azure AD App" inside the AAD:

- Go into the Azure Active Directy View and select "App registration".
- Here you will find your "AAD App", in our case it has been named "funalert-func-app". Click on it to call the detail view of our "AAD App" funalert-func-app:

![Overview](/img/cptdfun-alert/afa.auth.05.png "Overview")

Inside the Detail view of our "AAD App" we will also be able to see the "Object Id" of "funalert-func-app" which is unique inside the AAD Tenant:

![Overview](/img/cptdfun-alert/afa.auth.06.png "Overview")

Inside the Detail view of our "AAD App" we need to verify that an "Redirect URI" has been created under the "Authentication" Section:

![Overview](/img/cptdfun-alert/afa.auth.06.01.png "Overview")

Inside the Detail view of our "AAD App" we need to verify that a "Client Secret" has been created under the "Certificates & Secret" Section:

![Overview](/img/cptdfun-alert/afa.auth.06.02.png "Overview")

If any of both setting does not exist you did not have the needed permission to create the "AAD App" the right way. You will need to request the tenant/global admin to assign the required permission. Alternately, the tenant/global admin can assign the Application Developer role to an account to allow the registration of AAD App. [Learn more](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-users-assign-role-azure-portal).

### Support App Role based access

Inside "AAD App" "funalert-func-app" we can use the concept of an "App Role". "App Role" is something we can assign other "AAD Identities" like User, Group, Service Principal, Managed Identity, Enterprise Applications. In our case we like to assign this to our Azure Container Instance. But first we need to define the "App Role" inside our "AAD App":

- Select the "App Role" from the left hand menue bar inside the "ADD App" view of "funalert-func-app".
- Select "Create app role"

![Overview](/img/cptdfun-alert/afa.auth.07.png "Overview")

- Inside the new Dialog define a name for your App Role ("funalert-func-sp-approle").
- Select which type of AAD member should be able to get assigned this role (AAD Groups, Applications (= ADD App, Service Principal, Managed Identitys)).
- Value, in our case it will not be relevant, so you are free to add whatever you like.
- Give it a nice description.
- Check the box to enable the "App Role".
- Confirm by clicking the "apply" button.

![Overview](/img/cptdfun-alert/afa.auth.08.png "Overview")

We will need the "Id" or our new created "App Role":

- Select "Manifest" from the left hand menue bar.
- Find the "id" of our new "App Role" (Id ="ce2") inside the JSON file.

![Overview](/img/cptdfun-alert/afa.auth.09.png "Overview")

https://docs.microsoft.com/en-us/azure/active-directory/develop/scenario-protected-web-api-app-registration#if-your-web-api-is-called-by-a-daemon-app

### AAD Enterprise Application

"AAD App" (aka App Registration) does not represent an Service Principal inside an AAD. But to be able to define Access rights we will need to represent our Azure Function App as an Service Principal inside our AAD.
Therefore, during the creation of the "AAD App" "funalert-func-app", AAD created an "Service Principal" of the type "Enterprise Application" with a seperate "Object Id" in parallel. In the next step we need to retrieve the corresponding Object Id of the "Enterprise Application" Service Principal:

- Select "Enterprise Application" from the AAD Menue:

![Overview](/img/cptdfun-alert/afa.auth.10.png "Overview")

- Make sure you select "All Application" in the "Application Type" search filter.
- Press the "Apply" button.
- Type the name of the "AAD App" into the text field. In our case "funalert-func-app".
- Copy the Object Id of the "Enterprise Application" ("51c").

IMPORTANT
: The "Enterprise Applciation" Object Id ("51c") is different to the "AAD App" Object Id ("f38") even if both use the same name "funalert-func-app".

![Overview](/img/cptdfun-alert/afa.auth.11.png "Overview")

Status of our setup:
- "App Role" "funalert-func-sp-approle" (Id "ce2"),
- "Enterprise Application" "funalert-func-app" (Object Id "51c")

![Overview](/img/cptdfun-alert/afa.auth.12.png "Overview")


## Azure Container Instance Managed Identity

The Azure Container Instances [ACI] "funalert-aci" needs also to become visible to our AAD via an "Managed Identity".

- Select "Identity" from inside the ACI "funalert-aci" view.
- Select "On" from Status.
- Click "Save", afterwards you will see the Object Id ("4f9.."). We will need this later on.

![Overview](/img/cptdfun-alert/aci.auth.01.png "Overview")

Out of all the objects we generated so far this are the once which will become relevant for the next step:

- Azure Container "Managed Id" (Object Id = "4f9..")
- AAD App "App Role" (Id = "ce2..")
- AAD Enterprise Application (Object Id = "51c")

![Overview](/img/cptdfun-alert/overview.02.png "Overview")

## Assignment

We need to assign the "App Role" ("ce2..") to our ACI "Managed Id" ("4f9.."). Use the powershell cmdlt "New-AzureADServiceAppRoleAssignment" which is part of the "AzureAD" module.

NOTE
: Follow this instruction to install AzureAD module: https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-5.1.0

Powershell command:

~~~ text
New-AzureADServiceAppRoleAssignment -ObjectId <ACI Managed Id> -PrincipalId <ACI Managed Id> -Id <App Role> -ResourceId <Enterprise Application>
~~~

Adding corresponding "Object Id`s" and "Id":

~~~ text
New-AzureADServiceAppRoleAssignment -ObjectId 4f9.. -PrincipalId 4f9.. -Id ce2.. -ResourceId 51c..
~~~

The output will be a new AAD "Assignment" Object with a new Object Id ("gvS"):

~~~ text
ObjectId  ResourceDisplayName  PrincipalDisplayName
--------  -------------------  --------------------
gvST..    funalert-func-app    funalert-aci
~~~

In case we like to verify that our Azure Container Instance Managed Id has been assigned to the AAD App "App Role" we can verify this inside the AAD as follow:

- Select "All Application" in the "Application Type" search filter.
- Press "Apply" button.
- Type the name of your Azure Container Instance "Managed Id" into the text field. The Name is equal to the name of your ACI, in our case "funalert-aci".
- Verify the "Object Id" does match with yours ("4f9..").
- Click on the entry.

![Overview](/img/cptdfun-alert/overview.03.png "Overview")

- Select "Permission".
- Click on the "Permission" entry "funalert-func-app".
- "Service Principle" does refer to the "Enterprise Application" "Object Id" ("51c").
- "Perminsion display name" does refer to the "App Role" "funalert-func-sp-approle" ("ce2..").

![Overview](/img/cptdfun-alert/overview.04.png "Overview")

## Setup Alert

I will not go into detail how to setup an Azure alert but I will highlight the two important settings:

- Alert Signal logic
- Alert Action

### Alert Signal logic

In our case we would like to receive an alert whenever the Azure Container Instance has been restarted successfully.

- Selected Status "Succeeded".
- Click "Done".

![Overview](/img/cptdfun-alert/alert.setup.04.png "Overview")

### Alert Action Setup

Use "Action Type" "Secure Webhook", it does support AAD:

- Select the Azure Function App "AAD App" (Object Id = "f38..").
- Enter the Azure Function App URL you like to call. In our case we use ´https://funalert-func.azurewebsites.net/api/httptrigger?name=huhu´.

![Overview](/img/cptdfun-alert/alert.setup.08.png "Overview")

IMPORTANT
: Query Parameter "name=huhu" has been added to indentify the Webhook Request from Azure Alert.

## Test (Showtime)

### Test on my local Machine

We expect to receive an HTTP Response Code 200 OK:

~~~ text
$ curl "http://localhost:7071/api/HttpTrigger?name=christian" -v
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 7071 (#0)
> GET /api/HttpTrigger?name=christian HTTP/1.1
> Host: localhost:7071
> User-Agent: curl/7.58.0
> Accept: */*
>
< HTTP/1.1 200 OK
< Date: Fri, 19 Mar 2021 19:02:15 GMT
< Content-Type: text/plain; charset=utf-8
< Server: Kestrel
< Transfer-Encoding: chunked
< Request-Context: appId=
<
{
    "method": "GET",
    "url": "http://localhost:7071/api/HttpTrigger?name=christian",
    "originalUrl": "http://localhost:7071/api/HttpTrigger?name=christian",
    "headers": {
        "accept": "*/*",
        "host": "localhost:7071",
        "user-agent": "curl/7.58.0"
    },
    "query": {
        "name": "christian"
    },
    "params": {}
~~~

Corresponding local Azure Function App logs:

~~~ text
2021-03-19T19:01:52.292Z] Worker process started and initialized.
[2021-03-19T19:02:16.081Z] Executing 'Functions.HttpTrigger' (Reason='This function was programmatically called via the host APIs.', Id=fc52a922)
[2021-03-19T19:02:16.129Z] {
[2021-03-19T19:02:16.133Z]     "method": "GET",
[2021-03-19T19:02:16.135Z]     "url": "http://localhost:7071/api/HttpTrigger?name=christian",
[2021-03-19T19:02:16.137Z] JavaScript HTTP trigger function processed a request.
[2021-03-19T19:02:16.138Z]     "originalUrl": "http://localhost:7071/api/HttpTrigger?name=christian",
[2021-03-19T19:02:16.143Z]     "headers": {
[2021-03-19T19:02:16.144Z]         "accept": "*/*",
[2021-03-19T19:02:16.146Z]         "host": "localhost:7071",
[2021-03-19T19:02:16.148Z]         "user-agent": "curl/7.58.0"
[2021-03-19T19:02:16.150Z]     },
[2021-03-19T19:02:16.152Z]     "query": {
[2021-03-19T19:02:16.154Z]         "name": "christian"
[2021-03-19T19:02:16.156Z]     },
[2021-03-19T19:02:16.158Z]     "params": {}
[2021-03-19T19:02:16.160Z] }
[2021-03-19T19:02:16.213Z] Executed 'Functions.HttpTrigger' (Succeeded, Id=fc52a922-, Duration=165ms)
~~~

### Request direct against Azure Function App

We expect to receive an 401 Unauthorized response code:

~~~ text
$ curl "https://funalert-func.azurewebsites.net/api/httptrigger" -v
> GET /api/httptrigger HTTP/1.1
> Host: funalert-func.azurewebsites.net
> User-Agent: curl/7.58.0
> Accept: */*
>
< HTTP/1.1 401 Unauthorized
< Content-Length: 58
< Content-Type: text/html
< WWW-Authenticate: Bearer realm="funalert-func.azurewebsites.net" authorization_uri="https://login.windows.net/my-sts/oauth2/authorize" resource_id="bab9d3b0-16ae-450b-aa4a-f2fdba022a56"
< Date: Fri, 19 Mar 2021 14:49:35 GMT
<
~~~

### Restart Azure Container instance to trigger alert

~~~ text
PS C:\> func azure functionapp publish funalert-func
~~~

Retrieve logs via Azure ApplicationInsight which has been setup togther with the Azure Function App.

The Kusto query does look for the Query Parameter "name=huhu":

~~~ text
traces
| where timestamp > ago(30m) and message == "\"url\": \"https://funalert-func.azurewebsites.net/api/httptrigger?name=huhu\","
~~~

![Overview](/img/cptdfun-alert/test.01.png "Overview")

You can also make use of the Azure CLI to get the logs:

~~~ text
az monitor app-insights query --apps funalert-func -g funalert-rg --analytics-query 'traces | where timestamp > ago(10m) and message has \"huhu\"'
~~~

### Get Logs via the Azure Function CLI

Before you can retrive logs you will need to make sure that the logging is setup with ""fileLoggingMode": "always" inside the host.json.

NOTE: This should be done before you restart the ACI.

~~~ text
{
  "version": "2.0",
  "logging": {
    "fileLoggingMode": "always",
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request"
      }
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[1.*, 2.0.0)"
  }
}

~~~

Afterwards you can start to connect to the logstream as follow:

~~~ text
PS :\> func azure functionapp logstream funalert-func
~~~

Output should look as follow:

~~~ text
PS :\> func azure functionapp logstream funalert-func
2021-03-26T12:07:01.491 [Information] "caller": "ga@myedge.org",
2021-03-26T12:07:01.492 [Information] "correlationId": "c9547a1c-846d-4cd9-b5bc-4009dfe9c4f1",
2021-03-26T12:07:01.492 [Information] "description": "",
2021-03-26T12:07:01.492 [Information] "eventSource": "Administrative",
2021-03-26T12:07:01.492 [Information] "eventTimestamp": "2021-03-26T12:05:22.0029288+00:00",
2021-03-26T12:07:01.492 [Information] "httpRequest": "{\"clientRequestId\":\"88996428-8e2b-11eb-bca6-9de033d37913\",\"clientIpAddress\":\"93.230.221.88\",\"method\":\"POST\"}",
2021-03-26T12:07:01.492 [Information] "eventDataId": "58281b51-cc22-4f16-b93d-3b6a3b4863c7",
2021-03-26T12:07:01.492 [Information] "level": "Informational",
2021-03-26T12:07:01.492 [Information] "operationName": "Microsoft.ContainerInstance/containerGroups/restart/action",
2021-03-26T12:07:01.492 [Information] "operationId": "c9547a1c-846d-4cd9-b5bc-4009dfe9c4f1",
2021-03-26T12:07:01.492 [Information] "properties": {
2021-03-26T12:07:01.492 [Information] "eventCategory": "Administrative",
2021-03-26T12:07:01.492 [Information] "entity": "/subscriptions/my-subscription/resourceGroups/funalert-rg/providers/Microsoft.ContainerInstance/containerGroups/funalert-aci",
2021-03-26T12:07:01.492 [Information] "message": "Microsoft.ContainerInstance/containerGroups/restart/action",
2021-03-26T12:07:01.493 [Information] "hierarchy": "my-sts/my-subscription"
2021-03-26T12:07:01.493 [Information] },
2021-03-26T12:07:01.493 [Information] "resourceId": "/subscriptions/my-subscription/resourceGroups/funalert-rg/providers/Microsoft.ContainerInstance/containerGroups/funalert-aci",
2021-03-26T12:07:01.493 [Information] "resourceGroupName": "funalert-rg",
2021-03-26T12:07:01.493 [Information] "resourceProviderName": "Microsoft.ContainerInstance",
2021-03-26T12:07:01.493 [Information] "status": "Started",
2021-03-26T12:07:01.493 [Information] "subStatus": "",
2021-03-26T12:07:01.493 [Information] "subscriptionId": "my-subscription",
2021-03-26T12:07:01.493 [Information] "submissionTimestamp": "2021-03-26T12:06:50.1473765+00:00",
2021-03-26T12:07:01.493 [Information] "resourceType": "Microsoft.ContainerInstance/containerGroups"
2021-03-26T12:07:01.493 [Information] }
2021-03-26T12:07:01.493 [Information] },
2021-03-26T12:07:01.493 [Information] "properties": {}
2021-03-26T12:07:01.494 [Information] }
2021-03-26T12:07:01.494 [Information] },
~~~

## Thanks

This Blog is based on another one written by John Friesen:

https://dev.to/superjohn140/azure-alerts-secure-webhook-azure-functions-with-authentication-364

## Usefull links

Automation with powershell:

https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups#secure-webhook-powershell-script