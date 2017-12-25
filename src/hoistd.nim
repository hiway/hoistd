let doc = """
Hoist Directory

Usage:
  hoistd [--path=<path>] [--bind=<bind>] [--port=<port>]

Options:
  -h --help      Show this screen.
  --version      Show version.
  --path=<path>  Hoist directory at path [default: ./].
  --bind=<bind>  Bind to IP address [default: 127.0.0.1].
  --port=<port>  Bind to port [default: 8443].
"""

import strutils
import docopt
import terminal
import asyncdispatch
import strutils
import jester
import htmlgen
import os
import re
import cgi


let args = docopt(doc, version = "0.1.0")
let static_path = $args["--path"]
let port = Port(parseInt($args["--port"]))
let endpoint = $args["--bind"]


proc info(msg: string) =
  styledWriteLine(stdout, fgBlue, "INFO: ", resetStyle, msg)


settings:
  port = port
  bind_addr = endpoint


routes:
  get "/":
    setStaticDir(request, static_path)
    var file_list = ""
    var file_path = ""
    for file in walkDirRec static_path:
        file_path = file[2 .. ^1]  # Remove "./" prefix from path.
        file_list.add li(a(href=encode_url(file_path), file_path))
    let html = html(
      head(
        title("hoistd"),
        link(href="/app.css", rel="stylesheet"),
        ),
      body(
        h3("hoistd"),
        ul(file_list))
        )
    resp html

  get "/app.css":
    const app_css = staticRead "app.css"
    resp app_css


info "path: " & $args["--path"]
info "hoisted at: https://" & $args["--bind"] & ":" & $args["--port"]
runForever()
