import json, collections, re, glob, os
P={'claude-opus-5-5':(4,5,0.2,20),'claude-opus-5':(5,6.25,0.5,25),'claude-fable-5-1':(10,12.5,0.25,50),'claude-fable-5':(10,12.5,1.0,50)}
def cost(r):
    p=P.get(r['model'],(4,5,0.2,20))
    return (r['input_tokens']*p[0]+r['cache_creation_input_tokens']*p[1]+r['cache_read_input_tokens']*p[2]+r['output_tokens']*p[3])/1e6
rows=json.load(open('rows.json'))
for r in rows: r['usd']=cost(r)
tot=sum(r['usd'] for r in rows); print(f"TOTAL ~${tot:,.0f}")
by=collections.defaultdict(float)
for r in rows: by[(r['kind'],r['model'])]+=r['usd']
for k,v in sorted(by.items(),key=lambda x:-x[1]): print(f"  {k[0]:9}{k[1]:18} ${v:8,.0f}  {v/tot:5.1%}")
# share of cost by component for opus-5-5
for kind in ('main','workflow','agent'):
    rr=[r for r in rows if r['kind']==kind]
    p=collections.Counter()
    for r in rr:
        pr=P.get(r['model'])
        p['read']+=r['cache_read_input_tokens']*pr[2]/1e6; p['write']+=r['cache_creation_input_tokens']*pr[1]/1e6; p['out']+=r['output_tokens']*pr[3]/1e6
    print(kind, {k:round(v) for k,v in p.items()})
# workflow: label role (strip #n and suffix)
role=collections.defaultdict(lambda:[0,0.0,0,collections.Counter()])
for r in rows:
    if r['kind']=='workflow':
        lab=re.sub(r'#\d+.*','',r['desc']); lab=re.sub(r'\d+','N',lab)
        key=(r['phase'] or '-')+' | '+lab
    elif r['kind']=='agent': key='AGENT '+r['type']+' | '+r['desc'][:50]
    else: continue
    x=role[key]; x[0]+=1; x[1]+=r['usd']; x[2]+=r['calls']; x[3][r['model']]+=1
print('\nTOP roles by cost')
for k,v in sorted(role.items(),key=lambda x:-x[1][1])[:45]:
    print(f"${v[1]:7,.0f} runs={v[0]:3} calls/run={v[2]/v[0]:5.0f} {dict(v[3])}  {k[:95]}")
