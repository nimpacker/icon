
import imageman,streams,struct,asyncdispatch

# Sizes required for the ICO file. 
const REQUIRED_IMAGE_SIZES = [16, 24, 32, 48, 64, 128, 256]

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

type ICOOptions = object of RootObj
    name:string
    size:seq[int]

proc convertPNGtoDIB(src:seq[uint8],width:Natural,height:Natural,bpp:Natural):seq[uint8] = 
    # Convert a PNG of the byte array to the DIB (Device Independent Bitmap) format.
    # PNG in color RGBA (and more), the coordinate structure is the Top/Left to Bottom/Right.
    # DIB in color BGRA, the coordinate structure is the Bottom/Left to Top/Right.
    # https://en.wikipedia.org/wiki/BMP_file_format
    
    let cols = width * bpp
    let rows = height * cols
    let rowEnd = rows - cols
    var dest = newSeq[uint8](src.len)
    var row = 0
    var col = 0
    var pos = 0
    while row < rows :
        while col < cols :
            # RGBA: Top/Left -> Bottom/Right
            pos = row + col
            let r = src[pos]
            let g = src[pos + 1]
            let b = src[pos + 2]
            let a = src[pos + 3]

            # BGRA: Right/Left -> Top/Right
            pos = rowEnd - row + col
            dest[ pos] = b
            dest[ pos + 1] = g
            dest[pos + 2] = r
            dest[pos + 3] = a
            col += bpp
        row += cols

    return dest

proc createBitmapInfoHeader*(png:Image,compression:int):Stream = 
    # Create the BITMAPINFOHEADER.
    # https://msdn.microsoft.com/ja-jp/library/windows/desktop/dd183376%28v=vs.85%29.aspx

    result = newStringStream("")
    result.write extract_32(BITMAPINFOHEADER_SIZE.uint32,littleEndian) # 4 DWORD biSize
    result.write extract_32(png.width.int32,littleEndian) # 4 LONG  biWidth
    result.write extract_32(png.height.int32 * 2,littleEndian) #4 LONG  biHeight
    result.write extract_16(1.int16,littleEndian) # 2 WORD  biPlanes
    result.write extract_16( uint16(BPP_ALPHA * 8),littleEndian ) # 2 WORD  biBitCount
    result.write extract_32( uint32(compression) ,littleEndian) # 4 DWORD biCompression
    result.write extract_32( uint32(png.data.len) , littleEndian) # 4 DWORD biSizeImage
    result.write extract_32( 0'i32 ) # 4 LONG  biXPelsPerMeter
    result.write extract_32( 0'i32 ) # 4 LONG  biYPelsPerMeter
    result.write extract_32( 0'i32 ) # 4 DWORD biClrUsed
    result.write extract_32( 0'i32 ) # 4 DWORD biClrImportant

proc createDirectory*(png:Image,offset:int):Stream = 
    # Create the Icon entry.
    # offset The offset of directory data from the beginning of the ICO/CUR file
    result = newStringStream("")
    let size = png.data.len + BITMAPINFOHEADER_SIZE
    let width = if 256 <= png.width :0 else: png.width
    let height = if 256 <= png.height :0  else : png.height
    let bpp = BPP_ALPHA * 8

    result.write width.uint8 # 1 BYTE  Image width
    result.write height.uint8 # 1 BYTE  Image height
    result.write 0'u8 # 1 BYTE  Colors
    result.write 0'u8 # 1 BYTE  Reserved
    result.write extract_16(1.uint16,littleEndian) # 2 WORD  Color planes
    result.write extract_16(bpp,littleEndian) # 2 WORD  Bit per pixel
    result.write extract_32(size,littleEndian) # 4 DWORD Bitmap (DIB) size
    result.write extract_32(offset,littleEndian) # 4 DWORD Offset

proc writeDirectories(pngs:seq[Image],stream: var Stream) = 
    # Write ICO directory information to the stream.

    let offset = FILE_HEADER_SIZE + ICO_DIRECTORY_SIZE * pngs.len
    var directory:Stream
    for  png in pngs :
        directory = createDirectory(png, offset)
        stream.write(directory)
        offset += png.data.len + BITMAPINFOHEADER_SIZE
    
proc createFileHeader*(count:int):Stream = 
    # Create the ICO file header.

    result = newStringStream("") 
    result.write extract_16(0'u16,littleEndian) # 2 WORD Reserved
    result.write extract_16(1'u16,littleEndian) # 2 WORD Type
    result.write extract_16(count.uint16,littleEndian) # 2 WORD Image count

proc writePNGs*(pngs:seq[Image],stream:var Stream) = 
    # Write PNG data to the stream.
    var header:Stream
    var dib:seq[uint8]
    for  png in pngs :
        header = createBitmapInfoHeader(png, BI_RGB)
        stream.write(header)
        dib = convertPNGtoDIB(png.data, png.width, png.height, BPP_ALPHA)
        stream.write(dib)
    
proc generateICO*(images:seq[Image];dir:string;options:ICOOptions ){.async.} = 
    # Generate the ICO file from a PNG images.
    # ICOOptions(name:DEFAULT_FILE_NAME,sizes:REQUIRED_IMAGE_SIZES)
    let name =  if options.name.len > 0: options.name else: DEFAULT_FILE_NAME
    let sizes = if options.sizes.len > 0:options.sizes else:REQUIRED_IMAGE_SIZES
    let opt = ICOOptions(name: name,sizes:sizes)
    const dest = dir / options.name & FILE_EXTENSION
    const stream = open(dest)
    stream.write(createFileHeader(images.len))
    writeDirectories(images, stream)
    writePNGs(images, stream)
    stream.close

    return dest

