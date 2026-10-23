#!/usr/bin/env python3
"""
Analyze token usage from Claude Code session transcripts.
Breaks down usage by main session and individual subagents.
"""

import argparse
import glob
import json
import os
import sys
from pathlib import Path
from collections import defaultdict

def analyze_main_session(filepath):
    """Analyze a session file and return token usage broken down by agent."""
    main_usage = {
        'input_tokens': 0,
        'output_tokens': 0,
        'cache_creation': 0,
        'cache_read': 0,
        'messages': 0
    }

    # Track usage per subagent
    subagent_usage = defaultdict(lambda: {
        'input_tokens': 0,
        'output_tokens': 0,
        'cache_creation': 0,
        'cache_read': 0,
        'messages': 0,
        'description': None
    })

    with open(filepath, 'r') as f:
        for line in f:
            try:
                data = json.loads(line)

                # Main session assistant messages
                if data.get('type') == 'assistant' and 'message' in data:
                    main_usage['messages'] += 1
                    msg_usage = data['message'].get('usage', {})
                    main_usage['input_tokens'] += msg_usage.get('input_tokens', 0)
                    main_usage['output_tokens'] += msg_usage.get('output_tokens', 0)
                    main_usage['cache_creation'] += msg_usage.get('cache_creation_input_tokens', 0)
                    main_usage['cache_read'] += msg_usage.get('cache_read_input_tokens', 0)

                # Subagent tool results
                if data.get('type') == 'user' and 'toolUseResult' in data:
                    result = data['toolUseResult']
                    if 'usage' in result and 'agentId' in result:
                        agent_id = result['agentId']
                        usage = result['usage']

                        # Get description from prompt if available
                        if subagent_usage[agent_id]['description'] is None:
                            prompt = result.get('prompt', '')
                            # Extract first line as description
                            first_line = prompt.split('\n')[0] if prompt else f"agent-{agent_id}"
                            if first_line.startswith('You are '):
                                first_line = first_line[8:]  # Remove "You are "
                            subagent_usage[agent_id]['description'] = first_line[:60]

                        subagent_usage[agent_id]['messages'] += 1
                        subagent_usage[agent_id]['input_tokens'] += usage.get('input_tokens', 0)
                        subagent_usage[agent_id]['output_tokens'] += usage.get('output_tokens', 0)
                        subagent_usage[agent_id]['cache_creation'] += usage.get('cache_creation_input_tokens', 0)
                        subagent_usage[agent_id]['cache_read'] += usage.get('cache_read_input_tokens', 0)
            except:
                pass

    return main_usage, dict(subagent_usage)

def format_tokens(n):
    """Format token count with thousands separators."""
    return f"{n:,}"

def calculate_cost(usage, input_cost_per_m=3.0, output_cost_per_m=15.0):
    """Calculate estimated cost in dollars."""
    total_input = usage['input_tokens'] + usage['cache_creation'] + usage['cache_read']
    input_cost = total_input * input_cost_per_m / 1_000_000
    output_cost = usage['output_tokens'] * output_cost_per_m / 1_000_000
    return input_cost + output_cost

def last_usage_per_request(filepath):
    """Return {message.id: usage} keeping the last record per message.id."""
    msgs = {}
    with open(filepath, 'r', errors='ignore') as f:
        for line in f:
            try:
                data = json.loads(line)
            except ValueError:
                continue
            msg = data.get('message')
            if data.get('type') != 'assistant' or not isinstance(msg, dict):
                continue
            if not msg.get('usage') or msg.get('model') == '<synthetic>':
                continue
            msgs[msg.get('id') or f'noid-{len(msgs)}'] = msg['usage']
    return msgs

def context_of(usage):
    """Context size of one request: input + cache read + cache creation."""
    its = usage.get('iterations')
    u = its[-1] if its else usage
    return (u.get('input_tokens') or 0) + (u.get('cache_read_input_tokens') or 0) \
        + (u.get('cache_creation_input_tokens') or 0)

