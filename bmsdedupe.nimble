# Package

version       = "0.1.0"
author        = "NotMichaelChen"
description   = "Manages duplicate BMS in beatoraja"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["bmsdedupe"]


# Dependencies

requires "nim >= 2.0.2"
requires "db_connector#e65693709dd042bc723c8f1d46cc528701f1c479"
