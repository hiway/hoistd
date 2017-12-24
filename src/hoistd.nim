let doc = """
Hoist Directory

Usage:
  hoistd [--path=<path>] [--bind=<bind>] [--port=<port>]

Options:
  -h --help      Show this screen.
  --version      Show version.
  --path=<path>  Hoist directory at path [default: . ].
  --bind=<bind>  Bind to IP address [default: 127.0.0.1].
  --port=<port>  Bind to port [default: 8443].
"""

import strutils
import docopt
import terminal
import asyncdispatch
import asyncnet
import strutils
import jester
import htmlgen
import cgi
import logging


let args = docopt(doc, version = "0.1.0")


proc error(msg: string) =
  styledWriteLine(stderr, fgRed, "ERROR: ", resetStyle, msg)

proc info(msg: string) =
  styledWriteLine(stdout, fgBlue, "INFO: ", resetStyle, msg)


settings:
  port = Port(parseInt($args["--port"]))
  bind_addr = $args["--bind"]


routes:
  get "/":
    resp "Hello, world."


proc main() =
  info "path: " & $args["--path"]
  info "hoisted at: https://" & $args["--bind"] & ":" & $args["--port"]
  runForever()

main()
