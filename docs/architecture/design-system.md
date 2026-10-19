# DesignSystem

[ARCHITECTURE.md](../../ARCHITECTURE.md) 4절의 하위 문서다. `AnyChatDesignSystem` 타겟에 무엇을 두는지는 [ARCHITECTURE.md](../../ARCHITECTURE.md) 2절 "DesignSystem 에 무엇을 두는가" 가 정한다.

The default appearance follows Apple's system styles: blue outgoing bubbles, gray incoming bubbles, semantic labels and backgrounds, SF Symbols, and Dynamic Type text styles. The default layout follows Apple's iOS 26 Messages template. Layout measurements stay with their views.

Design references:

- [Color](https://developer.apple.com/design/human-interface-guidelines/color): use system color APIs, except where the Messages kit gives its own value (see the Colors row below).
- [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols): use the platform's symbols without bundling icon artwork.
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): use semantic system text styles that follow Dynamic Type.

## Tokens

- `ChatPalette` supplies semantic colors for light and dark appearances. The incoming bubble, accent, cursor, placeholder, reply quote text and border, and light list separator use the Messages kit's values ([docs/design/messages](../design/messages/README.md)); under Increase Contrast they fall back to the system color they stand in for, because the kit defines no stronger variant. The rest use UIKit system colors. Resolving a fixed appearance preserves the caller's other traits, including increased contrast. `adaptive(light:dark:)` chooses the matching appearance at render time. Text on a blue bubble or badge stays white in both appearances.
- `ChatTypography` supplies the text styles used by the screens: headline, body, button, caption, emphasized caption, and caption2. Themes continue to expose `Font` values for customization.
- `ChatIcon` maps the symbols used by the screens to SF Symbols available on iOS 18. No icon asset catalog or package resource bundle is required. Tests check that every symbol resolves on the supported simulator runtime.

### Icon sizes

`ChatIcon.sized(_:)` fits a symbol into the caller's existing layout size. Swipe action labels ignore SwiftUI frames, so `ChatIcon.redrawn(at:)` supplies a rasterized template image at the requested point size. Its cache is limited to these rendered symbol sizes.

## 원자

`Avatar` / `Badge` / `DividerLine` / `IconButton` / `Placeholder`. 색과 폰트를 파라미터로 받고 테마를 직접 읽지 않는다. 어떤 화면의 어떤 토큰을 쓸지는 호출하는 화면이 정한다. 표시 전용이라 테스트 대신 `#Preview` 를 둔다.

## 이미지

`RemoteImage` / `RemoteImageLoader` — URL 이미지 로딩. `AsyncImage` 는 뷰가 다시 만들어질 때 빈 단계로 되돌아가 스크롤 중 깜빡이므로 쓰지 않는다.

- The loader reads an image file or the first frame of a video. Both are decoded at no more than a maximum length on the longer side, so a full-resolution photo is never kept in memory. Each caller passes the length; the loader has no default, so screen sizes stay with the screens. `Avatar` asks for 168 pixels, its largest size of 56pt at 3x, for every size it draws, so a picture shown at several avatar sizes is decoded and cached once. The channel screen's media thumbnails ask for 720 pixels, the 240pt thumbnail at 3x, in single and grid layouts alike. An animated GIF decodes to its first frame.
- A load checks memory, then disk, then the network. The memory cache keeps decoded images up to 300 entries and 64 MB and evicts the least recently used first.
- The disk cache stores the downsampled result, not the downloaded bytes, under `Caches/AnyChatImages`. Files are named by a hash of the URL, the kind, and the maximum length, so an image and a video frame of the same URL, or an avatar and a thumbnail, do not collide. A picture shown after a relaunch therefore needs no download or full-size decode, and a video frame is not generated again. HTTP cache headers do not affect it, and a stored file never expires on its own. A URL is therefore treated as fixed content; adapters follow rule 14 of [backend-boundary.md](backend-boundary.md) "어댑터 규약".
- The disk cache is limited to 200 MB. When a write passes the limit, the least recently used files are removed until three quarters of the limit remain. A disk hit refreshes the file's modification date to mark it as used. The size count and the trim run after the picture is returned, one at a time, so a caller never waits for them. The system may also clear the folder under storage pressure; the loader then loads from the network again.
- HTTP responses other than 200 fail. `file:` URLs load without an HTTP response, so the demo app and tests run without a network.
- Loads in flight are shared by URL, kind, and maximum length. A view that disappears stops waiting, but the shared load finishes and fills the caches.

