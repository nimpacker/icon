import unittest
import icon/favicon
import sequtils
import asyncdispatch
import icon/png
import os

suite "favicon":
  test "generateFavicon":
    const root = currentSourcePath.parentDir.parentDir
    let images = REQUIRED_IMAGE_SIZES.map(proc(size: int): ImageInfo{.closure.} =
      let filePath = root / "examples/data" / $size & ".png"
      result = ImageInfo(size: size, filePath: filePath)
    )
    var results = waitFor generateFavicon(images, getTempDir())
    echo results
    check len(results) == 11
