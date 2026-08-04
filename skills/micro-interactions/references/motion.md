# Motion

Numbers are from a set of ~55 shipped components. They are worked values, not
arbitrary ones — the reasoning is given so you can re-derive them for a different
scale of interface.

---

## 1 · Springs, and why they are the interruptible choice

A fixed-duration tween restarted mid-flight either jumps back to its start or queues.
A spring has a position **and a velocity**, so a new target mid-flight is absorbed:
the element carries on from where it actually is. That is invariant 2, and it is the
whole reason the animation layer is spring-based.

`ζ = c / 2√(km)` — the damping ratio. Under 1 overshoots, at 1 is critical, over 1
crawls in.

**The right-hand columns are for stacks with no spring solver** — CSS transitions,
Web Animations API, Angular Animations. They are a first-class path, not a
consolation prize: most of this set's motion is overdamped, and an overdamped spring
is a decelerating curve with a settle time. That is exactly what a cubic-bezier gives
you.

| Name | k · c · m | ζ | **Springless equivalent** | Use |
|---|---|---|---|---|
| **CELL** | 520 · 34 · 0.45 | 1.11 | `ARRIVE` **180ms** | The default. A cell lighting, a tick landing, a thumb sliding, a row taking its slot. No tail. |
| **CROSSFADE** | 260 · 34 · 0.8 | 1.18 | `ARRIVE` **200ms**, opacity only | Opacity between two faces; anything whose whole content is being replaced. |
| **SMALL** | 700 · 46 · 0.5 | 1.23 | `ARRIVE` **170ms** | A label lifting, a caret rotating, a chip settling. No tail. |
| **DISCLOSE** | 150 · 27 · 1 | 1.10 | `ARRIVE` **400ms** | A surface travelling a real distance: a drawer, a swipe row, a card flying home. |
| **SURFACE** | 420 · 36 · 0.9 | 0.93 | `ARRIVE` **200ms** (the overshoot is what you lose) | A modal panel. Alive, does not bounce. |

```
ARRIVE  cubic-bezier(0.23, 1, 0.32, 1)      everything that lands
LEAVE   cubic-bezier(0.4,  0, 1,    1)      everything that goes — and always
                                            shorter: 0.11–0.18s (see §2)
```

**The k/c/m numbers do not port across solvers.** Stiffness 520 in one engine's
spring integrator is not stiffness 520 in another's, and neither is a WAAPI duration.
What ports is the **shape**: the damping ratio, the ordering, and the settle time.
Re-derive rather than copy:

```
ω₀ = √(k/m)                        the natural frequency
ζ  = c / 2√(km)                    the damping ratio
settle ≈ 4 / (ω₀ · (ζ − √(ζ²−1)))  overdamped, to within 2%
settle ≈ 4 / (ζ · ω₀)              underdamped
```

Treat the springless durations above as a **starting point to be checked on real
hardware**, not a specification. The two the source states directly are CELL (~180ms)
and SMALL (~170ms); the rest are computed from the formula and rounded to what reads
as a perceptual match.

**The distance chooses the spring.** Measure the travel in pixels: over 200 →
DISCLOSE, 20–200 → CELL, under 20 → SMALL. Read the table as a shape, not a list —
stiffness rises as distance falls, and mass falls with it. That relationship is the
part worth internalising; it survives any change of engine.

Worked one-offs, each of which earned its own numbers. The *reasons* port; the
numbers are examples of the reasoning:

```
tab indicator     620 · 42 · 0.35   ζ 1.42  wide, carries three shadows; any
                                            overshoot reads as a correction
step rail head    520 · 40 · 0.5    ζ 1.24  a head that overshoots a milestone
                                            and comes back reads as a mistake
tooltip rise      560 · 34 · 0.6    ζ 0.93  alive without bouncing
tooltip warm      900 · 48 · 0.5    ζ 1.14  already on screen; the trip is paid
                                            for, it only has to arrive
dropdown open     620 · 38 · 0.6    ζ 0.99  small and close: arrive, don't travel
toast surface     400 · 44 · 0.85   ζ 1.19  cards settle, never snap
progress fill     210 · 34 · 0.9    ζ 1.24  a meter must not spring past the
                                            number it is reporting
upload smooth     240 · 44 · 0.6    ζ 1.16  a spring over reported progress, so a
                                            lumpy transport reads smooth
carousel wall     700 · 30 · 0.5    ζ 0.80  the only underdamped spring in the
                                            set — an end is a wall, and a wall
                                            gives and comes back
```

Note the last one. Underdamped is not banned; it is *earned*, once, where the
overshoot is the information.

### The three jobs left for a CSS transition

A CSS transition on something being dragged will always look flatter than a spring:
one speed, no memory of where it was going. It survives only for discrete colour
changes on things nobody is dragging.

```
transition-colors 150ms                       hover and focus tint
transition-[border-color,box-shadow] 150ms    a field or button changing state
transition-[background-color] 200ms           a tone crossing a threshold
```

A field is the clearest case: nothing is dragged, the state changes discretely on
focus, and 150ms of colour is the whole move.

---

## 2 · Entrances and exits

