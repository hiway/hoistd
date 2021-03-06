let doc = """
hoistd

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
  --tor-persist           Create/use key for a persistent .onion address.
  --tor-key=<kp>          Save/load Tor service key to this path [default: ~/.hoistd].
  --tor-password=<file>   File containing Tor controller password, if using passwordhash.
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
let tor_persist = args["--tor-persist"]
let tor_key_file = $args["--tor-key"]
let tor_password = if $args["--tor-password"] != "": readFile($args["--tor-password"]).strip() else: ""



proc error(msg: string, hint: string = "") =
  styledWriteLine(stdout, fgRed, "ERROR ", resetStyle, msg, fgBlue, hint, resetStyle)


proc info(msg: string, hint: string = "") =
  styledWriteLine(stdout, fgBlue, "INFO ", resetStyle, msg, fgBlue, hint, resetStyle)


proc tor_create_hidden_service(sock: AsyncSocket): Future[string] {.gcsafe, async.} =
  await sock.send("ADD_ONION NEW:BEST Port=80," & endpoint & ":" & $port & "\r\L")
  let addr_line = await sock.recvLine()
  result = "http://" & addr_line[addr_line.find("=") + 1 .. ^1] & ".onion"
  let tor_key_response = await sock.recvLine()
  if tor_persist == true:
    info "PERSISTING hidden service."
    let tor_key = $tor_key_response[tor_key_response.find("=") + 1 .. ^1]
    discard execProcess("cat << EOF > " & tor_key_file & "\L" & tor_key & "\LEOF\L")
  else:
    info "EPHEMERAL hidden service."


proc tor_start_hidden_service(sock: AsyncSocket): Future[string] {.gcsafe, async.} =
  # let tor_key = readFile(tor_key_file)
  let tor_key = execProcess("cat " & tor_key_file).strip()
  if tor_key.find("file or directory") != -1:
    result = ""
    return
  let tor_command = "ADD_ONION " & $tor_key & " Port=80," & endpoint & ":" & $port & "\r\L"
  await sock.send(tor_command)
  let addr_line = await sock.recvLine()
  result = "http://" & addr_line[addr_line.find("=") + 1 .. ^1] & ".onion"


proc tor_authenticate(sock: AsyncSocket, password = "") {.gcsafe, async.} =
  await sock.send("PROTOCOLINFO\r\L")
  discard await sock.recvLine() # 250-PROTOCOLINFO 1
  # 250-AUTH METHODS=COOKIE,SAFECOOKIE,HASHEDPASSWORD COOKIEFILE="/usr/local/var/lib/tor/control_auth_cookie"
  let protocol_info = await sock.recvLine()
  discard await sock.recvLine()
  discard await sock.recvLine()

  if password != "":
    if  protocol_info.find("HASHEDPASSWORD") < 0:
      error "Password provided, but authentication not enabled.", "Set 'HashedControlPassword' in your 'torrc' file."
      # todo: exit.
    info "Password auth."
    await sock.send("AUTHENTICATE \"" & password & "\"\r\L")
  else:
    if protocol_info.find("COOKIE") < 0:
      error "Cookie authentication not enabled.", "Set 'CookieAuthentication 1' in your 'torrc' file."
      # todo: exit.
    info "Cookie auth."
    let tor_cookie_file = protocol_info[protocol_info.find("COOKIEFILE") + 12 .. ^2]   # /usr/local/var/lib/tor/control_auth_cookie
    let cmd = """hexdump -e '32/1 "%02x""\n"' """ & tor_cookie_file
    let outp = execProcess(cmd)
    await sock.send("AUTHENTICATE " & $outp.strip & "\r\L")
  discard await sock.recvLine()


proc tor_start_ephemeral_hidden_service(): Future[string] {.gcsafe, async.} =
  info "Connecting to Tor controller: ", tor_host & ":" & $tor_port
  var create_service = false
  var sock = newAsyncSocket()
  await sock.connect(tor_host, tor_port)
  await sock.tor_authenticate(tor_password)
  if tor_persist:
      result = await sock.tor_start_hidden_service()
      if result == "":
        create_service = true
  else:
    create_service = true
  if create_service:
    result = await sock.tor_create_hidden_service()
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


proc main() {.gcsafe, async.} =

  info "Directory: ", $args["--path"]
  info "Hoisted at: ", "http://" & $args["--bind"] & ":" & $args["--port"]

  if hoist_on_tor == true:
    let onion_address = await tor_start_ephemeral_hidden_service()
    info "Hoisted on Tor at: ", onion_address
    info "Tor address will be reachable in a few moments."


waitFor main()
runForever()
