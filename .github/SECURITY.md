# Security policy

## Supported versions

Only the latest release of DagaDyn receives fixes. If you are on an older
version, update from the [Releases](https://github.com/Dagadam/dagadyn/releases)
page first and check whether the problem is still there.

| Version | Supported |
|---|---|
| Latest release | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report them privately through GitHub:
[**Report a vulnerability**](https://github.com/Dagadam/dagadyn/security/advisories/new)
(also reachable from the *Security* tab of this repository).
If you cannot use it, write to [DagaWASD@icloud.com](mailto:DagaWASD@icloud.com) instead.

Please include:

- the DagaDyn version;
- your SketchUp and operating system versions;
- what an attacker can do, and the steps, model or file to reproduce it.

You will get an answer as soon as possible. Once a fix is released, the
advisory is published with credit to you, unless you prefer to stay
anonymous.

## Scope

What matters most:

- **Models**: animations travel inside `.skp` files (attribute dictionary
  `DagaDyn`). Opening a crafted model must never run script in the panel or
  code in SketchUp; anything that does is a vulnerability.
- **Imported settings**: the same for a settings file loaded with *Import
  settings…*.
- **Files**: the extension should write only to `%APPDATA%\DagaDyn`
  (settings and error log) and to the files the user picks for export.
  Writing anywhere else, or reading files it should not, is a
  vulnerability.
- **The link with DagaWASD** (`dagadyn/lib/api.rb`): it is called only from
  inside SketchUp and opens no network port.

Not vulnerabilities: anything that needs the developer tools in `tools/`,
which are not part of the extension, or a program already running under
your account changing the files in `%APPDATA%\DagaDyn`.
