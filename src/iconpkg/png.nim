import sequtils,algorithm
type ImageInfo* = object of RootObj
# Image size (width/height). 
  size*: int
# Path of an image file. 
  filePath*: string
#
# Filter by size to the specified image informations.
# @param images Image file informations.
# @param sizes  Required sizes.
# @return Filtered image informations.
#
proc filterImagesBySizes*(images: seq[ImageInfo], sizes: seq[int]):seq[ImageInfo] =
  return images
    .filter( proc (image:ImageInfo):bool =
       sizes.any( proc (size:int):bool =image.size == size)
    ).sortedByIt(it.size)
    

