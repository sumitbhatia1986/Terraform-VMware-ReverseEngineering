import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
import os
import json
import base64
import time
 
 
## Definition of Salt Stack enterprise connections
def connect_api(sse,user=None,password=None,config='internal',timeout=30,jsonfile=None):
    if jsonfile is not None:
        with open(jsonfile, 'r') as outfile:
            encpass=json.load(outfile)
        payload= { 'config_name' : base64.b64decode(encpass['data3']).decode('utf-8'), 'username' : base64.b64decode(encpass['data1']).decode('utf-8'), 'password' : base64.b64decode(encpass['data2']).decode('utf-8') }
        user=base64.b64decode(encpass['data1']).decode('utf-8')
    else:
        payload= { 'config_name' : config, 'username' : user, 'password' : password }
    if jsonfile is None and ( user is None or password is None):
        print("user or password is not set, please provide user and paasword or jsonfile")
        return None
    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
    url='https://'+ sse
    r1 = requests.request('GET', url  + '/version', verify=False)
    headers = {}
    headers['X-Xsrftoken'] = r1.headers['X-Xsrftoken']
    r2 = requests.request('POST', url + '/account/login', cookies=r1.cookies, headers=headers, data=json.dumps(payload), verify=False)
    if r2.status_code != 200:
        print('Login Failed for user %s , config %s, to %s with error code %s' % (user,config,url,r2.status_code))
        return None
    return r2
 
## Definition of calling specific API on Salt Stack enterprise
def call_api(client,data,output='text'):
    if type(data) is dict:
        data=json.dumps(data)
    host = client.url.split('/')[2]
    headers = {}
    headers['X-Xsrftoken'] = client.headers['X-Xsrftoken']
    headers['Accept'] = 'application/json'
    headers['Content-Type'] = 'application/json'
    split_cookie = client.headers['Set-Cookie'].split(';')
    headers['Cookie'] = split_cookie[0] + '; _xsrf=' + client.headers['X-Xsrftoken']
    #payload = { "resource": "test", "method": "echo", "kwarg": { "message": "Test Message from API"}}
    r3 = requests.request('POST', 'https://' + host + '/rpc', data=data, headers=headers, verify=False)
    if r3.status_code != 200:
        print("Failed")
        return None
    if output == 'dict':
        return json.loads(r3.text)
    if output == 'text':
        return r3.text
    elif output == 'json':
        return r3.json
    else:
        return r3
 

##Definition of accepting new minion key on Salt Stack enterprise
def accept_key(client,minion,master):
    #logit(NORM,"Accepting Minion key %s on %s wthout keycheck" % (add_minion,master_name))
    payload={"resource": "cmd", "method": "route_cmd", "kwarg": { "cmd":"wheel", "fun" : "key.accept" , "masters" : [ master, ], "arg": { "arg" : [ minion, ]}}}
    result=call_api(client,payload,output='dict')
    # {'riq': 140654342854920, 'error': None, 'ret': '20200502041037126948', 'warnings': []}
    if result['error']:
        result['info'] = "Key Accept Error for minion %s on master %s" % (minion,master)
        return result
    result['info'] = "Accepted key for minion %s on master %s" % (minion,master)
    return result
 
