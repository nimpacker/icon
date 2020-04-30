# Package

version       = "0.1.0"
author        = "bung87"
description   = "Generate icon files from PNG files."
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["icon"]



# Dependencies

requires "nim >= 1.2.0"
requires "nimPNG"
# requires "https://github.com/numforge/laser.git"
requires "arraymancer"