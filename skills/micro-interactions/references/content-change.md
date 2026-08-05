# Content Change

The half of this set that is neither a curve nor a layout rule: what happens when the
**content itself** changes — a number that moves, a label that becomes another label, a
paragraph that arrives, an icon that becomes a different icon.

The mistake is not animating it badly. The mistake is treating it as a text update.

---

## 1 · Content is replaced, never mutated

```
WRONG   node.textContent = next          the old value is gone before anyone saw it change
RIGHT   two nodes, one cell, the old one leaves while the new one arrives
```

A value written in place changes between two frames. There is no transition to perceive,
so the user gets no signal that anything happened — they either happened to be looking at
that pixel, or they did not. **A number that changes in place is a number you can miss.**

The whole family — flashing values, swapping labels, morphing icons, revealing text — is
one pattern: **the old content and the new content coexist for 150–200ms in a box that
never resizes.** Everything below is the consequence of that sentence.

The exception is real and it is §8: content that changes *every frame* must be written
directly to the DOM and must not be replaced. Rolling a 60fps readout produces a smear.

---

## 2 · The identity is the mechanism

This is the structural core, and it is what makes the pattern headless.

The hook does not animate anything. Its job is to notice that the value changed and to
**mint an identity for the change**, which the view uses as a key:

```ts
{ direction: "up" | "down" | null,   // the semantic axis, §3
  from: T,                            // what it was
  changeId: number,                   // the identity — increments per change
  flashing: boolean }                 // the display window, §6
```

`changeId` is the entire bridge between behaviour and presentation. The view keys its
copies on it; a new id means the previous copy exits and a fresh one enters. Nothing else
about the animation lives in the hook — swap the styled component and the behaviour is
unchanged, which is invariant 6 actually delivered rather than asserted.

Three details the hook owns, not the view:

- **Identity, not equality, decides.** `Object.is(previous, next)` — then compute a delta
  and **return early if the delta is zero.** A re-render with the same value must not
  produce a change. A formatted string that renders identically (`1.004` → `1.0`) is not
  a change either; compare the *source* value, not the formatted text.
- **Comparison is injectable.** Default to numeric subtraction, accept a `compare` for
  anything else. A hook that only understands numbers cannot flash a rank, a tier or a
  status.
- **The display window is a timer the hook holds**, cleared on unmount and restarted on
  each change. ~900ms: long enough to look at, short enough that two changes do not
  overlap their tints.

---

## 3 · The axis carries the information

The direction of travel is not decoration — it *is* the message.

```
value went up     new value enters from BELOW    old value leaves UPWARD
value went down   new value enters from ABOVE    old value leaves DOWNWARD
```

The content moves the way the quantity moved. Get this backwards and the animation
actively lies; make it always the same direction and you have thrown away a free channel
and kept the cost.

Where there is no semantic axis — a label becoming another label, an idle icon becoming a
success icon — **do not invent one.** Crossfade in place (CROSSFADE, `motion.md` §1) and
let the change be reported by the content rather than by a direction.

The accompanying glyph is the one place an underdamped spring is right in this family:

```
arrow / tick appearing   640 · 22 · 0.7   ζ 0.52   it is punctuation, not a surface;
                                                   it should land like a stamp
```

Compare the surface it sits on, which lifts to 1.05 and settles back — `380 · 26 · 0.7`,
ζ 0.80. The *container* is alive; the *glyph* pops. Two different jobs, two ratios.

---

## 4 · Geometry: `em`, one cell, clipped

```
travel        0.85em in, 0.7em out        NEVER px
container     inline-grid + overflow-hidden
both copies   col-start-1 row-start-1     same cell, so nothing reflows
numbers       tabular-nums                 digits must not change width
blur          5px in, 4px out
```

**`em`, not px, is the rule that makes this reusable.** The roll distance has to scale
with the type size or the same component reads as a twitch at 11px and a leap at 27px.
This is the one geometric constant in the whole set that is expressed relatively, and it
is worth understanding why: every other distance in this library is a real distance on
screen, but this one is a distance *within a line box*.

The clip is what makes it read as a roll rather than as two things flying past each
other. Without `overflow: hidden` on the cell, the departing copy is visible outside the
box and the effect immediately looks cheap.

`tabular-nums` is not a typographic nicety here — proportional digits mean `1` and `8`
have different widths, so a counter passing through `11 → 18` resizes its own box
mid-animation and violates invariant 1 from the inside.

Where the two states are *labels* rather than values, the cell must be reserved against
the longest one — the invisible twin, `craft.md` §1. The roll does not exempt you from
reserving space; it makes it more urgent, because both copies are in the box at once.

---

## 5 · Enter is a spring, exit is a tween

```
enter   spring 460 · 32 · 0.55   ζ 1.01   ≈ ARRIVE 150ms springless †
exit    tween  0.14s  LEAVE curve         ports as-is, no spring needed
```

† Computed from `motion.md` §1's formula. ζ sits almost exactly on the critical branch
point, where the overdamped and underdamped settle approximations disagree by ~10%
(138ms vs 155ms). Check it on hardware; do not treat 150 as a specification.

