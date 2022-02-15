# bluecloudmachine-blog

## Build and run 11th localy.

~~~ text
npm run build
npm run start
startedgeguest --url http://localhost:8080
~~~

## Create the azure resources.

az ad sp list --all --query "[?displayName=='${prefix}']"

~~~ text
prefix=cptdjamstack
spid=$(az ad sp list --all --query "[?displayName=='${prefix}'].objectId" -o tsv)
meid=$(az ad user list --query "[?displayName=='ga'].objectId" -o tsv)
az group create -n $prefix -l eastus
az deployment group create -n create-storage -g $prefix --template-file bicep/sab.bicep -p objectIdSp=$spid objectIdMe=$meid prefix=$prefix
az storage blob service-properties update --account-name $prefix --static-website --404-document 404.html --index-document index.html
~~~

## Test azure storage static page

~~~ text
mkdir misc/test
echo "hello world" > misc/test/test.txt
az storage blob upload-batch --account-name $prefix --auth-mode login -d '$web' -s misc/test
ssurl=$(az storage account show -n $prefix -g $prefix --query primaryEndpoints.web -o tsv)
curl -v $ssurl/test.txt
~~~

Create a new CDN edge location blog entry

~~~ text
npm run start
startedgeguest --url http://localhost:8080/
az account list-locations --query "[?not_null(metadata.latitude)].name" > _data/azregions.json
code _data/azregions.json
jq . _data/azregions.json
code blankblog.md
cp blankblog.md posts/azregions.md
sed -i 's/<DATAFILE>/azregions/g' posts/azregions.md
code posts/azregions.md
npm run build
git status
git add *
git status
git commit -m"try fix workflow"
git push origin master
startedgeguest --url https://cptdjamstack.z13.web.core.windows.net/
startedgeguest --url https://blog.bluecloudmachine.org
~~~

# Clean up

~~~ text
az group delete -n $prefix -y
~~~

# Misc

## Create service principal.

This tutorial does expect that you already created an Service Principal. If this is not the case follow the instruction mentioned [here](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-static-site-github-actions?tabs=userlevel).

~~~ text
subid=$(az account show --query id -o tsv)
az ad sp create-for-rbac --name $prefix --role contributor --scopes /subscriptions/$subid/resourceGroups/$prefix --sdk-auth
~~~

> TODO: sdk-auth flag is deprecated. Clarify how to replace it.

## openid auth setup.

~~~ text
az ad app create --display-name $prefix
appid=$(az ad app list --query "[?displayName=='${prefix}'].appId" -o tsv)
appobjectid=$(az ad app list --query "[?displayName=='${prefix}'].objectId" -o tsv)
echo $appid $objectid
az ad sp create --id $appid
ssobjectid=$(az ad sp show --id $appid --query objectId -o tsv) 
subid=$(az account show --query id -o tsv)
az role assignment create --role contributor --subscription $subid --assignee-object-id  $ssobjectid --assignee-principal-type ServicePrincipal
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${appobjectid}/federatedIdentityCredentials" --body '{"name":"cptdjamstack","issuer":"https://token.actions.githubusercontent.com","subject":"repo:cpinotossi/bluecloudmachine-blog:ref:refs/heads/main","description":"Testing","audiences":["api://AzureADTokenExchange"]}' --verbose
~~~

Clean up openid

~~~ text
az ad sp delete --id $appid
az ad app list --query [].displayName
az ad app delete --id $appobjectid
~~~

## Git commands.

~~~ text
git status
git remote get-url --all origin
git branch --all
git diff master remotes/origin/master
git fetch origin master
git merge origin/master

curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/meta -o _data/githubips.json
~~~

# Links
- [How to get github action vm´s ip](https://docs.github.com/en/rest/reference/meta#get-github-meta-information--code-samples)
- [About GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#ip-addresses)
- [MS Docs, how to setup static web site via storage account](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-host)
- [Deploy to az static web site service blog](https://squalr.us/2021/05/deploying-an-11ty-site-to-azure-static-web-apps/)
- [Deploy to az static web site with github actions by MS Docs](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-static-site-github-actions)
- [configure azure storage ip acl](https://docs.microsoft.com/en-us/azure/storage/common/storage-network-security?tabs=azure-cli)

## sed magic

~~~ text
sed -i 's/~~~~/~~~/g' posts/*.md
sed -i 's/~~~JSON/~~~ text/g' posts/*.md
sed -i 's/~~~bash/~~~ text/g' posts/*.md
sed -i 's/~~~json/~~~ text/g' posts/*.md
sed -i 's/~~~pwsh/~~~ text/g' posts/*.md
sed -i 's/~~~bicep/~~~ text/g' posts/*.md
sed -i 's/~~~kusto/~~~ text/g' posts/*.md
grep ~~~ posts/* | sort | uniq -c

grep JSON posts/* | sort | uniq -c

sed -i 's#(/images/#(/img/#g' posts/*.md
sed -i 's#(images/#(/img/#g' posts/*.md
sed -i 's#(/img/#(/img/cptdfun-alert/#g' posts/cptdfun-alert.md
sed -i 's#(/img/#(/img/cptdagw-storage/#g' posts/cptdagw-storage.md
grep -F '![' posts/* | sort | uniq -c
~~~

## TODO

Get it done with resource script instead like here:
https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.storage/storage-static-website/scripts/enable-static-website.ps1

[Bicep Script Resource](https://docs.microsoft.com/en-us/azure/templates/microsoft.resources/deploymentscripts?tabs=bicep)