# Visual Language

The static half. Motion cannot rescue a surface that reads as generic, and a
well-tuned spring on a pill-shaped, pulsing, gradient-filled box still looks like
every other generated interface.

The specific hex values below are one worked instance — replace them with your own.
The **system** is what ports.

---

## 1 · Depth is a material, not a border

Everything on screen is one of three layers, and depth is real: a well is cut *into*
the surface, a panel is lifted *out* of it, a cap has a bottom lip you could press.

| Layer | What it is | Light | Dark |
|---|---|---|---|
| **bezel** | The frame everything sits in. The page background. | `#EFEEEA` | `#141312` |
| **panel** | The lifted card, where content lives. | `#FFFFFF` | `#1D1D1A` |
| **well** | The recessed slot: inputs, code, previews, chips. | `#F6F6F4` | `#252522` |

Five shadows, and never a hand-written sixth:

```
panel   0 1px 2px rgba(28,25,23,0.06), 0 4px 10px -8px rgba(28,25,23,0.45)
float   0 28px 56px -24px rgba(24,22,20,0.45)     modal
        0 18px 40px -24px rgba(28,25,23,0.5)      popover
        0 16px 36px -18px rgba(28,25,23,0.5)      dropdown
well    inset 0 1px 2px rgba(28,25,23,0.07)
cap     inset 0 1.5px 0 rgba(255,255,255,0.95), inset 0 -1px 0 rgba(28,25,23,0.06)
row     inset ring + 0 1px 2px
```

**`rgba(28,25,23,·)` — the ink shadow — never `rgba(0,0,0,·)` on a light surface.**
A neutral black shadow on a warm surface reads as dirt. Dark mode *does* use plain
black, because there a shadow is an absence of light rather than a tint.

In dark mode, a lifted surface also carries an `inset 0 1px 0` white highlight on its
top edge. **That top light is what makes a dark surface read as lifted rather than as
a hole.** Dark surfaces rise by getting *lighter*.

**Rule: a plain border never carries elevation.** Use a hairline when you are dividing
one compartment from another, and material when you mean one thing is above or below
another.

---

## 2 · Radii nest

**Outer radius = inner radius + the padding between them.** The numbers are derived,
never guessed.

```
14 panel  → p-[5px] → 9 row       (14 = 9 + 5)
11 panel  → p-[5px] → 6 row       (11 = 6 + 5)
12 shell  → p-1     → 8 plateau   (12 = 8 + 4)
```

A worked ladder:

```
20  page panel          10  field, drop target, avatar tile
16  preview frame       9   list row, button, search field
14  card, section       8   nested row, tab plateau, step tile
13  list card           7   icon button inside a panel
12  tabs shell          6   cap, chip, chevron button
11  popover, dropdown   5   cell, small chip, kbd, checkbox
                        4   progress track    2  fill, tick, rail
```

When a number is not derivable, derive it from the nearest one that is.

---

## 3 · The bans, and what they are actually for

These exist to stop one thing: output that looks like every other generated interface.
They are a defence against genericness, **not a formula**. The moment a ban becomes a
formula it has failed in a new costume — swapping every `rounded-full` for a strip of
cells is the same absence of judgement as reaching for `rounded-full` in the first
place.

**A ban yields when the banned thing is genuinely the right answer, and you can say
why in one sentence.**

| Banned | Instead |
|---|---|
| `rounded-full`, pills, circular avatars | 5 / 6 / 9 / 11 / 14 / 20px |
| `animate-pulse`, any idle loop | Discrete cells, event-driven motion |
| Grid or dot-grid backgrounds | Material difference |
| Decorative gradients, glow, aurora | One accent, where it means something |
| Uppercase mono as a default voice | Mono for metadata and numbers only |
| Borders standing in for depth | Material |
| Drop shadows to "add polish" | The material already has the shadow |

What is *never* allowed is the thing the bans were written against: **decoration with
nothing behind it.** A pulse that means nothing. A gradient because the surface looked
empty. A pill because everything else was a pill.

The standing exemptions, each with its one-sentence defence — this is what a yielded
ban looks like:

```
ripple        a wave leaving a point is a circle; a scaled rounded rect grows its
              own radius and turns into a blob
typing dots   three dots in a bubble is a published, learned idiom — inventing a
              square one teaches nothing
spinner       unknown duration, constant speed, one arc
marquee       the loop IS the component
caret blink   1.06s, times [0, 0.5, 0.5, 1], linear — a hard square wave, the
              terminal's own shape
```

Note what the caret does **not** do: it does not fade. A sine-fading cursor is the tell
of a component that reached for `animate-pulse`.

**The test for a loop is not "does it look nice" but "is it bound to something real".**
An idle loop animates whether or not anything is happening — that is the banned thing.
A loop tied to a live in-flight operation *can* be honest. But honest is not the same
as necessary: a skeleton shimmer passes the honesty test and still fails the necessity
one, because a skeleton with correct timing does not need to prove it is alive (see
`craft.md` §7). The reference set's skeletons are flat, static blocks.

Two corollaries on honesty:

- **A wait whose duration is unknown gets a spinner.** A meter filling against a
  guessed duration claims progress it cannot know, which is worse than looking generic.
- **Discrete cells are for quantities that are actually countable in units** — a hold
  you can abandon, a countdown you can watch run out, a set of items. They are not a
  universal replacement for a bar.

---

## 4 · The input standard

Every field is the same object, and it is derived once and copied. The idea: **an empty
field is a slot; entering it brings it to the surface.** A field that only changes its
border colour on focus has no depth.

```
rest      border: 2px solid <stone-200>
          background: <stone-100/70>
          box-shadow: inset 0 1px 2px rgba(28,25,23,0.07)

focus     border: 2px solid <accent>
          background: white
          box-shadow: none

invalid   border: 2px solid <red>    + white background
success   border: 2px solid <green>  + white background

height 40px      radius 10px
transition: background-color, border-color, box-shadow 150ms
```

