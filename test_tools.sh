#!/usr/bin/env bash
# test_tools.sh — Validate OpenAI-compatible tool calling and tool-result round trip.
set -euo pipefail

HOST="${HOST:-localhost}"
PORT="${PORT:-8000}"
BASE_URL="http://${HOST}:${PORT}"
MODEL="${MODEL:-Ornith-1.0-35B}"

python3 - <<PY
import json
import urllib.request

base_url = '${BASE_URL}'
model = '${MODEL}'
url = f'{base_url}/v1/chat/completions'

tool = {
    'type': 'function',
    'function': {
        'name': 'get_weather',
        'description': 'Get current weather for a location',
        'parameters': {
            'type': 'object',
            'properties': {'location': {'type': 'string'}},
            'required': ['location'],
        },
    },
}

def post(payload):
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
    with urllib.request.urlopen(req, timeout=240) as response:
        return json.loads(response.read().decode())

messages = [
    {'role': 'user', 'content': 'Get the weather for Zurich, Switzerland using the tool, then summarize it.'}
]
first = post({
    'model': model,
    'messages': messages,
    'tools': [tool],
    'tool_choice': 'required',
    'max_tokens': 512,
    'temperature': 0,
})
first_choice = first['choices'][0]
first_msg = first_choice['message']
print('FIRST_FINISH', first_choice.get('finish_reason'))
print('FIRST_TOOL_CALLS', json.dumps(first_msg.get('tool_calls'), indent=2))
if not first_msg.get('tool_calls'):
    raise SystemExit('No tool_calls returned')

call = first_msg['tool_calls'][0]
messages.append({
    'role': 'assistant',
    'content': first_msg.get('content') or '',
    'tool_calls': first_msg['tool_calls'],
})
messages.append({
    'role': 'tool',
    'tool_call_id': call['id'],
    'name': 'get_weather',
    'content': json.dumps({
        'location': 'Zurich, Switzerland',
        'temperature_c': 21,
        'condition': 'partly cloudy',
    }),
})
second = post({
    'model': model,
    'messages': messages,
    'tools': [tool],
    'tool_choice': 'none',
    'max_tokens': 256,
    'temperature': 0,
})
second_choice = second['choices'][0]
second_msg = second_choice['message']
print('ROUNDTRIP_FINISH', second_choice.get('finish_reason'))
print('ROUNDTRIP_CONTENT', repr(second_msg.get('content')))
print('ROUNDTRIP_REASONING_PREFIX', repr((second_msg.get('reasoning') or '')[:250]))
if second_choice.get('finish_reason') != 'stop':
    raise SystemExit('Final response did not stop cleanly')
print('OK')
PY