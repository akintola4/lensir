# Checks under a link

Decided 8 November 2026, from four versions flipped live on the phone with a
debug-only picker. Tope's note going in: "the checks section ui feels too
stiff". He picked Tally and left the motion numbers at their defaults.

## Direction: Tally

Every check is on the compact drawer at once, as chips that wrap.

- What's wrong comes first, as plain sentences with no icons. A clean link
  gets its one line instead: "Secure · the real paystack.com".
- Then one chip per check. Failed chips come first, in a light red fill with
  a red cross. Passed chips follow, in the raised grey with a green tick.
  Within each group the checks keep their usual order.
- Details no longer has a Checks list. Everything it said is already in
  compact.
- No extra haptics. The brackets' tap and the drawer's detent tick are
  enough.

## Numbers

- Chips arrive one after another: 45 ms apart.
- Each chip: a spring, 320 ms, bounce 0.12, from scale 0.94 at its leading
  edge and opacity 0.
- They start when the drawer is 85% of the way up to compact, so they land
  with it, not after it.
- Reduce Motion: no stagger, the chips are just there.
- Failed chip fill: #452A2A on dark, #FBE6E8 on light; #5A3030 and #F5D0D4
  with Increase Contrast.

These live in `CheckChips` (timing, order) and `Palette.failChip`.

## Chip labels

The cost of Tally is that a chip only has room for a word or two. Each label
says what passing means, so a tick reads as "yes" and a cross as "no":

| Check | Chip |
|---|---|
| A web address | Web address |
| Secure connection (https) | https |
| A named site, not a bare IP address | Named site |
| The real site, not a lookalike | Real site |
| Plain letters, no punycode or mixed alphabets | Plain letters |
| No "@" hiding the real site | No @ trick |
| Not a link shortener | Not shortened |
| A normal number of subdomains | Few subdomains |
| A name that doesn't look made up | Real-looking name |

The sentences above the chips explain every failure in full. VoiceOver reads
each chip as its whole check and the result: "Not a link shortener: failed".

## Rejected

- **Now** (as it shipped): one icon and one sentence per line, the same
  weight for everything, nothing moving. That was the stiffness. A failure
  and a pass looked alike apart from the icon, and Details repeated the list.
- **Settle**: the same lines on soft tinted discs, rising in one after another
  as the drawer landed, with Details rows following the pull and a tick per
  failed row. Too subtle: in a still frame it was hard to tell from Now. It
  also added haptics on top of the drawer's own tick.
- **Verdict**: a tinted card with a bold "3 things are wrong" over the
  reasons, which opened Details with a pass/fail meter. It made the tallest
  compact drawer, and the red card was loud even for one minor problem (a
  plain http link). Seeing the checks took a second tap.
