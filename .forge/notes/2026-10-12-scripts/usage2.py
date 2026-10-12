import json, glob, os, collections, re
root = os.path.expanduser('~/.claude/projects/-Users-mac-Projects-Ya--Market-integration')
K = ('input_tokens','cache_creation_input_tokens','cache_read_input_tokens','output_tokens')
def scan(path):
    msgs={}; tools=collections.Counter(); ts0=None
    for line in open(path, errors='ignore'):
        try: d=json.loads(line)
        except: continue
        ts0 = ts0 or d.get('timestamp')
        m=d.get('message') or {}
        if d.get('type')!='assistant' or not isinstance(m,dict): continue
        for c in m.get('content') or []:
            if isinstance(c,dict) and c.get('type')=='tool_use': tools[c.get('name')]+=1
        u=m.get('usage'); mod=m.get('model','?')
        if not u or mod=='<synthetic>': continue
        cur=msgs.setdefault(m.get('id'),[mod,collections.Counter()])
        for k in K: cur[1][k]=max(cur[1][k],u.get(k) or 0)
    per=collections.defaultdict(collections.Counter)
    for mod,c in msgs.values():
        per[mod]+=c; per[mod]['calls']+=1
    return per,tools,ts0
rows=[]
for p in glob.glob(root+'/**/*.jsonl', recursive=True):
    if p.endswith('journal.jsonl'): continue
    rel=p[len(root)+1:]
    kind='main' if rel.count('/')==0 else ('workflow' if '/workflows/' in rel else 'agent')
    meta={}
    mp=p[:-6]+'.meta.json'
    if os.path.exists(mp):
        try: meta=json.load(open(mp))
        except: pass
    per,tools,ts=scan(p)
    for mod,c in per.items():
        rows.append(dict(kind=kind,file=rel,ts=ts,model=mod,type=meta.get('agentType',''),desc=meta.get('description',''),phase=meta.get('workflowPhase',''),tools=dict(tools),**{k:c[k] for k in K},calls=c['calls']))
json.dump(rows,open('rows.json','w'),ensure_ascii=False)
agg=collections.defaultdict(collections.Counter)
for r in rows:
    a=agg[(r['kind'],r['model'])]
    for k in K+('calls',): a[k]+=r[k]
    a['runs']+=1
for (kind,mod),c in sorted(agg.items()):
    print(f"{kind:9}{mod:20} runs={c['runs']:4} calls={c['calls']:6} cw={c['cache_creation_input_tokens']/1e6:6.1f}M cr={c['cache_read_input_tokens']/1e6:7.1f}M in={c['input_tokens']/1e6:5.2f}M out={c['output_tokens']/1e6:5.2f}M")
