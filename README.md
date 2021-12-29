# bluecloudmachine-blog



sed -i 's/~~~~/~~~/g' posts/*.md
sed -i 's/~~~JSON/~~~ text/g' posts/*.md
sed -i 's/~~~bash/~~~ text/g' posts/*.md
sed -i 's/~~~json/~~~ text/g' posts/*.md
sed -i 's/~~~pwsh/~~~ text/g' posts/*.md
sed -i 's/~~~bicep/~~~ text/g' posts/*.md
sed -i 's/~~~kusto/~~~ text/g' posts/*.md
grep ~~~ posts/* | sort | uniq -c

sed -i 's#(/images/#(/img/#g' posts/*.md
sed -i 's#(images/#(/img/#g' posts/*.md
sed -i 's#(/img/#(/img/cptdfun-alert/#g' posts/cptdfun-alert.md
sed -i 's#(/img/#(/img/cptdagw-storage/#g' posts/cptdagw-storage.md
grep -F '![' posts/* | sort | uniq -c
