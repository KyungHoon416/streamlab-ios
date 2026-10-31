#!/usr/bin/env python3
"""Loopback auth fixture with a controlled refresh barrier; dummy credentials only."""
import argparse
import hashlib
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

LOCK = threading.Lock()
CASES = {}


class Server(ThreadingHTTPServer):
    request_queue_size = 128


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, fmt, *args):
        # Never log headers or bodies.
        print(fmt % args, flush=True)

    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        self.close_connection = True
        try:
            parts = self.path.strip('/').split('/')
            if len(parts) != 3 or parts[0] != 'case':
                self.reply(404, {})
                return
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 65536:
                self.reply(400, {})
                return
            raw = self.rfile.read(size)
            body = json.loads(raw)
            case, action = parts[1:]
            with LOCK:
                if action == 'configure':
                    if case in CASES or body.get('mode') not in ('success', 'failure', 'delayed-resource'):
                        self.reply(400, {})
                        return
                    CASES[case] = dict(mode=body['mode'], gate=threading.Event(), refreshCalls=0,
                                      rejected=0, accepted=0, fingerprints=[], ids=[])
                    self.reply(200, {})
                    return
                state = CASES[case]
                if action == 'release':
                    state['gate'].set()
                    self.reply(200, {})
                    return
                if action == 'stats':
                    self.reply(200, {k: state[k] for k in ('refreshCalls', 'rejected', 'accepted', 'fingerprints', 'ids')})
                    return
                if action == 'resource' and state['mode'] != 'delayed-resource':
                    state['fingerprints'].append(hashlib.sha256(raw).hexdigest())
                    state['ids'].append(self.headers.get('Idempotency-Key', ''))
                    authorized = self.headers.get('Authorization') == 'Bearer fixture-renewed'
                    if authorized and state['mode'] == 'success':
                        state['accepted'] += 1
                        self.reply(200, {'ok': True})
                    else:
                        state['rejected'] += 1
                        self.reply(401, {})
                    return
                if action == 'resource' and state['mode'] == 'delayed-resource':
                    state['accepted'] += 1
                    gate, mode = state['gate'], state['mode']
                elif action == 'refresh':
                    state['refreshCalls'] += 1
                    gate, mode = state['gate'], state['mode']
                else:
                    self.reply(404, {})
                    return
            # Do not hold the lock while waiting: all eight requests must join the flight.
            if not gate.wait(timeout=10):
                self.reply(504, {})
            elif mode == 'failure':
                self.reply(500, {})
            else:
                self.reply(200, {'accessToken': 'fixture-renewed'})
        except (KeyError, ValueError, TypeError):
            self.reply(400, {})
        except (BrokenPipeError, ConnectionResetError):
            pass


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--ready-file', required=True)
    args = parser.parse_args()
    server = Server(('127.0.0.1', 0), Handler)
    Path(args.ready_file).write_text(f'http://127.0.0.1:{server.server_port}')
    server.serve_forever()
