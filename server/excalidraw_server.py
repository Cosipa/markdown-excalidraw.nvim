#!/usr/bin/env python3
"""Excalidraw file server for excalidraw.nvim.

Zero external dependencies - uses only Python stdlib.
Serves the Excalidraw web app and provides REST API for file I/O.
"""

import argparse
import json
import os
import signal
import socket
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs


ALLOWED_EXTENSIONS = (".excalidraw", ".excalidraw.json")


def is_allowed_path(path):
    """Check if the file path has an allowed extension."""
    for ext in ALLOWED_EXTENSIONS:
        if path.endswith(ext):
            return True
    return False


class ExcalidrawHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default logging to stderr
        pass

    def send_json(self, data, status=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, text, content_type="text/html", status=200):
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if path == "/":
            self.serve_index()
        elif path == "/api/file":
            self.handle_get_file(params)
        elif path == "/api/health":
            self.send_json({"status": "ok"})
        else:
            self.send_json({"error": "Not found"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if path == "/api/file":
            self.handle_post_file(params)
        else:
            self.send_json({"error": "Not found"}, 404)

    def serve_index(self):
        server_dir = os.path.dirname(os.path.abspath(__file__))
        index_path = os.path.join(server_dir, "index.html")
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                html = f.read()
            self.send_text(html)
        except FileNotFoundError:
            self.send_json({"error": "index.html not found"}, 500)

    def handle_get_file(self, params):
        file_path = params.get("path", [None])[0]
        if not file_path:
            self.send_json({"error": "Missing path parameter"}, 400)
            return

        file_path = os.path.abspath(file_path)
        if not is_allowed_path(file_path):
            self.send_json({"error": "File type not allowed"}, 403)
            return

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.send_json(data)
        except FileNotFoundError:
            self.send_json({"error": "File not found"}, 404)
        except json.JSONDecodeError as e:
            self.send_json({"error": f"Invalid JSON: {e}"}, 400)

    def handle_post_file(self, params):
        file_path = params.get("path", [None])[0]
        if not file_path:
            self.send_json({"error": "Missing path parameter"}, 400)
            return

        file_path = os.path.abspath(file_path)
        if not is_allowed_path(file_path):
            self.send_json({"error": "File type not allowed"}, 403)
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            data = json.loads(body)
        except json.JSONDecodeError as e:
            self.send_json({"error": f"Invalid JSON body: {e}"}, 400)
            return

        try:
            # Write to temp file first, then rename for atomicity
            tmp_path = file_path + ".tmp"
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
            os.replace(tmp_path, file_path)
            self.send_json({"status": "saved"})
        except OSError as e:
            self.send_json({"error": f"Write failed: {e}"}, 500)


def find_free_port(host):
    """Find a free port by binding to port 0."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, 0))
        return s.getsockname()[1]


def main():
    parser = argparse.ArgumentParser(description="Excalidraw file server")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind to")
    parser.add_argument("--port", type=int, default=0, help="Port (0 = random)")
    args = parser.parse_args()

    host = args.host
    port = args.port if args.port != 0 else find_free_port(host)

    server = HTTPServer((host, port), ExcalidrawHandler)

    # Graceful shutdown on SIGTERM/SIGINT
    def shutdown_handler(signum, frame):
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown_handler)
    signal.signal(signal.SIGINT, shutdown_handler)

    # Signal to Neovim that we're ready
    print(f"READY:{port}", flush=True)

    server.serve_forever()


if __name__ == "__main__":
    main()
