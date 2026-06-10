
type
  Indexable*[T] = concept x
    x[T] is T

  Bitmask* = object
    bytes*: seq[byte]
    len*: int


proc high*(bm: Bitmask): int {.inline.} =
  bm.len - 1


proc `[]`*(bm: Bitmask, i: int): bool {.inline.} =
  if (i div 8) notin 0..<bm.bytes.len: return false
  (bm.bytes[i div 8] and (1'u8 shl (i mod 8))).bool


proc `[]=`*(bm: var Bitmask, i: int, v: bool) {.inline.} =
  assert i >= 0
  if (i div 8) notin 0..<bm.bytes.len:
    bm.bytes.setLen(i div 8)
  if bm.len < i: bm.len = i

  if v:
    bm.bytes[i div 8] = bm.bytes[i div 8] or (1'u8 shl (i mod 8))
  else:
    bm.bytes[i div 8] = bm.bytes[i div 8] and not(1'u8 shl (i mod 8))



proc `[]`*(bm: Bitmask, i: BackwardsIndex): bool {.inline.} =
  bm[bm.len - i.int]


iterator items*(bm: Bitmask): bool =
  for i in 0..<bm.len: yield bm[i]

iterator pairs*(bm: Bitmask): (int, bool) =
  for i in 0..<bm.len: yield (i, bm[i])


proc `$`*(bm: Bitmask): string =
  result = ""
  for i, x in bm:
    result.add (if x: '1' else: '0')
    if (i > 0) and (i < bm.high) and (i mod 8 == 0):
      result.add '|'


proc add*(bm: var Bitmask, v: bool) {.inline.} =
  bm[bm.len] = v


proc del*(bm: var Bitmask, i: int) =
  if i >= bm.len:
    discard
  elif i == bm.high:
    dec bm.len
  else:
    bm[i] = bm[^1]
    dec bm.len


proc toSeq*(bm: Bitmask): seq[bool] =
  for x in bm: result.add x

proc toBitmask*(bm: seq[bool]): Bitmask =
  for x in bm: result.add x



when isMainModule:
  ##

