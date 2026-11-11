# Accessibility

DagaDyn makes objects move in a SketchUp model. Moving things are a visual
experience, but nobody should get a headache, feel sick or be shut out
because of a setting that could have been changed. This page says what you
can adjust today, what does not work well yet, and how to tell us.

Setting names below are as they appear in the panel
(*Extensions › DagaDyn › Animation panel…*). Some are only visible at the
**Advanced** or **Expert** level: pick it at the top of the panel.

## ⚠ Flashes (photosensitivity)

DagaDyn itself never flashes: no light effects, no sudden changes of the
whole view.

**The animations you build can flash**, though. Visibility and tag switch at
once; a colour or opacity animation with a short duration, a *Steps* curve,
or a loop played back and forth quickly can make an object blink. If you
make models for other people to watch (presentations, videos with
DagaWASD), keep blinking below **three times per second** and avoid large
areas alternating between dark and bright, especially red.

If an animation made by someone else bothers you:

- **⏸** (or Space in the panel) stops it where it is, **⏹** puts everything
  back at rest;
- *Settings › Playback › Speed* slows every animation down (for example
  0.25);
- with DagaWASD, *Settings › Playback › Animations in DagaWASD* off keeps the
  objects still while you walk, explore and export videos.

## Motion sickness

- **Nothing moves until you ask**: animations only play with **▶**, with the
  *Use* tool, or (if you leave it on) while DagaWASD is walking or exporting.
- **Look without motion**: the timeline bar shows any moment as a still
  picture; the dot next to each state shows the object in that state.
- **Speed and smoothness**: *Playback › Speed*, and gentle curves (*Speed up
  and slow down* is the default for new tracks; *Bounce* and *Elastic*
  shake the most).
- **Paths in the view**: *Settings › Editing › Show paths* draws the route of
  moving objects. Turn it off if the extra lines get in the way.
- **Panel animations**: *System › Appearance › Animations* (Advanced).
- **Moving platforms in DagaWASD** carry the player along, also turning:
  turn off *Animations in DagaWASD* if that is uncomfortable.

## Input

- **The panel works with the keyboard**: Tab moves between controls, Enter
  and the arrow keys change them, **Space** plays and pauses, **Esc** closes
  menus and the curve editor. *Search settings…* finds a setting by name.
- **The curve editor needs a pointer** to drag its dots. Every transition
  can use a ready-made curve from its list instead (linear, speed up, slow
  down, overshoot, bounce, elastic, steps), and values are typed in boxes.
- **The *Use* tool** needs a click on the object in the model. The same
  objects can start with the timeline or after another object instead
  (*Starts* in the object's settings); in DagaWASD the Use key works too,
  and DagaWASD's keys can all be changed.

## Seeing the panel and the view

- **Themes**: *System › Appearance › Theme* has **High contrast**, Light,
  Dark and others, or *Automatic* to follow Windows. *Custom background and
  text* (Expert) lets you pick your own colours; accent, highlight and stop
  colours can be changed too.
- **Text**: *Typeface*, *Text size*, *Line spacing* and *Spacing*; the
  *Name column width* (Expert) makes room for long labels.
- **Less clutter**: three levels (Basic, Advanced, Expert); *Show
  descriptions* hides the short explanation under each setting.

## Language and sound

- The panel is in **36 languages**, including right-to-left Arabic and
  Hebrew. It follows SketchUp's language, or you can choose one.
- DagaDyn makes **no sounds**: nothing depends on hearing.

## Known limitations

- **The 3D view cannot be read by a screen reader.** The panel is a web page
  inside SketchUp, but it has not been tested with screen readers (NVDA,
  JAWS, Narrator); the timeline, the curve editor and the small curve
  pictures are drawn, and may not be announced.
- **Some explanations are only in tooltips** shown on mouse hover.
- **Not yet tried on a Mac**, nor with every SketchUp version: it was
  developed on SketchUp 2024 for Windows.

## Tell us

If something gets in your way, please say so: accessibility problems are
treated as bugs. Open an [issue](https://github.com/Dagadam/dagadyn/issues/new/choose)
and describe what you use (screen reader, magnifier, switch, keyboard
only…) and what happened. You can write in English or Italian.

This statement was last reviewed for DagaDyn 0.2.0 (November 2026).
