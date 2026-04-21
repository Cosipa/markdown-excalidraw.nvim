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
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from urllib.parse import urlparse, parse_qs


ALLOWED_EXTENSIONS = (".excalidraw", ".excalidraw.json")


ALLOWED_BASE_DIRS = []

LIBRARY_PATH = None

IDLE_TIMEOUT_SECONDS = 0

LAST_REQUEST_TIME = None


def get_library_template():
    return {
        "type": "excalidrawlib",
        "version": 2,
        "source": "excalidraw.nvim",
        "libraryItems": [],
    }


def is_allowed_path(path):
    """Check if the file path has an allowed extension and is within allowed directories."""
    for ext in ALLOWED_EXTENSIONS:
        if path.endswith(ext):
            abs_path = os.path.abspath(path)
            for base_dir in ALLOWED_BASE_DIRS:
                if abs_path.startswith(os.path.abspath(base_dir)):
                    return True
            if not ALLOWED_BASE_DIRS:
                return True
    return False


def set_allowed_base_dir(path):
    """Set the allowed base directory based on the first file opened."""
    global ALLOWED_BASE_DIRS
    abs_path = os.path.abspath(path)
    for ext in ALLOWED_EXTENSIONS:
        if abs_path.endswith(ext):
            ALLOWED_BASE_DIRS = [os.path.dirname(abs_path)]
            return True
    return False


def touch_last_request():
    global LAST_REQUEST_TIME
    LAST_REQUEST_TIME = time.monotonic()


def idle_monitor(server, interval=30):
    """Background thread that shuts down server after idle timeout."""
    while True:
        time.sleep(interval)
        if IDLE_TIMEOUT_SECONDS <= 0:
            continue
        if LAST_REQUEST_TIME is None:
            continue
        idle = time.monotonic() - LAST_REQUEST_TIME
        if idle > IDLE_TIMEOUT_SECONDS:
            threading.Thread(target=server.shutdown, daemon=True).start()
            return


class ExcalidrawHandler(BaseHTTPRequestHandler):
    ALLOWED_ORIGINS = ("http://localhost", "http://127.0.0.1", "http://localhost:")

    def log_message(self, format, *args):
        pass

    def get_allowed_origin(self):
        origin = self.headers.get("Origin", "")
        for allowed in self.ALLOWED_ORIGINS:
            if origin.startswith(allowed):
                return origin
        return None

    def send_json(self, data, status=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        origin = self.get_allowed_origin()
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, text, content_type="text/html", status=200):
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        origin = self.get_allowed_origin()
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        touch_last_request()
        self.send_response(204)
        origin = self.get_allowed_origin()
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        touch_last_request()
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if path == "/":
            self.serve_index()
        elif path == "/api/file":
            self.handle_get_file(params)
        elif path == "/api/library":
            self.handle_get_library()
        elif path == "/api/health":
            self.send_json({"status": "ok"})
        else:
            self.send_json({"error": "Not found"}, 404)

    def do_POST(self):
        touch_last_request()
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if path == "/api/file":
            self.handle_post_file(params)
        elif path == "/api/library":
            self.handle_post_library()
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

        if not ALLOWED_BASE_DIRS:
            set_allowed_base_dir(file_path)

        if not is_allowed_path(file_path):
            self.send_json({"error": "File type not allowed or not in allowed directory"}, 403)
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

        if not ALLOWED_BASE_DIRS:
            set_allowed_base_dir(file_path)

        if not is_allowed_path(file_path):
            self.send_json({"error": "File type not allowed or not in allowed directory"}, 403)
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            data = json.loads(body)
        except json.JSONDecodeError as e:
            self.send_json({"error": f"Invalid JSON body: {e}"}, 400)
            return

        try:
            tmp_path = file_path + ".tmp"
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
            os.replace(tmp_path, file_path)
            self.send_json({"status": "saved"})
        except OSError as e:
            self.send_json({"error": f"Write failed: {e}"}, 500)

    def handle_get_library(self):
        if not LIBRARY_PATH:
            self.send_json({"error": "Library not configured"}, 400)
            return

        try:
            with open(LIBRARY_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.send_json(data)
        except FileNotFoundError:
            template = get_library_template()
            self.send_json(template)
        except json.JSONDecodeError as e:
            self.send_json({"error": f"Invalid library JSON: {e}"}, 400)

    def handle_post_library(self):
        if not LIBRARY_PATH:
            self.send_json({"error": "Library not configured"}, 400)
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            data = json.loads(body)
        except json.JSONDecodeError as e:
            self.send_json({"error": f"Invalid JSON body: {e}"}, 400)
            return

        try:
            os.makedirs(os.path.dirname(LIBRARY_PATH), exist_ok=True)
            tmp_path = LIBRARY_PATH + ".tmp"
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
            os.replace(tmp_path, LIBRARY_PATH)
            self.send_json({"status": "saved"})
        except OSError as e:
            self.send_json({"error": f"Library write failed: {e}"}, 500)


def find_free_port(host):
    """Find a free port by binding to port 0."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, 0))
        return s.getsockname()[1]


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


def main():
    global LIBRARY_PATH, IDLE_TIMEOUT_SECONDS

    parser = argparse.ArgumentParser(description="Excalidraw file server")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind to")
    parser.add_argument("--port", type=int, default=0, help="Port (0 = random)")
    parser.add_argument("--library", default=None, help="Path to library file")
    parser.add_argument("--timeout", type=int, default=0, help="Idle timeout in minutes (0 = disabled)")
    args = parser.parse_args()

    if args.library:
        LIBRARY_PATH = os.path.abspath(args.library)

    if args.timeout > 0:
        IDLE_TIMEOUT_SECONDS = args.timeout * 60

    host = args.host
    port = args.port if args.port != 0 else find_free_port(host)

    server = ThreadingHTTPServer((host, port), ExcalidrawHandler)

    def shutdown_handler(signum, frame):
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown_handler)
    signal.signal(signal.SIGINT, shutdown_handler)

    if IDLE_TIMEOUT_SECONDS > 0:
        t = threading.Thread(target=idle_monitor, args=(server,), daemon=True)
        t.start()

    print(f"READY:{port}", flush=True)

    server.serve_forever()


if __name__ == "__main__":
    main()
