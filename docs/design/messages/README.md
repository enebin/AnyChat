# Messages design source

The visual source for every screen is the iOS 26 Messages UI kit (Messages.sketch, changelog 26.1, with
symbols from the Apple iOS 26 UI Kit library), rebuilt as a design canvas. The boards' sources are in `boards/`; they render on that canvas, not as standalone pages. The kit file itself is Apple's and is not kept here.

Local source: `/Users/kai.lee/Downloads/Messages.sketch`.

Read values from the tables below. When this file and a board disagree, this file wins.

Frames below are on a 402 × 874pt screen (iPhone 17 Pro). The kit has no reply parts; the
"Replies" section is new and built from kit values.

## Color

| Role | Light | Dark |
|---|---|---|
| Background | `#FFFFFF` | `#000000` |
| Label | `#000000` | `#FFFFFF` |
| Secondary label | `rgba(60,60,67,0.6)` | `rgba(235,235,245,0.6)` |
| Tertiary label (chevrons) | `rgba(60,60,67,0.3)` | `rgba(235,235,245,0.3)` |
| Placeholder | `rgba(60,60,67,0.4)` | `rgba(235,235,245,0.4)` |
| Outgoing bubble | `#0088FF`, text `#FFFFFF` | same |
| Incoming bubble | `#E9E9EA`, text `#000000` | `#262629`, text `#FFFFFF` |
| Unread dot | `#0088FF` | same |
| Text cursor | `#0091FF` | same |
| List row separator | 1pt line `rgba(0,0,0,0.12)` | — |
| Glass (buttons, field, name capsule) | white 40% over `#FAFAFA`, hairline and soft shadow | kit dark symbol |

## Type (SF Pro)

| Use | Style |
|---|---|
| Large title | Bold 34 / 41 |
| Bubble text | Regular 17 / 22 |
| List name | Semibold 17 / 22 |
| List preview | Regular 15 / 20, two lines, secondary |
| List time | Regular 14 / 20, secondary; chevron Semibold 13, tertiary, 12pt after the time |
| Chat header name | Bold 16 / 21 |
| Field text and placeholder | Regular 16 / 19 |
| Sender name | Regular 11 / 13, secondary, inset 12 |
| Timestamp | Day Semibold 11 + time Regular 11 / 13, secondary, centered |

## Layout

