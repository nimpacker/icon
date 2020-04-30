# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.

import iconpkg/ico
import laser/tensor/[initialization]
import imageman

when isMainModule:
  # func toMetadata(s: varargs[int]): Metadata =
  #   result.len = s.len
  #   for i in 0..<s.len:
  #     result.data[i] = s[i]
  # proc newTensor*[T](shape: varargs[int]): Tensor[T] =
  #   var size: int
  #   initTensorMetadata(result, size, shape)
  #   allocCpuStorage(result.storage, size)
  #   setZero(result, check_contiguous = false)

  # proc newTensor*[T](shape: Metadata): Tensor[T] =
  #   var size: int
  #   initTensorMetadata(result, size, shape)
  #   allocCpuStorage(result.storage, size)
  #   setZero(result, check_contiguous = false)
  
  let img = loadImage[ColorRGBU]("sample.png")
  let tensor = toTensor(img.data)
  tensor[..., ::-1]
