import sequtils, strutils, strformat, struct, streams, nimPNG, asyncdispatch, asyncfile
import ./rle
import ./png
import os
import options
export nimPNG
export png
# Information of pack bit.
type PackBitBody = object of RootObj
  # Colors of compressed by ICNS RLE.
  colors: seq[char]
  # Masks of alpha color.
  masks: seq[char]

# Icon information in ICNS.
type IconInfo = object of RootObj
  typ: string
  size: int
  mask: string

# Options of ICNS.
type ICNSOptions* = object of RootObj
  # Name of an output file.
  name: string
  # Structure of an image sizes.
  sizes: seq[int]

# Sizes required for the ICNS file.
# @type {Array

const REQUIRED_IMAGE_SIZES* = [16, 32, 64, 128, 256, 512, 1024]

# The size of the ICNS header.
# @type {int

const HEADER_SIZE = 8

# Identifier of the ICNS file, in ASCII "icns".
# @type {int

const FILE_HEADER_ID = "icns"

# Default file name.
# @type {String

const DEFAULT_FILE_NAME = "app"

# ICNS file extension.
# @type {String

const FILE_EXTENSION = ".icns"

# Information of the images, Mac OS 8.x (il32, is32, l8mk, s8mk) is unsupported.
# If icp4, icp5, icp6 is present, Icon will not be supported because it can not be set as Folder of Finder.

let ICON_INFOS: array[10, IconInfo] = [
  # Normal
  IconInfo(typ: "ic07", size: 128),
  IconInfo(typ: "ic08", size: 256),
  IconInfo(typ: "ic09", size: 512),
  IconInfo(typ: "ic10", size: 1024),

  # Retina
  IconInfo(typ: "ic11", size: 32),
  IconInfo(typ: "ic12", size: 64),
  IconInfo(typ: "ic13", size: 256),
  IconInfo(typ: "ic14", size: 512),

  # Mac OS 8.5
  IconInfo(typ: "is32", mask: "s8mk", size: 16),
  IconInfo(typ: "il32", mask: "l8mk", size: 32)
]

# Select the support image from the icon size.
# @param size Size of icon.
# @param images File informations..
# @return If successful image information, otherwise null.

proc imageFromIconSize(size: int, images: seq[ImageInfo]): Option[ImageInfo] =
  for image in images:
    if (image.size == size):
      return some(image)
  return none(ImageInfo)
# Create the ICNS file header.
# @param fileSize File size.
# @return Header data.

proc createFileHeader(fileSize: int): Stream =
  result = newStringStream()
  result.write FILE_HEADER_ID
  result.write extract_32(fileSize.uint32, bigEndian)

# Create the Icon header in ICNS file.
# @param type Type of the icon.
# @param imageSize Size of the image data.
# @return Header data.

proc createIconHeader(typ: string, imageSize: int): Stream =
  result = newStringStream()
  result.write typ
  result.write extract_32(uint32(HEADER_SIZE + imageSize), bigEndian)


# Create a color and mask data.
# @param image Binary of image file.
# @return Pack bit bodies.

proc createIconBlockPackBitsBodies(png: string): PackBitBody =
  var results: PackBitBody = PackBitBody(colors: @[], masks: @[])
  var r: seq[char] = @[]
  var g: seq[char] = @[]
  var b: seq[char] = @[]
  var i = 0
  let max = png.len

  while i + 4 < max:
    # RGB
    r.add(png[i])
    g.add(png[i + 1])
    b.add(png[i + 2])

    # Alpha
    results.masks.add(png[i + 3])
    i += 4

  # Compress
  let packedR = packICNS(cast[seq[int]](r))
  let packedG = packICNS(cast[seq[int]](g))
  let packedB = packICNS(cast[seq[int]](b))
  discard results.colors.concat(cast[seq[char]](packedR))
  discard results.colors.concat(cast[seq[char]](packedG))
  discard results.colors.concat(cast[seq[char]](packedB))

  return results

# Create an icon block"s data.
# @param type Type of the icon.
# @param image Binary of image file.
# @return Binary of icon block.

proc createIconBlockData(typ: string, image: string): string =
  var header = createIconHeader(typ, image.len)
  let headerData = header.readAll
  result = headerData & image & $(headerData.len + image.len)

# Create an icon blocks (Color and mask) for PackBits.
# @param type Type of the icon in color block.
# @param mask Type of the icon in mask block.
# @param image Binary of image file.
# @return Binary of icon block.

proc createIconBlockPackBits(typ: string, mask: string, image: string): string =
  let bodies = createIconBlockPackBitsBodies(image)
  let colorBlock = createIconBlockData(typ, cast[string](bodies.colors))
  let maskBlock = createIconBlockData(mask, cast[string](bodies.masks))
  result = colorBlock & maskBlock & $(colorBlock.len + maskBlock.len)

# Create an icon block.
# @param info Icon information in ICNS.
# @param filePath Path of image (PNG) file.
# @return Binary of icon block.

