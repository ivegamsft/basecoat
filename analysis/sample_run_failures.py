import json, subprocess
from collections import defaultdict, Counter
from pathlib import Path

runs_data = json.loads(Path('analysis/mining_summary.json').read_text())
# reload raw runs for full fields
import json as _j

def parse_multi_json(path):
    txt=Path(path).read_text(encoding='utf-8')
    dec=_j.JSONDecoder(); i=0; vals=[]
    while i < len(txt):
        while i < len(txt) and txt[i].isspace(): i+=1
        if i>=len(txt): break
        v,j=dec.raw_decode(txt,i); vals.append(v); i=j
    return vals
pages=parse_multi_json('analysis/actions_runs.json')
runs=[]
for p in pages:
    if isinstance(p,dict) and 'workflow_runs' in p: runs.extend(p['workflow_runs'])

# take failed/cancelled runs only
bad=[r for r in runs if r.get('conclusion') in ('failure','cancelled','timed_out')]
by_wf=defaultdict(list)
for r in bad:
    by_wf[r.get('name','unknown')].append(r)

selected=[]
for wf,arr in sorted(by_wf.items(), key=lambda kv: len(kv[1]), reverse=True)[:8]:
    arr=sorted(arr,key=lambda x:x.get('created_at',''), reverse=True)
    selected.extend(arr[:4])

# dedupe
seen=set(); uniq=[]
for r in selected:
    if r['id'] in seen: continue
    seen.add(r['id']); uniq.append(r)

out=[]
for r in uniq:
    rid=r['id']
    try:
        res=subprocess.run(['gh','api',f'/repos/IBuySpy-Dev/wawkr/actions/runs/{rid}/jobs?per_page=100'],capture_output=True,text=True,check=True)
        j=_j.loads(res.stdout)
        jobs=j.get('jobs',[])
        failed_jobs=[jb for jb in jobs if jb.get('conclusion') in ('failure','cancelled','timed_out')]
        step_counts=Counter()
        step_examples=[]
        for jb in failed_jobs:
            for st in jb.get('steps') or []:
                if st.get('conclusion') in ('failure','cancelled','timed_out'):
                    nm=st.get('name','(unnamed)')
                    step_counts[nm]+=1
                    if len(step_examples)<3:
                        step_examples.append(nm)
        out.append({
            'run_id':rid,
            'workflow':r.get('name'),
            'title':r.get('display_title'),
            'url':r.get('html_url'),
            'conclusion':r.get('conclusion'),
            'event':r.get('event'),
            'head_branch':r.get('head_branch'),
            'failing_jobs':[{ 'name':jb.get('name'),'conclusion':jb.get('conclusion')} for jb in failed_jobs[:5]],
            'top_failing_steps':step_counts.most_common(8),
            'step_examples':step_examples
        })
    except Exception as e:
        out.append({'run_id':rid,'workflow':r.get('name'),'url':r.get('html_url'),'error':str(e)})

Path('analysis/run_job_failure_samples.json').write_text(_j.dumps(out,indent=2),encoding='utf-8')
print('Saved',len(out),'samples')
for item in out[:20]:
    print(item.get('run_id'),item.get('workflow'),item.get('conclusion'),item.get('top_failing_steps',[])[:3],item.get('url'))
