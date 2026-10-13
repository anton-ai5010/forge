import json, glob, os, re, collections, datetime, argparse
TZ = datetime.timezone(datetime.timedelta(hours=3))
def pt(s):
    d = datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))
    return d if d.tzinfo else d.replace(tzinfo=TZ)
ap = argparse.ArgumentParser()
ap.add_argument('--since', default='2026-10-12T00:00+03:00')
ap.add_argument('--until', default=None)
ap.add_argument('--project', default=None, help='substring of project folder name (after -Users-mac-Projects-)')
A = ap.parse_args()
SINCE = pt(A.since); UNTIL = pt(A.until) if A.until else None

# ROLE_GROUPS: frozen. Prefix = label before ':' (or first word), lowercased.
ROLE_GROUPS = {
 'implement': ['impl', 'implement', 'build', 'apply', 'write', 'batch'],
 'review': ['review', 're-review', 'reviewer', 'critic', 'critique', 'skeptic', 'pragmatist', 'architect',
            'user-advocate', 'audit', 'cross', 'check', 'consistency-editor', 'compare', 'fairness', 'challenge'],
 'verify': ['verify', 'verify0', 'verify1', 'verify2', 'verify3', 'confirm', 'validate', 'проверка'],
 'final-review': ['final-review', 'final', 'итог', 'synthesize'],
 'fix': ['fix', 'refix', 'revise', 'resolve', 'resolver'],
 'codex': ['codex'],
 'explore/scout': ['map', 'map0', 'map1', 'read', 'research', 'understand', 'анализ', 'investigate', 'find'],
 'other-known': ['plan', 'planner', 'design', 'draft'],
}
PREFIX2GROUP = {p: g for g, ps in ROLE_GROUPS.items() for p in ps}
def role_of(label):
    s = re.sub(r'\s*\(retry \d+\)\s*', '', label or '').strip().lower()
    pre = s.split(':')[0].strip() if ':' in s else (s.split()[0] if s.split() else '?')
    return pre
def group_of(pre):
    for c in (pre, re.sub(r'\d+$', '', pre), pre.split('-')[0]):
        if c in PREFIX2GROUP: return PREFIX2GROUP[c]
    return None

P={'claude-opus-5-5':(4,5,0.2,20),'claude-opus-5':(5,6.25,0.5,25),'claude-fable-5-1':(10,12.5,0.25,50),'claude-fable-5':(10,12.5,1.0,50),'claude-sonnet-5-5':(2,2.5,0.2,10),'claude-haiku-4-5':(1,1.25,0.1,5),'claude-haiku-4-5-20251001':(1,1.25,0.1,5)}
K=('input_tokens','cache_creation_input_tokens','cache_read_input_tokens','output_tokens')
root=os.path.expanduser('~/.claude/projects')
agg=collections.defaultdict(float); bymodel=collections.defaultdict(float); bysess=collections.defaultdict(float)
# role stats: key=(group, prefix) -> dict
rs=collections.defaultdict(lambda: {'usd':0.0,'n':0,'steps':0,'ctx':0,'models':collections.defaultdict(float)})
since_ts=SINCE.timestamp()
label_cache={}
def labels_for(proj_dir, sess, wid):
    key=(proj_dir,sess,wid)
    if key not in label_cache:
        m={}
        try:
            d=json.load(open(f"{root}/{proj_dir}/{sess}/workflows/{wid}.json"))
            for e in d.get('workflowProgress',[]):
                if e.get('type')=='workflow_agent': m[e.get('agentId')]=e.get('label','')
        except Exception: pass
        label_cache[key]=m
    return label_cache[key]
