# Craft

Everything that is not the animation curve: space, state, overlays, gestures, focus,
announcements, async and measurement.

---

## 1 · Reserving space — the invisible twin

Invariant 1 says every reachable state reserves its space up front. In practice this is
**the** reservation primitive — not one option among several. Reach for it first and
fall back to a fixed box only when the widest state is not renderable.

Put an invisible copy of the **widest state the box can ever hold** in the same grid
cell as the live content. It sizes the column once; the live content is drawn over it.

```html
<span class="grid">
  <span aria-hidden class="invisible col-start-1 row-start-1">Saving…</span>
  <span class="col-start-1 row-start-1">Save</span>
</span>
```

What it reserves against varies:

```
width, longest label     "Upload" / "Uploading…" / "Retry"
width, longest number    a counter that will reach 3 digits
width, longest string    "12 min left" at its maximum
FONT WEIGHT              an invisible *medium* twin under a regular label, so
                         going bold on selection cannot reflow the column
PROGRESSIVE TEXT         the whole string, invisible, with the revealed slice
                         drawn over it — so a paragraph that types itself out
                         never reflows the page as it grows
```

The progressive-text case is the same idea at its most useful. A streaming or
revealing text effect that grows its own box relayouts everything below it on every
tick; laying the finished string underneath at zero opacity fixes the box on the first
frame and the reveal happens inside it.

The weight case is the subtle one. A row whose label goes from regular to medium when
selected gets **wider**. In a vertical rail that means the whole column reflows as you
scroll.

Where a twin is overkill, a fixed box does the same job:

```
error line       height = reservedLines * 16    the error's space, always
floating label   padding-top on the wrapper     the raised label's destination
hint row         a fixed 16px row               hint, counter and error share it
status row       a fixed 16px row               hint / error / success
button row       a fixed 36px row               back and advance
mark cell        a fixed 14px box               the arrow that may or may not land
```

**The general form: find the tallest and widest state the component can reach, give
the box those dimensions permanently, and animate opacity inside it.**

Related: **a button keeps its width when its state changes.** Both labels live in the
same cell; only opacity moves.

---

## 2 · State without `disabled`

`disabled` is a last resort. A disabled control is a dead thing you can still see and
cannot ask about: it leaves a hole in the tab order, drops out of the accessibility
tree, and gets repainted in the UA's grey — the one colour you do not control.

Four replacements, in order of preference:

**Let it leave.** If a control has genuinely nothing left to do, remove it. No Back
button on the first step; no Finish button once the flow is complete. *A permanently
dead control is worse than an empty slot*, and *a Finish that stays pressable is a
Finish that never finished anything.* Animate it out, and back in when it means
something again.

**Let it go invisible but keep its cell.** `opacity: 0` plus `inert`. The control is
gone to the eye, gone to the keyboard, and still occupying its grid column — so the
row never moves. This is the right answer when the layout around it must not shift.

**Make it not a control.** A step you have not reached renders as a `<span>` with an
`sr-only` label, not a disabled `<button>`. *A step you have not reached is not a
broken button; it is not a button.*

**`aria-disabled`, and refuse the click yourself.** The control stays reachable and
announced, the handler returns early, and you keep your own colours.

The one legitimate use of the real attribute: a control whose *whole component* is
switched off from outside, where `disabled:opacity-50` is the entire story.

---

## 3 · Overlays: portal, lock, inert, stack

Four things happen when a surface covers the page. All four are required.

**Portal into the document body.** `position: fixed` is enough right up until an
ancestor grows a `transform`, a `filter` or a `will-change` — at which point the
overlay silently becomes a child of *that* box instead of the page, and that ancestor
is rarely yours. Resolve the host in an effect and render nothing until then, so the
server and the first client render agree.

**Scroll lock, with the gutter paid back.** Hiding the scrollbar narrows the viewport
and shifts the whole page left.

```js
const gap = window.innerWidth - document.documentElement.clientWidth;
body.style.overflow = "hidden";
if (gap > 0) body.style.paddingRight = `${base + gap}px`;
```

Read the computed `padding-right` first and **add** the gutter to it, rather than
overwriting a padding the app already had. And **refcount the lock**: a module-level
counter with a single release function, so two stacked dialogs do not each restore a
stale `overflow` on the way out.

**`inert` to mute everything else.** Different scopes, one attribute:

