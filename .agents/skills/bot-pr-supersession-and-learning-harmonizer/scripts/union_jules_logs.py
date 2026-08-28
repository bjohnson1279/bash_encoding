import os
import re
import sys
import glob

def union_jules_logs(repo_path):
    search_patterns = [
        os.path.join(repo_path, '.jules', '*.md'),
        os.path.join(repo_path, '.Jules', '*.md')
    ]
    
    files_to_process = []
    for pattern in search_patterns:
        files_to_process.extend(glob.glob(pattern))

    for filepath in files_to_process:
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if '<<<<<<< HEAD' in content and '=======' in content:
                print(f"Resolving conflicts in {filepath}...")
                pattern = r'<<<<<<<\s+.*?\n(.*?)\n=======\n(.*?)>>>>>>>\s+.*?\n?'
                new_content = re.sub(pattern, r'\1\n\2', content, flags=re.DOTALL)
                
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                
                print(f"Successfully unioned logs for {filepath}")
        except Exception as e:
            print(f"Error processing {filepath}: {e}", file=sys.stderr)

if __name__ == '__main__':
    target_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    union_jules_logs(target_dir)
