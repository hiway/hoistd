let doc = """
Hoist Directory

Usage:
  hoistd [options]

Options:
  -h --help               Show this screen.
  --version               Show version.
  --path=<path>           Hoist directory at path [default: ./].
  --bind=<bind>           Bind to IP address [default: 127.0.0.1].
  --port=<port>           Bind to port [default: 8443].
  --tor                   Connect to local Tor client and hoist a hidden service.
  --tor-host=<th>         Tor controller host [default: 127.0.0.1].
  --tor-port=<tp>         Tor controller port [default: 9051].
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
import net
import asyncnet
import osproc

let args = docopt(doc, version = "0.1.0")
let static_path = $args["--path"]
let port = Port(parseInt($args["--port"]))
let endpoint = $args["--bind"]
let hoist_on_tor = args["--tor"]
let tor_host = $args["--tor-host"]
let tor_port = Port(parseInt($args["--tor-port"]))

var onion_address = ""

proc error(msg: string, hint: string = "") =
  styledWriteLine(stdout, fgRed, "ERROR ", resetStyle, msg, fgBlue, hint, resetStyle)


proc info(msg: string, hint: string = "") =
  styledWriteLine(stdout, fgBlue, "INFO ", resetStyle, msg, fgBlue, hint, resetStyle)

proc recvAll(sock: AsyncSocket) {.async.} =
  for i in 0 .. 50:
    var ret = await recv(sock, 100)
    echo ret

proc tor_create_ephemeral_hidden_service() {.async.} =
  info "Connecting to Tor controller: ", tor_host & ":" & $tor_port
  var site_created = false
  var sock = newAsyncSocket()
  await sock.connect(tor_host, tor_port)
  await sock.send("PROTOCOLINFO\r\L")
  discard await sock.recvLine() # 250-PROTOCOLINFO 1
  # 250-AUTH METHODS=COOKIE,SAFECOOKIE,HASHEDPASSWORD COOKIEFILE="/usr/local/var/lib/tor/control_auth_cookie"
  let protocol_info = await sock.recvLine()
  if protocol_info.find("COOKIE") < 0:
    error "Cookie authentication not enabled.", "Set 'CookieAuthentication 1' in your 'torrc' file."
  discard await sock.recvLine()
  discard await sock.recvLine()
  let tor_cookie_file = protocol_info[protocol_info.find("COOKIEFILE") + 12 .. ^2]   # /usr/local/var/lib/tor/control_auth_cookie
  let cmd = """hexdump -e '32/1 "%02x""\n"' """ & tor_cookie_file
  let outp = execProcess(cmd)
  await sock.send("AUTHENTICATE " & $outp.strip & "\r\L")
  discard await sock.recvLine()
  await sock.send("ADD_ONION NEW:BEST Port=80," & endpoint & ":" & $port & "\r\L")
  let addr_line = await sock.recvLine()
  onion_address = "http://"
  onion_address.add(addr_line[addr_line.find("=") + 1 .. ^1])
  onion_address.add(".onion")
  discard await sock.recvLine()
  discard await sock.recvLine()


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
    let page = html(
      head(
        title("hoistd"),
        link(href="/app.css", rel="stylesheet"),
        ),
      body(
        h3("hoistd"),
        ul(file_list))
        )
    resp page

  get "/app.css":
    const app_css = staticRead "app.css"
    resp app_css


proc main() {.async.} =

  info "Directory: ", $args["--path"]
  info "Hoisted at: ", "http://" & $args["--bind"] & ":" & $args["--port"]

  if hoist_on_tor == true:
    await tor_create_ephemeral_hidden_service()
    info "Hoisted on Tor at: ", onion_address
    info "Tor address will be reachable in a few moments."


waitFor main()
runForever()
