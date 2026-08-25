
import json, subprocess, os, sys

sys.stdout.reconfigure(encoding='utf-8')

with open('triage_groups.json') as f:
    d = json.load(f)

repos = ['bjohnson1279/bash_encoding', 'bjohnson1279/tampermonkey_collection', 'bjohnson1279/convo-sim']

success_count = 0
for pr in d.get('group_a_safe', []):
    repo = pr['repository']
    if repo in repos:
        num = pr['number']
        title = pr['title']
        print(f'Merging PR {num} in {repo}: {title}')
        
        cmd = ['gh', 'pr', 'merge', str(num), '--repo', repo, '--admin', '--merge', '--delete-branch']
        res = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8')
        if res.returncode == 0:
            print(f'  -> Successfully merged PR {num}')
            success_count += 1
        else:
            print(f'  -> Failed to merge PR {num}: {res.stderr}')

print(f'\nTotal merged: {success_count}')

