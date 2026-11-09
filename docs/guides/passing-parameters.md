# Passing parameters

How to shape what a function or closure takes. The rules this builds on are in
`docs/spec/values-and-memory.md`, 1.5 (values and objects) and 1.13 (calls).

## What the language checks

- A call gives a function exactly as many arguments as it takes. A call naming a
  function with the wrong number is refused when the program is compiled; a closure
  called with the wrong number stops the program as a failed precondition.
- A last parameter named `rest` takes any further arguments as a list, however the
  function or closure is called.
- `takes none`, or no `takes` at all, declares no parameters.
- A closure is called with at most 8 arguments. A call with more is refused when the
  program is compiled.

There are no optional parameters and no defaults. A missing argument is an error, not
`unit`.

## Keep the list short

Three or four parameters read well at a call site. Past that, a reader has to count
positions to know which value is which, and two arguments of the same type can be
swapped without anything noticing. If a function wants more than about four, or a
closure is heading for the limit of 8, the parameters usually belong together and
should travel as one thing.

Don't use `rest` to get around the limit. `rest` is for a varying number of
arguments of the same kind (`sum(1, 2, 3)`, the arguments after `thread_spawn`'s
closure), not for a fixed set of different things passed by position.

Don't reach for top-level `let`s or named objects to avoid passing something. State a
function needs is a parameter.

## Group related parameters

Gather parameters that describe one thing into one argument. The choice is between
an object and a list, and it turns on whether the callee may change what it is
given (spec 1.5).

### An object, when the parts have names

A class gives each part a name, a default, and somewhere to state what makes it valid:

```patlang
class Camera {
  field position = [0, 0, -5]
  field fov = 60
}

make a function called camera_new takes position, fov returns c
  require fov > 0
  let c = new("Camera")
  c.position = position
  c.fov = fov
  return c
end
```

A function then takes the camera, not its pieces:

```patlang
make a function called view_width takes camera, distance returns w
  require type_of(camera) == "Camera"
  return 2 * distance * tan(camera.fov * 3.14159 / 360)
end
```

Field defaults replace optional parameters. A caller sets only what differs from the
default, and the callee still receives one argument.

An object has identity: a change the callee makes through it is seen by the caller,
and by everything else holding it. That suits a group the callee is meant to update
(an accumulator, a context passed down a pipeline). When it is not meant to change,
say so in the callee's contract, or pass a list.

Leave objects unnamed (`new("Camera")`) unless something must find them by name. A
named object lives until `object_delete`; an unnamed one lives as long as something
holds it.

### A list, when the parts are a sequence or a fixed small tuple

A list is a value: the callee cannot change the caller's copy. Use one for a
homogeneous sequence (points, items to process) and for a short fixed tuple whose
order is obvious from what it is (`[x, y, z]`, `[low, high]`). Say what each position
means in a comment at the function, and check the shape:

```patlang
# point: [x, y, z]
make a function called length_of takes point returns d
  require list_len(point) == 3
  return sqrt(point[0] * point[0] + point[1] * point[1] + point[2] * point[2])
end
```

A list of more than three or four positions, or of positions of different kinds, has
outgrown this. Make it an object, so each part is reached by name.

## Group hierarchically

When a function needs many things, nest the groups the way the problem is already
divided: a scene holds a camera, its lights and its size, and each of those is a
group of its own.

```patlang
class Light {
  field position = [5, 5, -5]
  field intensity = 1.0
}

class Scene {
  field camera = unit
  field lights = []
  field width = 640
  field height = 480
}

make a function called scene_new takes camera, lights returns s
  require (type_of(camera) == "Camera") and (type_of(lights) == "list")
  let s = new("Scene")
  s.camera = camera
  s.lights = lights
  return s
end

make a function called render takes scene returns image
  require type_of(scene) == "Scene"
  let camera = scene.camera
  ...
end
```

Each level is small enough to read, each is built in one place by its constructor
function, and a function deep in the work takes only the part it uses
(`view_width(scene.camera, d)`), not the whole scene. That keeps what a function can
reach visible in its parameters.

Set nested objects in the constructor, as `scene_new` does. Don't put `new(...)` in a
field default: every instance would get it from the class rather than one of its own.

## Contracts on groups

A group is a good place for a contract. A constructor function's `require` states what
a valid group is, once; a function taking the group can `require` its class (and any
fields it relies on) at the boundary, instead of checking each loose argument again.
