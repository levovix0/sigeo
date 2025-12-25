import macros

macro anyOrder*(body: untyped): untyped =
  #[runnableExamples:
    proc intersects*(a: LineSection, b: CircleArc): bool {.anyOrder.} =
      ## ...
    
    # will generate
    #[
      template intersects*(b: CircleArc, a: LineSection): bool =
        intersects(a, b)
    ]#
  ]#

  ## todo
  body

