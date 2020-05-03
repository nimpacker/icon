import sequtils,asyncdispatch,asyncstreams,asyncfile,strformat,os
import ./png
import ./ico

# Options ot generate ICO file. 
type FavOptions* = object of RootObj
# Prefix of an output PNG files. Start with the alphabet, can use `-` and `_`. This option is for PNG. The name of the ICO file is always `favicon.ico`. 
  name*: string
# Size structure of PNG files to output. 
  pngSizes*: seq[int]
# Structure of an image sizes for ICO. 
  icoSizes*: seq[int]

# Sizes required for the PNG files. 
const REQUIRED_PNG_SIZES* = [32, 57, 72, 96, 120, 128, 144, 152, 195, 228]
# Sizes required for ICO file. 
const REQUIRED_ICO_SIZES* = [16, 24, 32, 48, 64]
# Sizes required for Favicon files. 
const REQUIRED_IMAGE_SIZES* = [16, 24, 32, 48, 57, 64, 72, 96, 120, 128, 144, 152, 195, 228]
# File name of Favicon file. 
const ICO_FILE_NAME = "favicon"
# Prefix of PNG file names. 
const PNG_FILE_NAME_PREFIX = "favicon-"

# Copy to image.
# @param image Image information.
# @param dir Output destination The path of directory.
# @param prefix Prefix of an output PNG files. Start with the alphabet, can use `-` and `_`. This option is for PNG. The name of the ICO file is always `favicon.ico`.
# @return Path of generated PNG file.

proc copyImage(image:ImageInfo,dir:string,prefix:string): Future[string]{.async.} =
  let src = openAsync(image.filePath,fmRead)
  let destStream = newFutureStream[string]("copyImage")
  let destPath = dir / (fmt"{prefix}{image.size}.png")
  let dest = openAsync(destPath,fmWrite)
  destStream.callback = proc (future: FutureStream[string]){.closure, gcsafe.} =
    if not finished(future):
      discard dest.writeFromStream(future)
    else:
      dest.close
  await src.readToStream(destStream)
  return destPath

# Generate the FAVICON PNG file from the PNG images.
# @param images File information for the PNG files generation.
# @param dir Output destination the path of directory.
# @param prefix Prefix of an output PNG files. Start with the alphabet, can use `-` and `_`. This option is for PNG. The name of the ICO file is always `favicon.ico`.
# @param sizes Size structure of PNG files to output.
# @return Path of the generated files.

proc generatePNG*(images:seq[ImageInfo],dir:string,prefix:string,sizes:seq[int]): Future[seq[string]] {.async.} =

  let targets = filterImagesBySizes(images, sizes)
  for image in targets: 
    result.add(await copyImage(image, dir, prefix))

# Generate a FAVICON image files (ICO and PNG) from the PNG images.
# @param images File information for the PNG files generation.
# @param dir Output destination the path of directory.
# @param options Options.
# @return Path of the generated files.

proc generateFavicon*(images:seq[ImageInfo],dir:string,options:FavOptions): Future[seq[string]]{.async.} =
  let name =  if options.name.len > 0: options.name else: PNG_FILE_NAME_PREFIX
  let pngSizes = if options.pngSizes.len > 0:options.pngSizes else: REQUIRED_PNG_SIZES.toSeq
  let icoSizes = if options.icoSizes.len > 0:options.icoSizes else: REQUIRED_ICO_SIZES.toSeq
  let opt = FavOptions(name: name,pngSizes:pngSizes,icoSizes:icoSizes)
  result = await generatePNG(images, dir, opt.name, opt.pngSizes)
  let iconOpts = ICOOptions( name: ICO_FILE_NAME,sizes: opt.icoSizes)
  result.add(  generateICO(filterImagesBySizes(images,opt.icoSizes), dir,iconOpts))