folders=set()
for p in glob.glob(root+'/**/*.jsonl',recursive=True):
    if os.path.getmtime(p)<since_ts or p.endswith('journal.jsonl'): continue
    rel=p[len(root)+1:]; parts=rel.split('/'); proj=parts[0].replace('-Users-mac-Projects-','')
    if A.project and A.project not in proj: continue
    kind='main' if rel.count('/')==1 else ('workflow' if '/workflows/' in rel else 'agent')
    sid=parts[1][:8]
    rk=None
    if kind=='workflow':
        wid=parts[-2]; aid=os.path.basename(p)[len('agent-'):-len('.jsonl')]
        lab=labels_for(parts[0],parts[1],wid).get(aid)
        if lab is None:  # fallback: sidecar meta.json description (= label)
            try: lab=json.load(open(p[:-len('.jsonl')]+'.meta.json')).get('description')
            except Exception: lab=None
        pre=role_of(lab) if lab is not None else '(нет метки)'
        rk=(group_of(pre) or 'не распознано', pre)
    msgs={}
    for line in open(p,errors='ignore'):
        try:d=json.loads(line)
        except:continue
        if d.get('type')!='assistant':continue
        ts=d.get('timestamp')
        if not ts: continue
        try: t=pt(ts)
        except: continue
        if t<SINCE or (UNTIL and t>=UNTIL): continue
        m=d.get('message') or {}; u=m.get('usage'); mod=m.get('model','?')
        if not u or mod=='<synthetic>':continue
        cur=msgs.setdefault(m.get('id'),[mod,collections.Counter()])
        for k in K: cur[1][k]=max(cur[1][k],u.get(k) or 0)
    if not msgs: continue
    folders.add(parts[0])
    if kind=='workflow': rs[rk]['n']+=1
    elif kind=='agent': rs[('agent (non-workflow)','')]['n']+=1
    else: rs[('main','')]['n']+=1
    for mod,c in msgs.values():
        pr=P.get(mod,(4,5,0.2,20)); usd=(c['input_tokens']*pr[0]+c['cache_creation_input_tokens']*pr[1]+c['cache_read_input_tokens']*pr[2]+c['output_tokens']*pr[3])/1e6
        agg[(proj,kind)]+=usd; bymodel[mod]+=usd; bysess[(proj,sid,kind)]+=usd
        key=rk if kind=='workflow' else (('agent (non-workflow)','') if kind=='agent' else ('main',''))
        r=rs[key]; r['usd']+=usd; r['steps']+=1; r['ctx']+=c['input_tokens']+c['cache_creation_input_tokens']+c['cache_read_input_tokens']; r['models'][mod]+=usd
tot=sum(agg.values()); print(f"TOTAL {A.since} .. {A.until or 'now'} project={A.project or 'all'} ~${tot:,.0f} (API-equivalent)")
print('folders:', ', '.join(sorted(folders)))
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

grp=collections.defaultdict(lambda: {'usd':0.0,'n':0,'steps':0,'ctx':0,'models':collections.defaultdict(float)})
for (g,pre),r in rs.items():
    x=grp[g]; x['usd']+=r['usd']; x['n']+=r['n']; x['steps']+=r['steps']; x['ctx']+=r['ctx']
    for m,v in r['models'].items(): x['models'][m]+=v
print('\nBY ROLE (workflow agents)  [доля от расхода после фильтра]')
print(f"  {'group':22s} {'share':>6s} {'$':>7s} {'agents':>6s} {'steps/ag':>8s} {'ctx k/step':>10s}  models")
for g,x in sorted(grp.items(),key=lambda kv:-kv[1]['usd']):
    ms=', '.join(f"{m} {v/x['usd']:.0%}" for m,v in sorted(x['models'].items(),key=lambda kv:-kv[1])[:3]) if x['usd'] else ''
    print(f"  {g:22s} {x['usd']/tot:6.1%} {x['usd']:7.0f} {x['n']:6d} {x['steps']/max(x['n'],1):8.1f} {x['ctx']/max(x['steps'],1)/1000:10.0f}  {ms}")
wf=sum(x['usd'] for g,x in grp.items() if g not in ('main','agent (non-workflow)'))
un=grp.get('не распознано',{'usd':0.0})['usd']; share=un/wf if wf else 0
print(f"\nне распознано: {share:.1%} расхода воркфлоу-помощников")
for (g,pre),r in sorted(rs.items(),key=lambda kv:-kv[1]['usd']):
    if g=='не распознано': print(f"  {pre!r}: {r['usd']/wf:.1%} (${r['usd']:.0f}, {r['n']} помощн.)")
if share>0.05: print('ВНИМАНИЕ: не распознано >5% — замер не принимается, разметь ROLE_GROUPS')
