import json,re
from pathlib import Path
from collections import defaultdict,Counter

def parse_multi_json(path):
    txt=Path(path).read_text(encoding='utf-8')
    dec=json.JSONDecoder(); i=0; vals=[]
    while i<len(txt):
        while i<len(txt) and txt[i].isspace(): i+=1
        if i>=len(txt): break
        v,j=dec.raw_decode(txt,i); vals.append(v); i=j
    return vals

issues=[]
for p in parse_multi_json('analysis/issues_all.json'):
    if isinstance(p,list): issues.extend(p)
runs=[]
for p in parse_multi_json('analysis/actions_runs.json'):
    if isinstance(p,dict) and 'workflow_runs' in p: runs.extend(p['workflow_runs'])
samples=json.loads(Path('analysis/run_job_failure_samples.json').read_text())

issue_patterns={
'workflow_drift':r'concurrency|duplicate|workflow|path filter|ci|deploy|isolation',
'secret_auth':r'auth|oauth|oidc|b2c|secret|token|key vault|credential',
'branch_policy':r'branch protection|required checks|status check',
'env_parity':r'localhost|production|staging|environment|configuration error|container app',
'dependency_bumps':r'dependenc|upgrade|bump|lockfile|renovate',
'db_migration':r'database|migration|db|schema|prisma',
'metadata_governance':r'label|metadata|template|naming|docs|ownership|missing',
'flaky_tests':r'flaky|retry|timeout|e2e|playwright|intermittent|race',
}

issue_evidence=defaultdict(list)
for it in issues:
    text=((it.get('title') or '')+' '+(it.get('body') or '')).lower()
    url=it.get('html_url'); num=it.get('number')
    for k,rx in issue_patterns.items():
        if re.search(rx,text):
            issue_evidence[k].append((num,url,it.get('title')))

# runs pattern by workflow name/failing step
run_evidence=defaultdict(list)
for r in runs:
    if r.get('conclusion') not in ('failure','cancelled','timed_out'): continue
    n=(r.get('name') or '').lower(); t=(r.get('display_title') or '').lower()
    url=r.get('html_url'); rid=r.get('id')
    if 'deploy' in n and ('cancelled'==r.get('conclusion')):
        run_evidence['workflow_drift'].append((rid,url,r.get('name'),'cancelled'))
    if 'deploy' in n:
        run_evidence['deploy_pipeline'].append((rid,url,r.get('name'),r.get('conclusion')))
    if 'ci'==r.get('name') or 'ci' in n:
        run_evidence['ci_failures'].append((rid,url,r.get('name'),r.get('conclusion')))
    if 'mobile ci' in n:
        run_evidence['mobile_ci'].append((rid,url,r.get('name'),r.get('conclusion')))
    if 'database' in n:
        run_evidence['db_migration'].append((rid,url,r.get('name'),r.get('conclusion')))

# incorporate step-based
for s in samples:
    steps=' '.join([x[0] for x in s.get('top_failing_steps',[])]) if s.get('top_failing_steps') else ''
    url=s.get('url'); rid=s.get('run_id'); wf=s.get('workflow')
    low=(steps+' '+(s.get('title') or '')+' '+(wf or '')).lower()
    if re.search(r'azure login|tenant|oidc|auth|preflight checks',low):
        run_evidence['secret_auth'].append((rid,url,wf,steps))
    if re.search(r'e2e smoke|unit and integration tests|lint|run tests',low):
        run_evidence['flaky_tests'].append((rid,url,wf,steps))
    if re.search(r'install dependencies',low):
        run_evidence['dependency_bumps'].append((rid,url,wf,steps))

print('Issue evidence counts:')
for k,v in issue_evidence.items():
    print(k,len(v))
print('\nRun evidence counts:')
for k,v in run_evidence.items():
    print(k,len(v))

# print top examples
print('\nExamples:')
for k in ['workflow_drift','secret_auth','branch_policy','env_parity','dependency_bumps','db_migration','metadata_governance','flaky_tests']:
    print('\n',k)
    for item in sorted(issue_evidence.get(k,[]), key=lambda x:x[0], reverse=True)[:6]:
        print('issue',item[0],item[1],'-',item[2][:100])
    for item in run_evidence.get(k,[])[:6]:
        print('run',item[0],item[1],'-',item[2],item[3])

Path('analysis/pattern_evidence.json').write_text(json.dumps({'issues':{k:[{'number':n,'url':u,'title':t} for n,u,t in v] for k,v in issue_evidence.items()},'runs':{k:[{'id':i,'url':u,'workflow':w,'detail':d} for i,u,w,d in v] for k,v in run_evidence.items()}},indent=2),encoding='utf-8')
print('\nSaved analysis/pattern_evidence.json')
