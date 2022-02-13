---
title: 
description: 
date: 2022-02-13
tags:
- azure
---

Example
Based on GitHub [Metadata](https://docs.github.com/en/rest/reference/meta#get-github-meta-information)

{% set githubiplist = githubips.actions %}

Total Number of GitHub Action/Runner IPs: {{ githubiplist.length }}

{% include "githubiplist.njk" %}
