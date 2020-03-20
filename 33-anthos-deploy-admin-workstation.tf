data "template_file" "anthos_workstation_tf_vars" {
  template = file("anthos/static-ip.tfvars")
  vars = {
    vcenter_username = "Administrator@vsphere.local"
    vcenter_password = random_string.sso_password.result
    vcenter_fqdn     = format("vcva.%s", var.domain_name)

    vsphere_datastore     = var.anthos_datastore
    vsphere_datacenter    = var.vcenter_datacenter_name
    vsphere_cluster       = var.vcenter_cluster_name
    vsphere_resource_pool = var.anthos_resource_pool_name
    vsphere_network       = format("%s Net", var.vcenter_portgroup_name)
    anthos_version        = var.anthos_version
  }
}

data "template_file" "anthos_upload_ova_template" {
  template = file("anthos/upload_ova.sh")
  vars = {
    anthos_version       = var.anthos_version
    vmware_fqdn          = format("vcva.%s", var.domain_name)
    vmware_username      = "Administrator@vsphere.local"
    vmware_password      = random_string.sso_password.result
    vmware_datastore     = var.anthos_datastore
    vmware_resource_pool = var.anthos_resource_pool_name
  }
}

data "template_file" "anthos_replace_tf_vars" {
  template = file("anthos/replace_tf_vars.py")
  vars = {
    private_subnets = jsonencode(var.private_subnets)
    vsphere_network = var.vcenter_portgroup_name
    domain_name     = var.domain_name
  }
}

resource "null_resource" "anthos_deploy_workstation" {
  count      = var.anthos_deploy_workstation_prereqs ? 1 : 0
  depends_on = [null_resource.deploy_vcva, null_resource.vsan_claim]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    host        = packet_device.router.access_public_ipv4
  }

  provisioner "file" {
    content     = data.template_file.anthos_upload_ova_template.rendered
    destination = "/root/anthos/upload_ova.sh"
  }

  provisioner "file" {
    content     = file("anthos/static-ip.tf")
    destination = "/root/anthos/static-ip.tf"
  }

  provisioner "file" {
    content     = data.template_file.anthos_workstation_tf_vars.rendered
    destination = "/root/anthos/terraform.tfvars"
  }

  provisioner "file" {
    content     = data.template_file.anthos_replace_tf_vars.rendered
    destination = "/root/anthos/replace_tf_vars.py"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /root/anthos/",
      "chmod +x /root/anthos/upload_ova.sh",
      "/root/anthos/upload_ova.sh",
      "python3 /root/anthos/replace_tf_vars.py",
      "terraform init",
      "terraform apply --auto-approve"
    ]
  }
}
