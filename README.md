[![Packet Website](https://img.shields.io/badge/Website%3A-Packet.com-blue)](http://packet.com) [![Slack Status](https://slack.packet.com/badge.svg)](https://slack.packet.com) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
# Automated Anthos Installation via Terraform for Packet
These files will allow you to use [Terraform](http://terraform.io) to deploy [Google Cloud's Anthos GKE on-prem](https://cloud.google.com/anthos) on VMware vSphere on [Packet's Bare Metal Cloud offering](https://www.packet.com/cloud/). 

Terraform will create a Packet project complete with a linux machine for routing, a vSphere cluster installed on minimum 3 ESXi hosts with vSAN storage, and an Anthos GKE on-prem admin and user cluster registered to Google Cloud. You can you an existing Packet Project, check this [section] (#use-an-existing-packet-project) about instructions

![Environment Diagram](docs/images/google-anthos-vsphere-network-diagram-1.png)


Users are responsible for providing their own VMware software, Packet account, and Anthos subscription as described in this readme.

The build (with default settings) typically takes 70-75 minutes.

## Join us on Slack
We use [Slack](https://slack.com/) as our primary communication tool for collaboration. You can join the Packet Community Slack group by going to [slack.packet.com](https://slack.packet.com/) and submitting your email address. You will receive a message with an invite link. Once you enter the Slack group, join the **#google-anthos** channel! Feel free to introduce yourself there, but know it's not mandatory.

## Prerequisites
To use these Terraform files, you need to have the following Prerequisites:
* An [Anthos subscription](https://cloud.google.com/anthos/docs/getting-started)
* A [white listed GCP project and service account](https://cloud.google.com/anthos/gke/docs/on-prem/how-to/gcp-project).
* A Packet org-id and [API key](https://www.packet.com/developers/api/)
* A public SSH key within your Packet account and the associated private saved at `~/.ssh/id_rsa` on the device with Terraform Files. (See [Packet Documentation](https://support.packet.com/kb/articles/generate-ssh-keys) for more information on creating keys. Permissions should be set to `0400` for `~/.ssh/id_rsa`
* [VMware vCenter Server 6.7U3](https://my.vmware.com/group/vmware/details?downloadGroup=VC67U3B&productId=742&rPId=40665) - VMware vCenter Server Appliance ISO obtained from VMware
* [VMware vSAN Management SDK 6.7U3](https://my.vmware.com/group/vmware/details?downloadGroup=VSAN-MGMT-SDK67U3&productId=734) - Virtual SAN Management SDK for Python, also from VMware
 
## Associated Packet Costs
The default variables make use of 4 [c2.medium.x86](https://www.packet.com/cloud/servers/c2-medium-epyc/) servers. These servers are $1 per hour list price (resulting in a total solution price of roughly $4 per hour).

## Tested GKE on-prem verions
The Terrafrom has been succesfully tested with following versions of GKE on-prem:
* 1.1.2-gke.0*
* 1.2.0-gke.6*
* 1.2.1-gke.4*
* 1.2.2-gke.2*

To simplify setup, this is designed to used the EAP bundled Seesaw load balancer scheduled to go GA later this year. No other load balancer support is planned at this time.

\*Due to a known bug in the EAP version, the script will automatically detect when using the EAP version and automatically delete the secondary LB in each group (admin and user cluster) to prevent the bug from occurring.

## Setup your GCS object store 
You will need a GCS  object store in order to download *closed source* packages such as *vCenter* and the *vSan SDK*. (See below for an S3 compatible object store option)

The setup will use a service account with Storage Admin permissions to download the needed files. You can create this service account on your own or use the helper script described below.

You will need to layout the GCS structure to look like this:

```
https://storage.googleapis.com:
    |
    |__ bucket_name/folder/
        |
        |__ VMware-VCSA-all-6.7.0-14367737.iso
        |
        |__ vsanapiutils.py
        |
        |__ vsanmgmtObjects.py
```
Your VMware ISO name may vary depending on which build you download.
These files can be downloaded from [My VMware](http://my.vmware.com).
Once logged in to "My VMware" the download links are as follows:
* [VMware vCenter Server 6.7U3](https://my.vmware.com/group/vmware/details?downloadGroup=VC67U3B&productId=742&rPId=40665) - VVMware vCenter Server Appliance ISO
* [VMware vSAN Management SDK 6.7U3](https://my.vmware.com/group/vmware/details?downloadGroup=VSAN-MGMT-SDK67U3&productId=734) - Virtual SAN Management SDK for Python

You will need to find the two individual Python files in the vSAN SDK zip file and place them in the GCS bucket as shown above.
 
 
## Download/Create your GCP Keys for your service accounts and activate APIs for your project
The GKE on-prem install requires several servicea accounts and keys to be created. See the [Google documenation](https://cloud.google.com/gke-on-prem/docs/how-to/service-accounts) for more detials. You can create these keys manually, or use a provided helper scrip to make the keys for you.

The Terraform files expect the keys to use the following naming convention, matching that of the Google documentation:
* register-key.json
* connect-key.json
* stackdriver-key.json
* whitelisted-key.json

If doing so manually, you must create each of these keys an place it in a folder named `gcp_keys` within the `anthos` folder. 
The service accounts also need to have IAM roles assigned to each of them. To do this manually, you'll need to follow the [instructions from Google](https://cloud.google.com/gke-on-prem/docs/how-to/service-accounts#assign_roles)


GKE on-prem also requires [several APIs](https://cloud.google.com/gke-on-prem/docs/how-to/gcp-project#enable_apis) to be activated on your target project.

Much easier (and recommended) is to use the helper script located in the `anthos` directory called `create_service_accounts.sh` to create these keys, assign the IAM roles, and activate the APIs. The script will allow you to log into GCP with your user account and select your Anthos white listed project. You'll also have an option to create a GCP service account to read from the GCS bucket. If you choose this option, you will create a `storage-reader-key.json`.

 
You can run this script as follows: 
#`anthos/create_service_accounts.sh`

Prompts will guide you through the setup. 
 
## Install Terraform 
Terraform is just a single binary.  Visit their [download page](https://www.terraform.io/downloads.html), choose your operating system, make the binary executable, and move it into your path. 
 
Here is an example for **macOS**: 
```bash 
curl -LO https://releases.hashicorp.com/terraform/0.12.18/terraform_0.12.18_darwin_amd64.zip 
unzip terraform_0.12.18_darwin_amd64.zip 
chmod +x terraform 
sudo mv terraform /usr/local/bin/ 
``` 
 
## Download this project
To download this project, run the following command:

```bash
git clone https://github.com/packet-labs/google-anthos.git
```

## Initialize Terraform 
Terraform uses modules to deploy infrastructure. In order to initialize the modules your simply run: `terraform init`. This should download five modules into a hidden directory `.terraform` 
 
## Modify your variables 
There are many variables which can be set to customize your install within `00-vars.tf` and `30-anthos-vars.tf`. The default variables to bring up a 3 node vSphere cluster and linux router using Packet's [c2.medium.x86](https://www.packet.com/cloud/servers/c2-medium-epyc/). Change each default variable at your own risk. 

There are some variables you must set with a terraform.tfvars files. You need to set `auth_token` & `organization_id` to connect to Packet and the `project_name` which will be created in Packet. You will need to set `anthos_gcp_project_id` for your GCP Project ID. We will need a GCS bucket to download "Closed Source" packages such as vCenter. The GCS related variables is `gcs_bucket_name`. You need to provide the vCenter ISO file name as `vcenter_iso_name`. 

The Anthos variables include `anthos_version`  and the `anthos_user_cluster_name`.
 
Here is a quick command plus sample values to start file for you (make sure you adjust the variables to match your environment, pay specail attention that the `vcenter_iso_name` matches whats in your bucket): 
```bash 
cat <<EOF >terraform.tfvars 
auth_token = "cefa5c94-e8ee-4577-bff8-1d1edca93ed8" 
organization_id = "42259e34-d300-48b3-b3e1-d5165cd14169" 
project_name = "anthos-packet-project-1"
anthos_gcp_project_id = "my-anthos-project" 
gcs_bucket_name = "bucket_name/folder/" 
vcenter_iso_name = "VMware-VCSA-all-6.7.0-XXXXXXX.iso" 
anthos_version = "1.2.2-gke.2"
anthos_user_cluster_name = "packet-cluster-1"
EOF 
``` 

## Using a S3 compatible object store (optional)


You have the option to use an S3 compatible object store in place of GCS in order to download *closed source* packages such as *vCenter* and the *vSan SDK*. [Minio](http://minio.io) works great for this, which is an open source object store is a workable option.

You will need to layout the S3 structure to look like this:
``` 
https://s3.example.com: 
    | 
    |__ vmware 
        | 
        |__ VMware-VCSA-all-6.7.0-14367737.iso
        | 
        |__ vsanapiutils.py
        | 
        |__ vsanmgmtObjects.py
``` 
These files can be downloaded from [My VMware](http://my.vmware.com).
Once logged in to "My VMware" the download links are as follows:
* [VMware vCenter Server 6.7U3](https://my.vmware.com/group/vmware/details?downloadGroup=VC67U3B&productId=742&rPId=40665) - VVMware vCenter Server Appliance ISO
* [VMware vSAN Management SDK 6.7U3](https://my.vmware.com/group/vmware/details?downloadGroup=VSAN-MGMT-SDK67U3&productId=734) - Virtual SAN Management SDK for Python
 
You will need to find the two individual Python files in the vSAN SDK zip file and place them in the S3 bucket as shown above.

For the cluster build to use the S3 option you'll need to change your variable file by adding the `s3_boolean = "true"` and including the `s3_url`, `s3_bucket_name`, `s3_access_key`, `s3_secret_key` in place of the gcs variables.

Here is the create variable file command again, modified for S3:
```bash 
cat <<EOF >terraform.tfvars 
auth_token = "cefa5c94-e8ee-4577-bff8-1d1edca93ed8" 
organization_id = "42259e34-d300-48b3-b3e1-d5165cd14169" 
project_name = "anthos-packet-project-1"
anthos_gcp_project_id = "my-anthos-project" 
s3_boolean = "true"
s3_url = "https://s3.example.com" 
s3_bucket_name = "vmware" 
s3_access_key = "4fa85962-975f-4650-b603-17f1cb9dee10" 
s3_secret_key = "becf3868-3f07-4dbb-a6d5-eacfd7512b09" 
vcenter_iso_name = "VMware-VCSA-all-6.7.0-XXXXXXX.iso" 
anthos_version = "1.2.2-gke.2"
anthos_user_cluster_name = "packet-cluster-1"
EOF 
```  
 
## Deploy the Packet vSphere cluster and Anthos GKE on-prem cluster 
 
All there is left to do now is to deploy the cluster: 
```bash 
terraform apply --auto-approve 
``` 
This should end with output similar to this: 
``` 
Apply complete! Resources: 50 added, 0 changed, 0 destroyed. 
 
Outputs: 
 
VPN_Endpoint = 139.178.85.49 
VPN_PSK = @U69neoBD2vlGdHbe@o1 
VPN_Pasword = 0!kfeooo?FaAvyZ2 
VPN_User = vm_admin 
vCenter_Appliance_Root_Password = n4$REf6p*oMo2eYr 
vCenter_FQDN = vcva.packet.local 
vCenter_Password = bzN4UE7m3g$DOf@P 
vCenter_Username = Administrator@vsphere.local 
``` 
 
## Size of the vSphere Cluster
The code supports deploying a single ESXi server or a 3+ node vSAN cluster. Default settings are for 3 ESXi nodes with vSAN.

When a single ESXi server is deployed, the datastore is extended to use all available disks on the server. The linux router is still deployed as a separate system.

To do a single ESXi server deployment, set the following variables in your `terraform.tfvars` file:

```bash
esxi_host_count          = 1
anthos_datastore         = "datastore1"
```
This has been tested with the c2.medium.x86. It may work with other systems as well, but it has not been fully tested.
We have not tested the maximum vSAN cluster size. Cluster size of 2 is not supported.


## Connect to the Environment 
There is an L2TP IPsec VPN setup. There is an L2TP IPsec VPN client for every platform. You'll need to reference your operating system's documentation on how to connect to an L2TP IPsec VPN. 

[MAC how to configure L2TP IPsec VPN](https://support.apple.com/guide/mac-help/set-up-a-vpn-connection-on-mac-mchlp2963/mac)

[Chromebook how to configure LT2P IPsec VPN](https://support.google.com/chromebook/answer/1282338?hl=en)

Make sure to enable all traffic to use the VPN (aka do not enable split tunneling) on your L2TP client.

Some corporate networks block outbound L2TP traffic. If you are experiening issues connecting, you may try a guest network or personal hotspot.

## Connect to the clusters
You will need to ssh into the router/gateway and from there ssh into the admin workstation where the kubeconfig files of your clusters are located.

```
ssh root@VPN_Endpoint
ssh -i /root/anthos/ssh-key ubuntu@172.16.0.3
```

The kubeconfig files for the admin and user clusters are located under ~/cluster, you can for example check the nodes of the admin cluster with the following command

```
kubectl --kubeconfig ~/cluster/kubeconfig get nodes
```

## Cleaning the environement
To clean up a created environment (or a failed one), run `terraform destroy --auto-approve`.

If this does not work for some reason, you can manually delete each of the resources created in Packet (including the project) and then delete your terraform state file, `rm -f terraform.tfstate`.

## Skipping the Anthos GKE on-prem cluster creation steps
If you wish to create the environment (including deploy the admin workstation and Anthos pre-res) but skip the cluster creation (so that you can practice creating a cluster on your own) add `anthos_deploy_clusters = "False"` to your terraform.tfvars file. This will still run the pre-requisits for the GKE on-prem install including setting up the admin workstation.

To create just the vSphere environment and skip all Anthos related steps, add `anthos_deploy_workstation_prereqs = false`.

> Note that `anthos_deploy_clusters` uses a string of either `"True"` or `"False"` while  `anthos_deploy_workstation_prereqs` usses a boolean of `true` or `flase`. This is because the `anthos_deploy_clusters` variable is used within a bash script while `anthos_deploy_workstation_prereqs` is used by Terraform which supports booleans.

See [anthos/cluster/bundled-lb-admin-uc1-config.yaml.sample](https://github.com/packet-labs/google-anthos/blob/master/anthos/cluster/bundled-lb-admin-uc1-config.yaml.sample) to see what the Anthos parameters are when the default settings are used to create the environment.

## Use an existing Packet project
If you have an existing Packet project you can use it assuming the project has at least 5 available vlans, Packet project has a limit of 12 Vlans and this setup uses 5 of them.

Get your Project ID, navigate to the Project from the packet.com console and click on PROJECT SETTINGS, copy the PROJECT ID.

add the following variables to your terraform.tfvars

```
create_project                    = false
project_id                        = "YOUR-PROJECT-ID"
```

## Changing default Anthos GKE on-prem cluster defaults
Check the `30-anthos-vars.tf` file for additional values (including number of user worker nodes and vCPU/RAM settings for the worker nodes) which can be set via the terraform.tfvars file.


## Troubleshooting
Some common issues and fixes.

### Error: The specified project contains insufficient public IPv4 space to complete the request. Please e-mail help@packet.com.

Should be resolved in https://github.com/packet-labs/google-anthos/commit/f6668b1359683eb5124d6ab66457f3680072651a

Due to recent changes to the Packet API, new organizations may be unable to use the Terraform to build ESXi servers. Packet is aware of the issue and is planning some fixes. In the meantime, if you hit this issue, email help@packet.com and request that your organization be white listed to deploy ESXi servers with the API. You should reference this project (https://github.com/packet-labs/google-anthos) in your email.

### Error: POST https://api.packet.net/ports/e2385919-fd4c-410d-b71c-568d7a517896/disbond:

At times the Packet API fails to recognize the ESXi host can be enabled for Layer 2 networking (more accurately Mixed/hybrid mode). The terraform will exit and you'll see
```bash
Error: POST https://api.packet.net/ports/e2385919-fd4c-410d-b71c-568d7a517896/disbond: 422 This device is not enabled for Layer 2. Please contact support for more details. 

  on 04-esx-hosts.tf line 1, in resource "packet_device" "esxi_hosts":
   1: resource "packet_device" "esxi_hosts" {
```

If this happens, you can issue `terraform apply --auto-approve` again and the problematic ESXi host(s) should be deleted and recreated again properly. Or you can perform `terraform destroy --auto-approve` and start over again.

### null_resource.download_vcenter_iso (remote-exec): E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)

Occasionally the Ubuntu automatic unattended upgrades will run at an unfortunte time and lock apt while the script is attempting to run. 

Should this happen, best resolution is to clean up your deployment and try again. 

### SSH_AUTH_SOCK: dial unix /tmp/ssh-vPixj98asT/agent.11502: connect: no such file or directory

A failed deployment which results in the following output:
```bash
Error: Error connecting to SSH_AUTH_SOCK: dial unix /tmp/ssh-vPixj98asT/agent.11502: connect: no such file or directory



Error: Error connecting to SSH_AUTH_SOCK: dial unix /tmp/ssh-vPixj98asT/agent.11502: connect: no such file or directory



Error: Error connecting to SSH_AUTH_SOCK: dial unix /tmp/ssh-vPixj98asT/agent.11502: connect: no such file or directory



Error: Error connecting to SSH_AUTH_SOCK: dial unix /tmp/ssh-vPixj98asT/agent.11502: connect: no such file or directory
```

This could be because you are using a terminal emulation such as `screen`or `tmux` and the SSH agent is not running. May be corrected by running the command `ssh-agents bash` prior to running the `terraform apply --auto-approve` command.

