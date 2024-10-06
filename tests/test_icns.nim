import unittest
import os
import icon
import icon/icns
import sequtils
import asyncdispatch

suite "ICNS":
  test "generateICNS":
    let dir = getTempDir()
    const root = currentSourcePath.parentDir.parentDir
    let images = icns.REQUIRED_IMAGE_SIZES.map(proc (size: int): ImageInfo{.closure.} =
      let filePath = root / "./examples/data" / $size & ".png"
      result = ImageInfo(size: size, filePath: filePath)
    )
    let path = waitfor generateICNSAsync(images, dir)
    echo path
    check getFileSize(path) >= getFileSize(root / "tests" / "app.icns")
