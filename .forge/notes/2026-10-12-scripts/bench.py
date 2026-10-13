import json, sys, time, subprocess, glob, os, urllib.request
TASK = """Ты помогаешь агенту-программисту экономить внимание. Ниже — команда терминала и её вывод.
Сожми вывод до самого важного, не больше 15 строк:
- что делала команда / что проверялось;
- что упало, сломано или выглядит неправильно — с конкретикой: файлы, строки, числа, тексты ошибок;
- что прошло нормально — одной строкой.
Ничего не выдумывай: только то, что есть в выводе. Если важного нет — так и скажи.

КОМАНДА:
{cmd}

ВЫВОД:
{out}"""
def prompt(i):
    return TASK.format(cmd=open(f'samples/{i}.cmd').read()[:1500], out=open(f'samples/{i}.txt').read())
def run_haiku(i):
    t=time.time()
    p=subprocess.run(['claude','-p','--model','claude-haiku-4-5','--system-prompt','Ты точный и краткий помощник.','--tools','','--strict-mcp-config','--no-session-persistence','--output-format','json'],input=prompt(i),capture_output=True,text=True,timeout=300)
    d=json.loads(p.stdout)
    return dict(text=d.get('result',''),wall=round(time.time()-t,1),api=round(d.get('duration_api_ms',0)/1000,1),usd=d.get('total_cost_usd'),out_tok=d['usage']['output_tokens'])
def run_ollama(model,i):
    body=json.dumps(dict(model=model,prompt=prompt(i),stream=False,think=False,options=dict(num_ctx=32768,temperature=0.2))).encode()
    t=time.time()
    r=json.load(urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:11434/api/generate',body,{'Content-Type':'application/json'}),timeout=900))
    return dict(text=r.get('response',''),wall=round(time.time()-t,1),prompt_tok=r.get('prompt_eval_count'),prompt_s=round(r.get('prompt_eval_duration',0)/1e9,1),out_tok=r.get('eval_count'),gen_tps=round(r.get('eval_count',0)/max(r.get('eval_duration',1)/1e9,1e-9),1),load_s=round(r.get('load_duration',0)/1e9,1))
model=sys.argv[1]
ids=sorted(os.path.basename(f)[:2] for f in glob.glob('samples/*.txt'))
tag=model.replace(':','_')
for i in ids:
    fn=f'out/{tag}__{i}.json'
    if os.path.exists(fn): continue
    try: res=run_haiku(i) if model=='haiku' else run_ollama(model,i)
    except Exception as e: res=dict(error=str(e))
    json.dump(res,open(fn,'w'),ensure_ascii=False)
    print(model,i,{k:v for k,v in res.items() if k!='text'},flush=True)
print('DONE',model)
