import sse_api

user='sample_vmwareuser'
password='XXXXXXXX'
sse='saltstack.dev.com'
minion='terraform-test'
master='Master1'
 
 
client=sse_api.connect_api(sse,user=user,password=password,config='internal',timeout=120)
print(client)

# client should be <Response [200]>
if client.status_code != 200:
    print('connection failed')
    exit
result=sse_api.accept_key(client,minion,master)
print(result)
#
#  good result
# {'riq': 280033949565225, 'ret': '20200708144749932103', 'error': None, 'warnings': [], 'info': 'Accepted key for minion xxxxxxx on master xxxxxxx'}
#
# note this does not check if key actually exists, you just get confirmation your call was passed to master
#
