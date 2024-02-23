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
