import json
with open('triage_groups.json') as f:
    d = json.load(f)
repos = ['bjohnson1279/bash_encoding', 'bjohnson1279/tampermonkey_collection', 'bjohnson1279/convo-sim']
for g, prs in d.items():
    print(g.upper() + ':')
    for pr in prs:
        if pr['repository'] in repos:
            print(f'  - PR {pr[\"number\"]} in {pr[\"repository\"]}: {pr[\"title\"]}')

