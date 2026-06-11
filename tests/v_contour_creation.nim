import std/math
import pkg/[siwin, pixie]
import rice
import sigeo/[core, curves2d]


proc draw(ctx: DrawContext, curve: Curve2d, color: Color = color(1, 1, 1)) =
  let pts = curve.points()
  for i in 0 .. pts.high-1:
    ctx.fillCapsule(color = color, a = pts[i].V2.vec2.vec3(0), b = pts[i + 1].V2.vec2.vec3(0), radius = 0.05)


let win = newOpenglWindow(title = "sigeo contour creation test", size = ivec2(600, 600))
opengl.loadExtensions()
let ctx = newDrawContext()
var aafb = ctx.newAntialiasedFramebuffer(win.size)


win.eventsHandler.onResize = proc(e: ResizeEvent) =
  glViewport 0, 0, e.size.x.GlInt, e.size.y.GlInt
  ctx.resize(aafb, e.size)
  ctx.updateDrawingAreaSize(e.size)


win.eventsHandler.onRender = proc(e: RenderEvent) =
  glViewport 0, 0, e.window.size.x.GlInt, e.window.size.y.GlInt
  ctx.updateDrawingAreaSize(e.window.size)
  ctx.resize(aafb, e.window.size)

  ctx.drawInside aafb:
    glClearColor(0.12, 0.12, 0.12, 1)
    glClear(GL_COLOR_BUFFER_BIT)

    ctx.viewport = combine(
      scale(1/2'f32, -1/2'f32),
      translate(-0.5'f32, 0.5'f32),
    )

    let curves = @[
      lineSection(p2(0, 0), p2(2, 0)).toOwnedCurve2d,
      lineSection(p2(2, 2), p2(2, 0)).toOwnedCurve2d,
      lineSection(p2(0, 1), p2(0, 0)).toOwnedCurve2d,

      lineSection(p2(0, 0), p2(1, 1)).toOwnedCurve2d,
      lineSection(p2(2, 0), p2(1, 1)).toOwnedCurve2d,
      lineSection(p2(1, 2), p2(1, 1)).toOwnedCurve2d,
      
      lineSection(p2(1, 2), p2(2, 2)).toOwnedCurve2d,
      lineSection(p2(0, 0), p2(0, 1)).toOwnedCurve2d,
      circleArc(p2(0, 2), 1, 0.0, -Pi/2).toOwnedCurve2d,
    ]

    for curve in curves:
      ctx.draw curve
    
    let contour = outerContour(curves)
    for x in contour.curves:
      ctx.draw x, color(1, 0.4, 0.4)


run win
