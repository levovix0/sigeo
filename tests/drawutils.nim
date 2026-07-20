import std/[sequtils]
import pkg/[siwin, vmath, chroma, rice]
import sigeo/[core]
import sigeo/surfaces/[grids]


type
  CameraState* = ref object
    pos*: Vec3
    rot*: Mat4
    zoom*: float32

  VisualTest* = ref object
    win*: Window
    ctx*: DrawContext
    aafb*: AntialiasedFramebuffer

    camera*: CameraState
    clearColor*: Color


proc toVec3(p: Point2): Vec3 {.inline.} =
  vec3(p.x.float32, p.y.float32, 0)


proc drawSegment*(ctx: DrawContext, a, b: Point2, color: Color, thickness: float32 = 1.5) =
  if a.distanceTo(b) < 1e-9: return  # fillCapsule cannot draw zero-length capsules
  ctx.fillCapsule(color = color, a = a.toVec3, b = b.toVec3, radius = thickness / 2)


proc drawPolyline*(ctx: DrawContext, pts: openArray[Point2], color: Color, thickness: float32 = 1.5) =
  for i in 0 ..< pts.len - 1:
    ctx.drawSegment(pts[i], pts[i + 1], color, thickness)


proc drawDot*(ctx: DrawContext, p: Point2, color: Color, radius: float32) =
  ctx.fillCircle(color, radius, center = p.toVec3)


proc drawBoundsRect*(ctx: DrawContext, b: Bounds2, color: Color, thickness: float32 = 1) =
  let tr = point2(b.max.x, b.min.y)
  let bl = point2(b.min.x, b.max.y)
  ctx.drawSegment(b.min, tr, color, thickness)
  ctx.drawSegment(tr, b.max, color, thickness)
  ctx.drawSegment(b.max, bl, color, thickness)
  ctx.drawSegment(bl, b.min, color, thickness)



proc toGpu*(grid: Grid3): Mesh =
  let grid = triangulate grid

  case grid.kind
  of Triangles:
    let normals = computeVertexNormals(grid.points, grid.indices.mapIt(it.int))
    var points: seq[tuple[pos: Vec3, normal: Vec3]]
    for idx in countup(0, grid.indices.high - 2, 3):
      let i0 = grid.indices[idx].int
      let i1 = grid.indices[idx + 1].int
      let i2 = grid.indices[idx + 2].int
      points.add (grid.points[i0].V3.vec3, normals[i0].vec3)
      points.add (grid.points[i1].V3.vec3, normals[i1].vec3)
      points.add (grid.points[i2].V3.vec3, normals[i2].vec3)

    result = newMesh(points, GlTriangles)
  else:
    raise ValueError.newException("unsupported grid kind: " & $grid.kind)



proc addCameraMovement*(win: Window, cam: CameraState, axisYUp: bool = true) =
  var mpos = vec2()

  win.eventsHandler.onMouseButton = proc(e: MouseButtonEvent) =
    mpos = e.window.mouse.pos

  win.eventsHandler.onMouseMove = proc(e: MouseMoveEvent) =
    let d = e.window.mouse.pos - mpos
    let dn = d / vec2(
      e.window.size.x.float32 * (e.window.size.y / e.window.size.x).float32,
      (if axisYUp: 1 else: -1) * e.window.size.y.float32
    ) * 2

    if e.window.mouse.pressed == {MouseButton.right}:
      let zv = vec2(
        ((if axisYUp: -1 else: 1) * (mpos.y / e.window.size.y.float32 - 0.5)).clamp(-1, 1) / 2,
        ((mpos.x / e.window.size.x.float32 - 0.5) / (e.window.size.y / e.window.size.x).float32).clamp(-1, 1) / 2
      ).normalize

      cam.rot = combine(
        cam.rot,
        rotateY[float32](dn.x * Pi),
        rotateX[float32](dn.y * Pi),
        rotateZ[float32](dn.x * Pi * zv.x),
        rotateZ[float32](dn.y * Pi * zv.y),
      )

    elif e.window.mouse.pressed == {MouseButton.middle}:
      cam.pos = cam.pos - cam.rot.inverse * vec3(dn.x, -dn.y, 0) / cam.zoom

    mpos = e.window.mouse.pos
    redraw e.window


  win.eventsHandler.onScroll = proc(e: ScrollEvent) =
    let sd = (-e.delta).clamp(-1, 1)

    cam.zoom *= sd * 0.2 + 1

    let d = e.window.mouse.pos - e.window.size.vec2 / 2
    let dn = d / vec2(
      e.window.size.x.float32 * (e.window.size.y / e.window.size.x).float32,
      e.window.size.y.float32
    ) * 2 * -sd * 0.2 / cam.zoom

    cam.pos = cam.pos - cam.rot.inverse * vec3(dn.x, (if axisYUp: -1 else: 1) * dn.y, 0)
    redraw e.window



proc newVisualTest*(
  title: string,
  size: IVec2,
  contentCenter = vec2(0, 0),
  zoom: float32 = 0, ## initial zoom; 0 means "1 world unit = 1 pixel at the initial window size"
  clearColor = color(0.12, 0.12, 0.12),
): VisualTest =
  let win = newOpenglWindow(title = title, size = size)
  opengl.loadExtensions()

  let ctx = newDrawContext()

  result = VisualTest(
    win: win,
    ctx: ctx,
    aafb: ctx.newAntialiasedFramebuffer(win.size),
    camera: CameraState(
      pos: vec3(contentCenter.x, contentCenter.y, 0),
      rot: mat4(),
      zoom: (if zoom == 0: 2 / size.y.float32 else: zoom),
    ),
    clearColor: clearColor,
  )

  let app = result

  win.eventsHandler.onResize = proc(e: ResizeEvent) =
    glViewport 0, 0, e.size.x.GlInt, e.size.y.GlInt
    app.ctx.resize(app.aafb, e.size)
    app.ctx.updateDrawingAreaSize(e.size)

  addCameraMovement(win, app.camera, axisYUp = false)


proc onKey*(app: VisualTest, handler: proc(e: KeyEvent)) =
  app.win.eventsHandler.onKey = handler


proc run*(app: VisualTest, render: proc(ctx: DrawContext)) =
  ## sets up the render loop (clear, camera viewport, antialiasing) and runs the window
  app.win.eventsHandler.onRender = proc(e: RenderEvent) =
    let vw = e.window.size.x.float32
    let vh = e.window.size.y.float32

    glViewport 0, 0, e.window.size.x.GlInt, e.window.size.y.GlInt
    app.ctx.updateDrawingAreaSize(e.window.size)
    app.ctx.resize(app.aafb, e.window.size)

    app.ctx.drawInside app.aafb:
      glClearColor(app.clearColor.r, app.clearColor.g, app.clearColor.b, 1)
      glClear(GL_COLOR_BUFFER_BIT)

      # with the initial camera this maps world (= window pixel) coordinates to the screen 1:1
      app.ctx.viewport = combine(
        translate(-app.camera.pos),
        app.camera.rot,
        scale(vec3(app.camera.zoom)),
        scale(vec3(vh / vw, -1, 1/1000)),
      )

      render(app.ctx)

  run app.win

