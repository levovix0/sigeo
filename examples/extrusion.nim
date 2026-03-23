import siwin, sigeo, rice


proc toGpu*(grid: Grid3): Shape =
  let grid = triangulate grid

  case grid.kind
  of Triangles:
    var points: seq[tuple[pos: Vec3, normal: Vec3]]
    for idx in countup(0, grid.indices.high - 2, 3):
      let pts = [grid.points[grid.indices[idx]], grid.points[grid.indices[idx+1]], grid.points[grid.indices[idx+2]]]
      let n = plane(pts[0], pts[1], pts[2]).axisZ
      points.add (pts[0].Vec3, n.Vec3)
      points.add (pts[1].Vec3, n.Vec3)
      points.add (pts[2].Vec3, n.Vec3)

    result = newShape(points, GlTriangles)
  else:
    raise ValueError.newException("unsupported grid kind: " & $grid.kind)


let spiral = Curve3d(
  speedAtParam: proc(t: FloatParam): Float =
    1 / 10
  ,
  pointAtParam: proc(t: FloatParam): Point3 =
    let t = t * 1000
    point3(cos(t / 50) * 2, t / 100, sin(t / 50) * 2)
  ,
  derAtParam: proc(t: FloatParam): NormalVec3 =
    let t = t * 1000
    vec3(1 / 50 * -sin(t / 50) * 2, 1 / 50 * cos(t / 50) * 2, -1 / 100)
  ,
  xAxisAtParam: proc(t: FloatParam): NormalVec3 =
    let t = t * 1000
    plane(vec3(1 / 50 * -sin(t / 50) * 2, 1 / 50 * cos(t / 50) * 2, -1 / 100)).axisX
  ,
)

let circle = Curve3d(
  speedAtParam: proc(t: FloatParam): Float =
    1
  ,
  pointAtParam: proc(t: FloatParam): Point3 =
    point3(cos(t * Pi*2) / 5 + 2, sin(t * Pi*2) / 5, 0)
  ,
  derAtParam: proc(t: FloatParam): NormalVec3 =
    vec3(-sin(t * Pi*2) / 5, cos(t * Pi*2) / 5, 0)
  ,
  xAxisAtParam: proc(t: FloatParam): NormalVec3 =
    vec3(-sin(t * Pi*2) / 5, cos(t * Pi*2) / 5, 0).rotate(vec3(0, 0, 1), Pi/2)
  ,
)


let grid = extrusionShellGrid(
  contour = circle,
  spine = spiral,
  # sag = 0.01,
)


let win = newOpenglWindow(
  title = "sigeo extrusion example",
)

opengl.loadExtensions()
let ctx = newDrawContext()

var aafb = newAntialiasedFramebuffer(depth = true)

let gridGpu = grid.toGpu


win.eventsHandler.onRender = proc(e: RenderEvent) =
  glViewport 0, 0, e.window.size.x.GlInt, e.window.size.y.GlInt
  ctx.updateDrawingAreaSize(e.window.size)
  aafb.resize(e.window.size)

  ctx.drawInside aafb:
    glClearColor(0.2, 0.2, 0.2, 1)
    glClearDepthf(1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

    ctx.viewport = combine(
      scale vec3(0.3),
      rotateZ[float32](Pi / 2),
      translate vec3(-1.5, 0, 0),
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


run win
