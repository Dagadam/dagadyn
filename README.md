# DagaDyn

**English** · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

A SketchUp extension that makes objects dynamic. Any property of a group, a
component or a section plane goes from one state to another over the time
you choose, along a curve you draw, and you watch it happen in the scene.
Doors that open, lifts that rise, lamps that light up, sections that sweep
through a building.

⬇ **Download**: [latest release](https://github.com/Dagadam/dagadyn/releases/latest) (all versions: [Releases](https://github.com/Dagadam/dagadyn/releases))

🛏 **Example**: [a bedroom where everything moves](examples/README.md) (`examples/bedroom.skp`), with every feature of DagaDyn.

## What it does

- **Properties**: move (from where the object is), position, rotation, size
  (width, depth, height), scale, colour, opacity, visibility and tag. Section
  planes move and switch on and off.
- **States and curves**: every property has a start state, an end state and
  a duration; add more states to make a sequence. Each transition follows a
  curve: linear, speed up, slow down, overshoot, bounce, elastic, steps, or
  one you draw in the curve editor by dragging its dots.
- **Timeline**: Play, Pause, Stop and a bar to look at any moment. Once,
  in a loop or back and forth, at the speed you like.
- **Speed of time**: with the **⏱** button next to the timeline, a curve
  like the transitions decides how time flows for the whole model: steeper
  for a time-lapse, flatter for slow motion, and the playback can last less
  or more than the timeline.
- **Starts**: an object starts with the timeline, after another object has
  finished (plus a wait), or **when it is used**: click it with the *Use*
  tool. It can start over every time, or go forward and then back the next
  time (doors, drawers).
- **Chains that follow**: objects chained behind one that goes forward and
  back follow its direction, both ways, each one starting when the one before
  has finished (a lever, then the drawbridge).
- **The project does not change**: animations move the objects without
  touching the model. *Stop* puts everything back, and the file always
  saves the rest state; *Keep* leaves the objects as they are now (Ctrl+Z
  undoes it).
- **Inside the objects**: animations are saved in the `.skp` file and copied
  with the object. With several objects selected, a change applies to all of
  them, adapted to each one's position and size.
- **Paths in the view**: the route of the objects that move, with a dot for
  every state (SketchUp 2023 and later).
- **Preview while editing**: changing the value of a state shows the object
  in that state.
- **On its own or with [DagaWASD](https://github.com/Dagadam/dagawasd)**: DagaDyn needs nothing
  else. With DagaWASD 1.3.0 or later installed too, objects also move while
  you walk, explore, replay paths and export videos (frame by frame, at the
  video's time). Moving platforms carry you along, and the Use key starts the
  objects that start when used.
- Panel in 36 languages. With DagaWASD installed, it follows DagaWASD's
  language and appearance.
- **Accessibility**: see [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Requirements: SketchUp 2023 or later. Developed and tested on Windows; on a
Mac it has not been tested yet.

## How to use it

1. *Extensions › DagaDyn › Animation panel…* (or the toolbar).
2. Select a group, a component or a section plane. In *Animation › Object*
   pick a property to animate and press *Add*.
3. Write the start state and the end state (*⌖ current* takes the value the
   object has now), the duration, and pick a curve. Click the small curve to
   draw your own.
4. Press **▶** (or Space in the panel). **⏹** puts everything back.

For objects that start «when used», pick the *Use* tool (toolbar or menu)
and click the object in the model; Esc leaves the tool.
Under the mouse, the object that will start is outlined and shows its name.
When no object starts with the timeline, the **▶** button becomes **☝**, the
*Use* tool.

## Installation

Download **`dagadyn-<version>.rbz`** from the
[latest release](https://github.com/Dagadam/dagadyn/releases/latest) (under
*Assets*) and install it from *Extensions › Extension Manager › Install
Extension*.

Settings are stored in `%APPDATA%\DagaDyn\settings.json`: an update does not
erase them. Animations are in the models, not in the extension.

## Development

The code, its comments and the changelog are in Italian; how the extension
is built inside is in [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` copies the source into the Plugins folder of every SketchUp
  it finds.
- `tools\run_tests.bat` runs the tests (Ruby with a simulated SketchUp; the
  curve test also needs Node.js).
- `ruby tools\test_live.rb` tries it in the real SketchUp through DagaWASD's
  bridge (it needs a new model open, *File › New*, and leaves a new one).
- `ruby tools\crea_rbz.rb` makes the package in `dist\`.
- The version number lives only in `dagadyn.rb` (`VERSION`); every version
  has its section in `CHANGELOG.md`.
- This README is in several languages (`README.md` in English,
  `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`,
  `.ru`, `.ja`, `.ko`, `.zh`): a change goes into all of them.

Contributions are welcome: see [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Contact

Bugs and ideas are better as an
[issue](https://github.com/Dagadam/dagadyn/issues), where others can see and
follow them; security problems go through the
[security policy](.github/SECURITY.md). You can also write to
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

If DagaDyn is useful to you, you can support its development on
[Ko-fi](https://ko-fi.com/dagadam).

## License

[MIT](LICENSE) © 2026 Dagadam. You may use, modify and redistribute the code
freely, commercially too, as long as every copy keeps the copyright notice
and the license text.