| Part | Value |
|---|---|
| List top bar | y 62, height 105; 44pt glass buttons at x 16 and x 342; large title at x 16, y 116 |
| List row | height 79; unread dot 10pt at x 8, y 33.5; avatar 45pt at x 26, y 16; text from x 83 to 16 from the right; name at y 8, preview at y 30; separator from x 83 |
| List bottom bar | y 794, height 56; search field 286 × 48 at x 28 (radius 24); 48pt button at x 326 |
| Chat top bar | height 137; back and call buttons 44pt at y 54, insets 16; avatar 56pt centered at y 55; name capsule 30pt high, radius 15, padding 15, overlapping the avatar by 4 |
| Transcript | side insets 16; bubble max width 240; gap 8 between bubbles of one sender, 14 between senders; timestamp 10 above and below |
| Bubble | radius 20; padding 9 vertical, 14 horizontal; tail (25 × 12) only on the last bubble of a run |
| Composer, keyboard down | bar height 70; + button 44pt at x 28; field 290 × 43 at x 84, radius 21.5, text inset 16; mic glyph at the field's trailing edge |
| Composer, keyboard up | bar height 60; + button 44pt at x 16; field 314 × 43 at x 72; blue cursor 2 × 19 |
| Glass button | 44 × 44 circle, 36pt inner symbol |
| Jump to latest (new) | the glass button (44pt circle, the composer field's glass) with SF Symbol `arrow.down` in the composer's font and button tint, centered 8 above the composer and the reply bar; shown while the newest content is more than 100 below the visible bottom; fades and scales from 50% over 0.25s |
| Stop button (new) | SF Symbol `stop.circle.fill` in the send button's place and size (32pt target, 24pt glyph), send's tint; shown while the host reports a response in progress |

## Replies (new)

| Part | Value |
|---|---|
| "Replied to" line | sender-name style (11 / 13, secondary), inset 12, on the bubble's side. Mine: "You replied to Name", "You replied to yourself", "You replied" (original unavailable). Others': "Replied to you", "Replied to Name", "Replied"; the sender name above the quote already says who replied |
| Quote | radius 18; padding 7 vertical, 12 horizontal; 1pt border `rgba(60,60,67,0.29)` (dark `rgba(84,84,88,0.65)`); no fill, no tail; max width 240 |
| Quote text | Regular 15 / 20, `rgba(60,60,67,0.78)` (dark `rgba(235,235,245,0.78)`), two lines at most |
| Quote of media | first image 56 × 56, radius 12 |
| Quote, original unavailable | "Original message unavailable", dashed border, secondary text |
| Spacing | line, quote, and bubble 4 apart; a reply starts a new run, so it sits the gap between runs below the previous message |
| Reply bar | glass capsule, height 52, radius 26; side insets match the composer's (16 with the keyboard up, 28 down); 8 above the composer row; leading inset 16 |
| Reply bar text | "Replying to Name" ("Replying to yourself" for the user's own message) Semibold 13 / 18, label color; preview Regular 15 / 20, one line, quote text color |
| Reply bar close | 30pt circle `rgba(120,120,128,0.16)` (dark 0.36) with a 10pt xmark, in a 44pt target |

| Swipe to reply | the row's content follows the finger toward the trailing edge, one to one up to 60pt, then at a third of the finger's travel, up to 90pt |
| Swipe threshold | 60pt; crossing it plays one light haptic, going back under it cancels, releasing past it starts the reply; the row springs back either way |
| Swipe icon | SF Symbol `arrowshape.turn.up.left`, 15pt semibold, secondary label color, centered in a 32pt circle with the reply bar's close fill, 16pt in from the row's leading edge (32pt from the screen, as rows sit inside the 16pt transcript inset) and drawn behind the moving content, vertically centered on the row; it fades and grows from 50% to full size as the row reaches the threshold |

The quote text uses 78% instead of the kit's 60% secondary label because 60% fails 4.5:1 contrast on white.

## Long-press overlay (new)

The kit has no overlay. These values were measured from the iOS 26 system context menu on the simulator (iPhone 17 Pro, 402 × 874, light and dark).

| Part | Value |
|---|---|
| Dim | `rgba(0,0,25,0.16)` in light and dark (white becomes `#D7D7DA`); no blur; covers the list and the composer, not the navigation bar |
| Lift | the bubble scales by 1.12 from its top sender-side corner |
| Card | glass surface, 249 wide, radius 34; rows 52 high; side inset 16 |
| Spacing | card 22 below the bubble; the above view 22 above it |
| Motion | SwiftUI default animation in and out; the swipe's light impact on open |

## Group avatars

The group avatar uses a circular backdrop and separate circular member pictures, rather than
cropping pictures into tiles. One member fills the existing avatar; no members uses its placeholder.
Existing list (45pt) and header (56pt) sizes remain unchanged. All coordinates below are relative to
a 45 × 45pt avatar and scale uniformly with its size. Entries are painted in the listed order.

The two-member layout and backdrop fill come directly from the Light and Dark
`Chat/…/􀻃 Avatar/Group` symbols in Messages.sketch. The symbol's 18pt leading area holds the unread
indicator and is outside the avatar itself. Its 45pt `Frame` contains the member pictures.

| Part | Value |
|---|---|
| Backdrop | `rgba(116,116,128,0.08)`, light and dark |
| Two members | second: x 24.333, y 24.333, diameter 14.333; first: x 5, y 5, diameter 24.333 |
| Three members (new) | first: x 5, y 5, diameter 24.333; second: x 24, y 18, diameter 17; third: x 13, y 29, diameter 14 |
| Four members (new) | first: x 5, y 4, diameter 23; second: x 24, y 13, diameter 17; third: x 21, y 28, diameter 15; fourth: x 5, y 27, diameter 13 |

The three- and four-member layouts are new, approved for this change using the supplied iMessage
reference: a larger face at the upper left with smaller, overlapping faces around it. The first four
members retain their existing order. Missing pictures use the host theme's avatar placeholder
background and tint inside their own circles. Member circles have no additional border or shadow.
