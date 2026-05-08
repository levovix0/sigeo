import ../core/[vectors, points]


proc computeVertexNormals*(vertices: openArray[Point3], indices: openArray[int]): seq[Vec3] =
  result = newSeq[Vec3](vertices.len)
  var count = newSeq[int](vertices.len)

  for i in countup(0, indices.high, 3):
    let a = vertices[indices[i]]
    let b = vertices[indices[i+1]]
    let c = vertices[indices[i+2]]
    let n = cross(b - a, c - a).normalize
    result[indices[i]] += n
    result[indices[i+1]] += n
    result[indices[i+2]] += n
    inc count[indices[i]]
    inc count[indices[i+1]]
    inc count[indices[i+2]]

  for i, v in result.mpairs:
    v = v / i.float32


