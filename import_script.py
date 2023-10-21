# -*- coding: utf-8 -*-
"""
Created on Mon Dec  7 17:42:16 2022

@author: Sbhatia3
"""
import json
import requests
import sys
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from pyVim import connect
import ssl
from pyVmomi import vim
import re
import collections

#Defining class for structural collection of Config file parameters.
class OrderedConfig(collections.OrderedDict):
    pass

app_settings = {
    'api_pass': "XXXX",
    'api_user': "administrator@vsphere.local",
    'api_url': "https://<vCenter FQDN>/rest/",
    'vcenter_ip': "xx.xx.xx.xx",
    'VM_name': "UbantuTest", ### Desired VM for which we need to find details
    'vsphere_datacenter': "ECM"
}

## Authenticate with Vcenter to find the VM ID
def auth_vcenter(username, password):
    #print('Authenticating to vCenter, user: {}'.format(username))
    resp = requests.post(
        '{}/com/vmware/cis/session'.format(app_settings['api_url']),
        auth=(app_settings['api_user'], app_settings['api_pass']),
        verify=False
    )
    if resp.status_code != 200:
        print('Error! API responded with: {}'.format(resp.status_code))
        return
    return resp.json()['value']

def get_api_data(req_url):
    sid = auth_vcenter(app_settings['api_user'], app_settings['api_pass'])
    #print('Requesting Page: {}'.format(req_url))
    resp = requests.get(req_url, verify=False, headers={'vmware-api-session-id': sid})
    if resp.status_code != 200:
        print('Error! API responded with: {}'.format(resp.status_code))
        return
    return resp

## Getting VM details including VM ID needed to browser through MOB
def get_vm(vm_name):
    resp = get_api_data('{}/vcenter/vm?filter.names={}'.format(app_settings['api_url'], vm_name))
    j = resp.json()
    return (j)

#Fetching VM ID from REST API for the VM we want to import
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
vmdetails = get_vm(app_settings['VM_name'])
vmid = vmdetails['value'][0]['vm']

s = ssl._create_unverified_context()
service_instance = connect.SmartConnect(
    host=app_settings['vcenter_ip'], user=app_settings['api_user'], pwd=app_settings['api_pass'], sslContext=s
)
content = service_instance.RetrieveContent()
container = content.rootFolder  # starting point to look into
viewType = [vim.VirtualMachine]  # object types to look for
recursive = True  # whether we should look into it recursively
containerView = content.viewManager.CreateContainerView(container, viewType, recursive)  # create container view
children = containerView.view
for child in children:  # for each statement to iterate all names of VMs in the environment
    if (str(vmid) in str(child)):
        vm_summary = child.summary  #Summary of the desired VM to import
        vm_config = child.config #Complete config data hiararchy and child item values loaded in the variable
        vm_resourcepool = child.resourcePool #Resource pool details
        vm_network = child.network #Network details of the VM
        vm_datastore = child.datastore
        vm_parent = child.parent

# Config file structure and populating with corresponding values fetched with MOB
data = OrderedConfig()
data["provider"] = OrderedConfig()
data["provider"]["vsphere"] = OrderedConfig()
data["provider"]["vsphere"]["user"] = "sampleuser"
data["provider"]["vsphere"]["password"] = "samplepassword"
data["provider"]["vsphere"]["allow_unverified_ssl"] = "true"

#Posting resource pool details
resourcepool_string = str(vm_resourcepool.owner.name) + '/' + str(vm_resourcepool.name)
data["data"] = OrderedConfig()

data["data"]["vsphere_datacenter"] = OrderedConfig()
data["data"]["vsphere_datacenter"]["dc"] = OrderedConfig()
data["data"]["vsphere_datacenter"]["dc"]["name"] = app_settings['vsphere_datacenter']

data["data"]["vsphere_resource_pool"] = OrderedConfig()
data["data"]["vsphere_resource_pool"]["pool"] = OrderedConfig()
data["data"]["vsphere_resource_pool"]["pool"]["name"] = resourcepool_string
data["data"]["vsphere_resource_pool"]["pool"]["datacenter_id"] = "${data.vsphere_datacenter.dc.id}"

#Posting datastore details
datastore_string = str(vm_datastore[0].name)
data["data"]["vsphere_datastore"] = OrderedConfig()
data["data"]["vsphere_datastore"]["datastore"] = OrderedConfig()
data["data"]["vsphere_datastore"]["datastore"]["name"] = datastore_string
data["data"]["vsphere_datastore"]["datastore"]["datacenter_id"] = "${data.vsphere_datacenter.dc.id}"

#Posting virtual machine details
datastore_string = str(vm_datastore[0].name)
data["data"]["vsphere_virtual_machine"] = OrderedConfig()
data["data"]["vsphere_virtual_machine"]["template"] = OrderedConfig()
data["data"]["vsphere_virtual_machine"]["template"]["name"] = str(vm_config.name)
data["data"]["vsphere_virtual_machine"]["template"]["datacenter_id"] = "${data.vsphere_datacenter.dc.id}"

#for all network adapter, creating a stack, adapter details in order
network_adapter = []
for item_netadapter in vm_config.hardware.device:
    if (str("Network adapter") in str(item_netadapter.deviceInfo.label)):
        vm_networkadapter = item_netadapter
        #Posting adapter type for Network interface details
        if (str("E1000e") in str(type(vm_networkadapter))):
            network_adapter.append("e1000e")
        if (str("Vmxnet3") in str(type(vm_networkadapter))):
            network_adapter.append("vmxnet3")

