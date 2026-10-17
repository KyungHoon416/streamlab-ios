#!/usr/bin/env python3
"""In-memory mutation contract fixture, loopback only; not a production backend."""
import argparse
import json
import socket
import threading
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOCK = threading.Lock()
CASES = {}


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)

    def reply(self, status, body, headers=None):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Connection', 'close')
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(data)
        self.wfile.flush()

    def do_POST(self):
        self.close_connection = True
        parts = self.path.strip('/').split('/')
        if len(parts) != 3 or parts[0] != 'case':
            self.reply(404, {})
            return
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if size < 1 or size > 1024 * 1024:
                self.reply(400, {})
                return
            raw = self.rfile.read(size)
            body = json.loads(raw)
            with LOCK:
                status, response, headers, drop = self.process(parts[1], parts[2], body, raw)
            if drop:
                # Commit already happened; deliberately truncate the acknowledgement body.
                self.send_response(200)
                self.send_header('Content-Length', '1000')
                self.end_headers()
                self.wfile.write(b'{')
                self.wfile.flush()
                self.connection.shutdown(socket.SHUT_RDWR)
                self.connection.close()
            else:
                self.reply(status, response, headers)
        except (ValueError, KeyError, TypeError):
            self.reply(400, {})
        except (BrokenPipeError, ConnectionResetError):
            pass

    def process(self, case, action, body, raw):
        if action == 'configure':
            if case in CASES:
                return 409, {}, {}, False
            mode = body['mode']
            if mode not in ('lost', 'conflict', 'retry', 'exhaust', 'cancel'):
                return 400, {}, {}, False
            CASES[case] = dict(mode=mode, scope=body['scope'], revision=1 if mode == 'conflict' else 0,
                values={'key': 'Yg=='} if mode == 'conflict' else {}, requests=[], receipts={},
                effects=0, snapshots=0, dropped=False)
            return 200, {}, {}, False
        state = CASES[case]
        if action == 'stats':
            return 200, {k: state[k] for k in ('revision', 'effects', 'snapshots', 'requests')}, {}, False
        if action == 'snapshot':
            if body != state['scope']:
                return 403, {}, {}, False
            state['snapshots'] += 1
            return 200, {k: state[k] for k in ('scope', 'revision', 'values')}, {}, False
        if action != 'mutations':
            return 404, {}, {}, False
        if body['scope'] != state['scope'] or self.headers.get('Idempotency-Key') != body['id']:
            return 400, {}, {}, False
        wire = raw.decode()
        state['requests'].append(wire)
        prior = state['receipts'].get(body['id'])
        if prior:
            if prior['wire'] != wire:
                return 422, {}, {}, False
            return 200, prior['receipt'], {}, False
        attempt = len(state['requests'])
        if state['mode'] in ('exhaust', 'cancel') or (state['mode'] == 'retry' and attempt <= 2):
            status = 429 if attempt % 2 else 503
            return status, {}, {'Retry-After': '2'}, False
        if body['baseRevision'] != state['revision']:
            return 409, {'currentRevision': state['revision']}, {}, False
        state['revision'] += 1
        state['effects'] += 1
        if body.get('value') is None:
            state['values'].pop(body['key'], None)
        else:
            state['values'][body['key']] = body['value']
        receipt = {'id': body['id'], 'revision': state['revision']}
        state['receipts'][body['id']] = {'wire': wire, 'receipt': receipt}
        drop = state['mode'] == 'lost' and not state['dropped']
        state['dropped'] |= drop
        return 200, receipt, {}, drop


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--ready-file', required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    Path(args.ready_file).write_text(f'http://127.0.0.1:{server.server_port}')
    server.serve_forever()
