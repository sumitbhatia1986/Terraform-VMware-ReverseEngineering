# -*- coding: utf-8 -*-
"""
Created on Sat Feb 18 13:11:43 2023

@author: SBhatia3
"""
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from pyVim import connect
import ssl
from pyVmomi import vim

app_settings = {
    'api_pass': "xxxxxxx",
    'api_user': "administrator@vsphere.local",
    'api_url': "https://x.x.x.x/rest/",
    'vcenter_ip': "x.x.x.x",
    'VM_name': "Test" ### Desired VM for which we need to find details
    #'vpshere_server': "xx.xx.xx.xx",
    #'vsphere_datacenter': "Test"
}


## Authenticate with Vcenter to find the VM ID
def auth_vcenter(username, password):
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
        vm_name = child.name
        
print("VM name: ", vm_name)
print ("VM guestFullName: ", vm_config.guestFullName)
print("VM guestID: ", vm_config.guestId)
