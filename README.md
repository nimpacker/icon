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

let dir = getTempDir()
let images = REQUIRED_IMAGE_SIZES.map(proc (size:int):ImageInfo{.closure.} =
    let filePath = getCurrentDir() / "./examples/data" /  $size & ".png"
    result = ImageInfo( size:size, filePath:filePath )
)
let options = ICNSOptions()
let path = waitfor generateICNS(images,dir,options)

```


