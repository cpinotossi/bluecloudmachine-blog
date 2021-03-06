---
title: Azure Application Gateway, WAF and Certificate
description: How to use self signed certificates with Azure Application Gateway and WAF.
date: 2021-11-06
tags:
- azure
---

{% Image "Azure Application Gateway","/img/cptdagw-waf/picture1.png" %}

[Image: Azure Application Gateway](/img/cptdagw-waf/picture1.png)


In this entry we will create:

- Azure Application Gateway [agw]
- self signed server certificate for frontend and backend of agw (will use the same cert for both).
- waf custom rule (scope httplistener)
- diagnostic settings for agw

## Create resource group
---

~~~ text
az group create -n cptdagw -l eastus
~~~

## Modify Parameters File
---

Retrieve your object ID and update value "MY-OBJECT-ID" of the "myObjectId" property inside parameters.json accordently.
NOTE: Replace YOUR-USR-NAME with your account name in the following command

~~~ text
az ad user list --query '[?displayName==`YOUR-USER-NAME`].objectId'
~~~

NOTE:
Your object ID is needed to assign you azure storage blob storage contributor role.

## Create certificates 
---

IMPORTANT: This step is option and if done you will need to update certain files. Instead you can just use the certificates already created under the folder openssl.

Certificates will be created with the help of openssl and a corresponding config file (certificate.cnf).

~~~ text
./create.certificates.sh
~~~

NOTE: The server certificate is referenced inside the bicep/agw.bicep file.

~~~ text
var servercertificatefrontend = loadFileAsBase64('../openssl/cptdagw.org.svr.pfx')
var cacertificatebackend = loadFileAsBase64('../openssl/cptdagw.org.ca.crt')
~~~

## Create the vnet
---

~~~ text
az deployment group create -n create-vnet -g cptdagw --template-file bicep/vnet.bicep
~~~

## Create Storage Account with Blob
---

~~~ text
az deployment group create -n create-blob -g cptdagw --template-file bicep/sab.bicep
~~~

## Upload test.txt file
---

Following lines do not work:

~~~ text
keyctl session workaroundSession
azcopy login --tenant-id myedge.org
echo 'hello world' | azcopy cp https://cptdagw.blob.core.windows.net/cptdagw/test.txt 
~~~

NOTE: 
You will need to upload via powershell, portal or storage explorer.

## List storage account container
---

~~~ text
azcopy list https://cptdagw.blob.core.windows.net/cptdagw
~~~

## Create Application Gateway
---

~~~ text
az deployment group create -n create-agw -g cptdagw --template-file bicep/agw.bicep
~~~

## Setup node.js https server on vm
---

IMPORTANT:
This setup is optional. Everything will be already setup via the cloud-init file which does get used during the vm deployment.
But in case you like to setup the server by yourself (w/o the cloud-init) file please read the following section.

The following instruction is based on the following article:
- https://www.digitalocean.com/community/tutorials/how-to-set-up-a-node-js-application-for-production-on-ubuntu-16-04

Log into the vm via azure bastion host.

Clone the git repo.

~~~ text
github clone https://github.com/cpinotossi/cptdagw.git
~~~

Switch folder.

~~~ text
cd cptdagw
~~~

Make server.js executable.

~~~ text
chmod +x ./server.js
~~~

Install NPM module.

~~~ text
sudo npm install -g pm2
~~~

Run server.js as service

~~~ text
pm2 start ./server.js
~~~

## Send request via vm
---

Get AGW private IP

~~~ text
az network application-gateway show -n cptdagw -g cptdagw --query frontendIpConfigurations[].privateIpAddress
~~~

NOTE:
You can get the public IP as follow

~~~ text
az network public-ip show -n cptdagw -g cptdagw --query ipAddress
~~~

Log into the vm via bastion and send a request via curl.

~~~ text
# 200 OK
 curl -k -H'host:test.cptdagw.org' 'https://10.0.0.4/'
{
"x-forwarded-proto": "https",
"x-forwarded-port": "443",
"x-forwarded-for": "10.0.2.4:47904",
"x-original-url": "/",
"connection": "keep-alive",
"x-appgw-trace-id": "fbb1e0f840243e440e74de29ea5581bc",
"host": "test.cptdagw.org",
"x-original-host": "test.cptdagw.org",
"user-agent": "curl/7.58.0",
"accept": "*/*"
}
# Blocked by WAF
curl -k -v -H'host:test.cptdagw.org' 'https://10.0.0.4/?cpt=evil2'
HTTP/1.1 403 Forbidden

# 200 OK (No WAF configured)
curl -k -v -H'host:test.cptdagw.org' 'http://10.0.0.4/cptdagw/test.txt?cpt=evil2'
HTTP/1.1 200 OK
~~~

## Find the corresponding log
---

Get the log analytics workspace id.

~~~ text
law=$(az monitor log-analytics workspace show -g cptdagw -n cptdagw --query customerId |sed 's/"//g')
~~~

Use the node.js helper script to format the http header "x-appgw-trace-id" value into GUID format.

~~~ text
node guidformater.js fbb1e0f840243e440e74de29ea5581bc
~~~

Get application gateway log record by transaction id.

~~~ text
az monitor log-analytics query -w $law --analytics-query 'AzureDiagnostics | where transactionId_g=="fbb1e0f8-4024-3e44-0e74-de29ea5581bc"'
~~~

NOTE:
If you do not know the transaction ID you can query the log record by url query parameter and client ip.

~~~ text
az monitor log-analytics query -w $law --analytics-query 'AzureDiagnostics | where ResourceId contains "APPLICATIONGATEWAY" | where clientIP_s == "10.0.2.4" | where requestQuery_s == "cpt=evil2"' --query [].transactionId_g
~~~

Get web application firewall log record by transaction Id.

~~~ text
az monitor log-analytics query -w $law --analytics-query 'AzureDiagnostics | where transactionId_g =="96fd8d5a-998a-1b92-de37-e6be90e8673e"' --query '[].{}
~~~

Get web application firewall log record by url

~~~ text
az monitor log-analytics query -w $law --analytics-query 'AzureDiagnostics 
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog" | where clientIp_s == "10.0.2.4" | where requestUri_s == "/cptdagw/test.txt?cpt=evil2"'
~~~