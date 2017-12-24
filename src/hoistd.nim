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

let args = docopt(doc, version = "0.1.0")

proc error(msg: string) =
  styledWriteLine(stderr, fgRed, "ERROR: ", resetStyle, msg)

proc info(msg: string) =
  styledWriteLine(stdout, fgBlue, "INFO: ", resetStyle, msg)


info "path: " & $args["--path"]
info "endpoint: https://" & $args["--bind"] & ":" & $args["--port"]
info "Hoisted!"
