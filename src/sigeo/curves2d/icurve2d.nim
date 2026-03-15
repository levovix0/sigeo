import std/hashes
import ../core/[vectors, points]
import ../macros/[interfaces]
import ./[lineSection, circleArc]

type
  VtableCurve2d* = object
    typenameHash*: Hash
    
    destroy*: proc(this: pointer) {.nimcall, raises: [].}
    trace*: proc(this: pointer, env: pointer) {.nimcall, raises: [].}
    dup*: proc(this: var pointer, other: pointer) {.nimcall, raises: [].}
    sink*: proc(this: var pointer, other: pointer) {.nimcall, raises: [].}
    
    destroyRef*: proc(this: pointer) {.nimcall, raises: [].}
    traceRef*: proc(this: pointer, env: pointer) {.nimcall, raises: [].}
    dupRef*: proc(this: var pointer, other: pointer) {.nimcall, raises: [].}
    copyRef*: proc(this: var pointer, other: pointer) {.nimcall, raises: [].}

    length*: proc(this: pointer;): Float {.nimcall.}
    pointAtParam*: proc(this: pointer; param: FloatParam): Point2 {.nimcall.}
  
  Curve2d* = object
    ## untraced pointer to Curve2d, should be used in function arguments
    vtable*: ptr VtableCurve2d
    obj*: pointer
  
  OwnedCurve2d* = object
    ## acts like a unique_ptr in C++, should be used in object fields if it is NOT intended to be shared
    vtable*: ptr VtableCurve2d
    obj*: pointer
  
  RefCurve2d* = object
    ## acts like a ref object, should be used in object fields if it IS intended to be shared
    vtable*: ptr VtableCurve2d
    obj*: pointer


proc length*(this: Curve2d;): Float {.inline.} = this.vtable.length(this.obj)
proc pointAtParam*(this: Curve2d; param: FloatParam): Point2 {.inline.} = this.vtable.pointAtParam(this.obj, param)


proc `=destroy`(this: OwnedCurve2d) {.inline.} =
  this.vtable.destroy(this.obj)

proc `=trace`(this: var OwnedCurve2d, env: pointer) {.inline.} =
  this.vtable.trace(this.obj, env)

proc `=copy`(this: var OwnedCurve2d, other: OwnedCurve2d) {.inline.} =
  this.vtable.destroy(this.obj)
  this.vtable.dup(this.obj, other.obj)

proc `=dup`(this: OwnedCurve2d): OwnedCurve2d {.inline.} =
  this.vtable.dup(result.obj, this.obj)

proc `=sink`(this: var OwnedCurve2d, other: OwnedCurve2d) {.inline.} =
  this.vtable.sink(this.obj, other.obj)


proc `=destroy`(this: RefCurve2d) {.inline.} = this.vtable.destroyRef(this.obj)
proc `=trace`(this: var RefCurve2d, env: pointer) {.inline.} = this.vtable.traceRef(this.obj, env)


converter asPtr*(this: OwnedCurve2d): Curve2d = cast[Curve2d](this)
converter asPtr*(this: RefCurve2d): Curve2d = cast[Curve2d](this)



when false:
  # todo

  makeInterface Curve2d:
    proc length(this;): Float
    proc pointAtParam(this; param: FloatParam): Point2
    # proc derAtParam(this; param: FloatParam): Vec2

  Curve2d.implementInterfaceFor(LineSection, CircleArc)

