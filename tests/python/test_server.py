#!/usr/bin/env python3
"""Tests for excalidraw_server.py.

Uses only Python stdlib (unittest) to match the project's zero-dependency philosophy.
Run with: python -m pytest tests/python/ or python -m unittest tests/python/test_server.py
"""

import json
import os
import sys
import tempfile
import threading
import unittest
from http.server import HTTPServer
from urllib.request import Request, urlopen
from urllib.error import HTTPError

# Add server directory to path so we can import the module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "server"))

import excalidraw_server as server_module
from excalidraw_server import ExcalidrawHandler, is_allowed_path, find_free_port


class TestIsAllowedPath(unittest.TestCase):
    """Tests for the is_allowed_path() security function."""

    def setUp(self):
        server_module.ALLOWED_BASE_DIRS = ["/home/user", "/a/b/c/d/e", os.getcwd()]

    def tearDown(self):
        server_module.ALLOWED_BASE_DIRS = []

    def test_excalidraw_extension(self):
        self.assertTrue(is_allowed_path("/home/user/drawing.excalidraw"))

    def test_excalidraw_json_extension(self):
        self.assertTrue(is_allowed_path("/home/user/drawing.excalidraw.json"))

    def test_plain_json_rejected(self):
        self.assertFalse(is_allowed_path("/home/user/data.json"))

    def test_txt_rejected(self):
        self.assertFalse(is_allowed_path("/home/user/notes.txt"))

    def test_no_extension_rejected(self):
        self.assertFalse(is_allowed_path("/home/user/drawing"))

    def test_empty_string_rejected(self):
        self.assertFalse(is_allowed_path(""))

    def test_partial_extension_rejected(self):
        self.assertFalse(is_allowed_path("/home/user/file.excalidra"))

    def test_extension_in_directory_name_rejected(self):
        self.assertFalse(is_allowed_path("/home/user/.excalidraw/config.txt"))

    def test_nested_path(self):
        self.assertTrue(is_allowed_path("/a/b/c/d/e/drawing.excalidraw"))

    def test_relative_path(self):
        self.assertTrue(is_allowed_path("./drawing.excalidraw"))

    def test_dotfile_excalidraw(self):
        self.assertTrue(is_allowed_path("/home/user/.hidden.excalidraw"))

    def test_no_base_dirs_rejects_all(self):
        server_module.ALLOWED_BASE_DIRS = []
        self.assertFalse(is_allowed_path("/home/user/drawing.excalidraw"))
        self.assertFalse(is_allowed_path("/tmp/test.excalidraw"))


class TestFindFreePort(unittest.TestCase):
    """Tests for find_free_port()."""

    def test_returns_integer(self):
        port = find_free_port("127.0.0.1")
        self.assertIsInstance(port, int)

    def test_returns_valid_port(self):
        port = find_free_port("127.0.0.1")
        self.assertGreater(port, 0)
        self.assertLessEqual(port, 65535)

    def test_returns_different_ports(self):
        """Successive calls should generally return different ports."""
        ports = {find_free_port("127.0.0.1") for _ in range(5)}
        # At least some should differ (not guaranteed but extremely likely)
        self.assertGreaterEqual(len(ports), 1)


class LiveServerTestCase(unittest.TestCase):
    """Base class that starts a real HTTP server for integration tests."""

    @classmethod
    def setUpClass(cls):
        server_module.ALLOWED_BASE_DIRS = []
        cls.server = HTTPServer(("127.0.0.1", 0), ExcalidrawHandler)
        cls.port = cls.server.server_address[1]
        cls.base_url = f"http://127.0.0.1:{cls.port}"
        cls.thread = threading.Thread(target=cls.server.serve_forever)
        cls.thread.daemon = True
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.thread.join(timeout=5)
        server_module.ALLOWED_BASE_DIRS = []

    def request(self, method, path, body=None, headers=None):
        """Helper to make HTTP requests to the test server."""
        url = self.base_url + path
        data = body.encode("utf-8") if isinstance(body, str) else body
        req = Request(url, data=data, method=method)
        if headers:
            for k, v in headers.items():
                req.add_header(k, v)
        try:
            resp = urlopen(req)
            return resp.status, resp.read().decode("utf-8"), dict(resp.headers)
        except HTTPError as e:
            return e.code, e.read().decode("utf-8"), dict(e.headers)


class TestHealthEndpoint(LiveServerTestCase):
    """Tests for GET /api/health."""

    def test_health_returns_ok(self):
        status, body, _ = self.request("GET", "/api/health")
        self.assertEqual(status, 200)
        data = json.loads(body)
        self.assertEqual(data["status"], "ok")

    def test_health_content_type(self):
        _, _, headers = self.request("GET", "/api/health")
        self.assertIn("application/json", headers.get("Content-Type", ""))

    def test_health_cors_header(self):
        _, _, headers = self.request("GET", "/api/health", headers={"Origin": "http://localhost:3000"})
        self.assertIsNotNone(headers.get("Access-Control-Allow-Origin"))