def run_mode(args):
    """Report for one `claude -p --output-format json` run; exit 1 if the run is spoiled."""
    run = json.load(open(args.run))
    sid = run['session_id']
    found = glob.glob(os.path.expanduser(f'~/.claude/projects/*/{sid}.jsonl'))
    if not found:
        print(f"ПРОГОН В БРАК: транскрипт {sid}.jsonl не найден")
        sys.exit(1)
    main_file = found[0]
    subs = sorted(glob.glob(main_file[:-6] + '/subagents/agent-*.jsonl'))

    main_msgs = list(last_usage_per_request(main_file).values())
    main_ctx = context_of(main_msgs[-1]) if main_msgs else 0
    total_ctx = sum(context_of(u) for u in main_msgs)
    for sub in subs:
        total_ctx += sum(context_of(u) for u in last_usage_per_request(sub).values())

    print(f"main_context_last_request: {format_tokens(main_ctx)}")
    print(f"total_context_all_requests: {format_tokens(total_ctx)}")
    print(f"total_cost_usd: {run.get('total_cost_usd')}")
    print(f"subagent_stats.spawned: {len(subs)}")

    # Только то, что реально ушло модели: hook_additional_context (hook_success и
    # api-request-blob дублируют тот же текст для отладки).
    text = ''
    with open(main_file, errors='ignore') as f:
        for line in f:
            try:
                att = json.loads(line).get('attachment')
            except ValueError:
                continue
            if isinstance(att, dict) and att.get('type') == 'hook_additional_context':
                text += json.dumps(att.get('content'), ensure_ascii=False) + '\n'
    problem = None
    n = text.count('<forge-plugin-loaded>')
    if n != 1:
        problem = f"<forge-plugin-loaded> встречается {n} раз, нужен ровно 1"
    elif f"Forge plugin (v{args.expect_version})" not in text:
        problem = f"нет строки 'Forge plugin (v{args.expect_version})'"
    elif args.expect_delegation_rule and 'ПОМОЩНИКИ:' not in text:
        problem = "нет строки 'ПОМОЩНИКИ:'"
    if problem:
        print(f"ПРОГОН В БРАК: {problem}")
        sys.exit(1)
    print("проверки прогона: ок")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('session', nargs='?', help='session .jsonl file')
    ap.add_argument('--run', help='json from `claude -p --output-format json`')
    ap.add_argument('--expect-version')
    ap.add_argument('--expect-delegation-rule', action='store_true')
    args = ap.parse_args()
    if args.run:
        if not args.expect_version:
            ap.error('--run requires --expect-version')
        run_mode(args)
        return
    if not args.session:
        print("Usage: analyze-token-usage.py <session-file.jsonl> | --run <run.json> --expect-version X")
        sys.exit(1)
    main_session_file = args.session

    if not Path(main_session_file).exists():
        print(f"Error: Session file not found: {main_session_file}")
        sys.exit(1)

    # Analyze the session
    main_usage, subagent_usage = analyze_main_session(main_session_file)

    print("=" * 100)
    print("TOKEN USAGE ANALYSIS")
    print("=" * 100)
    print()

    # Print breakdown
    print("Usage Breakdown:")
    print("-" * 100)
    print(f"{'Agent':<15} {'Description':<35} {'Msgs':>5} {'Input':>10} {'Output':>10} {'Cache':>10} {'Cost':>8}")
    print("-" * 100)

    # Main session
    cost = calculate_cost(main_usage)
    print(f"{'main':<15} {'Main session (coordinator)':<35} "
          f"{main_usage['messages']:>5} "
          f"{format_tokens(main_usage['input_tokens']):>10} "
          f"{format_tokens(main_usage['output_tokens']):>10} "
          f"{format_tokens(main_usage['cache_read']):>10} "
          f"${cost:>7.2f}")

    # Subagents (sorted by agent ID)
    for agent_id in sorted(subagent_usage.keys()):
        usage = subagent_usage[agent_id]
        cost = calculate_cost(usage)
        desc = usage['description'] or f"agent-{agent_id}"
        print(f"{agent_id:<15} {desc:<35} "
              f"{usage['messages']:>5} "
              f"{format_tokens(usage['input_tokens']):>10} "
              f"{format_tokens(usage['output_tokens']):>10} "
              f"{format_tokens(usage['cache_read']):>10} "
              f"${cost:>7.2f}")

    print("-" * 100)

    # Calculate totals
    total_usage = {
        'input_tokens': main_usage['input_tokens'],
        'output_tokens': main_usage['output_tokens'],
        'cache_creation': main_usage['cache_creation'],
        'cache_read': main_usage['cache_read'],
        'messages': main_usage['messages']
    }

    for usage in subagent_usage.values():
        total_usage['input_tokens'] += usage['input_tokens']
        total_usage['output_tokens'] += usage['output_tokens']
        total_usage['cache_creation'] += usage['cache_creation']
        total_usage['cache_read'] += usage['cache_read']
        total_usage['messages'] += usage['messages']

    total_input = total_usage['input_tokens'] + total_usage['cache_creation'] + total_usage['cache_read']
    total_tokens = total_input + total_usage['output_tokens']
    total_cost = calculate_cost(total_usage)

    print()
    print("TOTALS:")
    print(f"  Total messages:         {format_tokens(total_usage['messages'])}")
    print(f"  Input tokens:           {format_tokens(total_usage['input_tokens'])}")
    print(f"  Output tokens:          {format_tokens(total_usage['output_tokens'])}")
    print(f"  Cache creation tokens:  {format_tokens(total_usage['cache_creation'])}")
    print(f"  Cache read tokens:      {format_tokens(total_usage['cache_read'])}")
    print()
    print(f"  Total input (incl cache): {format_tokens(total_input)}")
    print(f"  Total tokens:             {format_tokens(total_tokens)}")
    print()
    print(f"  Estimated cost: ${total_cost:.2f}")
    print("  (at $3/$15 per M tokens for input/output)")
    print()
    print("=" * 100)

if __name__ == '__main__':
    main()
