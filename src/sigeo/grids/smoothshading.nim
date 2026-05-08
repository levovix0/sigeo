import ../core/[vectors, points]


proc computeVertexNormals*(vertices: openArray[Point3], indices: openArray[int]): seq[Vec3] =
  result = newSeq[Vec3](vertices.len)

  for i in countup(0, indices.high, 3):
    let a = vertices[indices[i]]
    let b = vertices[indices[i+1]]
    let c = vertices[indices[i+2]]
    var n = cross(b - a, c - a)
    result[indices[i]] += n
    result[indices[i+1]] += n
    result[indices[i+2]] += n

  for i, v in result.mpairs:
    v = v.normalize