```
drawer      every body child that does not contain the drawer
modal       every sibling of the overlay in its portal parent
carousel    every slide that is not the current one
card deck   every card that is not the top one
```

Record the previous value and restore it on cleanup. Setting `inert` and removing it
unconditionally is how you break a page that was already using it.

**A stack, so Escape means one thing.** Keep a module-level array; each open surface
pushes a token, and the keydown handler returns unless its own token is on top.
Without it, one Escape closes three dialogs.

Where a single component has two Escape meanings, a **native listener on the shell
runs before the framework handler on the inner frame** — which is what lets Escape
mean "come home" while zoomed and "close" only once the image is back.

**Focus goes in and comes back.** Record `document.activeElement` on open, restore on
close, guarded by `isConnected` because the opener may have unmounted. The trap is the
same fifteen lines everywhere: collect the focusable set, wrap at both ends, and if
the panel contains nothing focusable, focus the panel itself. Belt and braces: also
listen on `focusin` and pull focus back if it ever escapes.

---

## 4 · Gestures: the whole abandonment surface

A gesture that only ends on `pointerup` is a gesture that gets stuck. Every
pointer-driven component listens for the full set of ways a press can stop being a
press:

```
pointerup                 the normal ending
pointercancel             the OS took the pointer (a system gesture, a call)
lostpointercapture        capture was stolen — treat as cancel, not as a drop
pointerleave              the finger left the target        (holds only)
window "blur"             the user alt-tabbed mid-press
document visibilitychange the tab went to the background
keydown Escape            the deliberate abort
blur                      keyboard-initiated press, focus moved away
move tolerance            the finger drifted: 8px for a long-press, 10px for a hold
```

**The rule: if a component can be mid-gesture, it registers a window `blur` listener.**
That single line is the difference between a component that recovers and one that
needs a reload.

Two more that are easy to miss:

- **`setPointerCapture` on the element you started on**, so a drag survives the pointer
  leaving the box. Paired with `lostpointercapture` treated as a **cancel**.
- **`touch-action`, chosen by the axis you own.** `manipulation` on a button (kills the
  300ms delay, keeps scrolling); `pan-y` on a horizontal drag (the page still scrolls
  vertically); `none` on a two-dimensional gesture where you own both axes.

---

## 5 · Focus and keyboard

### Keyboard is a second complete implementation

Every gesture has one. Not a tab stop — an equivalent:

```
resizable split   arrows step, Shift+arrow fine, Home/End limits, Enter parks
slider w/ detents arrows step, Shift/PageUp/PageDown jump detent to detent
card deck         ←→ decide, Backspace undoes
zoomable image    +/− zoom, arrows pan, 0 returns home
carousel          ←→ move, Home/End to the ends
```

Every one of them announces what it did — see §6.

### Focus, three shapes

One focus colour, three shapes, chosen by **geometry, not taste**.

**Inset** — a row, cell, item or region inside a container. The mark cannot leave the
container's clipping box, so it is drawn inward: a tinted background at ~6% plus
`box-shadow: inset 0 0 0 1px <accent>`.

**Border plus lift** — a standalone button with room around it. The border goes accent
and the shadow gains an accent-tinted glow, which reads as the button coming further
forward:

```
box-shadow: 0 1px 2px rgba(28,25,23,0.08),
            0 10px 20px -14px rgba(69,104,255,0.6);
```

**Outside** — an element that fills its own frame, where an inset line would be painted
over by its own content: a 1–1.5px outer ring.

Two structural notes that recur:

- **When something slides underneath, draw focus as a sibling above it.** An indicator
  child at `inset: 0` paints straight over a shadow set on the parent; use a
  pseudo-element instead. Anything with a travelling marker has this problem.
- **Draw the focus edge after the fill.** With roving tabindex, focus lands on the
  *selected* item — and an edge painted underneath a filled thumb is invisible exactly
  when it is needed.

**No focus rings on top of a focus border.** A 2px border plus the surface lifting is
already two signals; a ring on top is the "too much" everyone feels but few name. If
there is a global `:focus-visible` outline, put it in a base layer so a component that
draws its own focus can opt out.

---

## 6 · Announcements

A live region that fires on every state change is worse than none: it turns a drag
into a hundred interruptions. Three rules.