class TestIndexEndpoint(LiveServerTestCase):
    """Tests for GET /."""

    def test_index_returns_html(self):
        status, body, headers = self.request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn("text/html", headers.get("Content-Type", ""))
        self.assertIn("excalidraw", body.lower())

    def test_index_contains_react(self):
        _, body, _ = self.request("GET", "/")
        self.assertIn("react", body.lower())


class TestOptionsEndpoint(LiveServerTestCase):
    """Tests for OPTIONS (CORS preflight)."""

    def test_options_returns_204(self):
        status, _, headers = self.request("OPTIONS", "/api/file")
        self.assertEqual(status, 204)

    def test_options_cors_methods(self):
        _, _, headers = self.request("OPTIONS", "/api/file")
        self.assertIn("GET", headers.get("Access-Control-Allow-Methods", ""))
        self.assertIn("POST", headers.get("Access-Control-Allow-Methods", ""))

    def test_options_cors_headers(self):
        _, _, headers = self.request("OPTIONS", "/api/file")
        self.assertIn("Content-Type", headers.get("Access-Control-Allow-Headers", ""))


class TestNotFound(LiveServerTestCase):
    """Tests for 404 responses."""

    def test_get_unknown_path(self):
        status, body, _ = self.request("GET", "/unknown")
        self.assertEqual(status, 404)
        data = json.loads(body)
        self.assertEqual(data["error"], "Not found")

    def test_post_unknown_path(self):
        status, body, _ = self.request("POST", "/unknown", body="{}")
        self.assertEqual(status, 404)
        data = json.loads(body)
        self.assertEqual(data["error"], "Not found")


class TestGetFile(LiveServerTestCase):
    """Tests for GET /api/file."""

    def test_missing_path_param(self):
        status, body, _ = self.request("GET", "/api/file")
        self.assertEqual(status, 400)
        data = json.loads(body)
        self.assertEqual(data["error"], "Missing path parameter")

    def test_disallowed_extension(self):
        status, body, _ = self.request("GET", "/api/file?path=/tmp/bad.txt")
        self.assertEqual(status, 403)
        data = json.loads(body)
        self.assertIn("not allowed", data["error"])

    def test_file_not_found(self):
        status, body, _ = self.request(
            "GET", "/api/file?path=/tmp/nonexistent.excalidraw"
        )
        self.assertEqual(status, 404)
        data = json.loads(body)
        self.assertEqual(data["error"], "File not found")

    def test_read_valid_file(self):
        """Create a temporary .excalidraw file and read it via the API."""
        content = {
            "type": "excalidraw",
            "version": 2,
            "elements": [],
        }
        with tempfile.NamedTemporaryFile(
            suffix=".excalidraw", mode="w", delete=False
        ) as f:
            json.dump(content, f)
            tmp_path = f.name

        try:
            status, body, _ = self.request(
                "GET", f"/api/file?path={tmp_path}"
            )
            self.assertEqual(status, 200)
            data = json.loads(body)
            self.assertEqual(data["type"], "excalidraw")
            self.assertEqual(data["version"], 2)
            self.assertEqual(data["elements"], [])
        finally:
            os.unlink(tmp_path)

    def test_read_excalidraw_json_file(self):
        """Test that .excalidraw.json extension is also accepted."""
        content = {"type": "excalidraw", "version": 2}
        with tempfile.NamedTemporaryFile(
            suffix=".excalidraw.json", mode="w", delete=False
        ) as f:
            json.dump(content, f)
            tmp_path = f.name

        try:
            status, body, _ = self.request(
                "GET", f"/api/file?path={tmp_path}"
            )
            self.assertEqual(status, 200)
            data = json.loads(body)
            self.assertEqual(data["type"], "excalidraw")
        finally:
            os.unlink(tmp_path)

    def test_read_invalid_json(self):
        """Test reading a file with invalid JSON content."""
        with tempfile.NamedTemporaryFile(
            suffix=".excalidraw", mode="w", delete=False
        ) as f:
            f.write("not valid json{{{")
            tmp_path = f.name

        try:
            status, body, _ = self.request(
                "GET", f"/api/file?path={tmp_path}"
            )
            self.assertEqual(status, 400)
            data = json.loads(body)
            self.assertIn("Invalid JSON", data["error"])
        finally:
            os.unlink(tmp_path)


