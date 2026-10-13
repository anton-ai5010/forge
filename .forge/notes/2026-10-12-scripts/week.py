import json, glob, os, collections, time, datetime
SINCE = datetime.datetime(2026,10,12,0,0,tzinfo=datetime.timezone(datetime.timedelta(hours=3)))
P={'claude-opus-5-5':(4,5,0.2,20),'claude-opus-5':(5,6.25,0.5,25),'claude-fable-5-1':(10,12.5,0.25,50),'claude-fable-5':(10,12.5,1.0,50),'claude-sonnet-5-5':(2,2.5,0.2,10),'claude-haiku-4-5':(1,1.25,0.1,5),'claude-haiku-4-5-20251001':(1,1.25,0.1,5)}
K=('input_tokens','cache_creation_input_tokens','cache_read_input_tokens','output_tokens')
root=os.path.expanduser('~/.claude/projects')
agg=collections.defaultdict(float); bymodel=collections.defaultdict(float); bysess=collections.defaultdict(float); sess_ctx={}
since_ts=SINCE.timestamp()
for p in glob.glob(root+'/**/*.jsonl',recursive=True):
    if os.path.getmtime(p)<since_ts or p.endswith('journal.jsonl'): continue
    rel=p[len(root)+1:]; proj=rel.split('/')[0].replace('-Users-mac-Projects-','')
    kind='main' if rel.count('/')==1 else ('workflow' if '/workflows/' in rel else 'agent')
    sid=rel.split('/')[1][:8]
    msgs={}
    for line in open(p,errors='ignore'):
        try:d=json.loads(line)
        except:continue
        if d.get('type')!='assistant':continue
        ts=d.get('timestamp')
        if not ts: continue
        try: t=datetime.datetime.fromisoformat(ts.replace('Z','+00:00'))
        except: continue
        if t<SINCE: continue
        m=d.get('message') or {}; u=m.get('usage'); mod=m.get('model','?')
        if not u or mod=='<synthetic>':continue
        cur=msgs.setdefault(m.get('id'),[mod,collections.Counter()])
        for k in K: cur[1][k]=max(cur[1][k],u.get(k) or 0)
    for mod,c in msgs.values():
        pr=P.get(mod,(4,5,0.2,20)); usd=(c['input_tokens']*pr[0]+c['cache_creation_input_tokens']*pr[1]+c['cache_read_input_tokens']*pr[2]+c['output_tokens']*pr[3])/1e6
        agg[(proj,kind)]+=usd; bymodel[mod]+=usd; bysess[(proj,sid,kind)]+=usd
tot=sum(agg.values()); print(f"TOTAL since Mon ~${tot:,.0f} (API-equivalent)")
pj=collections.defaultdict(float)
for (pr,k),v in agg.items(): pj[pr]+=v
print('\nBY PROJECT'); [print(f"  {v/tot:5.1%} ${v:6.0f} {k}") for k,v in sorted(pj.items(),key=lambda x:-x[1])]
print('\nBY KIND'); kk=collections.defaultdict(float)
for (pr,k),v in agg.items(): kk[k]+=v
[print(f"  {v/tot:5.1%} {k}") for k,v in sorted(kk.items(),key=lambda x:-x[1])]
print('\nBY MODEL'); [print(f"  {v/tot:5.1%} {k}") for k,v in sorted(bymodel.items(),key=lambda x:-x[1])]
print('\nTOP SESSIONS (main + their agents merged)')
ss=collections.defaultdict(float)
for (pr,sid,k),v in bysess.items(): ss[(pr,sid)]+=v
[print(f"  {v/tot:5.1%} ${v:5.0f} {k[0]} {k[1]}") for k,v in sorted(ss.items(),key=lambda x:-x[1])[:10]]
