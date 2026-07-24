version       = "0.1.3"
author        = "levovix"
description   = "Computational geometry"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.2.0"
requires "vmath >= 2.0"  # for compatibility with vectors used by many nim projects


feature "opencascadeBackend":
  requires "https://github.com/levovix0/opencascade"

feature "c3dBackend":
  requires "https://github.com/levovix0/c3d"


feature "moduleTests":
  requires "print >= 0.1.0"  # for debugging

feature "examples":
  requires "rice"
  requires "shady == 0.1.4"
  requires "siwin"