**Announce late.** Anything driven by a stream of small events waits for the stream to
stop. The delay is a timeout whose cleanup cancels the previous one, so only the final
value is ever spoken:

```
scroll spy           420ms   the section you settled in
search               500ms   the result count
new-items pill       700ms   how many arrived
password strength    700ms   the verdict
typing indicator     700ms   who is typing
value flash          700ms   the number that stayed
presence avatars     900ms   four people joining at once is one sentence
```

**500ms is the default; deviate only with a reason.** It is the value repeated verbatim
across most of the set. Go shorter (420ms) when the stream stops crisply and the user
is waiting on the answer; go longer (700–900ms) when several events can legitimately
arrive together and you want them collapsed into one sentence rather than three.

**Announce once.** Key a `Set` on `${id}:${status}` — one announcement per message, and
one more when it resolves. Clear the set past a bound so a long session cannot leak.

**Announce the outcome, not the mechanism.** The sr-only text is a sentence, not a
value:

```
"Sorted by Revenue, descending. 24 rows."
"design removed, 4 left."
```

**The hint** is the counterpart: a permanent `sr-only` element wired through
`aria-describedby`, read once when the control is focused, that teaches the keyboard
model. It reads like an instruction, not a description:

> *"Drag to resize, or move the divider with the arrow keys. Home and End go to the
> limits, and Escape cancels a drag in progress."*

`role="status"` with no `aria-live` is the same thing at lower volume, and is correct
where the value is polled rather than pushed — report the **settled** zoom, not the
live one.

---

## 7 · Async: grace, minimum, settle, rollback

Four timing patterns, each solving a different flavour of flicker.

**Grace — before you claim nothing is there.** Wait ~220ms after a count hits zero
before saying "empty", because a list that is one frame from arriving should not flash
an empty state. Until then the status is `waiting`, which draws **nothing at all**.

**A minimum — so a fast response does not strobe.** Wait 120ms before showing a
skeleton, *and* keep it up for at least 380ms once shown. A 200ms request never sees a
skeleton; a 400ms one sees a complete one.

