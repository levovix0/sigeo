import os, strutils, strformat, sequtils, algorithm

task test, "run tests":
  for (kind, path) in walkDir("tests").toSeq.sorted:
    if path.splitFile.ext == ".nim" and path.splitFile.name.startsWith("t_"):
      exec &"nim c -r {path}"

task vtest, "run visual tests":
  for (kind, path) in walkDir("tests").toSeq.sorted:
    if path.splitFile.ext == ".nim" and path.splitFile.name.startsWith("v_"):
      exec &"nim c -r {path}"
