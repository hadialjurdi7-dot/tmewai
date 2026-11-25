#!/usr/bin/env python3
"""Static server for the Flutter web build with the drift MIME types.

python3 -m http.server sends .wasm as application/octet-stream, which makes
WebAssembly.instantiateStreaming refuse the module, so the database never opens
and the app sits on its spinner. This mirrors what docker/nginx.conf does.

Usage: python3 tool/serve_web.py <dir> <port>
"""
import functools
import http.server
import mimetypes
import sys

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("application/json", ".json")


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Cross-origin isolation is what lets drift run its database in a
        # SharedArrayBuffer-backed worker. Without these two headers the wasm
        # worker can stall before its first query, which looks like a spinner
        # that never resolves.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    directory = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
    handler = functools.partial(Handler, directory=directory)
    http.server.ThreadingHTTPServer(("0.0.0.0", port), handler).serve_forever()
