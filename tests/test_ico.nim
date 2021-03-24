# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import os
import iconpkg/ico

test "ico":
  const testDir = currentSourcePath.parentDir() #/ ".." / ".." / "tests" 
  const dir = getTempDir()
  const nim_logo = testDir / "logo_bw.png"
  let img = ImageInfo(filePath:nim_logo,size:32)
  let path = generateICO(@[img],dir)
  assert readFile(path) == readFile(testDir / "app.ico")
