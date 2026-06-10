
type
  SigeoBackend* = enum
    SigeoNative
    SigeoOpencascade
    SigeoC3d


const sigeo_use_opencascade {.booldefine, used.} = false
const sigeo_use_c3d {.booldefine, used.} = false


const sigeo_backend* =
  when sigeo_use_opencascade: SigeoOpencascade
  elif sigeo_use_c3d: SigeoC3d
  else: SigeoNative

