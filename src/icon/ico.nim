
import nimPNG, streams, struct, asyncdispatch
import sequtils, strutils
import os
import ./png
export png
export nimPNG
# Sizes required for the ICO file.
const REQUIRED_IMAGE_SIZES* = [16, 24, 32, 48, 64, 128, 256]

# Default name of ICO file.
const DEFAULT_FILE_NAME = "app"

# File extension of ICO file.
const FILE_EXTENSION = ".ico"

# Size of the file header.
const FILE_HEADER_SIZE = 6

# Size of the icon directory.
const ICO_DIRECTORY_SIZE = 16

# Size of the `BITMAPINFOHEADER`.
const BITMAPINFOHEADER_SIZE = 40

# Color mode of `BITMAPINFOHEADER`.
const BI_RGB = 0

# BPP (Bit Per Pixel) for Alpha PNG (RGB = 4).
const BPP_ALPHA = 4

type ICOOptions* = object of RootObj
  name*: string
  sizes*: seq[int]

proc convertPNGtoDIB[T](src: openarray[T], width: Natural, height: Natural, bpp: Natural): seq[T] =
  # Convert a PNG of the byte array to the DIB (Device Independent Bitmap) format.
  # PNG in color RGBA (and more), the coordinate structure is the Top/Left to Bottom/Right.
  # DIB in color BGRA, the coordinate structure is the Bottom/Left to Top/Right.
  # https://en.wikipedia.org/wiki/BMP_file_format

  let cols = width * bpp
  let rows = height * cols
  let rowEnd = rows - cols
  var dest = newSeq[T](src.len)
  var row = 0
  var col = 0
  var pos = 0
  var r, g, b, a: T
  while row < rows:
    col = 0
    while col < cols:
      # RGBA: Top/Left -> Bottom/Right
      pos = row + col
      r = src[pos]
      g = src[pos + 1]
      b = src[pos + 2]
      a = src[pos + 3]

      # BGRA: Right/Left -> Top/Right
      pos = rowEnd - row + col
      dest[pos] = b
      dest[pos + 1] = g
      dest[pos + 2] = r
      dest[pos + 3] = a
      col += bpp
    row += cols
  return dest

proc createBitmapInfoHeader*(png: PNGResult, compression: int): Stream =
  # Create the BITMAPINFOHEADER.
  # https://msdn.microsoft.com/ja-jp/library/windows/desktop/dd183376%28v=vs.85%29.aspx

  result = newStringStream()
  result.write extract_32(BITMAPINFOHEADER_SIZE.uint32, littleEndian) # 4 DWORD biSize
  result.write extract_32(png.width.int32, littleEndian) # 4 LONG  biWidth
  result.write extract_32(png.height.int32 * 2, littleEndian) #4 LONG  biHeight
  result.write extract_16(1.uint16, littleEndian) # 2 WORD  biPlanes
  result.write extract_16(uint16(BPP_ALPHA * 8), littleEndian) # 2 WORD  biBitCount
  result.write extract_32(uint32(compression), littleEndian) # 4 DWORD biCompression
  result.write extract_32(uint32(png.data.len), littleEndian) # 4 DWORD biSizeImage
  result.write extract_32(0'i32, littleEndian) # 4 LONG  biXPelsPerMeter
  result.write extract_32(0'i32, littleEndian) # 4 LONG  biYPelsPerMeter
  result.write extract_32(0'u32, littleEndian) # 4 DWORD biClrUsed
  result.write extract_32(0'u32, littleEndian) # 4 DWORD biClrImportant
  result.flush()
  result.setPosition(0)

proc createDirectory*(png: PNGResult, offset: int): Stream =
  # Create the Icon entry.
  # offset The offset of directory data from the beginning of the ICO/CUR file
  result = newStringStream()
  let size = png.data.len + BITMAPINFOHEADER_SIZE
  let width = if 256 <= png.width: 0 else: png.width
  let height = if 256 <= png.height: 0 else: png.height
  let bpp = BPP_ALPHA * 8

  result.write width.uint8 # 1 BYTE  Image width
  result.write height.uint8 # 1 BYTE  Image height
  result.write 0'u8 # 1 BYTE  Colors
  result.write 0'u8 # 1 BYTE  Reserved
  result.write extract_16(1.uint16, littleEndian) # 2 WORD  Color planes
  result.write extract_16(bpp.uint16, littleEndian) # 2 WORD  Bit per pixel
  result.write extract_32(size.uint32, littleEndian) # 4 DWORD Bitmap (DIB) size
  result.write extract_32(offset.uint32, littleEndian) # 4 DWORD Offset
  result.flush()
  result.setPosition(0)

proc writeDirectories(pngs: openarray[PNGResult], stream: var FileStream) =
  # Write ICO directory information to the stream.

  var offset = FILE_HEADER_SIZE + ICO_DIRECTORY_SIZE * pngs.len
  var directory: Stream
  for png in pngs:
    directory = createDirectory(png, offset)
    stream.write(directory.readAll)
    offset += png.data.len + BITMAPINFOHEADER_SIZE

proc createFileHeader*(count: int): Stream =
  # Create the ICO file header.

  result = newStringStream()
  result.write extract_16(0'u16, littleEndian) # 2 WORD Reserved
  result.write extract_16(1'u16, littleEndian) # 2 WORD Type
  result.write extract_16(count.uint16, littleEndian) # 2 WORD Image count
  result.flush()
  result.setPosition(0)

func toString*(bytes: openArray[char]): string {.inline.} =
  ## Converts a byte sequence to the corresponding string.
  let length = bytes.len
  if length > 0:
    result = newString(length)
    copyMem(result.cstring, bytes[0].unsafeAddr, length)

proc writePNGs*(pngs: openarray[PNGResult], stream: var FileStream) =
  # Write PNG data to the stream.
  var header: Stream
  var dib: seq[char]
  for png in pngs:
    header = createBitmapInfoHeader(png, BI_RGB)
    stream.write(header.readAll)
    dib = convertPNGtoDIB(png.data, png.width, png.height, BPP_ALPHA)
    stream.write(toString(dib))
    stream.flush

proc readPNGs(images: seq[ImageInfo], sizes: seq[int]): seq[PNGResult[string]] =
  let targets = filterImagesBySizes(images, sizes)
  return targets.map(proc (image: ImageInfo): PNGResult[string] = loadPNG32(image.filePath))


proc generateICO*(images: seq[ImageInfo]; dir: string; options: ICOOptions = default(ICOOptions)): string =
  # Generate the ICO file from a PNG images.
  let name = if options.name.len > 0: options.name else: DEFAULT_FILE_NAME
  let sizes = if options.sizes.len > 0: options.sizes else: REQUIRED_IMAGE_SIZES.toSeq
  let opt = ICOOptions(name: name, sizes: sizes.toSeq)
  let pngs = readPNGs(images, opt.sizes)
  if pngs.len == 0:
    raise newException(Exception, "There was no PNG file matching the specified size.")

  let dest = dir / (opt.name & FILE_EXTENSION)
  var stream = openFileStream(dest, fmWrite)
  stream.write(createFileHeader(images.len).readAll)
  writeDirectories(pngs, stream)
  writePNGs(pngs, stream)
  stream.close

  return dest

proc generateICOAsync*(images: seq[ImageInfo]; dir: string; options: ICOOptions = default(ICOOptions)): Future[string]{.async.} =
  # Generate the ICO file from a PNG images.
  return generateICO(images, dir, options)