> **Scope first: an entrance only belongs on content that arrives after first paint.**
>
> These values assume the element mounts on the client. On a prerendered or
> server-rendered page (SSG, SSR, islands, `@defer`), above-the-fold content is
> **already in the DOM at first paint** — that is usually the whole point, and it is
> how a page gets no loading mask and no CLS. Attaching an entrance to it either does
> nothing or, worse, replays the entrance at hydration: the user sees finished
> content, then watches it fade in again. That destroys exactly the property the
> prerender was bought for.
>
> ```
> prerendered, above the fold   NO entrance. It is already there. Let it be there.
> arrives after hydration       entrance applies: deferred blocks, async panels,
>                               route transitions, anything fetched
> ```
>
> Where a component can be either, the entrance must be **opt-in from the parent that
> knows which case it is** — never a default baked into the component. The child
> cannot tell whether it was prerendered.

```
enter    0.22s  { opacity: 0, scale: 0.97, y: 10, filter: blur(6px) }
exit     0.18s  { opacity: 0, scale: 0.98, y: 6,  filter: blur(3px) }
list     0.34s  y + scale, transform-origin pinned to the edge it came from
disclose 0.28s  height 0 → auto, opacity trailing at 0.18s
select   0.20s  content slides 3px
press    0.12s  translateY(1px)
```

- **Scale never starts at 0.** It starts at 0.9 or 0.97 — nothing in the physical
  world begins as a point.
- **`transform-origin` is pinned to the edge the thing came from.** A dropdown under
  a button grows from its top edge, not its centre.
- **More blur on the way in than on the way out.** That asymmetry is what makes a
  panel feel like it *settles* rather than *appears*.
- **Height and opacity get separate durations when disclosing.** Opacity finishing
  first hides the reflow.
- **The exit path matters as much as the timing.** A toast leaves *downward, out of
  the deck's band*, so the card behind it arrives into empty space rather than
  through a ghost. Its opacity beats its transform (0.11s vs 0.15s) so there is no
  smear to arrive through.

### Staggering, capped

A stagger that scales with the data eventually becomes a wait.

```
four bars           i * 0.03            small n, no cap needed
n sparks            hash-derived 0–0.05 deterministic, never Math.random
text reveal         min(stagger, span / (n-1))  compressed to fit maxDuration
```

The general rule: the caller asks for a per-unit stagger, the component silently
compresses it so the total never exceeds a ceiling (~1.6s). A hundred-word paragraph
reveals in the same time a ten-word one does.

Page-level entrances stagger by block — header 0, preview +0.07, body +0.14, each
0.34s — because a page that appears fully formed after a refresh reads as a document
rather than an application.

**Deterministic variation only — and under SSR or SSG this is mandatory, not a
preference.** If a cell needs to look random, hash its index:

```js
const h = (((i + 1) * 2654435761) % 997) / 997;   // Knuth, for a 0–1 offset
WIDTHS[(i * 7 + 3) % WIDTHS.length];              // a prime step, for a set
```

`Math.random` in a render makes the server and the client disagree about the markup,
which is a hydration mismatch — not a cosmetic difference. Anything prerendered that
looks random must be a pure function of its position.

---

## 3 · Physics beats taste

Springs are for things that move because a person intended them to: a panel arriving,
a row being picked, a sheet following a thumb. Those start and stop under intent, so
they ease.

Something that models a physical process obeys **that process** instead.

The ripple, fully specified, because it is worth getting right once:

```
radius     distance from the contact point to the FURTHEST corner of the box
shape      a real circle — a scaled rounded rect grows its own radius and turns
           into a shapeless blob
expansion  0.5s LINEAR, from scale 0 at the contact point
opacity    in over 0.07s linear while it grows; out over its own duration with
           the ARRIVE curve, once the press is released
tint       ink at 15% on light, white at 20% on dark
held       stays at full reach while the finger is down, fades on release
minimum    visible ≥220ms before it may begin to fade, so a fast tap still
           produces a wave you can see
```

The same reasoning produces every other `linear`: a spinner turns at one rate because
it is reporting an unknown; a marquee moves at one rate because it is a belt; a retry
countdown drains at one rate because seconds are one rate; a hold sweep fills at one
rate because that is the contract the button made with the finger.

---

## 4 · The three ways to make it laggy

In the order of how long each takes to find:

1. **Setting framework state during an animation.** An `onAnimationStart` that flips
   a `will-change` flag re-renders the subtree mid-flight and drops frames. Set the
   hint statically or not at all.
2. **Animating `mask-image`.** A mask is repainted every frame and cannot be
   composited. To fade an edge in and out, animate the **opacity of a gradient
   overlay** instead — that runs entirely on the compositor. Corollary, not
   exception: a mask is fine where it never animates.
3. **Animating layout properties when a transform would do.** A row leaving a list
   should exit on `opacity` and `x` and let its siblings close the gap with a
   position-only layout animation. Animating its `height` to zero relayouts the whole
   list every frame.

### Write the DOM directly when a value changes every frame

The framework should not re-render at 60fps. Name the channel each value travels
through, and give each channel its own cadence:

```
live geometry     container.style.setProperty("--split", "42%")   read by the grid template
live readout      node.textContent = "42%"                        via an onStep callback
reported value    el.setAttribute("aria-valuenow", "42")          imperative
committed value   setState(42)                                    ONLY when the drag ends
```

Three channels, three cadences, one render. A scroll-driven component can go further:
derive every value from the scroll position with a transform, and the framework
renders once, at the threshold.

---

## 5 · Quantisation is a render budget, not a look

Progress that comes from a gesture is reported in **discrete steps**, never as a
float. A 550ms hold drawn in twelve cells costs twelve renders instead of thirty-three
— and it is the honest shape for a countdown anyway.

```
long press          12 steps over 550ms
hold to confirm     20 steps over 1800ms
reading progress    24 steps
zoom readout         8 steps
swipe commitment     6 steps
```

The identity check is the whole saving. It appears in every one of them:

```js
setStep(prev => prev === s ? prev : s);
```

The rAF runs at 60fps; the component renders `steps` times. Leaving that line out is
how a hold-to-confirm costs 108 renders.

**Where both are needed, run them together.** Hold-to-confirm draws twenty discrete
cells for the count you can abandon *and* a continuous clip-path sweep for the
surface filling underneath. The cells are the information; the sweep is the material.
Quantising the sweep would make the fill stutter; not quantising the cells would cost
thirty renders to say the same thing.

If a quantity can be split into units, draw the units. A bar is for a continuous
quantity you cannot count.

---

## 6 · Reduced motion

`prefers-reduced-motion` is checked in every component that moves. The pattern is one
constant and one ternary:

```js
const INSTANT = { duration: 0 };
const move = reduced ? INSTANT : CELL;
```

**`duration: 0`, not "remove the animation"** — the element must still end up in the
right place. Invariant 3: the information arrives, the trip is skipped.

Four refinements:

- **Suppress the mount animation, don't delete it.** `initial={false}` (or your
  framework's equivalent) where a mount would otherwise animate in.
- **Shared-layout animations must be switched off, not zeroed.** They cannot be given
  `duration: 0`; pass `undefined` for the shared id under reduced motion.
- **Change behaviour, not just timing.** `scrollTo` goes from `smooth` to `auto`. A
  streaming text effect jumps straight to done and shows the whole string. A marquee
  stops looping entirely and becomes a real scroll container — and *gains a tab stop*,
  because the overflow is now the only route to the rest of the content.
- **A scroll-driven component needs no branch at all**, because every value resolves
  on the frame it is scrolled to. There is no trip to skip. Say so in a comment, so
  the next reader knows it is not an oversight.

---

## 7 · Shared-layout animation: three options, and when to use none

```
layout               a box whose size changes and must not be animated by
                     width/height        →  a tab indicator
layout="position"    a list where siblings close a gap
                     →  filter grids, tag inputs, upload lists
layoutId             ONE element that travels between mount points
                     →  a thumb moving between chips, a tooltip seat
NEITHER              an always-mounted element moved on `y`
                     →  a dropdown highlight
```

The dropdown is the instructive case *against* shared layout. Drawing a highlight per
row and crossfading kills the travel; sharing it by id makes it fly in from wherever
it last was when the list opens. So it does neither: **one span, always mounted,
animated on `y` by `activeIndex * rowHeight`, fading only when nothing is active.**
Row height is a constant, so nothing has to be measured.

Three traps that come with an auto-animating box:

- The engine counter-scales the radius only for properties **it owns**, and it does
  not parse the four-value shorthand. Write each corner individually or they smear on
  every move.
- The engine counter-scales a child that also animates. A hairline must live on such
  a child — a border drawn on the stretching box itself is not radius-corrected.
- No `overflow-x: auto` on the row. It clips in both axes, and the indicator has to
  hang 1px past the bottom edge to cover the hairline. That overhang is the entire
  join between the tab and the panel.

---

## 8 · Velocity is handed over, never dropped

A gesture that ends and then starts an animation from zero velocity is the single most
common way to make a drag feel cheap.

**This applies to gestures that commit to a destination** — a drawer that opens or
closes, a carousel that lands on a slide, a card that is kept or discarded. A gesture
that merely *positions* something has nowhere to be thrown to: a zoomable image pans
under the finger and springs back inside its bounds on release, with no velocity term
at all. Do not add momentum to a gesture that has no commitment to make; it reads as
the surface sliding away from you.

Where it does apply, pass the pointer's velocity into the spring that takes over:

```js
glide(to, velocity)  →  animate(x, to, { ...SPRING, velocity })
```

The thresholds are the second half of the same idea — a flick should commit even when
the finger never travelled far enough:

```
drawer      offset > width · 0.38   OR  speed > 520
carousel    projected = at − (v · 0.14) / step, capped at ±1 slide
swipe deck  |dx| ≥ 92               OR  |v| ≥ 520 and |dx| ≥ 32
toast       |dx| > 72               OR  |v| > 460 and |dx| > 20
```

**Momentum decides *whether* you move, not *how far*.** The ±1 cap is what keeps a
hard flick from skipping four slides.
