provider "vsphere" {
vsphere_server = "vcslab01.dc.com"
user = "administrator@vsphere.local"
password = "XXXXX"
#if you have a self-signed cert
allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "Lab"
}


data "vsphere_resource_pool" "pool" {
  name          = "vcslab01.dc.com/Resources"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datastore" "datastore" {
name = "XYZ" #Name of the datastore
datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
name = "VM Network"
datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "Win2K16" #Name of the template present in your Vcenter
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "vm"{
  name             = "Windows2016_terraform"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore1.id}"
  
  num_cpus = 4
  cpu_hot_add_enabled = "true"
  memory   = 12288
  memory_hot_add_enabled = "true"
  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout = 0
  firmware = "efi"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0.vmdk"
    #size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    size             = 120
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      windows_options {
        computer_name = "terraform-test"
        admin_password = "XXXX"
        auto_logon = true
        auto_logon_count = 1
        full_name = "Administrator"        
      }


      network_interface {
        ipv4_address = "x.x.x.x"
        ipv4_netmask = 24
      }

    ipv4_gateway = "x.x.x.x"
}

}
  provisioner "local-exec" {
    command = "copy-item C:\\terraform\\Install_Minion.ps1 -destination C:\\ -ToSession (New-PSSession -ComputerName x.x.x.x -Credential (new-object -typename System.Management.Automation.PSCredential -argumentlist local\\Administrator, (convertto-securestring -AsPlainText -Force -String W2K4u$)))"
    interpreter = ["PowerShell", "-Command"]
  }

  provisioner "local-exec" {
    command = "Invoke-Command -ComputerName x.x.x.x -Credential (new-object -typename System.Management.Automation.PSCredential -argumentlist local\\Administrator, (convertto-securestring -AsPlainText -Force -String xxxx)) -ScriptBlock { C:\\Install_Minion.ps1 }"
    interpreter = ["PowerShell", "-Command"]
  }
}
