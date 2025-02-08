import re
import os


def load_env(env_path):
    with open(os.path.expanduser(env_path)) as f:
        for line in f:
            if line.strip() and not line.startswith('#'):
                line = line.replace('export ', '').strip()
                if '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip().strip('"\'')

load_env('~/.dotfiles/.env')
JIRA_URL = os.environ.get('WORK_JIRA_URL')
JIRA_KEYS = os.environ.get('JIRA_KEYS')

def mark(text, args, Mark, extra_cli_args, *a):
    for idx, m in enumerate(re.finditer(f'(?:{JIRA_KEYS})-[0-9]+', text)):
        start, end = m.span()
        mark_text = text[start:end].replace('\n', '').replace('\0', '')
        yield Mark(idx, start, end, mark_text, {})

def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    matches, groupdicts = [], []
    for m, g in zip(data['match'], data['groupdicts']):
        if m:
            matches.append(m), groupdicts.append(g)
    for ticket in matches:
        boss.open_url(f'{JIRA_URL}/browse/{ticket}')
