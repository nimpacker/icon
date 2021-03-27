import unittest
import os
import iconpkg/icns
import sequtils
import iconpkg/png
import asyncdispatch

suite "ICNS":
  test "generateICNS":
    let dir = getTempDir()
    const root =  currentSourcePath.parentDir.parentDir
    let images = REQUIRED_IMAGE_SIZES.map(proc (size: int): ImageInfo{.closure.} =
      let filePath = root / "./examples/data" / $size & ".png"
      echo filePath
      result = ImageInfo(size: size, filePath: filePath)
    )
    let path = waitfor generateICNSAsync(images, dir)
    check readFile(path) == readFile(root / "tests" / "app.icns")
