#set page(fill: rgb("202020"), width: 50em, height: auto, margin: 1cm)
#set text(lang: "en", font: "Roboto", fill: rgb("c1c1c1"), size: 14pt)
#set line(stroke: (paint: rgb("808080"), cap: "round"))

#show raw: it => {
  set text(lang: "en", font: "Fira Code", size: 12pt)
  box(fill: rgb("#101010"), inset: (x: 2pt, y: 4pt), radius: 4pt, it)
}

#import "@preview/cheq:0.4.0": checklist
#show: checklist.with(fill: luma(20%))

#let optional = x => text(fill: rgb("808080"), x)
#let sep = line(length: 100%)
#let sep2 = {
  line(length: 100%, stroke: rgb("c1c1c1"))
  v(-1em - 1.25pt)
  line(length: 100%, stroke: rgb("c1c1c1"))
}
#let fira = x => text(font: "Fira Code", x)

#show link: set text(fill: rgb("a0a0ff"))

#show heading.where(depth: 1): set align(center)
#show heading.where(depth: 2): set align(center)

#let h1-n = state("h1-n", 0)
#show heading.where(depth: 1): it => context {
  if h1-n.get() != 0 { pagebreak() }
  h1-n.update(c => c + 1)
  it
  v(-1em + 2pt)
  line(length: 100%, stroke: 1pt + rgb("#c1c1c1"))
}

#show heading.where(depth: 2): it => {
  it
  v(-1em + 2pt)
  line(length: 75%, stroke: 1pt + rgb("#c1c1c1"))
}

#show math.equation.where(block: true): it => {set align(left); pad(left: 2em, box(stroke: 1pt + rgb("c1c1c1"), inset: 1em, it))}

#set par(hanging-indent: 2em)

#show math.cases: set text(size: 14pt)

#let forall_f = it => { text(size: 16pt, weight: 800, $forall(#it)$); $space$ }


#let ris-n = state("ris-n", 1)
#let risn = (offset: 0) => context {
  let n = ris-n.get() + offset
  link("Fig. " + str(n))
}

#let ris = (title, path, height: auto) => context {
  let n = ris-n.get()
  ris-n.update(c => c + 1)
  block(breakable: false, width: 100%)[
    #align(center, image(path, height: height))
    #align(center, [#text(fill: rgb("ffffac"), [Fig. #n]) -- #title.])
  ]
}

#let un = it => text(fill: orange, it)
#let letdef = text(fill: yellow, "let")

#let small = it => text(size: 0.7em, $(it)$)


= Plane3 $<->$ Plane3

given:

$ "Plane3"_1 :: \
#pad(left: 2em, [
  $"pos"_1: "Vec3" = (x_0, y_0, z_0)$ \
  $"axisX"_1: "Vec3" = (x_1, y_1, z_1)$ \
  $"axisY"_1: "Vec3" = (x_2, y_2, z_2)$ \
  $"axisZ"_1: "Vec3" = (A_1, B_1, C_1)$ \
])
$

$ "Plane3"_2 :: \
#pad(left: 2em, [
  $"pos"_2: "Vec3" = (X_0, Y_0, Z_0)$ \
  $"axisX"_2: "Vec3" = (X_1, Y_1, Z_1)$ \
  $"axisY"_2: "Vec3" = (X_2, Y_2, Z_2)$ \
  $"axisZ"_2: "Vec3" = (A_2, B_2, C_2)$ \
])
$

$
  "uv"_1: "Vec2" = (u, v) \
  "uv"_2: "Vec2" = (U, V) \
$

Any plane can be defined by the equation:

$ A x + B y + C z + D = 0 $

where $(A, B, C)$ is a normal vector of the plane. For a $"Plane3"$ the normal is $"axisZ" = "axisX" times "axisY"$, and $"pos"$ lies on the plane, so:

$
  (A, B, C) = "axisZ", quad D = -("axisZ" dot.op "pos")
$

The result is needed in $"uv"_1$ coordinates of $"Plane3"_1$, so a point of $"Plane3"_1$ is substituted into the equation of $"Plane3"_2$:

$
  letdef D_2 = - ("axisZ"_2 dot "pos"_2) \
  A_2 (x_0 + un(u) x_1 + un(v) x_2) + B_2 (y_0 + un(u) y_1 + un(v) y_2) + C_2 (z_0 + un(u) z_1 + un(v) z_2) + D_2 = 0 \
  small(x_0 A_2 + un(u) x_1 A_2 + un(v) x_2 A_2 + y_0 B_2 + un(u) y_1 B_2 + un(v) y_2 B_2 + z_0 C_2 + un(u) z_1 C_2 + un(v) z_2 C_2 + D_2 = 0) \
  small(un(u) x_1 A_2 + un(u) y_1 B_2 + un(u) z_1 C_2 + un(v) x_2 A_2 + un(v) y_2 B_2 + un(v) z_2 C_2 + x_0 A_2 + y_0 B_2 + z_0 C_2 + D_2 = 0) \
  un(u) (A_2 x_1 + B_2 y_1 + C_2 z_1) + un(v) (A_2 x_2 + B_2 y_2 + C_2 z_2) + (A_2 x_0 + B_2 y_0 + C_2 z_0 + D_2) = 0 \
$

Each group is a dot product of $"axisZ"_2 = (A_2, B_2, C_2)$ with a vector of $"Plane3"_1$:

$
  A_2 x_1 + B_2 y_1 + C_2 z_1 = "axisZ"_2 dot.op "axisX"_1 \
  A_2 x_2 + B_2 y_2 + C_2 z_2 = "axisZ"_2 dot.op "axisY"_1 \
  A_2 x_0 + B_2 y_0 + C_2 z_0 + D_2 = "axisZ"_2 dot.op "pos"_1 + D_2 = "axisZ"_2 dot.op ("pos"_1 - "pos"_2) \
$

$
  letdef a = "axisZ"_2 dot.op "axisX"_1 \
  letdef b = "axisZ"_2 dot.op "axisY"_1 \
  letdef c = "axisZ"_2 dot.op ("pos"_1 - "pos"_2) \
  un(u) a + un(v) b + c = 0 \
$

This is the equation of the intersection line in $"uv"_1$ coordinates.

$
  cases(
    un(v) = - un(u) a / b - c / b "," abs(a) < abs(b),
    un(u) = - un(v) b / a - c / a "," abs(a) > abs(b),
  )
$

$
  cases(
    "line2"((0, -c/b), (1, -c/b - a/b)) "," abs(a) < abs(b),
    "line2"((-c/a, 0), (-c/a - b/a, 1)) "," abs(a) > abs(b),
  )
$

Special case: $a approx 0 "," b approx 0$ means $"axisZ"_2$ is perpendicular to both $"axisX"_1$ and $"axisY"_1$, i.e. the planes are parallel ($c$ is then the signed distance between them), and if $c approx 0$: the planes coincide

