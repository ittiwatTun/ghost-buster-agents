---
name: perl-non-ascii-replacement
description: a perl -0777 -i edit whose replacement holds \x{...} above 255 double-encodes the whole UTF-8 file; write non-ASCII as literal bytes or use the Edit tool
type: feedback
---

`perl -0777 -i -pe 's/.../\x{2026}/'` reads the file as bytes. A replacement holding a character above U+00FF upgrades the whole string, and perl prints every original UTF-8 byte re-encoded, with a "Wide character in print" warning. Every `—` becomes `â€”`, across the whole file. CRLF survives, so `file` still says UTF-8 and the damage is easy to miss.

Repair in place, never through `git checkout`, which drops uncommitted edits: decode the file once as UTF-8, write each character below 256 back as one byte, and UTF-8 encode the rest. Before that, swap any intended U+0080–U+00FF character, such as `×`, for a private-use placeholder, and restore it as its UTF-8 bytes afterwards. Back up to scratchpad first.

**Why:** 2026-09-28, `openspec/changes/nav-geometry-artifact/tasks.md` was double-encoded by a note carrying `…` and `×`.

**How to apply:** for an edit whose new text holds non-ASCII, use the Edit tool. In perl, put the characters in the source as literal UTF-8 (no `\x{}`, no `-Mutf8`). After any perl edit, check with `grep -c "â" <file>`.