**The skeleton's box is sized by props, not by its content.** `height = reserve ??
lines * lineHeight`, set on the wrapper, with the content scrolling inside if it
overruns. The skeleton and the real content therefore occupy the same box by
construction — which is invariant 1 applied to the one place it is easiest to forget,
because at skeleton time you do not yet know how tall the content will be. Guessing
from the skeleton's own rows would make the box jump the moment real text arrives.

**The skeleton itself does not move.** No shimmer, no sweep, no pulse — a flat block
in the surface's own neutral, and the only animation in the whole component is the
opacity handover to the real content. This is a deliberate position, not an omission:
*the timing is what reassures, not the movement.* The 120ms grace means a fast request
never shows a skeleton at all, and the 380ms floor means a slow one shows a complete,
stable skeleton rather than a flash. Once those two are right, the shimmer has no job
left to do — it was only ever there to prove the page had not frozen.

If you ship a shimmer anyway, hold it to the same standard as any other loop (see
`visual-language.md` §3): it must be bound to a real in-flight operation, and you must
be able to say in one sentence what it tells the user that the timing does not. "The
skeleton looked dead" is not that sentence — that is a timing bug wearing a costume.

**A settle window — so a flurry becomes one commit.** The complete optimistic contract,
worth copying rather than approximating:

- every tap updates the UI immediately;
- a ~400ms timer restarts on each one;
- when it fires: if the intent now matches the truth, snap back and send **nothing**;
- otherwise abort the in-flight request, bump a sequence number, and send one;
- a response whose sequence is stale is discarded;
- a failure rolls **both** the count and the flag back to the last known truth.

**Backoff you can watch and interrupt.** Run the wait on rAF rather than a timer, so
the drain can be drawn in discrete steps with a "retrying in 3s" readout beside it.
`min(8000, 700 · 2^(n-1))`, and the retry control stays live during the wait.

Two more:

- **An automatic loader must be interruptible by inaction.** At most 3 consecutive
  automatic loads before it pauses and waits for a real click. Scrolling the sentinel
  out of view resets the count. An error blocks automatic loading entirely until a
  manual retry.
- **Per-item progress, never one global bar.** A concurrency-2 queue where each row
  owns its own `AbortController`, its own progress value and its own fill. Removing a
  row aborts it; unmounting aborts everything.

### Images are an async state too

Two details that look like animation polish and are actually correctness. Both are the
difference between a fade that helps and a fade that lies.

**A cached image must skip the fade entirely.** Check before you animate:

```js
const cached = img.complete && img.naturalWidth > 0;   // both, not just complete
```

`complete` alone is true for a failed load as well, which is why the natural width is
checked with it. A cached image that fades in is animating a transition that did not
happen — the user sees a delay you invented, on the fastest path you have.

**Reveal after decode, not after load.** `load` fires when the bytes have arrived, not
when the pixels are ready. Painting there means the browser decodes a full-size image
on the frame you asked it to appear, and that is a dropped frame you can see:

```js
if (typeof img.decode === "function") img.decode().then(reveal, fail);
else reveal();                                          // older browsers
```

Always keep the fallback path and a failure branch — `decode()` rejects on a broken
image, and a reveal that never fires is worse than an ugly one.

---

## 8 · Scroll containers

Six things every scroll box should agree on:

```
overflow-y: auto; overscroll-behavior: contain    never let a wheel escape to the page
scrollbar-gutter: stable                          reserve the track from the first paint
tabindex="0" + role="region" + aria-label         a scroller is keyboard-reachable
scroll-padding-top: barHeight + 8                 anchors land below a sticky bar
overflow-anchor: none                             where you manage position yourself
a spacer div, not padding                         content starting below an absolute bar
```

`scrollbar-gutter: stable` is conditional in both directions and both are correct:
reserve it only when the content can actually overflow (otherwise every short list pays
for a track it will never show), but reserve it in **both** states once content is
capped — expanding into a scrollbar moves every line left by its width.

The keyboard-reachability rule collides with a lint rule and is worth the suppression:
content that scrolls has to be reachable without a pointer, and the rule cannot see
that the box overflows.

**Scroll containers fade at both ends, never hard-cut.** Use a mask where it never
animates; use the opacity of a gradient overlay where it does (see motion §4).

The hard case, worth knowing: when new items arrive and the user is **not** pinned to
the bottom, restore the distance *from the bottom*, not the offset from the top. And on
a jump, **focus first, then scroll** — moving focus into a container that is already
mid-flight cancels the smooth scroll in WebKit, and the jump silently does nothing.

---

## 9 · Measurement

Nothing should read a layout value more than it has to, and nothing should re-render
because a number changed by half a pixel.

```js
// Always: a ResizeObserver, not a resize listener.
const observer = new ResizeObserver(read);
observer.observe(el);
return () => observer.disconnect();

// Always: an epsilon, so subpixel jitter cannot loop.
setBox(prev => Math.abs(prev.width - w) < 0.5 ? prev : { width: w });

// Always: a layout effect that is safe on the server, so the first paint is correct.
```

Without the epsilon, a fractional layout width feeds back into a state update that
changes the layout width, and the observer never settles.

**Prefer not measuring at all:**

```
dropdown highlight   ROW_H is a constant → no measurement
step rail            evenly spaced → the head travels on a percentage translate
segmented control    grid-template-columns: repeat(n, 1fr) → thumb x = i * 100%
carousel             one slide width, read once; everything else is arithmetic
```

**The test: can the position be derived from props and constants alone?** If yes, it is
arithmetic and you must not measure. If no, measure — but measure once and cache.

The same widget answers this both ways depending on its sizing, which is why it is a
test and not a preference. A **single sliding indicator** under a row of items is
arithmetic when the items are equal width (`x = i * slot`, from a grid template you
already control), and requires a real `offsetLeft` read when the items are sized by
their own content — because then only layout knows where item *i* starts. Equal-width
segmented controls and pagination take the first path; content-width tabs take the
second. Reaching for measurement on the equal-width case buys you a `ResizeObserver`,
an epsilon guard and a class of subpixel bugs, in exchange for a number you already
knew.

The trick worth stealing: an inverted label inside a moving thumb is **not** a second
copy positioned per option. It is the whole row of labels, drawn once inside the thumb
and **counter-translated** — `x: thumbX` on the thumb, `x: -thumbX` on the row inside
it. Two transforms, one truth, and the label inverts *through* the thumb rather than
crossfading with a duplicate.

Where a measurement is unavoidable and expensive, take it **once per gesture, not per
frame**: read every rect you need at pointer-down, cache it, then let the move handler
do pure arithmetic against the cache and write one transform.
