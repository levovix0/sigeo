import macros

macro anyOrder*(body: untyped): untyped =
  #[runnableExamples:
    proc intersects*(a: LineSection2, b: CircleArc2): bool {.anyOrder.} =
      ## ...
    
    # will generate
    #[
      template intersects*(b: CircleArc2, a: LineSection2): bool =
        intersects(a, b)
    ]#
  ]#

  ## todo
  body

