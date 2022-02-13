# bluecloudmachine-blog

Build and run 11th localy.

~~~ text
npm run build
npm run start
startedgeguest --url http://localhost:8080
~~~

~~~ text
prefix=cptdjamstack
subid=$(az account show --query id -o tsv)
az group create -n $prefix -l eastus
az ad sp list --query [].displayName
az ad sp create-for-rbac --name $prefix --role contributor --scopes /subscriptions/$subid/resourceGroups/$prefix --sdk-auth
~~~

~~~ text
ssurl=$(az storage account show -n $prefix -g $prefix --query primaryEndpoints.web -o tsv)
curl -v $ssurl/

curl ifconfig.io
~~~

openid auth.

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

az group delete -n $prefix -y






Git commands.

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
- https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#ip-addresses



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



