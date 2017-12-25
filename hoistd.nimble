version      = "0.1.0"
author       = "Harshad Sharma"
description  = "Serve contents of a directory quickly over self-signed https; with optional basic authentication."
license      = "MIT"
installFiles = @["hoistd.nim"]
bin = @["hoistd"]
srcDir = "src"

requires "nim >= 0.15.2", "jester", "docopt"

