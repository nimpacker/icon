# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import os
import icon/ico
import sequtils

test "ico":
  const testDir = currentSourcePath.parentDir() #/ ".." / ".." / "tests"
  const dir = getTempDir()
  const root = currentSourcePath.parentDir.parentDir
  let images = ico.REQUIRED_IMAGE_SIZES.map(proc (size: int): ImageInfo{.closure.} =
      let filePath = root / "./examples/data" / $size & ".png"
      echo filePath
      result = ImageInfo(size: size, filePath: filePath)
    )
  let path = generateICO(images, dir)
  echo path
  assert readFile(path) == readFile(testDir / "app.ico")
