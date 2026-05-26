import json,re
from collections import defaultdict,Counter
from pathlib import Path

def parse_multi_json(path):
    txt=Path(path).read_text(encoding='utf-8')
    dec=json.JSONDecoder(); i=0; vals=[]
    while i<len(txt):
        while i<len(txt) and txt[i].isspace(): i+=1
        if i>=len(txt): break
        v,j=dec.raw_decode(txt,i); vals.append(v); i=j
    return vals

issue_comments=[]
for p in parse_multi_json('analysis/issue_comments.json'):
    if isinstance(p,list): issue_comments.extend(p)
pr_comments=[]
for p in parse_multi_json('analysis/pr_review_comments.json'):
    if isinstance(p,list): pr_comments.extend(p)

patterns={
'workflow_drift':r'workflow|ci|pipeline|deploy|concurrency|duplicate|path filter|required check',
'secret_auth':r'secret|auth|oauth|oidc|b2c|token|credential|key vault',
'branch_policy':r'branch protection|required checks|status check|main branch|policy',
'test_flake':r'flaky|retry|timeout|e2e|playwright|intermittent|race',
'dependency':r'dependenc|upgrade|bump|lockfile|pnpm|npm',
'env_parity':r'prod|staging|environment|localhost|container app|configuration'
}

counts=Counter()
examples=defaultdict(list)
for c in issue_comments+pr_comments:
    body=(c.get('body') or '').lower()
    for k,rx in patterns.items():
        if re.search(rx,body):
            counts[k]+=1
            if len(examples[k])<12:
                examples[k].append({'id':c.get('id'),'url':c.get('html_url'),'issue_url':c.get('issue_url'),'pull_request_url':c.get('pull_request_url')})

print('comment_count',len(issue_comments),'pr_review_comment_count',len(pr_comments))
for k,v in counts.most_common():
    print(k,v)

Path('analysis/comment_theme_summary.json').write_text(json.dumps({'counts':counts,'examples':examples},indent=2,default=lambda o:dict(o)),encoding='utf-8')
print('saved comment_theme_summary.json')
