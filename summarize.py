import json
with open('triage_groups.json') as f:
    d = json.load(f)
repos = ['bjohnson1279/bash_encoding', 'bjohnson1279/tampermonkey_collection', 'bjohnson1279/convo-sim']
for g, prs in d.items():
    relevant = [pr for pr in prs if pr['repository'] in repos]
    if relevant:
        print(f'\n--- {g.upper()} ---')
        for pr in relevant:
            print(f'PR {pr[\"number\"]} ({pr[\"repository\"]}): {pr[\"title\"]}')

