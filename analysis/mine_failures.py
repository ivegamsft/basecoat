import json, re
from collections import Counter, defaultdict
from pathlib import Path

base = Path('analysis')

def parse_multi_json(path):
    txt = Path(path).read_text(encoding='utf-8')
    dec = json.JSONDecoder()
    i = 0
    vals = []
    n = len(txt)
    while i < n:
        while i < n and txt[i].isspace():
            i += 1
        if i >= n:
            break
        v, j = dec.raw_decode(txt, i)
        vals.append(v)
        i = j
    return vals

issues_pages = parse_multi_json(base / 'issues_all.json')
pulls_pages = parse_multi_json(base / 'pulls_all.json')
issue_events_pages = parse_multi_json(base / 'issue_events.json')
actions_pages = parse_multi_json(base / 'actions_runs.json')
issue_comments_pages = parse_multi_json(base / 'issue_comments.json')
pr_comments_pages = parse_multi_json(base / 'pr_review_comments.json')

issues = []
for p in issues_pages:
    if isinstance(p, list):
        issues.extend(p)
    elif isinstance(p, dict) and 'items' in p:
        issues.extend(p['items'])

pulls = []
for p in pulls_pages:
    if isinstance(p, list):
        pulls.extend(p)

issue_events = []
for p in issue_events_pages:
    if isinstance(p, list):
        issue_events.extend(p)

runs = []
for p in actions_pages:
    if isinstance(p, dict) and 'workflow_runs' in p:
        runs.extend(p['workflow_runs'])
    elif isinstance(p, list):
        runs.extend(p)

issue_comments = []
for p in issue_comments_pages:
    if isinstance(p, list):
        issue_comments.extend(p)

pr_comments = []
for p in pr_comments_pages:
    if isinstance(p, list):
        pr_comments.extend(p)

issues_only = [i for i in issues if 'pull_request' not in i]
prs_from_issues = [i for i in issues if 'pull_request' in i]

print('Counts:')
print('issues_only', len(issues_only), 'prs', len(pulls), 'issue_pr_rows', len(prs_from_issues))
print('issue_events', len(issue_events), 'runs', len(runs), 'issue_comments', len(issue_comments), 'pr_review_comments', len(pr_comments))

label_counter = Counter()
for i in issues_only:
    for l in i.get('labels', []):
        label_counter[l['name']] += 1
print('\nTop issue labels:')
for k, v in label_counter.most_common(20):
    print(v, k)

patterns = {
    'workflow_drift': r'workflow|ci|pipeline|deploy|concurrency|duplicate|path filter|branch protection|required check',
    'secret_auth': r'secret|key vault|auth|oauth|oidc|b2c|token|credential|login',
    'flaky_tests': r'flaky|intermittent|retry|race|timeout|e2e|playwright|test fails',
    'dependency_bump': r'dependenc|upgrade|bump|version|npm|pnpm|lockfile',
    'env_parity': r'dev|prod|staging|environment|parity|localhost|container app|configuration error',
    'missing_metadata': r'label|metadata|naming|docs|missing|template|description|ownership',
    'branch_policy': r'branch protection|required checks|status check|main branch|policy',
}

cat_issues = defaultdict(list)
for i in issues_only + prs_from_issues:
    text = ((i.get('title') or '') + ' ' + (i.get('body') or '')).lower()
    for cat, rx in patterns.items():
        if re.search(rx, text):
            cat_issues[cat].append(i['number'])

print('\nCategory hits in issues/PRs:')
for c in patterns:
    arr = cat_issues[c]
    print(c, len(arr), 'sample', sorted(set(arr), reverse=True)[:10])

conclusion_counter = Counter((r.get('conclusion') or 'null') for r in runs)
wf_conclusion = defaultdict(Counter)
retry_runs = []
for r in runs:
    wf = r.get('name') or r.get('path') or 'unknown'
    conc = r.get('conclusion') or 'null'
    wf_conclusion[wf][conc] += 1
    if (r.get('run_attempt') or 1) > 1:
        retry_runs.append(r)

print('\nRun conclusions:')
for k, v in conclusion_counter.most_common():
    print(v, k)

print('\nTop workflows by failure/cancelled:')
wf_bad = []
for wf, cnt in wf_conclusion.items():
    bad = cnt['failure'] + cnt['cancelled'] + cnt['timed_out'] + cnt['action_required']
    if bad:
        wf_bad.append((bad, wf, cnt))
for bad, wf, cnt in sorted(wf_bad, reverse=True)[:20]:
    print(bad, wf, dict(cnt))

print('\nRetries count', len(retry_runs))
for r in sorted(retry_runs, key=lambda x: x.get('created_at', ''), reverse=True)[:15]:
    print(r.get('id'), r.get('name'), r.get('conclusion'), 'attempt', r.get('run_attempt'), 'url', r.get('html_url'))

keywords = ['secret', 'auth', 'oidc', 'b2c', 'playwright', 'e2e', 'db', 'migrate', 'lint', 'build', 'deploy', 'concurrency']
kw_hits = defaultdict(list)
for r in runs:
    if r.get('conclusion') in ('failure', 'cancelled', 'timed_out'):
        txt = ((r.get('name') or '') + ' ' + (r.get('display_title') or '')).lower()
        for kw in keywords:
            if kw in txt:
                kw_hits[kw].append((r.get('id'), r.get('html_url')))

print('\nFailure keyword hits in run titles/workflow names:')
for kw in keywords:
    if kw_hits[kw]:
        print(kw, len(kw_hits[kw]), 'sample', kw_hits[kw][:5])

summary = {
    'counts': {
        'issues_only': len(issues_only),
        'prs': len(pulls),
        'issue_events': len(issue_events),
        'runs': len(runs),
        'issue_comments': len(issue_comments),
        'pr_review_comments': len(pr_comments)
    },
    'top_labels': label_counter.most_common(30),
    'category_hits': {k: sorted(set(v)) for k, v in cat_issues.items()},
    'run_conclusions': dict(conclusion_counter),
    'top_workflow_bad': [
        {'workflow': wf, 'bad': bad, 'counts': dict(cnt)}
        for bad, wf, cnt in sorted(wf_bad, reverse=True)[:30]
    ],
    'retry_runs': [
        {
            'id': r.get('id'),
            'name': r.get('name'),
            'attempt': r.get('run_attempt'),
            'conclusion': r.get('conclusion'),
            'url': r.get('html_url')
        }
        for r in retry_runs
    ]
}
(base / 'mining_summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print('\nSaved analysis\\mining_summary.json')
