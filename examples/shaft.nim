import std/[math, times, sequtils]
import pkg/siwin
import pkg/rice
import sigeo/[core, grids]
import sigeo/grids/smoothshading


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
      points.add (grid.points[i0].Vec3, normals[i0])
      points.add (grid.points[i1].Vec3, normals[i1])
      points.add (grid.points[i2].Vec3, normals[i2])

    result = newMesh(points, GlTriangles)
  else:
    raise ValueError.newException("unsupported grid kind: " & $grid.kind)


proc shaftSpine(radius: Float): Curve3d =
  Curve3d(
    speedAtParam: proc(t: FloatParam): Float =
      1 / (radius * Pi * 2)
    ,
    pointAtParam: proc(t: FloatParam): Point3 =
      let angle = t * Pi * 2
      point3(0, cos(angle) * radius, sin(angle) * radius)
    ,
    derAtParam: proc(t: FloatParam): NormalVec3 =
      let angle = t * Pi * 2
      vec3(0, -sin(angle), cos(angle)).normal
    ,
    xAxisAtParam: proc(t: FloatParam): NormalVec3 =
      vec3(1, 0, 0).normal
    ,
  )


proc profilePoint(x, radius: Float): Point3 =
  point3(x, radius, 0)


proc shaftProfile(): seq[Point3] =
  let
    journalLen = 36.0
    shoulderLen = 14.0
    bodyLen = 58.0
    neckLen = 12.0
    flangeLen = 22.0

    leftRadius = 11.0
    bodyRadius = 8.0
    neckRadius = 13.0
    drumRadius = 23.0

    chamfer = 2.5

  let
    x0 = 0.0
    x1 = x0 + journalLen
    x2 = x1 + shoulderLen
    x3 = x2 + bodyLen
    x4 = x3 + neckLen
    x5 = x4 + flangeLen

  @[
    profilePoint(x0, -0.99),
    profilePoint(x0, leftRadius - chamfer),
    profilePoint(x0 + chamfer, leftRadius),
    profilePoint(x1, leftRadius),
    profilePoint(x1, bodyRadius),
    profilePoint(x2, bodyRadius),
    profilePoint(x3, bodyRadius),
    profilePoint(x3, neckRadius),
    profilePoint(x4, neckRadius),
    profilePoint(x4, drumRadius),
    profilePoint(x5 - chamfer, drumRadius),
    profilePoint(x5, drumRadius - chamfer),
    profilePoint(x5, -0.99),
  ]


proc shaftGrid(sag: Sag): seq[Grid3] =
  let profile = shaftProfile()
  let spine = shaftSpine(radius = 1)

  for i in 0 ..< profile.high:
    result.add extrusionShellGrid(
      contour = [profile[i], profile[i + 1]],
      contourClosed = false,
      spine = spine,
      sag = sag,
    )



let modelSize = 36.0 + 14.0 + 58.0 + 12.0 + 22.0
let modelCenter = vec3(modelSize/2, 0, 0)


let win = newOpenglWindow(
  title = "sigeo shaft revolve example",
)

opengl.loadExtensions()
let ctx = newDrawContext()

var aafb = ctx.newAntialiasedFramebuffer(win.size, depth = true)

let shaft = shaftGrid(sag = 0.08)
let shaftGpu = shaft.map(toGpu)
var time = 0.0


win.eventsHandler.onRender = proc(e: RenderEvent) =
  glViewport 0, 0, e.window.size.x.GlInt, e.window.size.y.GlInt
  ctx.updateDrawingAreaSize(e.window.size)
  ctx.resize(aafb, e.window.size)

  ctx.drawInside aafb:
    glClearColor(0.2, 0.2, 0.2, 1)
    glClearDepthf(1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

    ctx.viewport = combine(
      translate vec3(-modelCenter.x, -modelCenter.y, -modelCenter.z),
      scale vec3(2.4 / modelSize),
      rotateY[float32](time),
    )
    ctx.projection = scale vec3(e.window.size.y / e.window.size.x, 1, 1 / 500)

    let color = color(0.95, 0.95, 0.98, 1)
    let shadowColor = color(0.32, 0.34, 0.38, 1)
    let lightDir: Vec3 = vec3(-1, -1, -0.7).normalize
    let backlight = 0.55

    glEnable(GL_DEPTH_TEST)
    let shader = ctx.makeShader:
      proc vert =
        var inPos {.inp.}: Vec3
        var inNormal {.inp.}: Vec3
        var gl_Position {.outGl.}: Vec4
        var lColor {.out.}: Vec4

        gl_Position = @(ctx.viewportToGlMatrix) * vec4(inPos, 1.0)
        let normal = inNormal
        let lightV = dot(@(lightDir), (normal / length(normal)).xyz)
        let light = if lightV > 0: lightV else: -lightV * @(backlight)
        lColor = @(color.vec4) * light + @(shadowColor.vec4) * (1 - light)

      proc frag =
        var glCol {.outGl.}: Vec4
        glCol = lColor

    useAndPassUniforms shader
    for mesh in shaftGpu:
      draw mesh

win.eventsHandler.onTick = proc(e: TickEvent) =
  time += e.deltaTime.inMicroseconds / 1_000_000
  redraw e.window


run win
