#!/usr/bin/env python3
"""Loopback-only fixture for the real URLSession loader; no external services."""
import argparse
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

LIMIT = 4 * 1024 * 1024
LOCK = threading.Lock()
STATE = {"targetHits": 0, "slowStarted": False, "slowDisconnected": False}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)

    def body(self, data, status=200, headers=None):
        self.send_response(status)
        self.send_header("Content-Length", str(len(data)))
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(data)
        self.wfile.flush()

    def do_GET(self):
        path = urlsplit(self.path).path
        try:
            if path == "/health":
                self.body(b"ready")
            elif path == "/stats":
                with LOCK:
                    data = json.dumps(STATE).encode()
                self.body(data)
            elif path == "/redirect":
                self.body(b"redirect", 302, {"Location": "/target"})
            elif path == "/target":
                with LOCK:
                    STATE["targetHits"] += 1
                self.body(b"must not follow")
            elif path in ("/exact", "/oversized"):
                # No Content-Length: exercise the byte limit while streaming.
                self.send_response(200)
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                for _ in range(LIMIT // 65536):
                    self.chunk(b"x" * 65536)
                if path == "/oversized":
                    self.chunk(b"x")
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()
            elif path == "/slow":
                self.send_response(200)
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                self.chunk(b"started")
                with LOCK:
                    STATE["slowStarted"] = True
                # Never complete normally during the cancellation test.
                for _ in range(750):
                    time.sleep(0.02)
                    self.chunk(b"x" * 1024)
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()
            else:
                self.body(b"not found", 404)
        except (BrokenPipeError, ConnectionResetError):
            if path == "/slow":
                with LOCK:
                    STATE["slowDisconnected"] = True
        finally:
            self.close_connection = True

    def chunk(self, data):
        self.wfile.write(f"{len(data):X}\r\n".encode() + data + b"\r\n")
        self.wfile.flush()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ready-file", required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    Path(args.ready_file).write_text(f"http://127.0.0.1:{server.server_port}")
    server.serve_forever()
