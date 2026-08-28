#!/bin/bash
# Scans pref snapshots (plist or JSON) for credential-shaped content before it
# can land in this public repo. Decodes recursively — nested plists, JSON
# embedded in strings or <data> blobs, base64 — because that is where secrets
# actually hide: Claude Usage kept live OAuth tokens inside a JSON string
# inside a binary plist, invisible to plutil -p and to line-based scanners.
#
# This is the deterministic backstop. It catches recognizable shapes (known
# token prefixes, PEM/JWT, emails, high-entropy strings, secret-looking key
# names); deciding whether a flagged value is scrub-it vs don't-track-the-app
# is still a review call — see AGENTS.md.
#
# Usage: ./scan.sh <file ...>
# Exit:  0 clean, 1 findings (an unparseable file is a finding: unreadable
#        means unreviewable, so it must not ship).
set -euo pipefail

exec /usr/bin/python3 - "$@" <<'PY'
import base64
import json
import math
import plistlib
import re
import sys

TOKEN_PATTERNS = [
    (re.compile(r'sk-ant-[A-Za-z0-9_\-]{8,}'), 'Anthropic token'),
    (re.compile(r'sk-[A-Za-z0-9_\-]{24,}'), 'secret-key-shaped token'),
    (re.compile(r'gh[pousr]_[A-Za-z0-9]{20,}'), 'GitHub token'),
    (re.compile(r'github_pat_[A-Za-z0-9_]{20,}'), 'GitHub token'),
    (re.compile(r'xox[baprs]-[A-Za-z0-9\-]{10,}'), 'Slack token'),
    (re.compile(r'AKIA[0-9A-Z]{16}'), 'AWS access key id'),
    (re.compile(r'AIza[0-9A-Za-z_\-]{30,}'), 'Google API key'),
    (re.compile(r'glpat-[A-Za-z0-9_\-]{20,}'), 'GitLab token'),
    (re.compile(r'eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}'), 'JWT'),
    (re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'), 'private key'),
    (re.compile(r'[A-Za-z][A-Za-z0-9._%+\-]*@[A-Za-z][A-Za-z0-9.\-]*\.[A-Za-z]{2,}'), 'email address'),
]

# Key names that promise a secret. A match is a finding when the value is a
# non-trivial string/blob — booleans and numbers can't hold a credential.
SUSPECT_KEY = re.compile(
    r'licen[cs]e|token|secret|passw|credential|api[_\-]?key|private[_\-]?key',
    re.I)

# High-entropy candidates: secret material is dense; prose and paths are not.
# UUIDs and plain hex (device ids, colors) are common in prefs and excluded.
CANDIDATE = re.compile(r'[A-Za-z0-9+/_\-=]{28,256}')
HEXISH = re.compile(r'^[0-9A-Fa-f\-]+$')
# A canonical UUID carrying a readable suffix — Bartender names every menu bar
# item this way (`82AF6838-…-D24C691F410F-CPU_bar_chart`). The bare UUID is
# already covered by HEXISH, but the suffix introduces non-hex letters, so the
# whole token used to reach the entropy test and trip it. Anchored end to end
# and the suffix is restricted to identifier characters, so this cannot swallow
# a credential that merely happens to begin with UUID-shaped bytes.
UUID_TAGGED = re.compile(
    r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-'
    r'[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}[-.][A-Za-z0-9_.\-]*$')

findings = []


def entropy(s):
    counts = {}
    for ch in s:
        counts[ch] = counts.get(ch, 0) + 1
    return -sum(n / len(s) * math.log2(n / len(s)) for n in counts.values())


def redact(s):
    return s[:10] + '…' if len(s) > 10 else s


def scan_text(text, path):
    for pattern, label in TOKEN_PATTERNS:
        for m in pattern.finditer(text):
            findings.append((path, f'{label}: {redact(m.group(0))}'))
    for m in CANDIDATE.finditer(text):
        tok = m.group(0)
        if HEXISH.match(tok) or UUID_TAGGED.match(tok):
            continue
        if entropy(tok) >= 4.4:
            findings.append((path, f'high-entropy string: {redact(tok)}'))


def try_structured(raw):
    """Decode bytes as plist or JSON, or None if they are neither."""
    for loader in (plistlib.loads, lambda b: json.loads(b.decode('utf-8'))):
        try:
            return loader(raw)
        except Exception:
            pass
    return None


def walk(obj, path):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if SUSPECT_KEY.search(k) and isinstance(v, (str, bytes)) and len(v) > 4:
                findings.append((f'{path}/{k}', 'key name promises a secret'))
            walk(v, f'{path}/{k}')
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            walk(v, f'{path}[{i}]')
    elif isinstance(obj, bytes):
        nested = try_structured(obj)
        if nested is not None:
            walk(nested, f'{path}(decoded)')
            return
        try:
            walk(obj.decode('utf-8'), f'{path}(text)')
        except UnicodeDecodeError:
            # Opaque binary (icons, archived UI state): no text secrets to
            # find, but token shapes could still be byte-embedded.
            scan_text(obj.decode('latin-1'), path)
    elif isinstance(obj, str):
        # A string that *is* JSON gets walked structurally, so a token inside
        # it is found by value with its key path, not by luck of formatting.
        if obj[:1] in '{[':
            try:
                walk(json.loads(obj), f'{path}(json)')
                return
            except Exception:
                pass
        if len(obj) >= 40 and re.fullmatch(r'[A-Za-z0-9+/=\s]+', obj):
            try:
                decoded = base64.b64decode(obj, validate=True)
                walk(decoded, f'{path}(base64)')
                return
            except Exception:
                pass
        scan_text(obj, path)


exit_code = 0
for filename in sys.argv[1:]:
    with open(filename, 'rb') as f:
        raw = f.read()
    data = try_structured(raw)
    if data is None:
        print(f'✗ {filename}: cannot parse as plist or JSON — unreviewable, refusing')
        exit_code = 1
        continue
    findings = []
    walk(data, '')
    if findings:
        exit_code = 1
        print(f'✗ {filename}:')
        for where, reason in findings:
            print(f'    {where or "/"}: {reason}')
    else:
        print(f'✓ {filename}: clean')
sys.exit(exit_code)
PY
