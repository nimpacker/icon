# icon  

Generate an icon files from **PNG** files.  

port of typescript project [akabekobeko/npm-icon-gen](https://github.com/akabekobeko/npm-icon-gen)

## Support formats

Supported the output format of the icon are following.

| Platform | Icon                                |
| -------: | ----------------------------------- |
|  Windows | `app.ico` or specified name.        |
|    macOS | `app.icns` or specified name.       |
|  Favicon | `favicon.ico` and `favicon-XX.png`. |

## Installation

```
$ nimble install https://github.com/bung87/icon
```

## Usage  

``` Nim 
import icon/icns
import asyncdispatch
import sequtils

let dir = getTempDir()
let images = icns.REQUIRED_IMAGE_SIZES.map(proc (size:int):ImageInfo{.closure.} =
    let filePath = getCurrentDir() / "./examples/data" /  $size & ".png"
    result = ImageInfo( size:size, filePath:filePath )
)
let path = waitfor generateICNS(images,dir)
# or generateICNSAsync(images, dir)

import asyncdispatch
import icon/ico
import sequtils

let images = ico.REQUIRED_IMAGE_SIZES.map(proc (size: int): ImageInfo{.closure.} =
      let filePath = root / "./examples/data" / $size & ".png"
      echo filePath
      result = ImageInfo(size: size, filePath: filePath)
    )
let path = generateICO(images, dir)
# or generateICOAsync(images, dir)
```


