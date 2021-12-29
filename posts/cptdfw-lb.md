---
title: Azure Firewall, Loadbalancer and NAT
description: This is a post about azure firewall and NAT
date: 2021-12-25
tags:
- azure
---

{% Image "Azure Firewall, Loadbalancer and Asymmetric routing","/img/cptdfw-lb/cptdfw.title.png" %}

[Image: Azure Firewall, Loadbalancer and Asymmetric routing](/img/cptdfw-lb/cptdfw.title.png)

Azure Firewall [fw] can be combined with Azure Load Balancer [lb]. The officel Azure [documentation](https://docs.microsoft.com/en-us/azure/firewall/integrate-lb#fix-the-routing-issue) does describe the concept in detail.

In additon there is an excellent [article](https://blog.cloudtrooper.net/2020/11/28/dont-let-your-azure-routes-bite-you/) by Jose Moreno. 

In the following article I would like to describe my own expirences by playing with lb and fw.

The goal is to setup an enviroment like described at the offical azure documentation and avoid *Asymmetric routing*.

> Asymmetric routing and Azure Firewall
Asymmetric routing is where a packet takes one path to the destination and takes another path when returning to the source. This issue occurs when a subnet has a default route going to the firewall's private IP address and you're using a public load balancer. In this case, the incoming load balancer traffic is received via its public IP address, but the return path goes through the firewall's private IP address. Since the firewall is stateful, it drops the returning packet because the firewall isn't aware of such an established session.
([source](https://docs.microsoft.com/en-us/azure/firewall/integrate-lb#asymmetric-routing))

IMPORTANT: By reading the official documentation you will see that it does mention two options. One with the Internal LB, one with the Public LB. Even if the documention does mention very clearly *The prefered design is to integrate an internal lb*. We will go with the Public LB to see what we can learn from going the *wrong* path ;).

## Azure Load Balancer Setup
---

First step, setup an the needed Azure resources:

- Virtual Machine [vm] (cptdfwspoke)
- Private IP of the vm [vm-ip] (10.2.0.4)
- Azure Standard Loadbalancer [lb]
- Azure Public IP [lb-pip] (104.45.155.21), assigend to the lb frontendIPConfigurations
- lb backendAddressPools (includes VM (cptdfwspoke) with vm-ip (10.2.0.4))
- lb inboundNatRule
- outboundRule
- Network Security Group [nsg] (to allow vm to receive traffic via lb-pip)
- Virtual Network [vnet] and corresponding subnet [sn] to host our vm

> NOTE: Best practices do recommend the usage of Azure NAT Gateway but our goal today is to keep things as simple as possible. So we will go without NAT Gatway and maybe risk to run into the [port exhaustion issue](https://docs.microsoft.com/en-us/azure/load-balancer/troubleshoot-outbound-connection#snatexhaust).

## Test connectivity of vm in combination with Load Balancer
---

Verify the vm-ip used by the Network Interface Card [NIC] of our vm:

~~~ text
ifconfig | grep inet | awk '{print $1 "\t" $2}'
~~~

Result:

~~~ text
inet    10.2.0.4
inet6   fe80::20d:3aff:fe55:55a3
inet    127.0.0.1
inet6   ::1
~~~

> NOTE: We make use of [azure bastion host](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview) to log into our vm.

The nic of our vm does use the vm-ip 10.2.0.4 (private IP).

Find out which IP is used for outbound connections to the internet from our vm via lb:

~~~ text
curl ifconfig.me
~~~

Result:

~~~ text
104.45.155.21 
~~~

> CONCLUSION: Our vm does make use of the lb-pip (104.45.155.21) to communicate via the internet. In addtion the curl (HTTP) response does proof that outbound connectivity provided via the lb works.

## Verify how the Loadbalancer Frontend IP [lb-pip] is connected to our vm
---

As soon as you add a vm to an lb backend pool it will get the lb-pip assigened.
At the same time the VM will no longer be able create outbound connections to the internet if we do not setup the corresponding settings. In our case we did setup an outbound rule for our vm to be still able to talk to the internet.

To see how this is setup inside the corresponding azure resources let us start by getting the lb-pip used by the lb:

~~~ text
lb-pipname=$(az network lb show -n cptdfwspoke -g cptdfw --query frontendIpConfigurations[].publicIpAddress.id -o tsv | awk -F/ '{print $NF}')

az network public-ip show -g cptdfw -n $lb-pipname --query ipAddress -o tsv
~~~

Result:

~~~ text
104.45.155.21
~~~

Now let us see how our lb-pip is aligned with our vm.

Remember we have seen before that our vm does use the lb-pip (Pub IP).

But we all know the vm itself does not provide connectivity. It´s the Network Interface Card [nic], attached to the vm, which does provide the connectivity. And therefore we need to look closer to the nic used by our vm.

Let´s verify if the nic attached to the VM does reference the lb-pip:

~~~ text
nic=$(az vm show -g cptdfw -n cptdfwspoke --query networkProfile.networkInterfaces[].id -o tsv| awk -F/ '{print $NF}')

az network nic show -n $nic -g cptdfw --query 'ipConfigurations[].publicIpAddress' -o tsv
~~~

Result:

~~~ text
empty (null)
~~~

"null" indicates that there is no public ip (lb-pip) assigend to the ip configuration of the nic.

But if we lookup the loadBalancerInboundNatRules of our nic we can see that it does refer our lb inbountNatRule

~~~ text
az network nic show -n $nic -g cptdfw --query 'ipConfigurations[].loadBalancerInboundNatRules[].id' -o tsv| awk -F/ '{print $NF}'
cptdfwspoke
~~~

> CONCLUSION: The lb-pip is not assigned directly as an public ip to the nic of our vm. Instead it is assigned via the corresponding lb settings of the nic.

## Watch the flow between client and Load Balancer
---

Now after we have seen that everything works as expected let us try to follow the flow of a tcp package send from our client till to the vm, through the lb.

> DISCLAIMER: I should mention right from the beginning that we will not be able to see tcp logs from inside the lb. We only will be able to see the tcp logs on client side and vm side.

First let us summarize which IPs exisit in our current setup:

The client-ip (my pc local IP) "172.25.155.32" which can be checked via the linux tool ifconfig:

~~~ text
ifconfig | grep inet | awk '{print $1 "\t" $2}'
~~~

Result:

~~~ text
inet    172.25.155.32
inet6   fe80::215:5dff:fee2:907b
inet    127.0.0.1
inet6   ::1
~~~

The client-pip (my pc public IP) "93.230.208.209" which is provided by my ISP and which can be verified via free services like http://ifconfig.me:

~~~ text
curl ifconfig.me
~~~

Result:

~~~ text
93.230.208.209
~~~

> NOTE: the client-ip (172.25.155.32) will be S-NAT by my ISP to become the client-pip (93.230.208.209):

On Azure we have two IPs:

- vm-ip (10.2.0.4)
- lb public ip/lb-pip (104.45.155.21)

|Name        |IP            |
|------------|--------------|
|client-ip   |172.25.155.32 |
|client-pip  |93.230.208.209|
|lb-pip      |104.45.155.21 |
|vm-ip       |10.2.0.4      |

Before we start to send traffic to the vm let´s see if there is already traffic send to our vm on port 80.

> NOTE: Make sure you are root on the vm to be able to run tcpdump on the azure vm:

~~~ text
sudo -i
~~~

Let´s get some tcp logs:

~~~ text
root@cptdfwspoke:~# tcpdump port 80 and dst 10.2.0.4
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
09:24:33.359120 IP 168.63.129.16.http > cptdfwspoke.internal.cloudapp.net.53642: Fla
gs [S.], seq 885760809, ack 4208169233, win 8192, options [mss 1460,nop,wscale 8,sac
kOK,TS val 1200223345 ecr 328774625], length 0
09:24:33.361116 IP 168.63.129.16.http > cptdfwspoke.internal.cloudapp.net.53642: Fla
gs [FP.], seq 1:2279, ack 200, win 8211, options [nop,nop,TS val 1200223347 ecr 3287
74626], length 2278: HTTP: HTTP/1.1 200 OK
09:24:33.361818 IP 168.63.129.16.http > cptdfwspoke.internal.cloudapp.net.53642: Fla
gs [.], ack 201, win 8211, options [nop,nop,TS val 1200223348 ecr 328774628], length
 0
~~~

Like we can see, we already receive traffic from the azure virtual public ip [avpi] 168.63.129.16.

*The azure virtual public ip 168.63.129.16 does enables health probes from Azure load balancer to determine the health state of VMs.*
source: [What is IP address 168.63.129.16?](https://docs.microsoft.com/en-us/azure/virtual-network/what-is-ip-address-168-63-129-16)

Our Network Security Group [nsg] already inlcude avpi (168.63.129.16). 

Every new nsg does include by default an inbound rule called AllowAzureLoadBalancerInBound which does include the avpi.

~~~ text
az network nic list-effective-nsg -n cptdfwspoke -g cptdfw --query 'value[].effectiveSecurityRules[][][]' | jq -c '.[] | select(.name=="defaultSecurityRules/AllowAzureLoadBalancerInBound")'
~~~

Result:

~~~ text
{
    "access": "Allow",
    "destinationAddressPrefix": "0.0.0.0/0",
    "destinationAddressPrefixes": [
        "0.0.0.0/0",
        "0.0.0.0/0"
    ],
    "destinationPortRange": "0-65535",
    "destinationPortRanges": [
        "0-65535"
    ],
    "direction": "Inbound",
    "expandedDestinationAddressPrefix": null,
    "expandedSourceAddressPrefix": [
        "168.63.129.16/32",
        "fe80::1234:5678:9abc/128"
    ],
    "name": "defaultSecurityRules/AllowAzureLoadBalancerInBound",
    "priority": 65001,
    "protocol": "All",
    "sourceAddressPrefix": "AzureLoadBalancer",
    "sourceAddressPrefixes": [
        "AzureLoadBalancer"
    ],
    "sourcePortRange": "0-65535",
    "sourcePortRanges": [
        "0-65535"
    ]
}
~~~

Another IP which could cause some nice could be the 169.254.169.254 aka the [Azure Metadata Service](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/instance-metadata-service?tabs=windows). So we will need to exclude this one too.

Filter out the avpi and Azure Metadata Service traffic:

~~~ text
tcpdump -n port 80 and not host 168.63.129.16 and not host 169.254.169.254
~~~

In addition we also like to run tcpdump on our local machine.
There we also like to filter out all the traffic which is not relevant:

~~~ text
sudo tcpdump -n port 80 and host 104.45.155.21
~~~

Send HTTP Request from my local machine:

~~~ text
curl -v 104.45.155.21
~~~

Result:

~~~ text
* Rebuilt URL to: 104.45.155.21/
*   Trying 104.45.155.21...
* TCP_NODELAY set
* Connected to 104.45.155.21 (104.45.155.21) port 80 (#0)
> GET / HTTP/1.1
> Host: 104.45.155.21
> User-Agent: curl/7.58.0
> Accept: */*
>
< HTTP/1.1 200 OK
< Date: Tue, 21 Dec 2021 11:17:21 GMT
< Connection: keep-alive
< Transfer-Encoding: chunked
<
{
        "host": "104.45.155.21",
        "user-agent": "curl/7.58.0",
        "accept": "*/*"
}{
        "ladd": "::ffff:10.2.0.4",
        "lport": 80,
        "radd": "::ffff:93.230.208.209",
        "rport": 21432
* Connection #0 to host 104.45.155.21 left intact
~~~

TCPdump logs from the vm:

~~~ text
11:59:13.184079 IP 93.230.208.209.21468 > 10.2.0.4.80: Flags [S], seq 511333143, win 64240, options [mss 1452,sackOK,TS val 329791480 ecr 0,nop,wscale 7], length 0
11:59:13.184137 IP 10.2.0.4.80 > 93.230.208.209.21468: Flags [S.], seq 3773881649, ack 511333144, win 65160, options [mss 1460,sackOK,TS val 851192548 ecr 329791480,nop,
wscale 7], length 0
11:59:13.285163 IP 93.230.208.209.21468 > 10.2.0.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 329791580 ecr 851192548], length 0
11:59:13.285164 IP 93.230.208.209.21468 > 10.2.0.4.80: Flags [P.], seq 1:78, ack 1, win 502, options [nop,nop,TS val 329791581 ecr 851192548], length 77: HTTP: GET / HTT
P/1.1
11:59:13.285255 IP 10.2.0.4.80 > 93.230.208.209.21468: Flags [.], ack 78, win 509, options [nop,nop,TS val 851192649 ecr 329791581], length 0
11:59:13.286225 IP 10.2.0.4.80 > 93.230.208.209.21468: Flags [P.], seq 1:297, ack 78, win 509, options [nop,nop,TS val 851192650 ecr 329791581], length 296: HTTP: HTTP/1
.1 200 OK
11:59:13.384761 IP 93.230.208.209.21468 > 10.2.0.4.80: Flags [.], ack 297, win 501, options [nop,nop,TS val 329791681 ecr 851192650], length 0
11:59:13.385301 IP 93.230.208.209.21468 > 10.2.0.4.80: Flags [F.], seq 78, ack 297, win 501, options [nop,nop,TS val 329791681 ecr 851192650], length 0
11:59:13.385594 IP 10.2.0.4.80 > 93.230.208.209.21468: Flags [F.], seq 297, ack 79, win 509, options [nop,nop,TS val 851192749 ecr 329791681], length 0
11:59:13.485865 IP 93.230.208.209.21468 > 10.2.0.4.80: Flags [.], ack 298, win 501, options [nop,nop,TS val 329791781 ecr 851192749], length 0
~~~

Logs from my local client

~~~ text
12:59:13.465717 IP 172.25.155.32.34378 > 104.45.155.21.80: Flags [S], seq 511333143, win 64240, options [mss 1460,sackOK,TS val 329791480 ecr 0,nop,wscale 7], length 0
12:59:13.566053 IP 104.45.155.21.80 > 172.25.155.32.34378: Flags [S.], seq 3773881649, ack 511333144, win 65160, options [mss 1440,sackOK,TS val 851192548 ecr 329791480,nop,wscale 7], length 0
12:59:13.566314 IP 172.25.155.32.34378 > 104.45.155.21.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 329791580 ecr 851192548], length 0
12:59:13.566775 IP 172.25.155.32.34378 > 104.45.155.21.80: Flags [P.], seq 1:78, ack 1, win 502, options [nop,nop,TS val 329791581 ecr 851192548], length 77: HTTP: GET / HTTP/1.1
12:59:13.666634 IP 104.45.155.21.80 > 172.25.155.32.34378: Flags [.], ack 78, win 509, options [nop,nop,TS val 851192649 ecr 329791581], length 0
12:59:13.666674 IP 104.45.155.21.80 > 172.25.155.32.34378: Flags [P.], seq 1:297, ack 78, win 509, options [nop,nop,TS val 851192650 ecr 329791581], length 296: HTTP: HTTP/1.1 200 OK
12:59:13.666704 IP 172.25.155.32.34378 > 104.45.155.21.80: Flags [.], ack 297, win 501, options [nop,nop,TS val 329791681 ecr 851192650], length 0
12:59:13.666951 IP 172.25.155.32.34378 > 104.45.155.21.80: Flags [F.], seq 78, ack 297, win 501, options [nop,nop,TS val 329791681 ecr 851192650], length 0
12:59:13.767036 IP 104.45.155.21.80 > 172.25.155.32.34378: Flags [F.], seq 297, ack 79, win 509, options [nop,nop,TS val 851192749 ecr 329791681], length 0
12:59:13.767197 IP 172.25.155.32.34378 > 104.45.155.21.80: Flags [.], ack 298, win 501, options [nop,nop,TS val 329791781 ecr 851192749], length 0
~~~

## Analyze the TCPDump logs between client, lb and vm
---

Looking through the logs we can see that S-NAT has been used between lb and vm  

- Client send: IP 172.25.155.32 > 104.45.155.21:  
- VM received: IP 93.230.208.209 > 10.2.0.4

- My ISP does S-NAT 172.25.155.32 to 93.230.208.209
- Azure lb does D-NAT 104.45.155.21 to 10.2.0.4

And accordently the response does get NAT'ed too
- VM send: IP 10.2.0.4 > 93.230.208.209
- Client received: 104.45.155.21 > 172.25.155.32

- Azure lb does S-NAT 10.2.0.4 to 104.45.155.21
- My ISP does D-NAT 93.230.208.209 to 172.25.155.32 to 

A more schematic diagram looks as follow:

{% Image "firewall-lb-asymmetric.png","/img/cptdfw-lb/lbpip.flow.png" %}

[Image: firewall-lb-asymmetric.png](/img/cptdfw-lb/lbpip.flow.png)

> NOTE: For simplicity I excluded the NATing done by the ISP and the clients starts right away with the client-pip.

## Add Azure Firewall to the mix
---

In a next step we will introduce the Azure Firewall [fw] into our existing deployment.
Like mentioned at the beginning of this article we will follow the architecture mentioned at the azure official [documentation](https://docs.microsoft.com/en-us/azure/firewall/integrate-lb):

{% Image "firewall-lb-asymmetric.png","img/cptdfw-lb/firewall-lb-asymmetric.png" %}

[Image: firewall-lb-asymmetric.png](/img/cptdfw-lb/firewall-lb-asymmetric.png)


We did setup a firewall with the public IP (fw-pip):

~~~ text
fwip=$(az network firewall show -n cptdfw -g cptdfw --query ipConfigurations[].publicIpAddress.id -o tsv | awk -F/ '{print $NF}')
az network public-ip show -g cptdfw -n $fwip --query ipAddress -o tsv
~~~

Result:

~~~ text
52.142.57.131
~~~

And a corresponding private IP (fw-ip):

~~~ text
az network firewall show -g cptdfw -n cptdfw --query ipConfigurations[].privateIpAddress -o tsv
~~~

Result:

~~~ text
10.0.3.4
~~~

Overall we have the following IPs:

|Name        |IP            |
|------------|--------------|
|client-ip   |172.25.155.32 |
|client-pip  |93.230.208.209|
|lb-pip      |104.45.155.21 |
|vm-ip       |10.2.0.4      |
|fw-pip      |52.142.57.131 |
|fw-ip       |10.0.3.4      |

## Azure Firewall D-NAT rule
---

To integrate the fw with our existing lb we would like to run all the inbound traffic via our fw.

Thereforew we defined the following fw nat rule:

~~~ text
az network firewall policy rule-collection-group collection list -g cptdfw --policy-name cptdfw --rcg-name DefaultDnatRuleCollectionGroup --query '[0].rules[0].{src:destinationAddresses[0],srcport:destinationPorts[0],des:translatedAddress,desport:translatedPort}'
~~~

Result:

~~~ text
{
  "des": "104.45.155.21",
  "desport": "80",
  "src": "52.142.57.131",
  "srcport": "80"
}
~~~

This fw D-NAT rule will rewrite incoming request on IP 52.142.57.131 (fw-pip) to the lb-pip 104.45.155.21.

The following picture does show how the fw d-nat rule get´s applied:

{% Image "firewall-lb-asymmetric.png","/img/cptdfw-lb/fwpip.lbpip.dnat.png" %}

[Image: firewall-lb-asymmetric.png](/img/cptdfw-lb/fwpip.lbpip.dnat.png)

> NOTE: In addition to D-NAT, connections via the firewall public IP address (inbound) are S-NATed to one of the firewall private IPs. This requirement today (also for Active/Active NVAs) to ensure symmetric routing.	To preserve the original source for HTTP/S, consider using XFF headers. For example, use a service such as Azure Front Door or Azure Application Gateway in front of the firewall. You can also add WAF as part of Azure Front Door and chain to the firewall. 
> ([source](https://docs.microsoft.com/en-us/azure/firewall/overview#known-issues))

## Azure Firewall Network rule
---

In addition we did setup Network Rules to restrict the traffic only from our client-pip (src:93.230.208.209) to lb-pip (des:104.45.155.21):

~~~ text
az network firewall policy rule-collection-group collection list -g cptdfw --policy-name cptdfw --rcg-name DefaultNetworkRuleCollectionGroup --query '[0].rules[0].{src:sourceAddresses[0],des:destinationAddresses[0],desport:destinationPorts[0]}'
~~~

Result:

~~~ text
{
  "des": "104.45.155.21",
  "desport": "80",
  "src": "93.230.208.209"
}
~~~

It is important to understand that the destination IP needs to be the lb-pip of our lb and not the fw-pip. 
This just works because of the way how fw applies the different rules: 

> *Application rules are always processed after Network rules, which are processed after D-NAT rules regardless of Rule collection group or Rule collection priority and policy inheritance.* 
> source [Configure Azure Firewall rules](https://docs.microsoft.com/en-us/azure/firewall/rule-processing)

That is the reason why we use the lb-pip as destination inside the fw network rule.

## Watch the flow again between client, Load Balancer and Firewall inbetween
---

HTTP Request from local pc/client

~~~ text
curl -v 52.142.57.131
* Rebuilt URL to: 52.142.57.131/
*   Trying 52.142.57.131...
* TCP_NODELAY set
* Connected to 52.142.57.131 (52.142.57.131) port 80 (#0)
> GET / HTTP/1.1
> Host: 52.142.57.131
> User-Agent: curl/7.58.0
> Accept: */*
>
< HTTP/1.1 200 OK
< Date: Tue, 21 Dec 2021 16:33:50 GMT
< Connection: keep-alive
< Transfer-Encoding: chunked
<
{
        "host": "52.142.57.131",
        "user-agent": "curl/7.58.0",
        "accept": "*/*"
}{
        "ladd": "::ffff:10.2.0.4",
        "lport": 80,
        "radd": "::ffff:52.142.57.131",
        "rport": 1024
* Connection #0 to host 52.142.57.131 left intact
~~~

TCP Dump from local pc/client (UTC+1):

~~~ text
sudo tcpdump -n port 80 and host 52.142.57.131
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
17:33:51.225503 IP 172.25.155.32.44680 > 52.142.57.131.80: Flags [S], seq 1032879940, win 64240, options [mss 1460,sackOK,TS val 1438364048 ecr 0,nop,wscale 7], length 0
17:33:51.342776 IP 52.142.57.131.80 > 172.25.155.32.44680: Flags [S.], seq 2803633477, ack 1032879941, win 65160, options [mss 1420,sackOK,TS val 835345473 ecr 1438364048,nop,wscale 7], length 0
17:33:51.343193 IP 172.25.155.32.44680 > 52.142.57.131.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1438364166 ecr 835345473], length 0
17:33:51.345123 IP 172.25.155.32.44680 > 52.142.57.131.80: Flags [P.], seq 1:78, ack 1, win 502, options [nop,nop,TS val 1438364168 ecr 835345473], length 77: HTTP: GET / HTTP/1.1
17:33:51.446758 IP 52.142.57.131.80 > 172.25.155.32.44680: Flags [.], ack 78, win 509, options [nop,nop,TS val 835345587 ecr 1438364168], length 0
17:33:51.446869 IP 52.142.57.131.80 > 172.25.155.32.44680: Flags [P.], seq 1:295, ack 78, win 509, options [nop,nop,TS val 835345588 ecr 1438364168], length 294: HTTP: HTTP/1.1 200 OK
17:33:51.446937 IP 172.25.155.32.44680 > 52.142.57.131.80: Flags [.], ack 295, win 501, options [nop,nop,TS val 1438364270 ecr 835345588], length 0
17:33:51.452374 IP 172.25.155.32.44680 > 52.142.57.131.80: Flags [F.], seq 78, ack 295, win 501, options [nop,nop,TS val 1438364275 ecr 835345588], length 0
17:33:51.652502 IP 52.142.57.131.80 > 172.25.155.32.44680: Flags [F.], seq 295, ack 79, win 509, options [nop,nop,TS val 835345696 ecr 1438364275], length 0
17:33:51.652722 IP 172.25.155.32.44680 > 52.142.57.131.80: Flags [.], ack 296, win 501, options [nop,nop,TS val 1438364476 ecr 835345696], length 0
^C
10 packets captured
10 packets received by filter
0 packets dropped by kernel
~~~

TCP dump from vm (UTC)

~~~ text
 tcpdump -n port 80 and not host 168.63.129.16 and not host 169.254.169.254
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
16:33:50.702257 IP 52.142.57.131.1024 > 10.2.0.4.80: Flags [S], seq 1032879940, win 64240, options [mss 1432,sackOK,TS val 1438364048 ecr 0,nop,wscale 7], length 0
16:33:50.702319 IP 10.2.0.4.80 > 52.142.57.131.1024: Flags [S.], seq 2803633477, ack 1032879941, win 65160, options [mss 1460,sackOK,TS val 835345473 ecr 1438364048,nop,
wscale 7], length 0
16:33:50.814814 IP 52.142.57.131.1024 > 10.2.0.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1438364166 ecr 835345473], length 0
16:33:50.816521 IP 52.142.57.131.1024 > 10.2.0.4.80: Flags [P.], seq 1:78, ack 1, win 502, options [nop,nop,TS val 1438364168 ecr 835345473], length 77: HTTP: GET / HTTP
/1.1
16:33:50.816546 IP 10.2.0.4.80 > 52.142.57.131.1024: Flags [.], ack 78, win 509, options [nop,nop,TS val 835345587 ecr 1438364168], length 0
16:33:50.817243 IP 10.2.0.4.80 > 52.142.57.131.1024: Flags [P.], seq 1:295, ack 78, win 509, options [nop,nop,TS val 835345588 ecr 1438364168], length 294: HTTP: HTTP/1.
1 200 OK
16:33:50.917852 IP 52.142.57.131.1024 > 10.2.0.4.80: Flags [.], ack 295, win 501, options [nop,nop,TS val 1438364270 ecr 835345588], length 0
16:33:50.924976 IP 52.142.57.131.1024 > 10.2.0.4.80: Flags [F.], seq 78, ack 295, win 501, options [nop,nop,TS val 1438364275 ecr 835345588], length 0
16:33:50.925433 IP 10.2.0.4.80 > 52.142.57.131.1024: Flags [F.], seq 295, ack 79, win 509, options [nop,nop,TS val 835345696 ecr 1438364275], length 0
16:33:51.124398 IP 52.142.57.131.1024 > 10.2.0.4.80: Flags [.], ack 296, win 501, options [nop,nop,TS val 1438364476 ecr 835345696], length 0
^C
10 packets captured
10 packets received by filter
0 packets dropped by kernel
~~~

## Analyze the TCPDump logs between client, fw, lb and vm
---

Looking through the logs we can see that S-NAT has been used between lb and vm  

- Client send: IP 172.25.155.32 (client-pip) > 52.142.57.131 (fw-pip)  
- VM received: IP 52.142.57.131 (fw-pip) > 10.2.0.4 (vm-ip)

- My ISP does S-NAT 172.25.155.32 (client-ip) to 93.230.208.209 (client-pip)
- Azure fw does D-NAT 52.142.57.131 (fw-pip) > 104.45.155.21 (lb-pip)
- Azure fw does S-NAT 52.142.57.131 (fw-pip) > 10.0.3.4 (fw-pip) // Based on [fw known issues](https://docs.microsoft.com/en-us/azure/firewall/overview#known-issues)
- Azure lb does D-NAT 104.45.155.21 (lb-pip) to 10.2.0.4 (vm-ip)

And accordently the response does get NAT'ed too:

- VM send: IP 10.2.0.4.80 > 52.142.57.131
Client received: 52.142.57.131 > 172.25.155.32

- Azure lb does S-NAT 10.2.0.4 to 104.45.155.21
- Azure fw does S-NAT 104.45.155.21 to 52.142.57.131
- My ISP does D-NAT 93.230.208.209 to 172.25.155.32

## Azure Firewall Logs
---

We have seen that a request has been received by the vm around 16:33:50 (UTC).
Let us find the corresponding fw logs which should proof that the fw D-NAT rule and the fw Network Rule have been applied:

~~~ text
lawid=$(az monitor log-analytics workspace show -g cptdfw -n cptdfw --query customerId -o tsv)
az monitor log-analytics query -w $lawid --analytics-query 'AzureDiagnostics | where TimeGenerated between(datetime("2021-12-21 16:32:00") .. datetime("2021-12-21 16:34:00")) | where OperationName contains "AzureFirewall"| project TimeGenerated,OperationName,msg_s' -o table
~~~

Result:

~~~ text
OperationName                TableName      TimeGenerated           Msg_s
---------------------------  -------------  ----------------------  -----------------------------------------------------------------------------------------
AzureFirewallNatRuleLog      PrimaryResult  2021-12-21T16:33:50.7Z  TCP request from 93.230.208.209:21410 to 52.142.57.131:80 was DNAT'ed to 104.45.155.21:80
AzureFirewallNetworkRuleLog  PrimaryResult  2021-12-21T16:33:50.7Z  TCP request from 93.230.208.209:21410 to 104.45.155.21:80. Action: Allow.
~~~

> Conclusion: Like expected we can see how the fw did D-NAT destination IP 52.142.57.131 to 104.45.155.21.
Also we can see that the fw did allow inbound request from 93.230.208.209

## Lock down lb public ip
---

Currently we are still able to send request to the lb-pip.
But because we would like to see all request to go through our fw we need to lock down access via lb-pip.

One way could be by locking down the access of our lb-pip via an IP based Access Control list [acl].
But the azure lb does not offer such a functionality.

Another way could be to limit access to our VM just via the lb with nsg rules. But let´s assume we like to make use of our shine new fw.

Therefore we need to make use of User Defined Routes [udr] which are defined via route tables [rt].

We will assign a rt to the subnet which does include our vm with the following udr´s:

~~~ text
az network route-table show -g cptdfw -n cptdfwspoke --query 'routes[].{name:name,dst:addressPrefix,nextHopType:nextHopType,nextHopIpAddress:nextHopIpAddress}'
~~~

Result:
~~~ text
[
  {
    "dst": "52.142.57.131/32",
    "name": "fwviainternet",
    "nextHopIpAddress": null,
    "nextHopType": "Internet"
  },
  {
    "dst": "0.0.0.0/0",
    "name": "internetviafw",
    "nextHopIpAddress": "10.0.3.4",
    "nextHopType": "VirtualAppliance"
  }
]
~~~

- 0.0.0.0/0 does also match lb-pip and fw-pip
- 52.142.57.131 = fw-pip
- nextHopIpAddress of fwviainternet is expected to be null because the internet is not represented by a single ip ;)

Let´s see how this changes the routing of our vm.

~~~ text
nicid=$(az network nic show -n cptdfwspoke -g cptdfw --query id -o tsv)
az network nic show-effective-route-table --ids $nicid -o table
~~~

Result:

~~~ text
Source    State    Address Prefix    Next Hop Type     Next Hop IP
--------  -------  ----------------  ----------------  -------------
Default   Active   10.2.0.0/16       VnetLocal
Default   Active   10.0.0.0/16       VNetPeering
User      Active   52.142.57.131/32  Internet
Default   Invalid  0.0.0.0/0         Internet
User      Active   0.0.0.0/0         VirtualAppliance  10.0.3.4
~~~

- Like we can see all traffic for 0.0.0.0/0 is now send to the private ip of our fw (fw-ip).
- Traffic send to the fw-pip will be send to the internet which also includes our lb-pip

With the introduction udr the flow via the fw-pip looks as follow:

{% Image "symetric flow with firewall and loadbalancer","/img/cptdfw-lb/fwpip.lbpip.flow.png" %}

[Image: symetric flow with firewall and loadbalancer](/img/cptdfw-lb/fwpip.lbpip.flow.png)

The flow via the lb-pip (lb-pip) does change as follow:


{% Image "asymetric flow with firewall and loadbalancer","/img/cptdfw-lb/lbpip.fwip.flow.png" %}

[Image: asymetric flow with firewall and loadbalancer](/img/cptdfw-lb/lbpip.fwip.flow.png)

> Conclusion: lb-pip is still available from outside but the response is no longer delivered because the fw does not see the whole flow.


## Into the NATing rabbit hole
---

Now that we started looking deeper into NATing it would be interesting to understand the whole flow in more detail.

Again Jose Moreno did write an execellent [article](https://docs.microsoft.com/en-us/azure/architecture/example-scenario/gateway/firewall-application-gateway) about it right at the Azure Architecture center.

The articel does cover the FW and Azure Application Gateway case which is not the one we are looking into. It does tell us still a lot about how NAT does take place in combination with Azure fw.

We will combine this with the insides Jose Moreno shared on his own [blog](https://blog.cloudtrooper.net/2020/11/28/dont-let-your-azure-routes-bite-you/) about how the Azure fw is setup internally :

*Essentially, an Azure Firewall is composed of two or more multiple instances with two load balancers in front of them: a public one (to get traffic from the public Internet), and an internal one (to get traffic from on-premises or the rest of the Azure Virtual Network environment). Something like this:*

![Image: Internal structure of Azure Firewall](/img/cptdfw-lb/internal-structure-of-azure-firewall.png)

Let´s start small. Let´s make the following assumption.
Let´s assume the firewall would act as it´s own client and would like to send a request to the vm.
The public loadblancer which is part of the Azure Firewall structure would nat the request via his public ip.
The flow would look as follow:


{% Image "asymetric flow from firewall vm to vm via loadbalancer","/img/cptdfw-lb/fwip.flow.png" %}

[Image: asymetric flow from firewall vm to vm via loadbalancer](/img/cptdfw-lb/fwip.flow.png)

Ok we understand now how the flow looks if the request would have been triggered by the fw. But the true is, the fw will not trigger the request. Request will be triggered by the client via his pip.

So we are going to look into how this works.
But to keep things simple we will simplfy what happens between step 2 and 3.
There we would see the request flow which has been presented already on our last diagram (between fw and vm via lb).

Let us have a look at the flow without showing the flow to the vm in detail:


{% Image "asymetric flow with firewall and loadbalancer","/img/cptdfw-lb/clientpip.flow.png" %}

[Image: asymetric flow with firewall and loadbalancer](/img/cptdfw-lb/clientpip.flow.png)

Now let´s put all togther and see how it looks:


{% Image "asymetric flow with firewall and loadbalancer","/img/cptdfw-lb/clientpip.total.flow.png" %}

[Image: asymetric flow with firewall and loadbalancer](/img/cptdfw-lb/clientpip.total.flow.png)

QUESTION: Based on the tcp logs from the vm no traffic does hit the vm if we send a request via lb-pip. How does fw know that it needs to block the traffic?

NOTE: I believe this is done via the Azure SDN. It seems to keep some kind of flow table which tells him right away that this is not going to work at all and therefore the request does not hit our vm at all.</

## Tip
---

You can turn off and on your firewall in case you like to play with it.

~~~ text
$azfw = Get-AzFirewall -Name cptdfw -ResourceGroupName cptdfw
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw
~~~
