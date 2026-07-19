import ../core/[vectors, points]
import ../macros/[interfaces]
export implementInterfaceFor


makeInterface Surface3:
  ## U,V -> X,Y,Z

  proc pointAt(this; uv: Point2): Point3

