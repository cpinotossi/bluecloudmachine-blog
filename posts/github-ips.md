---
title: List of GitHub Action/Runner's IP addresses
description: This is a post about GitHub IP lists
date: 2022-02-13
tags:
- azure
---
Based on GitHub [Metadata](https://docs.github.com/en/rest/reference/meta#get-github-meta-information)

{% set githubiplist = githubips.actions %}

Total Number of GitHub Action/Runner IPs: {{ githubiplist.length }}

{% include "githubiplist.njk" %}

In case you like to protect your Azure storage account via the firewall/acl/network-rule feature please keep in mind that the storage account limits:
- Maximum number of IP address rules per storage account	200
- Maximum number of virtual network rules per storage account	200image
For more information: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#storage-limits
