# sigeo

Computational geometry

![example](examples/example.png)

(work-in-progress, do not use)


## Example

[extrusion, shown on window](examples/extrusion.nim)

```nim
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
```

## Compile flags

- Float size:  
  Which float type to use by default in sigeo, also applied as float type for vectors, points and matrices.
  - `-d:sigeo_use_float64` (default) - Float = float64
  - `-d:sigeo_use_float32` - Float = float32

- Zero-sized vector normalization:  
  What to do if trying to normalize zero-sized vector.
  - `-d:sigeo_raise_valueError_when_zeroLen_normal_vector` (default) - raise an error
  - `-d:sigeo_assume_no_zeroLen_normal_vector` - undefined behaviour
  - `-d:sigeo_return_axisX_when_zeroLen_normal_vector` - return vec2(1, 0) | vec3(1, 0, 0)