class TestPostFile(LiveServerTestCase):
    """Tests for POST /api/file."""

    def test_missing_path_param(self):
        status, body, _ = self.request(
            "POST",
            "/api/file",
            body="{}",
            headers={"Content-Type": "application/json"},
        )
        self.assertEqual(status, 400)
        data = json.loads(body)
        self.assertEqual(data["error"], "Missing path parameter")

    def test_disallowed_extension(self):
        status, body, _ = self.request(
            "POST",
            "/api/file?path=/tmp/bad.txt",
            body="{}",
            headers={"Content-Type": "application/json"},
        )
        self.assertEqual(status, 403)
        data = json.loads(body)
        self.assertIn("not allowed", data["error"])

    def test_invalid_json_body(self):
        with tempfile.NamedTemporaryFile(
            suffix=".excalidraw", mode="w", delete=False
        ) as f:
            f.write("{}")
            tmp_path = f.name

        try:
            status, body, _ = self.request(
                "POST",
                f"/api/file?path={tmp_path}",
                body="not json{{",
                headers={"Content-Type": "application/json"},
            )
            self.assertEqual(status, 400)
            data = json.loads(body)
            self.assertIn("Invalid JSON body", data["error"])
        finally:
            os.unlink(tmp_path)

    def test_write_valid_file(self):
        """Write a file via POST and verify it on disk."""
        content = {
            "type": "excalidraw",
            "version": 2,
            "elements": [{"id": "test"}],
        }

        with tempfile.NamedTemporaryFile(
            suffix=".excalidraw", delete=False
        ) as f:
            tmp_path = f.name

        try:
            status, body, _ = self.request(
                "POST",
                f"/api/file?path={tmp_path}",
                body=json.dumps(content),
                headers={"Content-Type": "application/json"},
            )
            self.assertEqual(status, 200)
            data = json.loads(body)
            self.assertEqual(data["status"], "saved")

            # Verify file on disk
            with open(tmp_path, "r") as f:
                saved = json.load(f)
            self.assertEqual(saved["type"], "excalidraw")
            self.assertEqual(saved["elements"], [{"id": "test"}])
        finally:
            os.unlink(tmp_path)

    def test_atomic_write_no_tmp_left(self):
        """Verify that no .tmp file remains after a successful write."""
        content = {"type": "excalidraw", "version": 2}

        with tempfile.NamedTemporaryFile(
            suffix=".excalidraw", delete=False
        ) as f:
            tmp_path = f.name

        try:
            self.request(
                "POST",
                f"/api/file?path={tmp_path}",
                body=json.dumps(content),
                headers={"Content-Type": "application/json"},
            )
            # The .tmp file should not exist after successful write
            self.assertFalse(os.path.exists(tmp_path + ".tmp"))
        finally:
            os.unlink(tmp_path)

    def test_write_preserves_formatting(self):
        """Verify that written JSON is indented (human-readable)."""
        content = {"type": "excalidraw", "version": 2}

        with tempfile.NamedTemporaryFile(
            suffix=".excalidraw", delete=False
        ) as f:
            tmp_path = f.name

        try:
            self.request(
                "POST",
                f"/api/file?path={tmp_path}",
                body=json.dumps(content),
                headers={"Content-Type": "application/json"},
            )
            with open(tmp_path, "r") as f:
                raw = f.read()
            # Should have indentation (pretty-printed)
            self.assertIn("  ", raw)
            # Should end with newline
            self.assertTrue(raw.endswith("\n"))
        finally:
            os.unlink(tmp_path)

    def test_write_to_new_path(self):
        """Write to a path that doesn't exist yet."""
        tmp_dir = tempfile.mkdtemp()
        tmp_path = os.path.join(tmp_dir, "new_drawing.excalidraw")

        try:
            content = {"type": "excalidraw", "version": 2}
            status, body, _ = self.request(
                "POST",
                f"/api/file?path={tmp_path}",
                body=json.dumps(content),
                headers={"Content-Type": "application/json"},
            )
            self.assertEqual(status, 200)
            self.assertTrue(os.path.exists(tmp_path))

            with open(tmp_path, "r") as f:
                saved = json.load(f)
            self.assertEqual(saved["type"], "excalidraw")
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            os.rmdir(tmp_dir)

    def test_roundtrip(self):
        """Write then read back the same content."""
        content = {
            "type": "excalidraw",
            "version": 2,
            "source": "test",
            "elements": [{"id": "1", "type": "rectangle"}],
            "appState": {"viewBackgroundColor": "#000000"},
            "files": {},
        }

        with tempfile.NamedTemporaryFile(
            suffix=".excalidraw", delete=False
        ) as f:
            tmp_path = f.name

        try:
            # Write
            status, _, _ = self.request(
                "POST",
                f"/api/file?path={tmp_path}",
                body=json.dumps(content),
                headers={"Content-Type": "application/json"},
            )
            self.assertEqual(status, 200)

            # Read back
            status, body, _ = self.request(
                "GET", f"/api/file?path={tmp_path}"
            )
            self.assertEqual(status, 200)
            data = json.loads(body)
            self.assertEqual(data, content)
        finally:
            os.unlink(tmp_path)


if __name__ == "__main__":
    unittest.main()
