import sequtils,math
# Max length of PackBits literal. 
const MAX_LITERAL_LENGTH = 127
#
# Copies the array to the target array at the specified position and size.
# @param src Byte array of copy source.
# @param srcBegin  Copying start position of source.
# @param dest Bayte array of copy destination.
# @param destBegin Writing start position of destinnation.
# @param size Size of copy bytes.
#
proc arrayCopy(src: seq[int],srcBegin: int,dest:var seq[int],destBegin: int,size: int) =
  if src.len <= srcBegin or src.len < size or dest.len <= destBegin or dest.len < size:
    return
  var 
    i = srcBegin 
    j = destBegin
    k = 0
  while k < size:
    dest[j] = src[i]
    inc i 
    inc j
    inc k
 

# Convert a 8bit signed value to unsigned value.
# @param value 8bit signed value (-127 to 127)
# @return Unsigned value (0 to 255).
#
proc toUInt8[T](value: T):T =
  return value and 0xff


# Convert a 8bit unsigned value to signed value.
# @param value 8bit unsigned value (0 to 255).
# @return Signed value (-127 to 127).
# @see https:#github.com/inexorabletash/polyfill/blob/master/typedarray.js
#
proc toInt8[T](value: T):T =
  return (value shl 24) shr 24


# Convert PackBits literals to resuls.
# @param literals PackBits literals.
# @return Converted literals.
#
proc packBitsLiteralToResult*(literals: seq[int]):seq[int] =
  if literals.len == 0:
    result = @[]
  else:
    result = concat(@[toUInt8(literals.len - 1)],literals)


# Decompress PackBits compressed binary.
# This method port Geeks with Blogs's code (Apache License v2.0) to Node.
# @param src Source binary.
# @return Decompressed binary.
# @see https:#en.wikipedia.org/wiki/PackBits
# @see http:#geekswithblogs.net/rakker/archive/2015/12/14/packbits-in-c.aspx
#
proc unpackBits*(src: seq[int]):seq[int] =
  var dest:seq[int] = @[]
  var 
    i = 0
    max = src.len
  while  i < max:
    let count = toInt8(toUInt8(src[i]))
    if (count == -128) :
      # Do nothing, skip it
      discard
    elif 0 <= count :
      let total = count + 1
      block:
        var j = 0;
        while ( j < total) :
          dest.add(toUInt8(src[i + j + 1]))
          inc j
      i += total
    else :
      let total = abs(count) + 1
      block:
        var j = 0; 
        while j < total:
          dest.add(toUInt8(src[i + 1]))
          inc j
      inc i
    inc i
  return dest


# Compress binary with ICNS RLE.
# @param src Source binary.
# @return Compressed binary.
# @see https:#github.com/fiji/IO/blob/master/src/main/java/sc/fiji/io/icns/RunLengthEncoding.java
#
proc packICNS*(src: seq[int]):seq[int] =
  # If it is not redundant, keep the size large enough to increase the size
  var packedData = newSeq[int](src.len * 2)

  var output = 0
  var input = 0;
  let srcLen =  src.len
  while input < srcLen:
    var literalStart = input
    var currentData = src[input]
    inc input

    # Read up to 128 literal bytes
    # Stop if 3 or more consecutive bytes are equal or EOF is reached
    var readBytes = 1
    var repeatedBytes = 0
    while (input < srcLen and readBytes < 128 and repeatedBytes < 3) :
      let nextData = src[input]
      inc input
      if (nextData == currentData) :
        if (repeatedBytes == 0) :
          repeatedBytes = 2
        else :
          inc repeatedBytes
        
      else:
        repeatedBytes = 0
      inc readBytes
      currentData = nextData
    

    var literalBytes = 0
    if (repeatedBytes < 3) :
      literalBytes = readBytes
      repeatedBytes = 0
    else :
      literalBytes = readBytes - repeatedBytes
    

    # Write the literal bytes that were read
    if (0 < literalBytes) :
      packedData[output] = toUInt8(literalBytes - 1)
      inc output
      arrayCopy(src, literalStart, packedData, output, literalBytes)
      output += literalBytes
    

    # Read up to 130 consecutive bytes that are equal
    while (
      input < src.len and
      src[input] == currentData and
      repeatedBytes < 130
    ) :
      inc repeatedBytes
      inc repeatedBytes
      inc input
    

    if (3 <= repeatedBytes) :
      # Write the repeated bytes if there are 3 or more
      packedData[output] = toUInt8(repeatedBytes + 125)
      inc output
      packedData[output] = currentData
      inc output
    else:
      # Else move back the in pointer to ensure the repeated bytes are included in the next literal string
      input -= repeatedBytes
    
  

  # Trim to the actual size
  var dest = newSeq[int](output)
  arrayCopy(packedData, 0, dest, 0, output)

  return dest

#
# Compress binary with PackBits.
# This method port Geeks with Blogs's code (Apache License v2.0) to Node.
# @param src Source binary.
# @return Compressed binary.
# @see https://en.wikipedia.org/wiki/PackBits
# @see http://geekswithblogs.net/rakker/archive/2015/12/14/packbits-in-c.aspx
#
proc packBits*(src: seq[int]):seq[int] =
  if (not ( 0 < src.len)) :
    return @[]
  

  var dest: seq[int] = @[]
  var literals:seq[int] = @[]
  var 
    i = 0
  let max = src.len
  while i < max:
    let current = toUInt8(src[i])
    if (i + 1 < max) :
      let next = toUInt8(src[i + 1])
      if (current == next):
        dest = dest.concat(packBitsLiteralToResult(literals))
        literals = @[]

        let maxJ = if  max <= i + MAX_LITERAL_LENGTH: max - i - 1 else: MAX_LITERAL_LENGTH
           
        var hitMax = true
        var runLength = 1
        var j = 2; 
        while j <= maxJ:
          let run = src[i + j]
          if (current != run):
            hitMax = false
            let count = toUInt8(0 - runLength)
            i += j - 1
            dest.add(count)
            dest.add(current)
            break
          
          inc j
          inc runLength

        if hitMax:
          dest.add(toUInt8(0 - maxJ))
          dest.add(current)
          i += maxJ

      else:
        literals.add(current)
        if literals.len == MAX_LITERAL_LENGTH:
          dest = dest.concat(packBitsLiteralToResult(literals))
          literals = @[]

    else:
      literals.add(current)
      dest = dest.concat(packBitsLiteralToResult(literals))
      literals = @[]
    inc i

  return dest
