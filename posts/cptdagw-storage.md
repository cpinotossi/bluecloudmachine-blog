---
title: Azure Application Gateway and Azure Storages
description: How to shared over multiple azure storage accounts.
date: 2021-05-15
tags:
- azure
---
{% Image "Overview of deployment", "/img/cptdagw-storage/azss.002.png"%}

[Overview of deployment](/img/cptdagw-storage/azss.002.png)

## Azure Storage Limits:
---

Azure Storage Account have limits on Bandwidth and IOPS:

|Resource|Limit|Type|
|---|----|---|
|Number of storage accounts per region per subscription, including standard, and premium storage accounts.|250|-|
|Maximum storage account capacity|5 PiB|soft|
|Maximum number of blob containers, blobs, file shares, tables, queues, entities, or messages per storage account|No limit|-|
|Maximum request rate per storage account|20,000 requests per second|soft|
|Maximum ingress per storage account (US, Europe regions)|10 Gbps|-|
|Maximum ingress per storage account (regions other than US and Europe)|5 Gbps if RA-GRS/GRS is enabled, 10 Gbps for LRS/ZRS2|-|
|Maximum egress for general-purpose v2 and Blob storage accounts (all regions)|50 Gbps|-|
|Maximum number of virtual network rules per storage account|200|-|
|Maximum number of IP address rules per storage account|200|-|
|Target request rate for a single blob|Up to 500 requests per second|hard|
|Target throughput for a single page blob|Up to 60 MiB per second|-|
|Target throughput for a single block blob|Up to storage account ingress/egress limits|-|