proc createIconBlockAsync(info: IconInfo, filePath: string): Future[string]{.async.} =
  # doAssert fileExists(filePath),&"{filePath} not exists"
  if not fileExists(filePath):
    raise newException(IOError, &"{filePath} not exists")
  let file = openAsync(filePath, fmRead)
  let image = await file.readAll
  file.close
  case info.typ:
    of "is32", "il32":
      return createIconBlockPackBits(info.typ, info.mask, image)
    else:
      return createIconBlockData(info.typ, image)

proc createIconBlock(info: IconInfo, filePath: string): string =
  # doAssert fileExists(filePath),&"{filePath} not exists"
  if not fileExists(filePath):
    raise newException(IOError, &"{filePath} not exists")
  let file = open(filePath, fmRead)
  let image = file.readAll
  file.close
  case info.typ:
    of "is32", "il32":
      return createIconBlockPackBits(info.typ, info.mask, image)
    else:
      return createIconBlockData(info.typ, image)

# Creat a file header and icon blocks.
# @param images Information of the image files.
# @param dest The path of the output destination file.
# @return `true` if it succeeds.

proc createIconAsync(images: seq[ImageInfo], dest: string): Future[bool]{.async.} =
  var fileSize = 0
  var body: string
  var blk: string
  var image: Option[png.ImageInfo]
  for i, info in ICON_INFOS:
    image = imageFromIconSize(info.size, images)
    if image.isNone:
      continue
    blk = await createIconBlockAsync(info, image.get.filePath)
    body = body & blk & $(body.len + blk.len)
    fileSize += blk.len
  if fileSize == 0:
    return false
  # Write file header and body
  var stream = openFileStream(dest, fmWrite)
  stream.write(createFileHeader(fileSize + HEADER_SIZE).readAll)
  stream.write(body)
  stream.flush
  stream.close

  return true

proc createIcon(images: seq[ImageInfo], dest: string): bool =
  var fileSize = 0
  var body: string
  var blk: string
  var image: Option[png.ImageInfo]
  for i, info in ICON_INFOS:
    image = imageFromIconSize(info.size, images)
    if image.isNone:
      continue
    blk = createIconBlock(info, image.get.filePath)
    body = body & blk & $(body.len + blk.len)
    fileSize += blk.len
  if fileSize == 0:
    return false
  # Write file header and body
  var stream = openFileStream(dest, fmWrite)
  stream.write(createFileHeader(fileSize + HEADER_SIZE).readAll)
  stream.write(body)
  stream.flush
  stream.close

  return true

# Unpack an icon block files from ICNS file (For debug).
# @param src Path of the ICNS file.
# @param dest Path of directory to output icon block files.
# @return Asynchronous task.

proc debugUnpackIconBlocks*(src: string, dest: string): Future[void]{.async.} =
  let file = openAsync(src, fmRead)
  let data = await file.readAll
  var
    pos = HEADER_SIZE
  let max = data.len
  var header, body, typ: string
  var size: int
  var headerFile, bodyFile: AsyncFile
  while pos < max:
    header = data[pos .. pos + HEADER_SIZE]
    typ = header[0..^4]
    size = parseInt(header[4..^8]) - HEADER_SIZE

    pos += HEADER_SIZE
    body = data[pos..^(pos+size)]
    headerFile = openAsync(dest / typ & ".header")
    bodyFile = openAsync(dest / typ & ".body")
    await headerFile.write(header)
    headerFile.close
    await bodyFile.write(body)
    bodyFile.close

    pos += size

# Create the ICNS file from a PNG images.
# @param images Information of the image files.
# @param dir Output destination the path of directory.
# @param logger Logger.
# @param options Options.
# @return Path of generated ICNS file.

proc generateICNS*(images: seq[ImageInfo], dir: string, options: ICNSOptions = default(ICNSOptions)): string =
  let name = if options.name.len > 0: options.name else: DEFAULT_FILE_NAME
  let sizes = if options.sizes.len > 0: options.sizes else: REQUIRED_IMAGE_SIZES.toSeq
  let opt = ICNSOptions(name: name, sizes: sizes.toSeq)
  let dest = dir / (opt.name & FILE_EXTENSION)
  let targets = filterImagesBySizes(images, opt.sizes)
  discard createIcon(targets, dest)
  return dest

proc generateICNSAsync*(images: seq[ImageInfo], dir: string, options: ICNSOptions = default(ICNSOptions)): Future[
    string]{.async.} =
  let name = if options.name.len > 0: options.name else: DEFAULT_FILE_NAME
  let sizes = if options.sizes.len > 0: options.sizes else: REQUIRED_IMAGE_SIZES.toSeq
  let opt = ICNSOptions(name: name, sizes: sizes.toSeq)
  let dest = dir / (opt.name & FILE_EXTENSION)
  let targets = filterImagesBySizes(images, opt.sizes)
  discard await createIconAsync(targets, dest)
  return dest