data["resource"] = OrderedConfig()
data["resource"]["vsphere_virtual_machine"] = OrderedConfig()
data["resource"]["vsphere_virtual_machine"]["jsontemplate"] = OrderedConfig()

#Posting network details and adding network interface details at same order
for index, nic in enumerate(vm_network): 
  network_string = str(nic.name)
  data["data"]["vsphere_network"+str(index)] = OrderedConfig()
  data["data"]["vsphere_network"+str(index)]["network"+str(index)] = OrderedConfig()
  data["data"]["vsphere_network"+str(index)]["network"+str(index)]["name"] = network_string
  data["data"]["vsphere_network"+str(index)]["network"+str(index)]["datacenter_id"] = "${data.vsphere_datacenter.dc.id}"

for index, nic in reversed(list(enumerate(vm_network))): 
  #adding network interface details
  #network_string = str(nic.name)
  #print(nic.name)
  data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["network_interface"+str(index)] = { "adapter_type" : network_adapter.pop() }
  data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["network_interface"+str(index)]["network_id"] = str("${data.vsphere_network."+"network"+str(index)+".id}")

#########################################################################
#########################################################################
###################Posting other VM generic details######################
#########################################################################
#########################################################################

#Posting Name of the Virtual machine
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["name"] = str(vm_config.name)
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["folder"] = vm_parent.name
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["resource_pool_id"
                                                            ] = "${data.vsphere_resource_pool.pool.id}"
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["datastore_id"] = "${data.vsphere_datastore.datastore.id}"
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["boot_retry_enabled"
                                                            ] = vm_config.bootOptions.bootRetryEnabled
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["enable_disk_uuid"] = vm_config.flags.diskUuidEnabled
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["enable_logging"] = vm_config.flags.enableLogging
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["num_cores_per_socket"
                                                            ] = vm_config.hardware.numCoresPerSocket

#Posting Number of CPU's
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["num_cpus"] = vm_config.hardware.numCPU

data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["guest_id"] = str(vm_config.guestId)
#Posting Memory
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["memory"] = vm_config.hardware.memoryMB

#Posting guestid
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["guest_id"] = str(vm_config.guestId)

#Posting CPU Hot add enabled flag info
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["cpu_hot_add_enabled"] = str(vm_config.cpuHotAddEnabled
                                                                                         ).lower()

#Posting Memory hot add enabled flag info
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["memory_hot_add_enabled"] = str(
    vm_config.memoryHotAddEnabled
).lower()

#Posting firmware information
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["firmware"] = str(vm_config.firmware).lower()

#Posting scsi type information
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["scsi_type"] = "${data.vsphere_virtual_machine.template.scsi_type}"

#Posting ignore tags and custom attribute changes
data["resource"]["vsphere_virtual_machine"]["jsontemplate"]["lifecycle"] = { "ignore_changes": ["custom_attributes", "tags"]}
disk_starting_name = "disk"
no_of_disk = 0

#Posting disk information
for item_virtualdisk in vm_config.hardware.device:
    if (str("VirtualDisk") in str(type(item_virtualdisk))):
        diskname = disk_starting_name + str(no_of_disk)
        data["resource"]["vsphere_virtual_machine"]["jsontemplate"][diskname] = OrderedConfig()
        data["resource"]["vsphere_virtual_machine"]["jsontemplate"][diskname]["label"] = "disk" + str(
            item_virtualdisk.unitNumber
        )
        data["resource"]["vsphere_virtual_machine"]["jsontemplate"][diskname]["size"] = int(
            item_virtualdisk.capacityInKB / 1048576
        )
        data["resource"]["vsphere_virtual_machine"]["jsontemplate"][diskname]["unit_number"] = item_virtualdisk.unitNumber
        data["resource"]["vsphere_virtual_machine"]["jsontemplate"][diskname]["thin_provisioned"] = str(
            item_virtualdisk.backing.thinProvisioned
        ).lower()
        data["resource"]["vsphere_virtual_machine"]["jsontemplate"][diskname]["path"] = str(
            item_virtualdisk.backing.fileName
        )
        data["resource"]["vsphere_virtual_machine"]["jsontemplate"][diskname]["keep_on_remove"] = "true"
        no_of_disk += 1

for key in data:
    if (key == 'resource'):
        for t in data[key]:
            if (t == 'vsphere_virtual_machine'):
                data[key][t][str(vm_config.name)] = data[key][t].pop('jsontemplate')

#getting json string (Order changing issue)
json_string = json.dumps(data, indent = 4)

#replacing all different diskname(eg: disk0) to "disk" itself
for i in range(no_of_disk):
    replace_string = '"disk'+ str(i) +'": {'
    json_string = re.sub(replace_string, '"disk": {', json_string) 

#replacing all different diskname(eg: "vsphere_network0") to "vsphere_network" itself
for i in range(len(vm_network)):
    replace_string = '"vsphere_network'+ str(i) +'": {'
    json_string = re.sub(replace_string, '"vsphere_network": {', json_string) 

#replacing all different diskname(eg: "network_interface0") to "network_interface" itself
for i in range(len(vm_network)):
    replace_string = '"network_interface'+ str(i) +'": {'
    json_string = re.sub(replace_string, '"network_interface": {', json_string)       

sys.stdout.write(json_string)

#outputting config JSON file
with open("main.tf.json", "w") as outfile:
    outfile.write(json_string)