Dark mode is the instructive part: **the interior is the same dark every card interior
wears.** A lighter tint inside a field makes it glow against its neighbours; the
recession comes from the shadow, never from a lighter fill. And the resting border sits
*below* hairline strength on purpose — a 2px border at hairline strength reads as a
focus ring at rest. The well does the recessing; the border whispers until focus makes
it shout.

Two more the roster agreed on:

- **The field owns the border; the input owns nothing.** Put the border on a wrapper
  and make the `<input>` transparent with no outline. That is what lets the shell
  animate its width, or a label float out of it, without the input's own box fighting.
- **A chip inside a field is filled, never outlined.** A 1px outline on a white chip
  sitting on a white field is invisible.

---

## 5 · Colour semantics

```
ink     #1B1B19 / #F3F3EF    headings, primary text
ink-2   #46463F / #C2C2BA    body copy
ink-3   #6E6E66 / #93938B    metadata, labels, disabled rows

hairline         ink 17% / white 16%    dividers, compartment edges
hairline-strong  ink 30% / white 28%    hover borders, scrollbar thumb

accent  #4568FF / #93B0FF    interaction, focus, selected state, "this exists"
success #3D7A4E / #5BD79C
error   #C0442F / #F5897F
```

Both the ink ramp and the hairlines were raised **twice**, and that is its own lesson.
A divider at 7% and metadata at `#A6A6A0` read as "refined" in a mockup and as "broken"
on a real screen. **When in doubt between subtle and legible, legible wins** —
restraint belongs in the type sizes and the motion, not in whether people can see the
line.

Three rules that decide where accent goes:

- **Accent marks interaction and state. It is never decoration.**
- **"Selected" is usually ink, not accent.** A segmented thumb, a filter chip thumb, a
  slider fill, a completed step — all ink and depth. Accent is reserved for *"the
  system is responding to you right now"*: focus, a drop marker, a live progress fill,
  a card you are holding. **If every selected thing were blue, focus would stop meaning
  anything.**
- **The accent is chosen against the surface it is drawn on, not against the page.** A
  dark button on a light page takes the *dark-mode* accent for its focus mark. This
  looks like a bug in a diff and is not one.

A third semantic colour (amber, for a genuine three-verdict scale like password
strength) is defensible exactly once. In a set this size it is a slope, not a palette.

---

## 6 · Typography

Sans by default. Mono only for metadata, numbers, code, ids and keycaps.

```
27px    medium    tracking -0.03em    page title
15px    regular   leading-relaxed     lede, modal title
13.5px  regular   leading-relaxed     body
13px    medium                        card title, row name, control
12.5px  regular                       secondary line, chip
11.5px  regular                       hint, error, tooltip, caption
11px    semibold  uppercase +0.08em   section label, column header
10.5px  mono                          metadata, counts
9.5px   mono tabular                  ids, counters, keycaps
```

- **Headings are medium, never bold.** Negative tracking does the work that weight
  would do badly.
- **Anything showing a number gets `tabular-nums`.**
- **`line-height: 1` is banned on anything containing a word.** It shrinks the box to
  the em square and a descender then sits high in it. Use ~1.4 — a normal line box
  centres on the baseline, which is what the eye reads as centred. `leading-none` is
  only for a numeral or a glyph in a fixed-size tile.
- **Uppercase always gets +0.06em to +0.08em tracking.** Uppercase at default tracking
  is a wall. Use it in three places at most.
- **Scaling type blurs it.** Transform-scaled text loses its hinting; below ~0.9 it is
  visibly soft. If a label must shrink as it moves, 0.92 is the floor — better still,
  move it and leave the size alone.

**Icons:** one weight, drawn inline rather than pulled from a package, so a component
costs one dependency instead of two.

```
viewBox 0 0 256 256   stroke-width 16     → 1.5px at a 24px render
viewBox 0 0 24 24     stroke-width 1.5
stroke-linecap: round; stroke-linejoin: round    always
```

An icon a user already knows beats a clever mark they have to learn.

---

## 7 · The details that carry the whole thing

- **When something leaves its container, it must land on a line that already exists.**
  A label floating out of a field aligns with the field's *edge*, not with its inner
  text padding — otherwise the page grows a third vertical axis that agrees with
  nothing.
- **A row picked out of a list is marked by its surface, not by moving.** A 3px content
  nudge belongs to *transient* selection — a cursor travelling a command palette, where
  it reads as the cursor landing. On a **persistent** state like the current route it is
  one row permanently out of line with every other row: the ragged left edge you feel
  before you can name it. Same for hover: the highlight already says which option is
  yours; sliding the label as it arrives reads as the list shifting under the pointer.
- **Sub-text wakes up on selection:** `ink-3` → `ink-2`. Never a colour change large
  enough to notice *as* a colour change.
- **Separators belong to the slots, not to the rows.** In a sortable table the hairlines
  are absolutely positioned at `(i+1) * rowHeight` and are children of no row — hanging
  them off a row's sorted index makes them blink off mid-travel. They also paint last,
  so a marked row's tint cannot swallow one.
- **A ghost of the thing you are dragging is one statement too many.** The gap the
  siblings open **is** the drop target.
- **The scrollbar is furniture.** A 4px mark in a 10px gutter, ink at 16%, 2px radius,
  transparent track, 28% on hover: visible when you look for it, invisible when you do
  not. Remove it entirely where a fade already says there is more.
- **Every item in one flat list is a wall, not navigation.** Sections open and close
  independently, any number at once, the active one opens itself, and a filter is one
  keystroke away for when the name is already known.
