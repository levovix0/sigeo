import std/[times, sequtils]
import pkg/siwin
import pkg/rice
import sigeo/[core, curves2d, grids]
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


proc spiralF(t: float): Point3 = point3(cos(t / 50) * 2, t / 100, sin(t / 50) * 2)

let spiral = Curve3d(
  speedAtParam: proc(t: FloatParam): Float =
    1 / 20
  ,
  pointAtParam: proc(t: FloatParam): Point3 =
    spiralF(t * 1000)
  ,
  derAtParam: proc(t: FloatParam): NormalVec3 =
    let u = t * 20
    vec3(-sin(u) * 40, 10, cos(u) * 40).normal
  ,
  xAxisAtParam: proc(t: FloatParam): NormalVec3 =
    let u = t * 20
    vec3(cos(u), 0, sin(u)).normal
  ,
)

let circle = circleArc(point2(), 1/2)


let grid = extrusionShellGrid(
  contour = circle,
  spine = spiral,
  sag = 0.1,
)


let win = newOpenglWindow(
  title = "sigeo extrusion example",
)

opengl.loadExtensions()
let ctx = newDrawContext()

var aafb = ctx.newAntialiasedFramebuffer(win.size, depth = true)

let gridGpu = grid.toGpu
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
      scale vec3(0.2),
      rotateZ[float32](Pi / 2),
      translate vec3(-1, 0, 0),
      rotateY[float32](time),
    )
    ctx.projection = scale vec3(e.window.size.y / e.window.size.x, 1, 1/1000)

    let color = color(1, 1, 1, 1)
    let shadowColor = color(0.4, 0.4, 0.4, 1)
    let lightDir: Vec3 = vec3(-1, -1, -1).normalize
    let backlight = 0.6
    
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
    draw gridGpu

win.eventsHandler.onTick = proc(e: TickEvent) =
  time += e.deltaTime.inMicroseconds / 1_000_000
  redraw e.window


run win