## Messages layout reference

Source: Apple's [Messages template](https://www.sketch.com/s/d6cd3d23-7aec-43d5-acb9-52f720ff48b7), linked from [Apple Design Resources](https://developer.apple.com/design/resources/). The downloaded document uses Sketch 2025.3.2 and includes Liquid Glass toolbar components. Values below come from its layer frames and text styles, not screenshots.

| Element | Measured values |
| --- | --- |
| Reference viewport | 402 × 874pt |
| Text bubble | 20pt corner radius, 14pt horizontal / 9pt vertical text inset, 17pt text with 22pt line height, 40pt minimum height; 240pt maximum body width, as the transcript examples place their longest bubbles (240–243pt; the 300pt master minus its 20pt spacer would allow 280) |
| Message column | x = 16, width = 370; bubbles of one run 8pt apart, adjacent sender runs separated by 10pt |
| Timestamp | day 11pt semibold, then the time 11pt regular; a 17pt frame with the line at its bottom, 10pt from the rows around it |
| List row | 79pt minimum height; avatar 45pt at x = 26, text starts at x = 83, right inset 16pt; title line 22pt; time then a 13pt semibold tertiary chevron 12pt after it |
| List unread marker | 10pt circle at x = 8; 8pt gap before avatar |
| List fonts | title 17pt semibold, preview 15pt, timestamp 14pt |
| Header | avatar 56pt; name capsule 30pt high, overlapping avatar by 4pt; name 16pt bold |
| Composer | attach button 44pt at x = 28; field starts x = 84, height 43pt, right inset 28pt; gap 12pt; field text 16pt with 19pt lines, inset 16pt. With the keyboard up: attach button at x = 16, right inset 16pt |
| Colors | incoming bubble #E9E9EA (dark #262629); outgoing bubble, unread marker, and accent #0088FF in both appearances; cursor #0091FF; placeholder 40% secondary; list separator rgba(0,0,0,0.12). Under Increase Contrast the matching system colors apply |

On iOS 26, the composer controls and header name use native Liquid Glass. Earlier supported systems use a filled capsule. Native navigation still owns the back button and host toolbar actions. The default header has no disclosure chevron because the SDK has no channel-details action. Host header, avatar, time, unread-count, and composer slots remain available. Default receipts appear as text beneath outgoing bubbles. The sample's testing controls and slot demonstrations are enabled only by its customization test fixture so they do not define the default appearance.

The list title defaults to “Messages”. The default UI test checks the measured 83pt title inset and 44pt attachment-button bounds, and captures the list, conversation, and sent-message states. List timestamp text keeps the reference's fixed 14pt system size; the other default text styles scale with Dynamic Type.

### Bubble footprint and receipt alignment

The default text bubble reserves 7pt inside its view frame for the tail, rounding up the source's measured 6.946pt extension. The rounded body keeps its existing text insets and minimum height. Receipts and following content are laid out after the complete bubble, including its tail. A custom bubble background keeps its original body frame and does not inherit the default tail reservation.

Outgoing receipt and sending-status labels use a trailing inset equal to the measured 20pt corner radius. This aligns them with the end of the body's straight bottom edge, to the left of the tail, as in the provided Messages reference. The row's existing 4pt vertical gap is measured from the tail's full footprint.

### Composer customization compatibility

The default composer retains the Messages field and an attachment control outside it. The current main branch's `composerItemsInsideField()` option still moves the leading controls into one capsule, and `composerSendButtonLabel(_:)` still supplies a host label in either layout. Both layouts preserve the multiline `fixedSize` behavior so the hosted composer grows with its text. The explicit capsule option uses the same glass surface as the default field.
