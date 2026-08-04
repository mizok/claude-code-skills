---
name: micro-interactions
description: Use when building, animating, or reviewing any interactive UI — buttons, fields, modals, drawers, toasts, tabs, dropdowns, carousels, drag/swipe/hold gestures, loading and async states — or whenever a component moves, appears, disappears, or reports progress. Enforces the last twenty percent: zero layout shift, interruptible motion, the right spring for the distance, the full gesture-abandonment surface, keyboard parity, screen-reader announcements, and reduced-motion behaviour. Framework-agnostic.
---

# Micro-Interactions

## Overview

Everybody builds these components. Almost nobody finishes them. They are not hard,
which is exactly the problem: every team writes them, no team is given a week to
write them, so they ship at eighty percent and stay there for the life of the
product.

The missing twenty percent is always the same three things:

1. **A jump** — the box resizes when its state changes and shoves everything nearby.
2. **A restart** — a second click mid-animation queues or restarts instead of resuming.
3. **An animation that ignores the person watching it** — no reduced-motion path, no
   keyboard path, no announcement.

Trust is won in the half-second after a click and lost in exactly the same place.
Every rule in this skill exists to protect that half-second.

Distilled from [interior.dev](https://www.interior.dev/)'s design language
([ddoemonn/interior](https://github.com/ddoemonn/interior), MIT). The reference
implementation is React + `motion`; everything here is stated as a rule first and
illustrated in that stack second. Ports to Angular Animations, Web Animations API,
CSS transitions, SwiftUI, Compose.

---

## The seven invariants

Any component that moves must satisfy all seven. This is the gate — if you cannot
name how a component meets each one, it is not finished.

1. **Zero layout shift.** Every reachable state reserves its space up front.
2. **Interruptible.** The animation resumes from where the element *currently is*,
   not from the start. Springs do this natively; a fixed-duration tween restarted
   mid-flight does not.
3. **Reduced motion delivers the information.** The trip is skipped, the destination
   is not. Never hide the element under `prefers-reduced-motion`.
4. **Full keyboard and ARIA.** Keyboard is a second complete implementation, not a
   fallback. Screen readers get the final value once, not sixty updates a second.
5. **Minimum dependencies.** Styling is overridable from outside; behaviour and
   presentation are separable.
6. **Behaviour and markup are separable.** Ship the logic headless (a hook, a
   directive, a controller) and the styled component as one example of using it.
   The behaviour is finished; the style is theirs.
7. **Write the DOM directly when a value changes every frame.** No framework should
   re-render at 60fps to move a number.

---

## Before you write a line

Answer these five. They decide the implementation, not the styling.

| Question | What it decides |
|---|---|
| **What is the widest / tallest state this box can ever reach?** | The reserved dimensions. See `references/craft.md` §1. |
| **How far does the thing travel, in pixels?** | The spring. >200px → soft; 20–200px → default; <20px → tight. See below. |
| **Is this content already in the DOM at first paint?** | Whether it gets an entrance **at all**. Prerendered content must not animate in. See `references/motion.md` §2. |
| **Can this be abandoned mid-gesture?** | The listener set. Every abandonment path is a real path. See `references/craft.md` §4. |
| **What does a person hear who cannot see it?** | The live region, the hint, the debounce. See `references/craft.md` §6. |

---

## Motion: the two decisions you make every time

### 1 · Which curve

Two curves, and only two. Everything arriving decelerates; everything leaving
accelerates away.

```
ARRIVE   cubic-bezier(0.23, 1, 0.32, 1)    starts fast, lands soft
LEAVE    cubic-bezier(0.4,  0, 1,    1)    starts slow, accelerates out of frame
```

**A departure is always shorter than an arrival.** Enter 0.20–0.28s against exit
0.11–0.18s. This is not taste: an exit that takes as long as an entrance means the
thing replacing it either waits (reads as lag) or crossfades through it (reads as a
smear).

### 2 · Which spring — the distance chooses it

```
travel > 200px      stiffness 150,  damping 27,  mass 1     ζ 1.10   drawer, sheet, card flying home
travel 20–200px     stiffness 520,  damping 34,  mass 0.45  ζ 1.11   row taking its slot, thumb sliding, cell lighting
travel < 20px       stiffness 700,  damping 46,  mass 0.5   ζ 1.23   label lifting, caret rotating, chip settling
opacity / face swap stiffness 260,  damping 34,  mass 0.8   ζ 1.18   crossfade, replacing all content
```

ζ is the damping ratio, `c / 2√(km)`. Under 1 overshoots, at 1 is critical, over 1
crawls in. **Almost everything should be slightly over 1** — alive, but it does not
bounce. Stiffness rises as distance falls; mass falls the same way.

Reusing a surface spring on a small element is the most common tuning bug. A soft
spring reaches the target fast and then *crawls* the last few pixels. Nobody sees
the crawl and thinks "underdamped"; they think slow.

**No spring solver?** (CSS transitions, Web Animations API, Angular Animations.) An
overdamped spring *is* a decelerating curve with a settle time, so use the `ARRIVE`
curve at the equivalent duration — 180ms for the 20–200px row, 170ms for the <20px
move. `references/motion.md` §1 carries the full equivalence table keyed by the same
names, plus the formula to re-derive a duration for any spring. The overshoot is what
you lose; the timing and the ordering are what matter.

**The k/c/m numbers do not port across engines.** What ports is the damping ratio, the
ordering, and the settle time. Re-derive; do not copy.

### When a spring is wrong

Anything that models a **physical process** obeys that process instead of taste.
A wave travels at constant speed, so a ripple expands **linearly**, not eased. Easing
it makes it read as a growing shape rather than a spreading wave.

Linear is correct for: a spinner (reporting an unknown at a constant rate), a marquee
(it is a belt), a countdown drain (seconds are one rate), a hold-to-confirm sweep
(that is the promise the button made to the finger).

Fixed-duration tweens stay only where the **timing itself is the information**: a
count-up has to land when it says it will, a page entrance should not vary.

Full motion detail — the spring catalogue, the entrance/exit values, velocity
handover, the three ways to make it laggy, quantisation, reduced motion:
**`references/motion.md`**.

---

## Review checklist

Run this against any component that moves, yours or someone else's. Each failure
maps to a section.

- [ ] Click it twice, fast. Does the second click resume or restart? → motion §1
- [ ] Trigger the longest state (longest label, biggest number, error message).
      Did anything else on the page move? → craft §1
- [ ] Start a drag/hold, then Alt-Tab away. Is it stuck? → craft §4
- [ ] Unplug the mouse. Can you reach and operate it? Does it announce what
      happened, once, in a sentence? → craft §5, §6
- [ ] Turn on Reduce Motion. Does the information still arrive, or did the element
      vanish / stop working? → motion §6
- [ ] On a prerendered page: hard-reload and watch the first paint. Does anything
      above the fold fade in *again* after hydration? → motion §2
- [ ] Open two overlays. Does one Escape close one, or three? → craft §3
- [ ] Watch it under a slow network. Does a skeleton strobe? Does an empty state
      flash before the data lands? → craft §7
- [ ] Profile a gesture. Is anything re-rendering at 60fps? Is any layout property
      animating where a transform would do? → motion §4, §5

---

## References

Load the one you need; do not load all three.

| File | Covers |
|---|---|
| `references/motion.md` | Spring catalogue with damping ratios **and springless CSS/WAAPI equivalents** · when an entrance is wrong (prerendered / hydrated content) · entrance/exit values · physics-driven linear motion · velocity handover and flick thresholds · the three causes of jank · quantisation as a render budget · shared-layout animation · reduced motion |
| `references/craft.md` | Reserving space (the invisible twin) · state without `disabled` · overlays (portal, refcounted scroll lock, inert, escape stack, focus return) · the gesture abandonment surface · focus, three shapes · announcements (late, once, outcome) · async (grace, minimum, settle, rollback) · scroll containers · measurement |
| `references/visual-language.md` | Depth as material, not borders · nested radii arithmetic · the anti-generic bans and when a ban yields · the input standard · colour semantics (accent means "the system is responding to you") · type scale · discrete cells |

## Working rules

- **Research before inventing.** A ripple, a spinner, a slider detent, a scroll lock
  — these are solved, published and measured. Invent the parts nobody has solved;
  look up the parts everyone has.
- **Never sell the animation. Describe the problem it removes.** If you cannot name
  the problem, the animation is decoration and should be cut.
- **A ban yields when the banned thing is genuinely the right answer and you can say
  why in one sentence.** The moment a ban becomes a formula it has failed in a new
  costume.
- **Demos are replayable.** A micro-interaction you can only watch once is a
  screenshot with extra steps.
- **Do not copy the source's constant duplication.** The reference set declares its
  easing curves and springs separately in every single file, because each file must
  survive being copied alone into someone else's codebase. That is the price of
  copy-paste distribution, and it has already cost it drift: one spring exists at four
  slightly different stiffnesses and one curve under four different names. **If you
  have a token layer or a theme, put the curves and springs in it once.** Take the
  values from here; do not take the distribution model.
