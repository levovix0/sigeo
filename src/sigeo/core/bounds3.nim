import ./[vectors, points]


type
  Bounds3* = object
    min*: Point3 = point3(+Inf)
    max*: Point3 = point3(-Inf)

  BvhNodeKind* = enum
    bvhBrunch
    bvhLeaf
  
  HasBounds3* = concept x
    x.bounds3 is Bounds3

  BvhNode3*[T: HasBounds3] {.acyclic.} = ref object
    bounds3*: Bounds3
    case kind*: BvhNodeKind
    of bvhBrunch:
      left*, right*: BvhNode3
    of bvhLeaf:
      objects*: seq[T]


template bounds3*(b: Bounds3): untyped = b


proc center*(b: Bounds3): Point3 =
  ((b.min.V3 + b.max.V3) / 2).P3


proc isEmpty*(b: Bounds3): bool =
  b.min.x > b.max.x


proc add*(a: var Bounds3, p: Point3) =
  a.min.x = min(a.min.x, p.x)
  a.min.y = min(a.min.y, p.y)
  a.min.z = min(a.min.z, p.z)
  a.max.x = max(a.max.x, p.x)
  a.max.y = max(a.max.y, p.y)
  a.max.z = max(a.max.z, p.z)

proc add*(a: var Bounds3, b: Bounds3) =
  a.min.x = min(a.min.x, b.min.x)
  a.min.y = min(a.min.y, b.min.y)
  a.min.z = min(a.min.z, b.min.z)
  a.max.x = max(a.max.x, b.max.x)
  a.max.y = max(a.max.y, b.max.y)
  a.max.z = max(a.max.z, b.max.z)


proc `+`*(a: Bounds3, b: Point3|Bounds3): Bounds3 =
  result = a
  result.add b

template `+`*(a: Point3, b: Bounds3): Bounds3 = b + a


template bounds3FromIterator(v: iterable[HasBounds3]): Bounds3 =
  var res = Bounds3()
  for x in v:
    res.add x.bounds3
  res


proc buildBvh3[T: HasBounds3](objects: var seq[T], start, `end`: int): BvhNode3[T] =
  ## todo

  # let node = BVHNode()
  # let count = `end` - start

  # # Вычисляем границы текущего узла
  # node.bounds = computeBounds(objects.toOpenArray(start, `end` - 1))

  # # Базовый случай: если объектов мало, создаем лист
  # if count <= 2:
  #   node.isLeaf = true
  #   node.objects = objects[start ..< `end`]
  #   return node

  # # Находим наиболее растянутую ось для разделения
  # let extentX = node.bounds.maxPoint[0] - node.bounds.minPoint[0]
  # let extentY = node.bounds.maxPoint[1] - node.bounds.minPoint[1]
  # let extentZ = node.bounds.maxPoint[2] - node.bounds.minPoint[2]
  
  # var axis = 0
  # if extentY > extentX: axis = 1
  # if extentZ > max(extentX, extentY): axis = 2

  # # Сортируем объекты по центроиду вдоль выбранной оси
  # sort(objects[start ..< `end`], proc (x, y: T): int =
  #   cmp(x.centroid[axis], y.centroid[axis])
  # )

  # # Разделяем пополам (объектный медианный сплит)
  # let mid = start + count div 2

  # node.isLeaf = false
  # node.leftChild = buildBVH(objects, start, mid)
  # node.rightChild = buildBVH(objects, mid, `end`)
  
  # return node



when isMainModule:
  let objects = [
    (bounds3: Bounds3(min: p3(0, 0, 0), max: p3(100, 100, 100))),
    (bounds3: Bounds3(min: p3(50, 20, 70), max: p3(150, 40, 90))),
    (bounds3: Bounds3(min: p3(60, -20, 70), max: p3(70, -10, 90))),
    (bounds3: Bounds3(min: p3(0, 0, 0), max: p3(0, 0, 0))),
    (bounds3: Bounds3(min: p3(0, 0, 0), max: p3(0, 100, 0))),
    (bounds3: Bounds3()),
  ]

  echo bounds3FromIterator(objects.items)


