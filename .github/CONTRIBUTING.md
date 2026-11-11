# Contributing to DagaDyn

Thanks for wanting to help! Bug reports, translation fixes, ideas and pull
requests are all welcome.

## Reporting a bug or asking for a feature

Use the [issue forms](https://github.com/Dagadam/dagadyn/issues/new/choose):
they ask for the details that are needed (SketchUp, operating system and
DagaDyn versions, steps, error log). Security problems go through the
[security policy](SECURITY.md) instead, never in a public issue.

## Translations

The panel is in 36 languages, one file per language in `dagadyn/lang/`
(`en.json`, `it.json`, …). If a text in your language sounds wrong or
unnatural, a pull request that fixes it is very welcome, even a single line.
Keep the placeholders as they are (`{n}`, `{s}`, `{name}`…) and the keys in
square brackets (`[Space]`, `[▶]`…).

## Code

Before you start on something big, open an issue to talk about it. How the
extension is built inside (files, engine rules, the link with DagaWASD) is
in [SVILUPPO.md](../SVILUPPO.md).

- **Language.** Code, comments, commit messages and `CHANGELOG.md` are in
  Italian. If you don't speak Italian, write in English: it will be
  translated when merging.
- **SketchUp 2023 or later.** Developed on Windows; if you can try it on a
  Mac, that is very welcome.
- **Install your copy** into every SketchUp found with `installa.bat`, then
  restart SketchUp.
- **Tests.** `tools\run_tests.bat` must end with `TUTTO OK`. It needs Ruby
  3.2 and, for the curve test, Node.js. SketchUp is simulated
  (`tools/fake_sketchup.rb`), so the tests run without it. Add a test for
  what you change.
- **Curves** exist twice, in `dagadyn/lib/curves.rb` and in
  `dagadyn/panel.html`: change both, `tools/test_curves.rb` checks that they
  agree.
- **New texts** go into **all** files in `dagadyn/lang/`, not only Italian
  and English.
- **New Ruby files** in `dagadyn/lib/` must be listed in `dagadyn/main.rb`.
- **The link with DagaWASD** goes only through the public methods in
  `dagadyn/lib/api.rb`: neither extension may need the other to work.
- **Changelog.** Describe what changes for the user under
  `## [Non ancora uscito]` at the top of `CHANGELOG.md`.
- **Version.** Don't change `VERSION` in `dagadyn.rb`: it is bumped when a
  release is made.

## Pull requests

Keep a pull request to one topic, and fill in the checklist of the template.
By contributing you agree that your work is released under the
[MIT license](../LICENSE) of the project.

Everyone taking part is expected to follow the
[code of conduct](CODE_OF_CONDUCT.md).
