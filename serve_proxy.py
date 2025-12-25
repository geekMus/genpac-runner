#!/usr/bin/env python3
# 只暴露 /proxy.pac，浏览器访问直接显示 UTF-8 内容
from http.server import HTTPServer, BaseHTTPRequestHandler

PAC_FILE = "/data/proxy.pac"
PORT = 8080

class ProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            # 访问根路径自动跳转到 /proxy.pac
            self.send_response(302)
            self.send_header("Location", "/proxy.pac")
            self.end_headers()
            return
        if self.path != "/proxy.pac":
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Forbidden\n")
            return
        try:
            with open(PAC_FILE, "r", encoding="utf-8") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(content.encode("utf-8"))))
            self.end_headers()
            self.wfile.write(content.encode("utf-8"))
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode("utf-8"))

httpd = HTTPServer(("", PORT), ProxyHandler)
print(f"Serving proxy.pac on port {PORT}, UTF-8, inline display")
httpd.serve_forever()
