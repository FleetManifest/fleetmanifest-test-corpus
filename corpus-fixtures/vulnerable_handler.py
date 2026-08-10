# Corpus fixture. Deliberately vulnerable — do not copy.
import os
import sqlite3
from http.server import BaseHTTPRequestHandler


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        name = self.path.split("=")[-1]

        # py/shell-command-injection
        os.system("echo " + name)

        # py/sql-injection
        conn = sqlite3.connect(":memory:")
        conn.execute("select * from users where name = '" + name + "'")

        self.send_response(200)
        self.end_headers()
