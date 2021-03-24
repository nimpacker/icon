import unittest
import os
import iconpkg/icns
import sequtils
import iconpkg/png 
import asyncdispatch

suite "ICNS":
    test "generateICNS":
        let dir = getTempDir()
        let images = REQUIRED_IMAGE_SIZES.map(proc (size:int):ImageInfo{.closure.} =
            let filePath = getCurrentDir() / "./examples/data" /  $size & ".png"
            result = ImageInfo( size:size, filePath:filePath )
        )
        let path = waitfor generateICNSAsync(images,dir)
        check readFile(path) == readFile( getCurrentDir() / "tests" / "app.icns" )