The asymmetry is deliberate and it is the general rule from `motion.md` §2 applied here:
the exit must **clear the cell before the arrival crosses it**, or the new value is read
through the ghost of the old one and both are illegible for 60ms. A spring on the exit
would give it a settle tail it has no use for — nothing needs to *land* on its way out of
a clipped box.

Practical consequence: **the exit half of this pattern ports to any stack unchanged.**
Only the entrance wants a spring solver. On CSS or Angular Animations you lose the
entrance's overshoot-free settle and nothing else.

---

## 6 · The animated stack is `aria-hidden`. A sibling carries the truth.

This is not an accessibility footnote — it is the reason the pattern is safe to use at
all, and it is the part most implementations get wrong.

```html
<span aria-hidden>  …the two rolling copies, the tint, the glyph…  </span>
<span class="sr-only" aria-live="polite">{settled}</span>
```

Two nodes, two audiences. The visual stack is entirely hidden from the accessibility
tree, because a screen reader encountering two copies of a value in one box reads **both
of them** — and during the transition it may read a value that is on its way out.

The live region is a *separate, plain text node* holding the **settled** value, debounced
(~700ms, `craft.md` §6). It never contains the outgoing copy, so it cannot announce a
value that no longer exists. Label it if the number alone is ambiguous:
`` `${label}: ${settled}` `` — "Balance: 1,240" is a sentence; "1,240" is a noise.

The same split applies to every member of the family:

```
revealed text     sr-only holds the WHOLE string; the split glyphs are aria-hidden
streaming text    sr-only holds the whole string; add aria-busy while in flight
icon morph        the icons are aria-hidden; the button's accessible name states the state
```

**The rule: if you split content into pieces to animate it, the pieces are decoration and
a whole, unsplit copy must exist for anything that is not an eye.** A screen reader given
per-character spans reads a word letter by letter, or skips it, depending on the engine.

---

## 7 · Splitting text without breaking it

Splitting a string into animatable units destroys two things the browser was doing for
you. Both must be put back.

**Word wrapping.** Per-character `inline-block` spans let the line break *inside* a word.
Group the characters of each word in a wrapper and pin it:

```
word wrapper    inline-block + whitespace-nowrap    the word breaks as a unit
unit            inline-block + align-baseline        vertical rhythm survives
gaps            a real space between word groups, not a margin
```

`align-baseline` is not optional. An `inline-block` defaults to baseline alignment of its
*bottom margin edge*, and a transformed one drifts off the line's baseline in a way that
is invisible in a one-line demo and obvious in a paragraph.

**The stagger has a ceiling, and the ceiling subtracts the unit's own duration:**

```
step = min(stagger, (maxDuration − unitDuration) / (n − 1))
```

The subtraction is the part that is easy to get wrong. The last unit *starts* at
`(n−1)·step` and *finishes* one duration later, so budgeting the span against
`maxDuration` alone overruns by exactly one unit duration on every long string. Ceiling
~1.6s: a hundred-word paragraph reveals in the same time a ten-word one does.

**Choose `word` by default.** Per-character is for a headline of a few words. A paragraph
split by character is `n` animated nodes where `n` is the character count, and it reads as
a machine printing rather than as text arriving.

---

## 8 · The boundary: replaced vs. written

The two halves of this library meet here, and the line between them is sharp:

```
DISCRETE, meaningful change      →  replace   (this document)
   a price tick, a vote count, a label swap, a status
CONTINUOUS, per-frame change     →  write     (motion.md §4)
   a drag readout, a live percentage, a scrubber position
```

A rolling animation on a value that updates every frame is a permanent blur — the exit
never completes before the next entrance begins, so the cell holds three or four copies
and reads as vibration. Write those directly: `node.textContent = …`, no state, no key.

**Between the two, coalesce.** If discrete changes can legitimately arrive faster than the
exit clears (~150ms), the hook must collapse them: hold the latest value and mint one
`changeId` when the burst stops. Two changes 40ms apart are one change to a person
watching; rendering them as two is how a "live" component starts to look broken. This is
the settle-window pattern from `craft.md` §7, applied to display rather than to commits.

---

## 9 · Reduced motion

The information here is *the change itself*, so it must survive:

```
travel      dropped     no y, no blur
opacity     kept        the swap still happens, at duration 0
direction   kept        the glyph still says up or down
tint        kept        it is colour, not motion
live region unchanged   it never depended on the animation
```

`duration: 0` on both copies, not "skip the swap". The new value must still replace the
old one through the same code path, or you have built a second rendering mode that no
one tests. Invariant 3: the trip is skipped, the destination is not.

For streaming or revealing text, reduced motion means **jump to done and show the whole
string** — never a faster reveal.

---

## 10 · Review checklist for this family

- [ ] Set the value to what it already is. Does anything animate? → §2
- [ ] Change it through a width boundary (`9 → 10`, `99 → 100`). Did the box move? → §4
- [ ] Change it twice within 100ms. Two copies, or four? → §8
- [ ] Read it with a screen reader mid-change. Does it say the old value, or both? → §6
- [ ] Make it go down. Does the content move downward? → §3
- [ ] Set the font size to 27px. Is the travel still proportionate? → §4
- [ ] Reveal a paragraph. Does any word break across a line? → §7
- [ ] Reduce Motion on: does the value still change, and does the direction still show? → §9
