---
title: Azure Regions List
description: 
date: 2022-02-13
tags:
- azure
---

Azure Regions List based on Azure API

{% set list = azregions.actions %}

Total Number of GitHub Action/Runner IPs: {{ azregions.length }}

{% include "simplelist.njk" %}