Source:
- [Storage limits](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#storage-limits)
- [Azure Blob storage limits](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-blob-storage-limits)

Storage limits:
When certain metrics like Maximum request rate per storage account is exceeded the following throttling behaviour takes place;

|Error code|HTTP status code|User message|
|--|--|--|
|ServerBusy|Service Unavailable (503)|The server is currently unable to receive requests. Please retry your request.|
|ServerBusy|Service Unavailable (503)|Ingress is over the account limit.|
|ServerBusy|Service Unavailable (503)|Egress is over the account limit.|
|ServerBusy|Service Unavailable (503)|Operations per second is over the account limit.|

source: [Storage Rest API Error Codes](https://docs.microsoft.com/en-us/rest/api/storageservices/common-rest-api-error-codes)

### Summary
---

- We can serve 500 req/sec in paralle for a single Blob.
- We can serve 20000 req/sec via a single Storage Account.
- We can serve a max of 60 Mbps for a single Blob Storage.
- We can serve 10000 Mbps via a single Storage Account.

## Serve a single blob with +500 req/sec
---

In case we like to serve a single blob with +500 req/sec we will need to use multiple storage accounts.

To loadbalance between the Storage Accounts we are going to use Application Gateway:
![Overview](/img/cptdagw-storage/azss.001.png)

## Create Azure Key Vault
---

Request will be served via https.
The corresponding server certificate will be created and stored inside Azure Key Vault.

Update parameter file [parameters.json](./deploy.parameters.json).

- prefix: Use a unique string. The prefix will be used in front of each azure resources but also become part of the blob storage account FQDN.
- regionPairA: Location, Azure Region (e.g. westeurope}.
- userAdminObjectId: GUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) of the user/service principal which will deploy the ARM templates.

Create Azure Key Vault with Azure CLI:

~~~ text
$ az deployment group create --mode Incremental -n {deployment name} -g {resource group name} --template-file ./arm/deploy.keyvault.json -p @deploy.keyvault.parameters.json
~~~

[![Launch Cloud Shell](https://shell.azure.com/images/launchcloudshell.png "Launch Cloud Shell")](https://shell.azure.com/bash)

Via Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fcpinotossi%2Faz-storagesharding%2Fmain%2Farm%2Fdeploy.keyvault.json)

## Create Certificate inside Azure Key Vault
---

Update "subject" value of azure certificate policy [certificate.policy.json](./certificate.policy.json) with your certificate CN (e.g download.sample.com).

~~~ text
"subject": "CN={REPLACE}",
~~~

Create Certificate via Azure CLI:

~~~ text
$ az keyvault certificate create --vault-name {prefix}-01-kv -n {your-suffix}-01-certificate-01-kv --policy @certificate.policy.json
~~~

[![Launch Cloud Shell](https://azure.microsoft.com/svghandler/cloud-shell/?width=50 "Launch Cloud Shell")](https://shell.azure.com/bash)

IMPORTANT: Replace value {your-suffix} of parameter "-n".

## Deploy Application Gateway and rest
---

Update parameter file [parameters.json](./deploy.parameters.json).

- prefix: Use the same unique string as used during the Azure Key Vault deployment.
- regionPairA: Use the same Location as used during the Azure Key Vault deployment.
- regionPairB: Look up the corresponding pair Azure Region [here](https://docs.microsoft.com/en-us/azure/best-practices-availability-paired-regions#azure-regional-pairs).
- myip: IP which will be whitelisted on the Azure Storage Accounts.
- certificationCN: FQDN, same as used during the subject CN inside the certificate.

via Azure CLI

~~~ text
$ az deployment group create --mode Incremental -n {deployment name} -g {resource group name} --template-file ./arm/deploy.json -p @deploy.parameters.json
~~~

[![Launch Cloud Shell](https://azure.microsoft.com/svghandler/cloud-shell/?width=50 "Launch Cloud Shell")](https://shell.azure.com/bash)

via Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fcpinotossi%2Faz-storagesharding%2Fmain%2Farm%2Fdeploy.json)


## China Deployment
---

The following points need to be considered in case of China:

- Application Gateway V2 is only supported in certain China Regions (we used "China North 2").
- Availability Zones for Application Gateway are not supported.
- Availability Zones for Public IP are not supported.
- Routing Preference for Storage Account are not supported.
- Make sure to choose the right Storage Domain for China ("blob.core.chinacloudapi.cn").

## DNS Entry
---

In case you like to test via your Domain directly you will need to add an A Record inside the corresponding DNS Zone and use the Application Gateway Public IP.

## Number of Storage Accounts
---

The ARM Template will deploy two Storage Account.
The Application Gateway will load balance incoming request between both Storage Account.
To make this work we will need to store the same Data under the same Container on both Storage Accounts.

### Azure Storage Access
---

Azure Storage Account are setup to only allow the Application Gateway and myIP to access the corresponding Data directly via the following Azure Storage Account setup:

~~~ text
"networkAcls": {
    "resourceAccessRules": [],
    "bypass": "AzureServices",
    "virtualNetworkRules": [
        {
            "id": "[variables('subnetRef')]",
            "action": "Allow",
            "state": "Succeeded"
        }
    ],
    "ipRules": [
        {
            "value": "[parameters('myip')]",
            "action": "Allow"
        }
    ],
    "defaultAction": "Deny"
},
~~~

## Azure Storage Internet Routing
---

You can setup Azure Storage Account with [Internet Routing Preference](https://docs.microsoft.com/en-us/azure/storage/common/network-routing-preference). This will reduce the Bandwidth cost.

~~~ text
"routingPreference": {
    "routingChoice": "InternetRouting",
    "publishMicrosoftEndpoints": false,
    "publishInternetEndpoints": false
},
~~~

### Cooled access tier for Blobs
--

We did setup the Azure Blob Storage with Access Tier "Cool".
Our expection is that we will only use "read" operations and therefore "Cool" is the most cost efficient option.

~~~ text
    },
    "accessTier": "Cool"
}
~~~

## Test URL
---

IMPORTANT: You will need to upload a file with the name "test.txt" under the container "test" of each Storage Account first.

Access the file directly via the blob storage
NOTE: Works only if you whitelisted your IP.

~~~ text
curl -v -k curl -v -k https://<STORAGE-ACCOUNT-NAME>.blob.core.windows.net/test/test.txt
~~~

Access via the Application Gateway

~~~ text
curl -v -k curl -v -k https://<YOUR-DOMAIN>/test
~~~

## Clean Up
---

~~~ text
PS C:\sbapp> az deployment group create --resource-group {resource group name} --mode complete --name delete --template-file ./arm/empty.json
~~~

## Usefull Links
---

- [Ms Doc: Use Azure Storage blob inventory to manage blob data](https://docs.microsoft.com/en-us/azure/storage/blobs/blob-inventory)
- [MS Doc: How AGW terminates TLS](https://docs.microsoft.com/en-us/azure/application-gateway/key-vault-certs)
