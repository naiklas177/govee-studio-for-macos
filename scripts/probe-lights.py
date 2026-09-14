#!/usr/bin/env python3
"""Bounded on-device interop check. Close Govee Studio first. Restores basic state."""
import argparse, base64, json, socket, time, pathlib, functools, operator
p=argparse.ArgumentParser()
p.add_argument('--mode', choices=['whole','auto','dream','desktop','chroma'], default='whole')
p.add_argument('--stretch',type=int,choices=[0,1],default=0)
p.add_argument('--seconds',type=float,default=4)
p.add_argument('--sku',default='')
p.add_argument('--channels',type=int,choices=range(1,85))
p.add_argument('--channel-test',action='store_true')
p.add_argument('--reuse-recovery',action='store_true')
a=p.parse_args()
config=json.loads((pathlib.Path.home()/'Library/Application Support/GoveeStudio/workspace.json').read_text())
devices=[d for d in config['devices'] if not a.sku or d['sku']==a.sku]
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
s.bind(('',4002)); s.settimeout(0.2)
def send(ip,cmd,data):
    s.sendto(json.dumps({'msg':{'cmd':cmd,'data':data}},separators=(',',':')).encode(),(ip,4003))
def state(ip):
    for _ in range(3):
        send(ip,'devStatus',{})
        until=time.monotonic()+0.7
        while time.monotonic()<until:
            try:
                raw,src=s.recvfrom(8192)
                j=json.loads(raw)
                if src[0]==ip and j.get('msg',{}).get('cmd')=='devStatus': return j['msg']['data']
            except socket.timeout: pass
    raise RuntimeError('No state from '+ip)
saved={d['ip']:state(d['ip']) for d in devices}
recovery=pathlib.Path(__file__).resolve().parent.parent/'.local/probe-recovery.json'
recovery.parent.mkdir(exist_ok=True)
if a.reuse_recovery:
    saved=json.loads(recovery.read_text())
else:
    recovery.write_text(json.dumps(saved,indent=2))
print(json.dumps({'mode':a.mode,'before':saved}),flush=True)
try:
    for d in devices:
        ip=d['ip']
        send(ip,'razer',{'pt':'uwABsQAL'}); time.sleep(0.15)
        send(ip,'turn',{'value':1}); time.sleep(0.15)
        send(ip,'brightness',{'value':35 if a.channel_test else 60}); time.sleep(0.15)
        if a.mode!='whole':
            send(ip,'razer',{'pt':'uwABsQEK'}); time.sleep(0.15)
    for phase,color in enumerate([(255,0,0),(0,220,30),(0,50,255)]):
        print(json.dumps({'phase_rgb':color,'channel':phase+1 if a.channel_test else None}),flush=True)
        until=time.monotonic()+a.seconds
        while time.monotonic()<until:
            for d in devices:
                if a.mode=='whole': send(d['ip'],'colorwc',{'color':dict(zip('rgb',color)), 'colorTemInKelvin':0})
                else:
                    n=a.channels or len(d['zones'])
                    header=2+3*n if a.mode=='auto' else {'dream':250,'desktop':32,'chroma':14}[a.mode]
                    values=list(color)*n
                    if a.channel_test:
                        values=[2,2,4]*n
                        values[phase*3:phase*3+3]=[20,210,255]
                    b=bytearray([0xBB,0,header,0xB0,a.stretch,n]+values)
                    b.append(functools.reduce(operator.xor,b))
                    send(d['ip'],'razer',{'pt':base64.b64encode(b).decode()})
            time.sleep(0.05 if a.mode!='whole' else 0.25)
        print(json.dumps({'reported':[{'ip':d['ip'],'state':state(d['ip'])} for d in devices]}),flush=True)
finally:
    restored={}
    failed={}
    for ip,old in saved.items():
        for attempt in range(3):
            try:
                send(ip,'razer',{'pt':'uwABsQAL'}); time.sleep(0.25)
                send(ip,'colorwc',{'color':old['color'],'colorTemInKelvin':old.get('colorTemInKelvin',0)}); time.sleep(0.15)
                send(ip,'brightness',{'value':old['brightness']}); time.sleep(0.15)
                send(ip,'turn',{'value':old['onOff']}); time.sleep(0.25)
                current=state(ip)
                restored[ip]=current
                if current['onOff']==old['onOff'] and current['brightness']==old['brightness']: break
            except Exception as error:
                print(json.dumps({'restore_attempt':attempt,'error':str(error)}),flush=True)
            time.sleep(0.35)
        else: failed[ip]=old
    print(json.dumps({'restored':restored,'pending':failed}),flush=True)
    s.close()
    if failed:
        recovery.write_text(json.dumps(failed,indent=2))
        raise RuntimeError('Restoration incomplete; recovery file retained')
    recovery.unlink(missing_ok=True)
