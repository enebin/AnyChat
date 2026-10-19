# 채널 화면 (메시지 목록)

[ARCHITECTURE.md](../../../ARCHITECTURE.md) 6절의 하위 문서다. Reducer / State / Store 의 공통 계약은 6절이 정하고, 여기는 이 화면에만 해당하는 것을 적는다. Repository 계약은 [backend-boundary.md](../backend-boundary.md) "`ChannelRepository`" 에 있다. 텍스트, 시스템, 첨부(이미지 / GIF / 영상 / 파일) 메시지를 그리고, 텍스트와 첨부를 보낸다. 메시지에 답장할 수 있다("답장").

## 타입

| 타입 | 접근 | 하는 일 |
|---|---|---|
| `ChannelView` | public | 진입점. `init(channel:)` 은 Environment 의 백엔드로 `makeChannelRepository(channelID: channel.id)` 를 부르고, `init(channel:repository:currentUserID:)` 는 그것을 덮어쓴다. 아직 켜고 끌 기능이 없어 옵션 타입은 두지 않는다 |
| `ChannelTheme` | public | 화면 테마. `View.channelTheme(_:)` 로 내려보낸다 |
| `MessageScrollBehavior` | public | How the list moves when the user sends: `followsLatest` (the default) or `questionToTop`. `ChannelView.messageScrollBehavior(_:)` sets it. See "스크롤" → "Question to top" |
| `MessageRowContext` | public | 슬롯 문맥 값. 아래 "커스터마이즈" |
| `MessageDateSeparatorContext` | public | The date separator's date and default `day` / `time` texts. The rows carry it, and the `messageDateSeparator` slot receives it. See "날짜 구분선" |
| `MessageActionContext` | public | 메시지 신호 클로저가 받는 상태, 동작, 기본 항목. 아래 "메시지 신호와 동작" |
| `MessageOverlayContext` | public | The long-press overlay's state, actions, `dismiss()`, and default items. See "길게 누르기 메뉴의 범위" → "Long-press overlay" |
| `MessageLongPressOverlay` | internal | The overlay over `ChannelBody` that lifts the pressed bubble, dims the list and the composer, and places the host's views with a one-pass layout over `OverlayPlacement`. Its `presentableRow(id:in:)` is the "still presentable" check. See "Long-press overlay" |
| `OverlayRowButtonStyle` | internal | The card's row style for the `below:` view's buttons. See "Long-press overlay" → "Values" |
| `MessageLongPressController` | internal | The collection view's long-press recognizer that opens the overlay. It keeps the cells' bubble frames. See "Long-press overlay" → "The press" |
| `OverlayPlacement` | internal | The overlay's frames from the bubble frame, the views' sizes, and the bounds. A pure value type |
| `MessageBubbleContent` | internal | The bubble alone (the `messageContent` slot's view or the default content). `MessageRow` puts it in the row, and the overlay draws it again |
| `ComposerContext` | public | 입력창 슬롯이 받는 상태와 동작, 기본 항목. 아래 "입력창 커스터마이즈" |
| `MessageSignals` | internal | 호스트의 신호 클로저, `canSend`, 메시지마다 답장할 수 있는지 묻는 `canReply`(Store 상태의 `canAnswer(_:)`), 재전송 / 삭제 / 답장 동작을 들고 메시지와 신호마다 내용과 `MessageActionContext` 를 만든다. 신호별 기본 항목도 여기서 정한다. 셀과 화면의 확인 창이 같은 값에서 만든다. The long-press overlay's `MessageOverlayContext` is built here too |
| `ChannelReducer` / `ChannelState` / `ChannelStore` | internal | 상태와 전이 |
| `MessageRowState` | internal | 메시지 행의 파생 값. 아래 "행" |
| `ChannelBody` | internal | SwiftUI bridge to the container view controller |
| `ChannelBodyViewController` | internal | Contains the message collection view controller as a child and hosts the composer on the keyboard layout guide. See "입력창". It owns `ChannelEmptyState`'s presentation and layout while the phase is `.empty`; the list controller holds the hosting controller in its background view. It also hosts the jump-to-latest button 8pt above the composer ("스크롤" → "Jump to latest") |
| `ChannelEmptyState` / `EmptyStatePresentation` | internal | The host's `channelEmptyState` view or the default "No messages" placeholder, centered in the list's area, and the observable slot, theme, environment, and bottom inset it reads. See "Empty channel" |
| `ComposerRoot` | internal | The hosted composer root: the default bar or the host's `composer` view, and the attachment pickers bound to `ComposerPresentation`'s four picker flags. Its `ComposerContext` comes from `ComposerPresentation.context(showsAttachButton:)`. See "입력창 커스터마이즈" |
| `ComposerBackground` | internal | The host's `composerBackground` view in the environment it adopts, hosted inside the composer backdrop. See "입력창" → "Composer background" |
| `MessageComposer` | internal | The default bar: attachment button or the host's items, text field, send or stop button, disabled state. Owns the draft text |
| `ComposerPresentation` | internal | Observable theme, enabled state, send / attachment / cancel-reply actions, the message being answered and its `ReplyBarText` (derived next to `ReplyQuote` and tested there), the host's composer slots including the reply bar, placeholder, stop button, background, and environment, and the four picker flags, read by the hosted composer. `trailingControl(hasDraft:)` decides between stop, send, and the trailing items. `context(showsAttachButton:)` is the one place a `ComposerContext` is built, for the composer slots and the empty state, so the empty state's context opens the composer's pickers and follows `canSend` |
| `CameraPicker` | internal | `UIViewControllerRepresentable` around `UIImagePickerController` |
| `AttachmentSource` | internal | What a picker returned: a photo library item, a file importer URL, a camera photo, or a camera video. It travels in Inputs and keys the `.preparing` slot, so every case is `Hashable` and `Sendable`. The cases carry a `PhotosPickerItem`, the file importer's URL, the camera's `UIImage` (`Sendable` and, as an `NSObject`, `Hashable`), and the camera's movie URL. `CameraPicker` only forwards what the picker returned; `AttachmentPreparer` encodes and copies off the main actor |
| `AttachmentPreparer` | internal | Copies sources into the temporary folder and makes `ChatOutgoingAttachment` values. The Store's default preparation |
| `MessageCollectionViewController` | internal | Owns the collection view lifecycle and forwards scrolling and pagination events. Holds the empty state's hosting controller as its child in the background view (`setBackground(_:)`) |
| `MessageListDataSource` | internal | Owns message snapshots, cell registration, and item-to-row lookup |
| `MessageListScrollController` | internal | Preserves the visible position during updates and later cell height changes. Reports whether the list is away from the bottom and scrolls back to it for the jump-to-latest button. With `questionToTop`, moves the sent row to the top and keeps the space below it |
| `MessageListContent` | internal | Immutable rows and pagination display values passed from SwiftUI. `sentRowID(after:)` finds the row a send added |
| `MessageListCellPresentation` | internal | Observable environment, slots, retry action, and failed message tap read by hosted SwiftUI cells. With the message signals it also carries what the rows need to build them ("메시지 신호와 동작"). For the long-press overlay it carries the closure through which cells report each bubble's frame by message id (kept by `MessageLongPressController`) and the id of the lifted message, whose bubble the cell hides |
| `MessageReplyQuote` | internal | The default quote above a reply's bubble. See "답장" |
| `ComposerReplyBar` | internal | The default "replying to" bar above the composer. See "답장" |
| `MessageSwipeController` | internal | The collection view's horizontal pan that starts a reply. See "답장" → "Swipe" |
| `ScrollAnchor` | internal | 내용이 바뀔 때 지킬 스크롤 위치의 계산. 순수 값 타입이다. Its `Geometry.isAwayFromBottom` decides whether the jump-to-latest button shows, and `sentRowAtTop(id:in:)` and `spaceBelowContent(bringingRowAt:toTopOf:)` place a sent row at the top |
| `JumpToLatestButton` / `JumpToLatestPresentation` | internal | The round button above the composer that returns to the newest message, or the host's `jumpToLatestButton` view, and the observable slot, theme, environment, visibility, and action it reads. See "스크롤" → "Jump to latest" |

호스트는 `ChannelListView.onChannelSelected` 에서 이 화면을 push 한다. 이동은 호스트의 `NavigationStack` 이 소유한다. The header, the frozen banner, and `canSendMessage` follow the latest `ChatChannel` value the host passes for the same channel id. The package does not observe the channel from the backend, so a change the host does not pass (a rename, a freeze) does not show until it does. A different id is a different screen: `ChannelView` keys its content by the id, so a new Store starts.

채널 리스트에서 만든 포매터 중 이 화면도 쓰는 것(채널 이름 등)은 `Common/Formatting` 으로 옮긴다([ARCHITECTURE.md](../../../ARCHITECTURE.md) 4절 Presentation).

## Input 과 Effect

- **Input**
  - 사용자 의도: `.start`, `.retry`, `.loadPreviousPage`, `.retryPreviousPage`, `.sendText(String)`, `.sendAttachments([AttachmentSource])`, `.startReply(messageID:)`, `.cancelReply`, `.resendMessage(id:)`, `.removeFailedMessage(id:)`, `.dismissAttachmentError`
  - 외부 사실: `.channelChanged(ChatChannel)`(the host passed a newer value of the same channel), `.messagesChanged([ChatMessage])`, `.observationEnded(message:)`(취소하지 않았는데 스트림이 끝났다. [어댑터 규약](../backend-boundary.md#어댑터-규약) 10번. 표시 문구는 Store 가 채운다)
  - Effect 완료: `.pageLoaded(MessagePage)`, `.pageFailed(message:)`, `.attachmentsPrepared([ChatOutgoingAttachment], replyTo: String?)`, `.attachmentsFailed(message:)`(the screen also sends it when the file importer fails. 아래 "입력창")
- **Effect**: `.startObserving`(관찰을 열고 최신 페이지를 읽는다), `.loadPrevious`, `.sendText(String, replyTo: String?)`, `.prepareAttachments([AttachmentSource], replyTo: String?)`, `.sendAttachments([ChatOutgoingAttachment], replyTo: String?)`, `.discardAttachments([ChatOutgoingAttachment])`(prepared copies that will never be sent), `.resendMessage(id:)`, `.removeFailedMessage(id:)`
- **State**: `phase`(`.idle` / `.loading` / `.loaded(isLoadingPrevious:)` / `.empty` / `.error`), `messages`, `hasPrevious`, `loadPreviousError`, `attachmentError`, `canSendMessage` and `canReply` (from the channel when the Store is made, then from `.channelChanged`), and `replyingToID` ("답장"). Derived `canSend` is `canSendMessage` and `phase` being `.loaded` or `.empty`.
- 새로고침은 없다. 맨 위에서 당기는 동작이 이전 페이지 읽기와 겹치고, 관찰이 항상 최신을 싣기 때문이다.
- There is no host callback Effect (`.notify`). Read failures and send failures both show inside the screen: a failed send is a failed message in the list, and a failed attachment preparation is an alert.
- Store 의 Task 슬롯은 `.observing`, `.page`, `.preparing([AttachmentSource])` 다. 늦은 완료 버리기, 스트림 소비, 관찰 수명은 채널 리스트와 같다.
- **스트림은 첫 페이지를 받은 뒤에야 읽는다.** 그래서 첫 페이지 전에 실린 스냅샷은 버퍼에 남았다가 페이지 뒤에 적용된다. 어댑터는 그 전에 스냅샷을 싣지 않는다([어댑터 규약](../backend-boundary.md#어댑터-규약) 13번). Reducer 는 `.idle` / `.loading` / `.error` 에서 `.messagesChanged` 를 받아도 상태를 바꾸지 않는다. 목록이 화면에 없을 때다.
- **페이지 완료는 기다리는 중일 때만 받는다.** `.loading` 과 `.loaded(isLoadingPrevious: true)` 밖에서 온 `.pageLoaded` / `.pageFailed` 는 늦은 완료로 보고 무시한다.

### 채널을 잃었을 때

**스트림이 끝나면 Store 가 `.page` 슬롯을 취소한 뒤 `.observationEnded` 를 보낸다.** Task 가 취소되어 끝난 경우는 보내지 않는다. `.page` 를 먼저 취소하는 이유는, 진행 중이던 이전 페이지 읽기의 완료가 에러 화면을 다시 목록으로 되돌리지 않게 하기 위해서다. 채널 리스트는 `.error` 가 `.loading` 에서만 생기므로 이 경우가 없다.

Reducer 는 `phase` 를 에러로 바꾸고 화면은 Retry 를 띄운다. Retry 는 관찰을 다시 열고, 채널이 정말 없으면 첫 `loadPrevious()` 가 `.channelNotFound` 를 던져 에러가 유지된다.

## 보내기

**The adapter owns every outgoing message.** The Store never inserts a local copy. A send Effect calls the repository, which returns at once; the pending message, then the sent or failed one, arrive in later snapshots ([backend-boundary.md](../backend-boundary.md) "`ChannelRepository`", adapter rules 15–20). That is why the send Effects have no completion Input.

- **One rule decides whether sending is possible: `ChannelState.canSend`.** The Reducer ignores `.sendText` and `.sendAttachments` when it is `false`, and the composer is enabled only when it is `true`. So the composer is disabled while the first page loads, during a Retry, and in channels where the user cannot send. A tap the Reducer would ignore cannot happen, and no draft is lost. `canSendMessage` is State rather than Reducer configuration so the composer reads the same value the Reducer checks. It changes only through `.channelChanged`, which the screen sends when the host passes a newer value of the same channel. `.channelChanged` is accepted in every `phase`, and one whose `canSendMessage` and `canReply` both equal the State's is ignored. A Store only ever sees one channel id, so the Reducer does not compare ids.
- **Text.** The composer keeps the draft in its own view state. No transition depends on it, and sending it through the Store on every keystroke would redraw the screen for nothing. Tapping send trims leading and trailing whitespace and newlines, sends `.sendText`, and clears the draft. Send is disabled while the trimmed draft is empty. The draft is cleared only from an enabled composer, which means the Reducer accepts the Input. A later delivery failure needs no draft restore, because it becomes a failed message the user can resend.
- **Other send Inputs.** `.sendText` with empty text is ignored. `.sendAttachments` and `.attachmentsPrepared` with an empty list are ignored, so a picker that reports an empty selection (for example after its selection is reset) never reaches the repository. `.resendMessage` is a send, so it is ignored unless `canSend` is `true` and `messages` holds that id with `sendingStatus == .failed`. `.removeFailedMessage` sends nothing, so it does not depend on `canSendMessage`: it is accepted in `.loaded` and `.empty` whenever `messages` holds that id as failed. A message that failed because the channel froze can therefore always be removed, even after it reappears in a channel the user can no longer send to (adapter rules 17 and 20).
- **Attachments.** `.sendAttachments(sources)` becomes `.prepareAttachments(sources)`. The Store runs the preparation in the `.preparing(sources)` slot and sends `.attachmentsPrepared` or `.attachmentsFailed`. Keying the slot by the sources lets two quick picks prepare side by side; picking the very same items twice replaces the first run. `TaskBag` keeps an entry until it is cancelled, so after sending the completion Input the Store cancels that slot to drop the entry; otherwise every pick, camera photos included, would stay in memory until the Store is released. `.attachmentsPrepared` becomes `.sendAttachments(attachments)`: one message holding every attachment in picking order. When `canSend` has turned `false` meanwhile, nothing is sent and it becomes `.discardAttachments(attachments)`, which deletes the copies. That happens when the observation ended, a Retry started, or the host passed a channel the user cannot send to.
- **Preparation is all or nothing.** If any source cannot be read, nothing is sent and `attachmentError` is set. The screen shows it as an alert; dismissing it sends `.dismissAttachmentError`. Sending part of a batch would produce a message the user did not pick.
- **Preparation is I/O, so it is injected.** `ChannelStore` takes `prepareAttachments: @MainActor ([AttachmentSource]) async throws -> [ChatOutgoingAttachment]`, the same way it takes `now`. The default is `AttachmentPreparer`. It copies each source into `FileManager.default.temporaryDirectory/AnyChatOutgoing/<UUID>/`, keeping the picked file name when there is one, encoding a camera photo as JPEG, and sets `kind` from the file's type ([domain-models.md](../domain-models.md) "`ChatOutgoingAttachment`"). Copying runs off the main actor. The file importer's security-scoped URL is opened only while copying.
- **Copies nobody sends are deleted.** `AttachmentPreparer` checks for cancellation before each item, and a run that stops or fails deletes its folder. The Store also takes `discardAttachments: @MainActor ([ChatOutgoingAttachment]) -> Void`, defaulting to `AttachmentPreparer.discard(_:)`, which deletes a run's folder. It runs for `.discardAttachments`, and when a run finishes after it was replaced by the same pick or after the Store was released. Copies handed to the repository are the adapter's ([backend-boundary.md](../backend-boundary.md) adapter rule 18). A photo library item arrives in a folder of its own; that folder is removed whether moving the file out of it succeeds or fails.
- **No row appears while preparing.** The pending row appears with the adapter's next snapshot. Copying a long video can therefore take a moment without feedback. Revisit only if measurement shows it matters.
- **After sending, the list returns to the bottom.** When the user taps send or finishes picking, the container stops any running fling, pins the list to the bottom, and scrolls there. The pending message in the next snapshot is then followed by the pinned rule. This is presentation state, so it does not pass through the Store.

**One Reducer.** The composer adds an attachment preparation lifecycle next to the message list. It adds one State field and no new `phase` combinations, so `ChannelReducer` stays whole ([ARCHITECTURE.md](../../../ARCHITECTURE.md) 6절 "Reducer 가 커질 때"). Replies add two Inputs and two State fields, and still no new `phase` combinations, so the Reducer stays whole after them too. Split it if composer features such as drafts or editing make State and Input combinations keep growing.

## 답장

A user answers a message from the long-press menu or by swiping its row. The composer shows a "replying to" bar until the message is sent or the bar is closed. A sent reply shows a quote of the original above its bubble. Jumping from a quote to the original is not part of it: the list only pages back from the latest message, so an original on an unread page cannot be reached.

The look comes from the "Replies" section of the design source ([docs/design/messages/README.md](../../design/messages/README.md)). The kit has no reply parts, so those values were made from kit values; the quote and the bar read them there.

### When replying is possible

**`canReply` decides whether the action exists at all.** It comes from `ChatChannel.canReply` ([domain-models.md](../domain-models.md)), like `canSendMessage`, and changes only through `.channelChanged`. A message can be answered when `canSend` and `canReply` are both `true` and the message is sent (`sendingStatus == nil`) and is not a system message. The same rule gates the menu item, the swipe, the accessibility action, and the Reducer's `.startReply`, so no entry point offers what the Reducer would ignore. Pending and failed messages cannot be answered: their ids may not exist on the backend yet.

Quotes are drawn whenever a message has `replyTo`, whatever `canReply` says now (adapter rule 25).

### State and Inputs

- **`replyingToID: String?`** holds the message being answered. It is State rather than composer view state, unlike the draft text, because the send Inputs read it: the Reducer attaches it to the send Effect and clears it in the same transition. The bar draws the message the State points to, looked up in `messages`, so an edit of the original redraws the bar.
- **`.startReply(messageID:)`** sets it when the message can be answered (above). Starting a reply to another message replaces it. Otherwise it is ignored.
- **`.cancelReply`** clears it. It is accepted whenever it is set.
- **Sending a reply.** `.sendText` becomes `.sendText(text, replyTo: replyingToID)` and clears `replyingToID`. `.sendAttachments(sources)` becomes `.prepareAttachments(sources, replyTo: replyingToID)` and clears it at once, the moment the user finishes picking, as the text send does. The Store hands the same id back in `.attachmentsPrepared(attachments, replyTo:)`, which becomes `.sendAttachments(attachments, replyTo:)`. The Reducer checks the id again there, because the original may be deleted or `canReply` may turn `false` while files are copied, the same window the existing `canSend` check covers: when `canReply` is `false` or `messages` no longer holds that id as a sent message, the attachments are sent with `replyTo: nil`. The user picked them to send, so they still go, as an ordinary message, and the screen never passes an id the boundary does not allow. Clearing at pick time means a reply started while a long video prepares is not attached to that video.
- **It is cleared when it can no longer be sent.** When `messages` no longer holds that id as a sent message, when `canReply` turns `false` through `.channelChanged`, and on `.retry`. When only `canSendMessage` turns `false`, it stays: the composer is disabled, and the bar is still there when sending returns. A reply whose original disappears between the send and the adapter's snapshot is the adapter's case (adapter rule 23).
- **The draft is untouched.** Starting or cancelling a reply keeps the text the user typed.
- **Focus.** Starting a reply focuses the default composer's text field, so the keyboard opens as in messengers. This is presentation, so the composer reacts to `replyingToID` changing to a value; the Store does not know about focus. A host `composer` reads `context.replyingTo` and decides for itself.

### Quote in the row

`MessageReplyQuote` sits above the bubble of a message with `replyTo`: the design source's "replied to" line and an outlined copy of the original's text, or its first picture when the original has no text. A quote with `isUnavailable` shows the design source's unavailable text in a dashed outline. The values come from `MessageRowState.replyQuote` (`ReplyQuote`: the line, the text, the thumbnail), derived with the current user's id so the line can say "you"; the text reuses the words of `MessagePreviewFormatter` (`Common/Formatting`, shared with the channel list) for attachments, such as "Photo". The line uses the sender name's font and color; the quote uses `ChannelTheme.replyQuoteText`, `replyQuoteBorder`, and `replyQuoteFont`.

- **Placement.** Inside the bubble column, above media and text, aligned to the sender-side edge like the accessory. The sender name stays above the quote.
- **Grouping.** A reply starts a new run, so it never sits in the middle of a run with its quote between two bubbles. Messages after it can join its run. This is a `MessageRowState` derivation and is tested there.
- **Slot.** `messageReplyQuote { message, context in ... }` replaces the quote. Like every message slot it receives the reply `ChatMessage` and `MessageRowContext`, and reads the original from `message.replyTo`. It is called only for messages whose `replyTo` is not `nil`. Receiving the reply, not only the reference, lets a quote say who replied to whom, for example "Mina replied to you" in a group; `context.isMine` is the reply's, so the slot compares the original's sender with the current user's id it captured itself. It follows the rules of the avatar, name, and time slots ("보낸 사람 사진, 이름, 시각"): empty hides the quote and its spacing, it is called for non-system rows drawn by the default bubble row with or without a `messageContent` slot, a `messageRow` slot draws its own quote, and the package applies no theme value to the slot's view.
- **Gestures.** The quote is part of the row for the double tap and the failed-message tap. The long-press menu stays on the bubble ("길게 누르기 메뉴의 범위"), so the quote is not lifted with it. Tapping a quote does nothing by default; a slot that wants a tap uses a `Button`.

### Reply bar

`ComposerReplyBar` sits directly above the composer while `replyingToID` is set: the design source's "Replying to <name>" line ("Replying to yourself" for the user's own message), a one-line preview of the original in the quote's words, and a close button that sends `.cancelReply`. Its values are the design source's reply bar; it uses `ChannelTheme.replyBarTitleFont` and `replyBarCloseBackground`, and otherwise the composer field's background, `composerText`, and the quote's text values. The Store state's `canAnswer(_:)` is the one rule the menu item and the Reducer's `.startReply` share.

- **Placement.** It is part of the hosted composer root, so it moves with the keyboard, the composer backdrop paints behind it, and the list inset grows by its height. It sits above the default bar and above a host `composer` view alike, so a custom composer gets replies without drawing anything.
- **Slot.** `composerReplyBar { message, context in ... }` replaces the bar. It receives the message being answered and `ComposerContext`, whose `cancelReply()` closes it. Empty hides it, which a host `composer` that draws its own bar uses. The environment rule of the composer slots applies ("입력창 커스터마이즈" → "Environment").
- **`ComposerContext`** gains `replyingTo: ChatMessage?` and `cancelReply()`. `send(text:)` sends a reply while one is set, because the Reducer reads the State, not the call.

### Starting a reply

- **Menu.** `MessageActionContext` gains `canReply` (the rule above for that message) and `reply()`, which sends `.startReply`. The default long-press menu lists Reply first when `canReply` is `true` ("메시지 신호와 동작"). The failed-message dialog does not offer it.
- **Swipe.** Dragging a row toward the trailing edge starts a reply, as in messengers. It follows "슬롯과 동작": the package attaches it around every row path, default or slot, so a host never wires it.
  - **Why UIKit.** A SwiftUI drag gesture inside a hosted cell cannot be ordered against the collection view's pan or the navigation controller's back swipe: it either blocks vertical scrolling and the interactive keyboard dismissal, or loses every drag to them. A recognizer on the collection view can decline to begin, and can require the back swipe to fail ([ARCHITECTURE.md](../../../ARCHITECTURE.md) section 1).
  - `MessageSwipeController` adds one pan recognizer to the collection view, not one per hosted cell. It begins only when the movement is mostly horizontal and toward the trailing edge, and only on a row whose message can be answered. A vertical drag therefore stays a scroll and still drives the interactive keyboard dismissal ("입력창"), and the navigation controller's edge swipe keeps priority: the recognizer requires the interactive pop gesture to fail.
  - The row's content follows the finger with resistance, and the design source's reply icon appears in the space it leaves. Passing the threshold plays one light haptic; going back under it cancels. Releasing past it sends `.startReply`; either way the row springs back. The threshold, resistance, and icon are the design source's "Swipe" rows ([docs/design/messages/README.md](../../design/messages/README.md)). The offset is a pure function of the finger's travel and is tested.
  - Moving the content is presentation only; it never changes Store state until release. The controller moves a picture of the row over the collection view and hides the cell's content while it moves, because a hosted cell redraws its content for its pressed state and drops a transform set on it. It hides by cell rather than by message id because the gesture is short and restores the cell it hid; a list update during the swipe ends it at once without a reply, so a moved or reused cell is never left hidden. The icon is a view the controller owns, drawn behind the moving picture.
- **Accessibility.** Rows that can be answered carry a "Reply" accessibility action, so VoiceOver users have an entry point without the swipe.

### Steps, tests, and MCP

The domain and boundary, the quote, the composer state and bar, and the swipe are separate steps. Each one that adds or changes a public symbol updates the MCP catalog in the same PR ([mcp.md](../mcp.md) "Keeping the MCP in step with the SDK"). Reducer tests cover the Inputs above; `MessageRowState` tests cover a reply starting a run; `MessageSignals` tests cover the Reply item and `canReply`; `ComposerContext` tests cover `cancelReply()` and `send(text:)` while replying; `ChannelSlots` tests cover the two new slots. QuickStart verifies the quote, the bar, starting a reply from the menu, and the swipe, with screenshots.

### Not included

Editing, threads, a reply count, jumping to the original, and replying to several messages at once. There is no switch to turn the swipe off while keeping replies; add one when a host needs the swipe for something else.

## 입력창

The design source's composer: an attachment button, a text field with the placeholder "Enter message", and a send button while there is text. Sizes and colors come from the design source in the composer step.

- **Placement.** `ChannelBodyViewController` contains `MessageCollectionViewController` as a child that fills the view, and hosts `ComposerRoot` in a `UIHostingController` whose bottom is pinned to `view.keyboardLayoutGuide.topAnchor`. With the keyboard hidden, the guide sits at the bottom safe area. The collection view uses `keyboardDismissMode = .interactive`; the layout guide follows the keyboard during that drag, so the composer moves with the finger. SwiftUI's keyboard safe area does not report the drag, which is why this placement is UIKit ([ARCHITECTURE.md](../../../ARCHITECTURE.md) 1절).
- **Composer height.** The hosted SwiftUI root reports its rendered height at the available width. The container applies that height to the hosting view, so multiline text and its glass background grow together above the keyboard instead of overflowing a one-line intrinsic size.
- **Keyboard up.** On every layout pass the container compares the keyboard layout guide's top with the bottom safe-area edge and writes how far the keyboard has risen over its first 60pt to `ComposerPresentation.keyboardProgress` (0 to 1). Only the default bar and the default reply bar read it, to narrow their side padding from 28pt to 16pt as the design source does, gradually so an interactive dismissal does not make it jump; the reply bar takes the value from `MessageComposer.sidePadding(keyboardProgress:)` so the two stay aligned; a host `composer` or `composerReplyBar` view and `ComposerContext` do not receive it.
- **Empty channel.** While the phase is `.empty`, the container shows a second `UIHostingController` with `ChannelEmptyState`, inside a plain view set as the collection view's `backgroundView`. `MessageCollectionViewController.setBackground(_:)` sets it and adds the hosting controller as its own child: a child must belong to the controller whose view holds its view. With the container as the parent, a hosting view threw `UIViewControllerHierarchyInconsistency` as it entered the window when the screen switched to an empty channel. Inside the list, its buttons take their own taps while a drag anywhere on it reaches the list's pan, so `.interactive` keyboard dismissal works in an empty channel as before. Laid over the list as a sibling, it swallowed that drag; laid behind the transparent list, it lost its taps. The background view fills the list and stays put while the list bounces, and the list fills the container, so the container's coordinates apply. Its frame runs from the list's safe-area top, which already includes the header and frozen-banner inset, to the bottom of the container, under the composer, and does not change with the keyboard. On every layout pass the container writes the distance from the container's bottom to the composer's top to `EmptyStatePresentation.bottomInset`, and the hosted view pads its content by it with the composer's 0.25s smooth animation, so the content stays above the composer while the keyboard moves. Resizing the hosting view instead made SwiftUI lay the content out for the final size at once, so a view at the bottom jumped ahead of the composer. It uses a frame, not constraints: constraints between it and the composer kept the composer from rising with the keyboard in channels with messages, where the view is hidden. Its `safeAreaRegions` is empty, so the hosting view does not move its content again for the keyboard. As with the composer, only the host's view adopts the screen's environment; the default placeholder reads the theme from `EmptyStatePresentation`. In every other phase it is hidden, which also removes it from accessibility, and the container skips its frame and inset while hidden. Before showing it, the container sets both without animation, so the content does not slide into place when it appears or when a channel becomes empty again. See "Empty channel".
- **SwiftUI must not avoid the keyboard too.** `ChannelBody` ignores the keyboard safe area, so only the layout guide reacts to the keyboard.
- **Header inset.** The default header, the avatar and the name capsule below it, is a SwiftUI top safe-area inset above the UIKit list. It is not a `.principal` toolbar item: the inline bar clips its items to its own 44pt height, which cut the top and bottom of the 56pt avatar. The inset is pulled up by 43pt so the avatar starts 1pt below the bar's top, as in the design source, and reaches past the bar's bottom. `ChannelContent` measures the part below the bar and passes it to the list as an additional top safe-area inset, adding the frozen banner height when present. A custom navigation-bar header adds no inset. This lets the oldest date and loading/retry row rest below the complete header while scrolling content can still pass behind the glass.
- **Edge blur.** On iOS 26 the navigation bar draws no background, only a soft blur over the content under it, and only for the scroll view it knows. It cannot find a list inside a representable, so the list scrolled under a sharp bar. `ChannelBodyViewController` registers the collection view with `setContentScrollView(_:for: .top)` on the view controller the navigation controller holds, in `viewWillAppear`. Before iOS 26 it does not: a bar that knows a scrolled list turns opaque and hides the avatar drawn under it.
- **List inset.** The container sets the child controller's `additionalSafeAreaInsets.bottom` to the distance from the composer's top edge to the container's bottom safe-area edge, updated on every layout pass. The collection view keeps `contentInsetAdjustmentBehavior = .automatic`, so its adjusted inset adds the device's bottom safe area exactly once, and `ScrollAnchor` keeps reading `adjustedContentInset` as it does now. Setting `contentInset.bottom` to the full distance would count the home indicator area twice. When the inset changes, a list pinned to the bottom stays at the bottom through the existing pinned rule. A list scrolled up keeps its offset, and the keyboard covers its lower rows, matching scroll behavior 4.
- **Environment.** The hosted composer receives the theme and actions through `ComposerPresentation`, not the whole environment. An `EnvironmentValues` taken from `context.environment` carries the representable's read tracker; a hosted graph that adopts it with `.environment(\.self, _)` shares that tracker, so what each side reads depends on the other's reads. The composer's own `.disabled(true)` came back through `context.environment.isEnabled` and kept the attachment button disabled after `canSend` returned to `true`. The package's own composer controls read only the theme. Their UIKit traits follow the system, but they redraw for a new color scheme only when `update` hands the theme over again. Host views placed in the composer follow the rule in "입력창 커스터마이즈". Hosted cells still receive the whole environment because slots may read any key. `updateUIViewController` reruns only when a `context.environment` key it reads changes, and color resolution is not such a read, so `ChannelBody` reads the color scheme, contrast, Dynamic Type size, and Bold Text setting. Without those reads, a switch to dark while the screen was open left the cells on the light environment and the composer's + button light. Its actions are user taps, so they send Store Inputs directly; only work started inside `updateUIViewController` must be deferred.
- **Cannot send.** When `canSend` is `false`, the attachment button and the text field are disabled. When the reason is `canSendMessage == false`, the field shows "Chat is unavailable in this channel" (design source); while loading it keeps the ordinary placeholder. When `channel.isFrozen`, a "Channel is frozen" banner sits at the top of the list (design source). The list's top inset grows by the banner's height, so the oldest rows and the "Tap to load more" row can scroll out from under it. The banner explains the reason; whether sending works comes only from `canSendMessage`. The banner and the composer read the same channel value, so they change together when the host passes a newer one. A change the host does not pass shows up as failed sends (adapter rule 17).
- **Attachment menu.** The attachment button opens a confirmation dialog with Camera, Photo library, Files, and Cancel (design source). iOS presents it as a popover from the composer bar and drops the design source's row icons. `AttachmentPickers` holds the menu and the three pickers. Photo library uses `PhotosPicker` for images and videos with multiple selection. Files uses `fileImporter` for any type with multiple selection. Camera uses `CameraPicker` for a photo or a video. Whatever one pick returns is sent as one message. A `fileImporter` failure sends `.attachmentsFailed` with the Store's message, so it shows the same "Couldn't attach" alert as a failed preparation; a cancel reports nothing.
- **Camera availability.** Camera is offered only when `UIImagePickerController.isSourceTypeAvailable(.camera)` is true and the host app's Info.plist has `NSCameraUsageDescription`. Video capture is offered only when `NSMicrophoneUsageDescription` is present too. Without those keys the system would end the app, so the menu hides the item instead. The simulator has no camera, so UI tests cover only the menu and the photo picker opening. On the iOS 26.4 simulator, `PhotosPickerItem.loadTransferable` fails even for `Data`, so a photo library send needs a device check; preparing and sending picked files is covered by `AttachmentPreparer` and Store tests.
- **Composer background.** `ChannelBodyViewController` paints `composerBackground` once, on a backdrop view from the composer's top edge down to the screen edge behind the home indicator. The hosted composer paints no background of its own, so a translucent color has no darker band and no seam at the composer's bottom edge. When the host sets `composerBackground { … }` ("입력창 커스터마이즈"), a third `UIHostingController` with `ComposerBackground` fills the backdrop and the backdrop's color turns clear; otherwise that hosting view is hidden. Its `safeAreaRegions` is empty, so the host view spans the whole backdrop under the home indicator and is not moved again for the keyboard. Its view takes no touches; the backdrop around it still takes them as before, so a touch below the composer does not reach the cells hidden there. It shares the composer's `ComposerPresentation`, which carries the slot and the environment the host view adopts.
- **Theme.** The composer and the frozen banner read `ChannelTheme`'s `composer…` and `frozenBanner…` colors and fonts, whose defaults read DesignSystem tokens.
- **Customization.** A host changes the placeholder, adds buttons beside or inside the field, changes the send button's label, turns send into stop while a response is in progress, draws its own view behind the composer, or replaces the whole composer ("커스터마이즈" → "입력창 커스터마이즈"). Every path keeps this section's placement, backdrop, list inset, frozen banner, and scroll-to-bottom on send.

## View folders

`Channel/View` keeps `ChannelContent`, `ChannelSlots`, `MessageSignals`, `ChannelBody`, `ChannelBodyViewController`, `ChannelEmptyState`, and `JumpToLatestButton` at its root. `MessageList/` contains the collection view and controller, data source, hosted cell presentation, scroll handling, and the swipe and long-press controllers. `LongPressOverlay/` contains `MessageLongPressOverlay`, its row button style, and `OverlayPlacement`. `MessageRow/` contains the default message rows, bubble content, and date separator. `Composer/` contains `ComposerRoot`, `MessageComposer`, `ComposerReplyBar`, `ComposerPresentation`, `FrozenBanner`, `AttachmentPickers` (the attachment menu), and `CameraPicker`. `AttachmentSource` and `AttachmentPreparer` are not views; they sit in `Channel/Sending/`. Files are grouped by responsibility rather than UI framework; access levels and module boundaries stay the same.

## 행

State 는 `messages` 만 담고, Store 가 `rows: [MessageRowState]` 를 파생한다. 채널 리스트의 `rows` 와 같은 이유다.

Each `MessageRowState` retains its original `ChatMessage`. Its ID, sender, custom payload, and content come from that message, while grouping and display values are derived from the message and its neighbors. Sender information is retained even when the default row hides it. Sender name and avatar visibility are computed separately; system rows show neither. Slots receive `row.message`, so a row is never paired with another array by index. Equality and hashing include the complete message and the derived values.

Ordinary messages may carry text and attachments together. The row content splits the attachments into **media** (`.image`, `.gif`, `.video`) and **files** (every other kind), keeping the original order within each group. The default row stacks media first, then file rows, then the text bubble when the body is not empty, 4pt apart. The design source never mixes media and files in one message; when an adapter does, media still comes first. Legacy `.file` / `.files` content without attachment metadata keeps the unsupported-content placeholder. The original text and attachment metadata remain available to slots. System notices retain their separate rendering. Attachment-only metadata changes with the same message ID update rows and reach slots. Attachment loading state belongs to the image loader, not the domain message or the common row state.

- **One media attachment** is a 240×160 thumbnail with 16pt corners, filled and cropped. A GIF shows its first frame and a 48pt animated-image SF Symbol badge; a video shows a frame generated from its start and a 48pt play badge. Animation and playback are not part of the default row.
- **Two or more media attachments** form the design source's two-column grid: 240pt wide, 4pt padding and spacing, 114pt square cells on the incoming bubble background. Cells round 12pt where they meet the grid's corners and 6pt elsewhere. With an odd count, the last cell sits on the sender's side: leading for incoming, trailing for outgoing. Badges are 32pt.
- **Files** are 44pt bubbles with a 28pt icon tile, the file name truncated in the middle, and the bubble colors of a text message. Audio and voice use the audio icon; other kinds use the document icon. A missing file name falls back to the URL's last path component.
- Thumbnails show the photo icon on the incoming bubble background until the image arrives, and keep it when loading fails.

- **행 하나는 메시지 하나다.** `id` 는 메시지 `id` 다. 날짜 구분선도 별도 항목이 아니라 그날 첫 메시지 행의 값(`dateSeparator: MessageDateSeparatorContext?`, 날짜와 그날 첫 메시지의 시각)으로 둔다. 그래서 목록 항목의 식별자가 메시지 id 하나로 유지되고, 스크롤 위치를 고정할 기준이 단순해진다.
- **행 값은 이웃에 따라 달라진다.** 같은 보낸 사람이 같은 분에 보낸 연속 메시지 묶기(묶음의 처음에만 이름, 끝에만 사진과 시각. 묶음 안 간격 8, 묶음 사이 10), 날짜 구분선, 내 메시지 여부(`sender` 와 `currentUserID` 가 모두 있고 id 가 같을 때만. 둘 다 `nil` 인 경우를 내 메시지로 보지 않는다. `sendingStatus` 가 있는 메시지는 이 기기가 보낸 것이므로 언제나 내 메시지다. So with `currentUserID == nil`, a message this device sent moves to the other side once it is sent. This is documented on `ChannelView.init(channel:repository:currentUserID:)` and `MessageRowContext.isMine` rather than changed), 내 메시지의 수신 확인이다. 시각은 `hh:mm`, 날짜 구분선은 오늘이면 `Today`, 어제면 `Yesterday`, 올해면 `E, MMM dd`, 지난해면 `MMM dd, yyyy` 이고, 굵은 날짜 뒤에 보통 굵기의 `h:mm a` 시각이 붙는다. 묶는 기준과 표시 문구는 디자인 원본을 따랐다. 계산은 순수 함수로 두고 테스트한다.
- 표시 종류는 `.text` 말풍선, `.system` 안내, 첨부, 나머지 내용의 자리표시다.
- **Unsent messages come last.** Snapshots hold sent messages oldest first, then this device's pending and failed messages in send order ([adapter rule](../backend-boundary.md#어댑터-규약) 8). An unsent message never starts a date separator: its `createdAt` is local time, and a message received while it waits can carry a later server time, so its day can run backwards against the row above. Unsent messages group only with each other. When a message is sent it joins the sent order, and its row moves there with the same id.
- **Sending status replaces the receipt.** It follows `sendingStatus`, not `isMine`: only this device's messages carry a status (rule 17), and a host that passes `currentUserID: nil` must still see a failed send. A pending message shows a 16pt system spinner, turning, and a failed one a 16pt system error icon, below the outgoing bubble in place of its receipt (`SendingStatusIndicator`, tinted by `ChannelTheme.sendingIndicatorTint` / `failedIndicatorTint`). A pending attachment shows its thumbnail from the local file URL. The design source has no upload-in-progress state for attachments, so the sending indicator below the bubble marks it like a text message.
- **Tapping a failed message opens a confirmation dialog** (by default Retry / Remove; a host changes it with `failedMessageActions`, see "메시지 신호와 동작"). The tap target is the failed message's whole row, whether the default bubble row (including its error icon and a content slot's area) or a whole-row slot's view. `MessageListRow` attaches it around either one. While a message has a `sendingStatus`, its default attachment views are not buttons and `onAttachmentSelected` is not called: the file is not on the backend yet, and an attachment button would otherwise take the tap and hide Retry / Remove. A slot's own buttons still take their taps first. The row reports the tap through `MessageListCellPresentation`. `ChannelContent` shows the confirmation dialog at screen level. By default it holds the design source's Retry, Remove, Cancel and sends `.resendMessage` or `.removeFailedMessage`; with `failedMessageActions` it holds the host's buttons and Cancel. The dialog is anchored to a point at the bottom edge, on the composer: iOS presents it as a popover from its anchor, and a screen-sized anchor would point at whatever row is in the middle. By default Retry is listed only while `canSend` is `true`, so it never offers an action the Reducer would ignore, and Remove is always listed. A host decides its own items. The dialog is not placed inside the cell because a reused cell would lose it. Slots see `message.sendingStatus` but never receive these actions: the tap belongs to the row around any slot ("커스터마이즈" → "슬롯과 동작").
- `MessageRow` selects the default view for the content. `MessageBubbleRow` owns the shared incoming/outgoing layout and accepts a content view and optional host views for the accessory, picture, name, and time ("커스터마이즈" → "말풍선 아래 덧붙이기", "보낸 사람 사진, 이름, 시각"). `TextMessageContent`, `AttachmentMessageContent` (with `MediaAttachmentContent`, `MediaAttachmentGrid`, `MediaThumbnail`, and `FileAttachmentContent`), `UnsupportedMessageContent`, and `SystemMessageRow` own their content presentation. Custom content slots replace the bubble content; custom row slots replace the whole row.
- **Store 는 `messages` 가 바뀌면 바뀐 메시지와 그 이웃의 행만 다시 만든다.** 행은 메시지와 앞뒤 이웃에만 의존하므로, 셋이 그대로인 행은 이전 값을 그대로 쓴다. 메시지 2,000개에 스트리밍을 걸어 쟀을 때 전체 재생성이 스냅샷마다 약 2.9ms(Release, 시뮬레이터)로 Store 비용의 대부분이었기 때문이다. 행 위치는 보통 그대로라 같은 자리의 id 를 먼저 보고, 이전 페이지가 앞에 붙어 자리가 밀렸을 때만 id 로 찾는다. 날짜 구분선은 올해인지에 따라 연도를 빼므로, 해가 바뀌면 전부 다시 만든다. 로캘이나 시간대가 화면을 연 채로 바뀌면 다시 만든 행만 새 형식을 따른다. 화면을 다시 열면 맞춰지므로 따로 처리하지 않는다. 비교와 diffable 적용 같은 뷰 쪽 O(메시지 수) 비용은 남는다.

## 스크롤

`ChannelStore` remains the single owner of domain state and backend effects. SwiftUI observes the Store and passes `MessageListContent` values to the internal collection view controller. UIKit reports pagination intent through closures; it does not subscribe to the repository or mutate Store state. `MessageListCellPresentation` uses Observation only for rendering inputs: hosted cells observe the latest environment, slots, and retry action even when their message data has not changed. What cells report back (the long-press overlay's bubble frames) goes through closures, not through observed state. There is no second message Store or Combine subscription.

The controller owns the concrete data source and scroll controller. The data source handles snapshots and cell configuration; the scroll controller handles anchors and position restoration. Controller lifecycle and collection view layout callbacks drive both, and deferred pagination requests are cancelled when the SwiftUI bridge is dismantled. Hosted rows use the message ID as SwiftUI identity so cell reuse does not carry a custom view's local state into another message.

`ChannelBody` connects `ChannelBodyViewController` through `UIViewControllerRepresentable`; it contains `MessageCollectionViewController`, which owns only the scrolling container. 셀은 `UIHostingConfiguration` 으로 SwiftUI 행(날짜 구분선, `MessageRow`, 메시지 슬롯)을 그린다. 항목은 행 id 다. 위가 오래된 메시지인 정방향이며, 리스트를 뒤집지 않는다. 지켜야 할 동작은 넷이다.

1. 처음에는 최신 메시지(바닥)에서 시작한다.
2. 바닥에 있을 때 새 메시지가 오거나 행이 길어지면(스트리밍) 바닥을 따라간다.
3. 이전 페이지를 위에 붙여도 보고 있던 메시지가 화면에서 움직이지 않는다.
4. 위로 올려 둔 상태에서 새 메시지가 오면 따라가지 않는다. 그동안 입력창 위에 최신으로 돌아가는 버튼이 뜬다(아래 "Jump to latest").

These are the default, `MessageScrollBehavior.followsLatest`. With `.questionToTop`, a send moves the sent message to the top instead of following the bottom; the rest holds (below, "Question to top").

### 왜 SwiftUI `ScrollView` 가 아닌가

`ScrollView` + `LazyVStack` + `defaultScrollAnchor(.bottom)` 은 바닥에 붙어 있을 때만 위쪽 삽입을 보정한다. 위로 올려 둔 상태에서 이전 페이지가 붙으면 offset 이 그대로 남아 화면이 새로 붙은 행 쪽으로 점프한다. 그 레이아웃에서 위쪽 행의 `onAppear` 가 다음 페이지를 불러, 첫 메시지까지 연쇄로 읽었다. SwiftUI 안에서 고치려던 방법은 셋 다 실패했다.

- `scrollPosition(id:)` 나 `ScrollPosition.scrollTo(id:)` 로 보던 행 되돌리기: 행이 바뀐 직후 부르면 무시되고, 한 번 미뤄 부르면 점프한 프레임이 먼저 그려져 그 사이에 다음 페이지를 부른다.
- `ScrollView` 아래 `UIScrollView` 의 `contentOffset` 보정: `contentSize` 변경 알림이 `onAppear` 보다 늦게 오고, 쓴 offset 을 SwiftUI 가 덮어쓴다.
- `onScrollGeometryChange` 안에서 `scrollTo(y:)`: 무시된다. `.scrollPosition` 을 붙이면 바닥에서 하던 보정까지 꺼진다.

원인은 같다. SwiftUI 는 행 추가, 레이아웃, `onAppear` 를 한 패스에 끝내서 보정을 끼워 넣을 틈이 없다. 코드가 공개된 메신저(Telegram, Signal)와 exyte/Chat 도 모두 UIKit 리스트에서 offset 을 직접 다룬다.

### 규칙

- **바닥에 고정되어 있으면 바닥에 붙고, 아니면 보이던 행 하나의 화면상 위치를 지킨다.** 앞은 1·2번이다. 뒤는 위에 행이 붙으면 바닥까지의 거리를 지키는 셈이 되고(3번), 아래에 붙으면 offset 이 그대로 남는다(4번). 바닥까지의 거리만 지키면 4번이 깨진다. 계산은 `ScrollAnchor` 가 하고 테스트한다.
- **기준 행은 이번 갱신에서 내용이 바뀌지 않는 행이다.** 보이는 행 중 바뀌지 않은 첫 행을 고르고, 모두 바뀌었을 때만 보이는 첫 행을 쓴다. 이전 페이지가 붙으면 기존의 첫 행은 위 여백이 생기고, 날짜 구분선이나 보낸 사람 이름을 잃을 수 있다. 셀의 위쪽 끝을 고정해도 셀 안의 말풍선이 그만큼 움직여, 맨 위에 닿은 채로 페이지가 붙으면 아래가 통째로 밀렸다.
- **보정은 그리기 전에 끝난다.** 갱신 한 번은 위치 기록 → snapshot `apply`(애니메이션 없음. 같은 id 인데 내용이 바뀐 행은 `reconfigureItems`) → `layoutIfNeeded()` 와 offset 복원의 반복 순서이며, 한 런루프 안에서 돈다. 복원한 offset 으로 화면에 들어온 셀은 다음 레이아웃 패스에서야 실제 높이를 재므로, offset 이 더 바뀌지 않을 때까지(최대 몇 번) 되풀이한다. 그래서 점프한 프레임이 그려지지 않는다.
- **맨 위를 넘겨 당긴 상태에서 페이지가 붙으면 바운스를 먼저 멈춘다.** 위에 행이 생겨 더 당겨질 이유가 없는데, 남은 바운스 복귀가 보정한 뒤의 목록을 계속 아래로 끌고 가기 때문이다.
- **"바닥에 고정" 은 offset 이 아니라 상태다.** 드래그를 시작하면 풀고, 드래그나 감속이 바닥에서 끝나면 다시 건다. 셀이 추정 높이에서 실제 높이로 정착하면 내용의 끝이 움직이므로, offset 으로 판단하면 바닥에 있는데도 아니라고 본다. 고정 중에는 컬렉션 뷰의 레이아웃이 끝날 때마다 바닥으로 맞춰, 갱신 밖의 셀 정착과 스트리밍 성장을 따라간다. This presentation state belongs to `MessageListScrollController`, separate from the Reducer state.
- **셀 높이는 추정값으로 시작하고, 보일 셀만 UIKit 이 잰다**(`UICollectionViewCompositionalLayout` 의 estimated 높이). 위의 반복 보정이 갱신 때의 오차를 흡수하므로 화면 밖 행을 미리 재지 않는다.
- **행은 셀 높이가 아니라 자기 높이로 그린다.** 셀은 행에 `.fixedSize(horizontal: false, vertical: true)` 를 건다. `reconfigureItems` 로 다시 구성한 행은 셀이 새 높이로 커지기 전에 옛 높이로 한 번 그려진다. 그 높이를 그대로 받으면 스트리밍으로 자라는 행 안의 줄바꿈 텍스트가 한 줄로 눌려 "…" 로 잘린다. 고정하면 그 순간에도 행은 자기 높이로 그려지고, 셀이 곧 그 높이로 맞춰진다. 호스트의 행 슬롯이 따로 `fixedSize` 를 걸 필요는 없다.
- **갱신 밖의 높이 변화도 보던 행을 지킨다.** 이미지가 늦게 로드되거나, 호스트의 슬롯 뷰가 커지거나, 접힌 메시지를 펼치면 갱신이 끝난 뒤에 행 높이가 바뀐다. 그 행이 기준 행보다 위에 있으면 화면이 밀린다. UIKit 이 이를 늘 보정하지는 않는다. 그래서 `MessageListScrollController` 는 보던 행의 화면상 위치를 기억해 두고, 사용자가 스크롤하지 않았는데 레이아웃만으로 그 행이 움직이면 그만큼 offset 을 되돌린다.
- **The default attachment row has a fixed size before its image arrives.** Thumbnails and grid cells use the design source's fixed frames, so a late image never changes the row height. `ChatAttachment.imageSize` stays available to custom slots that size by aspect ratio; late height changes from such slots are covered by the rule above.
- **The composer's height and the keyboard set the bottom inset.** See "입력창". An inset change follows the same pinned / not-pinned rule as a content change.
- **이전 페이지는 맨 위까지 남은 거리로 요청한다.** 남은 거리가 화면 높이의 2 배보다 작으면 `send(.loadPreviousPage)` 를 부르고, 같은 첫 행에서는 한 번만 부른다. 행 개수(위에서 몇 번째)로 재면 긴 행과 빠른 스크롤에서 페이지보다 손가락이 먼저 맨 위에 닿는다. 그래서 첫 페이지가 화면 2 개보다 짧으면 열자마자 이전 페이지를 더 읽는다. 갱신 중의 offset 변화는 사용자 스크롤이 아니므로 판단하지 않는다. 보이는 행이 필요할 때는 현재 bounds 의 레이아웃 속성으로 구한다. `indexPathsForVisibleItems` 는 offset 을 바꾼 직후에도 이전 셀을 돌려주기 때문이다. `canLoadPreviousPage` 와 실패 후 재시도 규칙은 [채널 리스트의 페이지네이션](channel-list.md#페이지네이션)과 같다. 로딩 표시와 "Tap to load more" 는 목록의 첫 항목이다.
- **셀은 SwiftUI Environment 를 다시 받는다.** 호스팅 셀은 바깥 Environment 를 물려받지 않는다. `ChannelBody` 는 자기가 받은 Environment 를 셀 내용과 입력창에 그대로 넣는다. 그래서 테마와, 호스트가 슬롯 안에서 읽는 자기 Environment 값이 함께 간다.
- **셀은 재사용된다.** 화면 근처의 셀만 만들고 돌려 쓰므로 긴 히스토리의 메모리가 셀 수에 비례하지 않는다.

### Jump to latest

While the list is scrolled up, a round down-arrow button floats above the composer, as in Messages; tapping it returns to the newest message. The design source has no such button, so its values are built from the kit's and marked new in [the design README](../../design/messages/README.md).

- **When it shows.** While the newest content is more than 100pt below the visible bottom: `ScrollAnchor.Geometry.isAwayFromBottom`, which compares `maxOffset - offset` with `ScrollAnchor.awayFromBottomDistance`. The distance, not the pinned state, decides, because a drag unpins the list the moment it starts, and a small nudge or a bounce at the bottom must not flash the button. 100pt is about two one-line bubbles. A list shorter than the screen is never away from the bottom, so an empty or short channel shows no button.
- **When it hides.** As soon as the list comes back within that distance, whether by the user's scroll, by a send (which already returns to the bottom), or by the button itself.
- **New messages while scrolled up.** The list does not follow them (behavior 4). A message added below grows the distance, so the button shows if it was not already showing. It carries no unread count; that is out of #150's scope.
- **Tap.** The list scrolls to the bottom with UIKit's animated `setContentOffset` and pins there, so it follows new and streaming messages again, as after a send. `MessageListScrollController` pins before the animation starts, skips its layout-time restoration while the animation runs (restoring the old anchor would stop it), and settles on the exact bottom when the animation ends, as rows measured on the way can move it. A drag during the animation unpins as usual; an update during it stops the animation and lands on the bottom at once. Already at the bottom, it just pins.
- **Where its state lives.** Whether the list is away from the bottom is UIKit presentation state, like the pinned state, so it stays out of the Store. `MessageListScrollController` recomputes it after each scroll, layout, update, and pin, outside its own adjustments, and reports only changes through a closure. `ChannelBodyViewController` writes it to `JumpToLatestPresentation.isVisible`, which the hosted button reads, and turns the hosting view's user interaction and accessibility elements off while it is hidden. SwiftUI's `accessibilityHidden` inside the hosted view left the hidden button in the accessibility tree, so UI tests still found it.
- **Placement.** A fourth `UIHostingController` in `ChannelBodyViewController`, sized to its content (`sizingOptions = .intrinsicContentSize`), centered horizontally, its bottom 8pt above the composer view's top edge, the reply bar's spacing. The composer view includes the reply bar, so the button rises above it, and the composer sits on the keyboard layout guide, so the button follows the keyboard, including an interactive dismissal. Its `safeAreaRegions` is empty. It floats over the list; the rows scroll behind it, and the list's bottom inset does not change.
- **Default look.** The kit's glass button, like the composer's + button: a 44pt circle with `GlassSurface` tinted `composerFieldBackground`, the SF Symbol `arrow.down` (`ChatIcon.jumpToLatest`) in `composerFont`, tinted `composerButtonTint`. No new theme value: the slot covers any other look.
- **Animation.** Showing and hiding fade and scale between 50% and full size with the composer's 0.25s smooth animation. The view stays in the hierarchy while hidden, so its size and the hosting view's do not change mid-transition; hidden, it takes no touches and is hidden from accessibility.
- **Accessibility.** VoiceOver reads the default as "Jump to latest". A host view labels its own controls.
- **Demos.** Lumen uses the default: its theme's `composerButtonTint` gives the arrow its ink color, and its design source shows no other look to measure.
- **Slot.** `jumpToLatestButton { jump in … }` replaces the button. The closure receives the action that scrolls to the newest message, a plain `() -> Void`, so `Button(action: jump)` works directly; a context value was set aside because the action is the only thing a button needs, and the visibility stays with the package. Returning no view hides the button: an empty view gives the hosting view no size. The package keeps when it shows, the placement, and the animation around the host's view, as the message signals keep their actions around slots ("슬롯과 동작"). The view is centered; a host that wants another horizontal position is not covered yet. The host's view adopts the screen's environment like the composer's host views ("입력창 커스터마이즈" → "Environment"); nothing is written between it and the view.

### Question to top

By default a send pins the list to the bottom, and the list follows the answer as it grows (behaviors 1–2). An AI chat instead moves the user's question to the top of the list and lets the answer fill the space below it. `ChannelView.messageScrollBehavior(_:)` chooses one of the two: `MessageScrollBehavior.followsLatest`, the default and today's behavior, or `.questionToTop`.

- **Names.** `followsLatest` says what the list does after a send, as in a messenger. `questionToTop` names the AI chat pattern by what the user sees: their question goes to the top. Its doc comment says the "question" is any message the user sends from the composer. It is a public enum like `MessageRowContext.GroupPosition`, set on the view and stored in `ChannelSlots` like `messageBubbleLayout`.
- **Which row.** A send from the screen's composer path asks for the move: text, attachments, and `ComposerContext.send(text:)` all go through it. The first update after the send that adds a pending row of the current user's carries the question; adapter rule 15 puts it in the next snapshot. If one update adds several, the last one wins. `MessageListContent.sentRowID(after:)` finds it. Until it arrives, the list does what every send does: it pins to the bottom. A drag before it arrives cancels the request, as the user has taken over.
- **Where it goes.** The row's top edge goes 16pt below the visible top (`ScrollAnchor.sentRowTopSpacing`). That is the list's own top inset, so the row sits where the list's first row sits, and the first message of an empty channel does not move. The move happens inside the update that adds the row (`ScrollAnchor.sentRowAtTop(id:in:)` becomes the anchor before the settle), so the row is first drawn already at the top and the older rows jump up without animation, as the send's pin does today.
- **The space below.** Moving the last row to the top needs more room than the content has. `MessageListScrollController` adds it as the collection view's `contentInset.bottom`, apart from the composer and keyboard inset in `additionalSafeAreaInsets`. `ScrollAnchor.spaceBelowContent(bringingRowAt:toTopOf:)` computes it as the amount that makes the furthest offset equal to the offset that puts the row in its place: `max(0, (rowMinY − 16 − topInset) − (contentHeight + bottomInset − viewportHeight))`, where `bottomInset` leaves the space out. It is recomputed in every settle pass and after every layout, so:
  - **As the answer grows**, the content grows and the space shrinks by the same amount. The furthest offset stays where it was, so the question does not move.
  - **When it reaches 0**, the answer has reached the visible bottom. The space is then dropped for good: later growth or shrinking does not bring it back.
  - **The keyboard and the composer** change `bottomInset`, and the space changes by the opposite amount, so the question stays at the top with the keyboard up or down while the space lasts. Once the answer fills the viewport and the space is dropped, a keyboard that goes down later lets the question slide down, as in any list.
  - **Older pages added above** move the row and the end of the content by the same height, so the space does not change.
  - **Scrolling** does not change it: it depends on the row and the end of the content, not on the offset. The user can scroll up and come back down to the question.
  - **The next send** removes it before pinning, so the pin does not land on blank space. The new question gets its own.
  - **The row goes away** (a removed failed message): the space is dropped.
- **Following.** After the move the list is not pinned. It keeps the question's row in place like any visible row (rule 1 in "규칙", behavior 4), so the answer grows below it without moving it and the list does not follow it past the visible bottom. Once the answer is 100pt past, `isAwayFromBottom` turns on and the jump-to-latest button shows as usual. The space counts toward the furthest offset, so while there is space, the question at the top is the bottom: no button shows, and a drag that ends there pins the list.
- **Pinned again.** A drag that ends at the bottom, or the jump-to-latest button, pins the list as before. While the space remains, the bottom is the question at the top, so nothing moves. Once the space is gone, a pinned list follows the answer, as a messenger does.
- **Default.** With `.followsLatest` none of this happens: no request, no space, and a send pins as before.
- **Where its state lives.** The request, the question's row, and the space are presentation state in `MessageListScrollController`, like the pinned state. The Store and the Reducer do not change.
- **Demos.** Lumen uses `.questionToTop`; QuickStart turns it on with `QUICKSTART_QUESTION_TO_TOP_DEMO=1` ("검증").

### 검증

1번(바닥에서 시작), 3번(늦게 도착한 이전 페이지가 붙어도 보이던 메시지가 그대로), 맨 위 페이지까지 읽기는 데모 앱 UI 테스트가 확인한다. 데모 샘플 백엔드는 3번을 잴 수 있도록 이전 페이지를 늦게 돌려주고, 샘플 메시지에 1·2·3·4·10 줄과 저절로 줄바꿈되는 문단을 섞어 추정 높이가 크게 틀리게 한다. 3번은 바닥에 있을 때, 위로 올려 둔 때, 빠르게 튕겨 페이지보다 먼저 맨 위에 닿았을 때를 따로 잰다. 위로 올려 둔 때는 첫 메시지까지 저절로 읽지 않는지도 본다. 2·4번은 데모의 Assistant 채널로 잰다. 이 채널은 답장을 단어 단위로 자라게 보내고, UI 테스트가 바닥에서는 답장을 따라가는지, 위로 올려 둔 동안에는 보던 메시지가 그대로인지 잰다. `testJumpToLatestButtonReturnsToTheNewestMessage` checks the jump-to-latest button: none at the bottom, one above the composer after scrolling up, and the newest message back in view with the button gone after a tap. Its show/hide rule is a unit test on `ScrollAnchor.Geometry`. `testQuestionToTopKeepsTheQuestionAtTheTopWhileTheAnswerStreams` checks question to top with `QUICKSTART_QUESTION_TO_TOP_DEMO=1`, where the Assistant channel answers each sent text with a numbered list that streams in and is taller than the screen: the sent message lands near the top with no jump-to-latest button, stays there while the answer streams below it, and the list does not follow the answer past the visible bottom, so the button shows. The default behavior stays covered by the tests above. The row choice and the space are unit tests on `MessageListContent` and `ScrollAnchor`.

### 고르지 않은 대안

- 회전한 리스트(Telegram, exyte/Chat): 최신이 offset 0 이 되어 위쪽 삽입이 저절로 맞는다. 아직 재지 않은 이전 행이 레이아웃 순서상 보이는 행 뒤에 오므로 추정 높이가 틀려도 화면이 밀리지 않는다. 하지만 컨텍스트 메뉴, 접근성 순서, 스크롤 인디케이터, 키보드 inset 을 뒤집힌 상태에 맞춰야 하고, 호스트가 슬롯에 넣은 뷰도 뒤집힌 컨테이너 안에 놓인다. 또 위로 올려 둔 동안 최신 쪽에서 자라는 새 메시지와 스트리밍 답장에 같은 보정이 반대쪽에서 필요해진다. 스트리밍은 제품 방향 4번(AI Agent UI)의 중심이라 이 비용이 더 자주 든다.
- 모든 행의 높이를 미리 재는 커스텀 레이아웃(Signal): 갱신 직후의 레이아웃이 곧 최종이라 반복 보정이 필요 없고, offset 은 `UICollectionViewLayoutInvalidationContext.contentOffsetAdjustment` 로 옮긴다. 대신 화면 밖 행까지 SwiftUI 레이아웃을 한 번 더 돌리고, 내용·폭·글자 크기가 바뀔 때마다 다시 재는 캐시를 둬야 한다. 지금 방식으로 맞추지 못하는 경우가 생기면 이것으로 옮긴다.
- SwiftUI 안의 보정: 위 세 방법. 모두 실패했다.

## 정체성

`channel` 도 Store 를 정하는 입력이다. `NavigationSplitView` 의 detail 처럼 같은 자리에서 `channel` 만 바뀌면, `@State` 가 옛 Store 를 유지해 새 헤더 아래 옛 채널의 메시지가 보인다. 그래서 안쪽 뷰의 `.id` 는 백엔드와 `channel.id` 를 함께 쓴다. 덮어쓰기 init 은 백엔드가 없으므로 `channel.id` 만 쓴다. 공통 규칙은 [ARCHITECTURE.md](../../../ARCHITECTURE.md) 7절.

## 커스터마이즈

**슬롯은 public 값만 받는다.** `MessageRowState` 는 `internal` 이므로 슬롯 클로저에 넘기지 않는다. 메시지 슬롯은 `ChatMessage` 와, 행 위치처럼 슬롯이 알아야 할 값을 담은 **슬롯 문맥 값**을 받는다. 슬롯 문맥 값은 public 범주의 하나다([ARCHITECTURE.md](../../../ARCHITECTURE.md) 2절 표). 도메인 사실이 아니라 화면이 파생한 표시 정보라서 Core 가 아니라 UI 타겟에 둔다. `MessageRowContext` 는 `isMine` 과 `groupPosition`(`.single` / `.first` / `.middle` / `.last`)을 싣는다. 슬롯은 열둘이다. `channelHeader` 는 내비게이션 바 앞쪽의 채널 사진과 이름을 바꾸거나 숨긴다(아래 "헤더 크기", "헤더 숨기기"). `channelEmptyState` 는 메시지가 없는 채널의 "No messages" 를 바꾼다(아래 "Empty channel"). `messageRow` 는 날짜 구분선을 뺀 행 전체를, `messageContent` 는 사용자 메시지의 말풍선만 바꾼다. `messageContent` 를 쓰면 이름, 사진, 시각, 수신 확인은 그대로 남는다. `messageAvatar`, `messageSenderName`, `messageTime` 은 말풍선 둘레의 사진, 이름, 시각을 하나씩 바꾸거나 숨긴다(아래 "보낸 사람 사진, 이름, 시각"). `messageBubbleBackground` 는 텍스트 말풍선의 모양과 채우기만 바꾼다(아래 "말풍선 배경"). 슬롯은 아니지만 `messageBubbleLayout(insets:maxWidth:)` 는 같은 텍스트 말풍선의 안쪽 여백과 최대 너비를 바꾼다(아래 "말풍선 여백과 너비"). `messageAccessory` 는 아무것도 바꾸지 않고 말풍선 아래에 뷰를 덧붙인다(아래 "말풍선 아래 덧붙이기"). `messageReplyQuote` 는 답장 말풍선 위의 원본 인용을 바꾸거나 숨긴다(위 "답장"). `messageDateSeparator` 는 그날 첫 메시지 위의 날짜 구분선을 바꾸거나 숨긴다(아래 "날짜 구분선"). `jumpToLatestButton` 은 위로 올려 둔 동안 입력창 위에 뜨는 최신으로 돌아가기 버튼을 바꾸거나 숨긴다(위 "스크롤" → "Jump to latest"). 입력창 슬롯은 따로 있다(아래 "입력창 커스터마이즈", 답장 줄은 위 "답장").

`onAttachmentSelected` is called with the attachment and its message when a default attachment view is tapped. The host decides whether to open, download, or preview it; the package does none of these. Without the callback, attachments are not buttons. It is not called for pending or failed messages (see "행"). Attachments drawn by custom content and row slots are the slot's own views, so the slot handles their taps.

### 슬롯과 동작

**슬롯은 외형만 바꾸고, 동작은 패키지가 슬롯 바깥에 붙인다.** 메시지 행의 동작은 실패한 메시지의 Retry / Remove, 길게 누르기 메뉴, 더블탭, 그리고 답장을 여는 스와이프다. 패키지는 이 동작을 행 단위에서, 슬롯이 돌려준 뷰를 감싸 붙인다. 기본 행, `messageContent`, `messageRow`(타입별 등록 포함) 중 어느 경로로 그려도 같은 동작이 붙는다. 슬롯 작성자가 동작을 연결할 일이 없으므로 외형을 바꾸다가 기능을 잃지 않는다. 고객 에이전트가 슬롯 문서만 보고 써도 마찬가지다(제품 방향 2번). 채널 리스트의 `channelRow` 가 행을 바꿔도 스와이프 동작을 유지하는 것과 같은 규칙이다.

- **슬롯 안의 컨트롤이 먼저다.** 슬롯이 그린 버튼과 자체 제스처는 패키지가 붙인 행 동작보다 먼저 탭을 받는다. 행 동작은 슬롯이 처리하지 않은 영역에만 걸린다. 실패한 메시지의 탭이 지금 내용 슬롯의 버튼에 양보하는 것과 같다. The long press is the exception, as the system menu is today: after 0.5s it takes the touch from a button inside the bubble ("Long-press overlay" → "The press"). A tap still goes to the button.
- **호스트는 신호마다 하나씩 체이닝 메서드로 끼워 넣는다.** The one exception is the long press, which has two presentations: the menu (`messageContextMenu`) and the overlay (`messageLongPressOverlay`, "Long-press overlay"). When both are set, the overlay wins. SwiftUI 의 `toolbar` 처럼 호스트는 그 신호에 넣을 항목만 선언하고, 언제 어떻게 보여 줄지는 패키지가 정한다. 메뉴나 확인 창이 뜨는 신호는 `.contextMenu` 와 같은 SwiftUI `Button` 을 받고, 더블탭처럼 화면이 없는 신호는 동작을 바로 실행하는 클로저를 받는다(아래 "메시지 신호와 동작"). 패키지 고유의 항목 타입이나 프로토콜은 두지 않는다.
- **패키지 항목은 신호마다의 기본값이다.** 호스트가 그 신호를 정하지 않으면 패키지 기본값이 들어간다. 실패한 메시지의 탭이면 Retry / Remove 이고, Retry 는 지금처럼 `canSend` 일 때만 보인다. 호스트가 신호를 정하면 그 신호의 기본값만 바뀐다. `context.defaultItems` 한 줄로 기본값을 다시 넣을 수 있고, 빼면 쓰지 않는 것이다. 외형만 바꾸다가 기능을 잃는 것과 달리, 신호를 정하면서 기본값을 뺀 것은 호스트가 고른 결과이기 때문이다.
- **슬롯에 동작을 넘기지 않는다.** `MessageRowContext` 는 행 위치를 알리는 `Hashable` 값으로 두고 클로저를 싣지 않는다. 그래서 슬롯이 Retry 버튼을 자기가 원하는 자리에 직접 두는 것은 지금 제공하지 않는다. 동작이 필요한 곳은 신호 클로저뿐이고, 신호 클로저는 문맥 값과 분리된 `MessageActionContext` 로 동작을 받는다.
- **예외는 입력 슬롯이다.** 입력창처럼 사용자의 입력 자체를 바꾸는 슬롯은 보내기, 첨부 고르기, 지금 보낼 수 있는지 같은 동작과 상태를 넘겨받는다. 표시용 메시지 슬롯과 달리 동작이 곧 그 슬롯의 내용이기 때문이다. 넘기는 값은 `ComposerContext` 다(아래 "입력창 커스터마이즈"). 키보드를 따라가는 배치(위 "입력창")는 그때도 패키지가 맡는다.

실패한 메시지의 탭, 길게 누르기, 더블탭, 답장 스와이프, "Reply" 접근성 동작은 모든 경로에 붙는다. 스와이프는 셀 밖의 컬렉션 뷰 인식기라 슬롯이 끊을 수 없고, 가로로 움직일 수 있는 스크롤 뷰(SwiftUI `ScrollView` 포함)나 UIKit 컨트롤에서 시작한 드래그는 슬롯이 먼저 받는다. SwiftUI `Button` 은 UIKit 컨트롤이 아니어서 그 위에서 시작한 드래그도 Messages 처럼 스와이프가 된다. 탭은 그대로 버튼이 받는다.

#### 길게 누르기 메뉴의 범위

**메뉴는 행이 아니라 말풍선에 붙인다.** iOS 의 메뉴는 붙은 뷰를 통째로 들어 올린다. 행에 붙이면 사진, 이름, 시각, 옆의 빈 공간까지 함께 떠올라 행 전체가 하이라이트되고, 들어 올리는 순간 행 전체가 한 번 어두워졌다가 옆으로 밀려 깜빡여 보였다. 그래서 `MessageRow` 가 말풍선(기본 내용이나 `messageContent` 슬롯의 뷰)과 시스템 메시지에 메뉴를 붙인다. 슬롯이 돌려준 뷰를 패키지가 감싸는 규칙은 그대로다. `messageRow` 슬롯은 말풍선이 어디인지 패키지가 모르므로 그 행 전체에 붙인다. 더블탭과 실패한 메시지의 탭은 지금처럼 행에 남는다. 탭은 빈 공간에서 받아도 들어 올릴 것이 없기 때문이다. 답장을 여는 스와이프는 행 전체에 걸리며 "답장" → "Starting a reply" 에 있다. 텍스트 말풍선의 모양과 채우기는 `messageBubbleBackground` 로 바꾼다(아래 "말풍선 배경").

#### Long-press overlay

A host can replace the system long-press menu with its own views around the pressed bubble, such as an emoji bar above it and a list of actions below it. The package lifts the bubble, dims the list and the composer, places the views, and dismisses them. The host draws the content of the two views; the package draws the card around the actions below. The system menu stays the default.

```swift
ChannelView(channel: channel)
    .messageLongPressOverlay { message, context in
        if message.sendingStatus == nil {
            EmojiBar { emoji in
                react(to: message, with: emoji)
                context.dismiss()
            }
        }
    } below: { message, context in
        context.defaultItems
        Button("Report") {
            report(message)
            context.dismiss()
        }
    }
```

- **API.** One modifier, `messageLongPressOverlay(above:below:)`, with two `@ViewBuilder` closures that receive the message and a `MessageOverlayContext`. Neither label has a default, so both closures are always written; a closure may return nothing (`below: { _, _ in }`). One modifier rather than two keeps the replacement of the menu a single, visible decision. Reactions themselves stay with the host: picking an emoji calls the host, which draws reactions with `messageAccessory`. The sample checks `sendingStatus` for the same reason as the double tap: a pending or failed message is not on the backend yet.
- **`MessageOverlayContext`** is a slot context value like `MessageActionContext`, not `Hashable`. It carries the same state and actions as `MessageActionContext` (`isMine`, `canResend`, `canReply`, `canCopy`, `resend()`, `remove()`, `reply()`, `copy()`) plus `dismiss()`, and `defaultItems`: the long-press menu's default buttons. A separate type rather than adding `dismiss()` to `MessageActionContext`, because `dismiss()` means nothing for the double tap and the failed-message dialog that share that type. The cost is that a later action is added to both types; their doc comments point at each other.
- **Dismissing after an action.** The default items dismiss after acting. A host button does not dismiss by itself and calls `context.dismiss()`, because the package cannot tell a button that finishes the interaction from one that does not (an emoji bar's "more" button that expands it). The first line of the modifier's doc comment says so, and every sample calls it.
- **Who draws what.** The `above:` view is placed as it is. The `below:` view is placed inside one card that the package draws: the design system's glass surface in a rounded rectangle, with the closure's buttons stacked as rows. The package applies a row button style to the card's content, so `context.defaultItems` and a host `Button` look the same. A host button with its own `.buttonStyle` keeps that style, and a view that is not a button is placed in the stack as it is. Card and row values are under "Values" below.
- **Nothing to show, nothing opens.** The rule for menus applies: the results of both closures are counted with `Group(subviews:)`, and when both are empty (an emoji-only host on a failed message, or only `defaultItems` for an attachment with no text when replying is not possible), the long press does nothing and the bubble carries no "Show actions" action.
- **Relation to `messageContextMenu`.** The long press is one signal with two presentations. While the overlay is declared, it is what the long press shows and `messageContextMenu` has no effect, whatever the modifier order. Both doc comments say so, and a DEBUG build logs once when both are set. The failed-message tap and its dialog stay as they are. System messages get neither, as today.
- **What is lifted.** The overlay draws the bubble again from the same row state, the same view the menu lifts ("길게 누르기 메뉴의 범위"): the default bubble or the `messageContent` slot's view, or the whole row for a `messageRow` slot, where the sender side is the row's leading or trailing edge by `isMine`. A redraw rather than a picture of the cell, so the copy keeps Dynamic Type, dark mode, and a streaming text's latest value. The copy is proposed the cell bubble's width. A slot's view-local `@State` (an expanded "Read more", a playing video) starts fresh in the copy, so the `messageContent` and `messageRow` doc comments say that state which must survive the overlay comes from the message or the host's model. While the copy is lifted, the cell's bubble is hidden through `MessageListCellPresentation`, keyed by message id, so reuse does not lose it and the bubble does not appear twice.
- **The press.** A long-press recognizer on the collection view, next to the swipe recognizer, rather than a SwiftUI gesture on the bubble. A SwiftUI button in a hosted cell starts its own recognizer at touch down, which would keep the long press from recognizing, so the long press recognizes together with the recognizers inside the cells and, when it fires, cancels the ones that tracked the same touch. It needs what the swipe needed (ARCHITECTURE.md §1): it must fire over buttons inside the bubble (a tappable attachment, a slot's button) and cancel their touch so releasing does not also tap them, and once the overlay opens the same touch must not scroll the list or move the row. A SwiftUI gesture in the hosted cell cannot cancel the collection view's pan or a child button's touch. The recognizer uses the system menu's 0.5s minimum, does not begin while the swipe or the scroll is moving, and cancels both when it fires. It fires only inside a registered bubble frame (below), so it fires only on a bubble that has something to show, as the menu does today. The double tap and the failed-message tap are unchanged.
- **How it is presented.** `ChannelContent` holds the open overlay as presentation state, the pressed message's id, outside the Store, like the failed-message dialog. It draws the overlay over `ChannelBody`: the list and the composer. The navigation bar, which holds the header and the back button, belongs to the host's `NavigationStack` and stays undimmed. The keyboard stays up; it sits above the overlay, and the overlay's views fit above its top. Typing while the overlay is open still goes to the draft under the dim.
- **Data flow.** `ChannelContent`'s open id is the single source; everything else is derived from it or reported up through closures, like `onFailedMessageSelected`.
  - *Down.* The open id goes down as `ChannelBody`'s `liftedMessageID` to the collection view controller, which sets `MessageListCellPresentation.liftedMessageID` after the first frame report, so the matching cell hides its bubble with opacity; the bubble stays laid out and keeps reporting its frame.
  - *Something to show.* Emptiness is known only inside a SwiftUI body, so the cell decides it. It resolves both overlay closures with `Group(subviews:)`, the way `LongPressMenu` resolves the menu today. The same result decides the cell's "Show actions" action.
  - *Up.* A cell with something to show reports its bubble's frame, in the cell's coordinate space, through a closure on the presentation; a cell with nothing to show reports none. `MessageLongPressController` keeps these cell-local frames by id in a plain dictionary, not in observed state. A frame is not cleared when its content disappears: a reconfigured cell's old content disappears after the new content reported, and a reused cell re-sends its last frame for its new id. The recognizer finds the cell under the touch, converts that cell's stored frame at lookup (so a moved cell is never stale), and calls an "open" closure with the message id when the touch is inside; `ChannelContent` sets its state from it. Without `messageLongPressOverlay`, cells register nothing and the recognizer is not attached.
  - *Frame for the overlay.* While the overlay is open, the controller reports the lifted bubble's frame in `ChannelBody`'s coordinate space, the space the overlay is drawn in, after each layout pass, through another closure, only when the frame changed. Layout can run inside `updateUIViewController`, so the report is deferred to the next main-actor turn, as the page request is. It reports nothing when the cell leaves the screen.
- **Live updates.** The overlay keeps the message id and reads everything from the current state on every update: the row from `store.rows`, the context from the signals, and the bubble's frame from the controller. So the copy follows its cell when the list moves under it (a new message on a pinned list, a streaming reply growing), the group is fitted again when the bubble's height changes, and the default items follow `canReply` and `canResend`. The dim takes every touch, so the list does not scroll while the overlay is open.
- **Position.** The copy sits on its cell's bubble, scaled from the bubble's top sender-side corner; a `messageRow` slot's whole row is not scaled. Gaps and fitting use the scaled frame, which `OverlayPlacement` computes from the bubble frame. The above view sits above the bubble and the card below it, both aligned to the bubble's sender side. The above view is proposed the screen width minus the transcript's side insets; the card has the measured width. A view wider than the space on that side slides inward until it is inside the insets. When the group does not fit between the top of the list and the keyboard's top (or the bottom safe area), the whole group moves just enough to fit. When the bubble is taller than the space the two views leave, the copy is cut at that height with a fade at its bottom edge. When the two views alone do not fit, the card scrolls.
- **Dismissal.** A tap on the dim, `context.dismiss()`, the default items after acting, the escape gesture under VoiceOver, the message leaving the list or turning into a system message, a change of the overlay's size (rotation, a window resize), the lifted cell leaving the screen, and the channel content disappearing (the host pushes a screen from its header) all dismiss it. The undimmed navigation bar keeps working while the overlay is open. The user's dismissals (the dim, `dismiss()`, the default items, escape) reverse the lift toward the bubble's current frame and then remove the overlay; the others remove it at once, because the bubble it would return to is gone, moved, or off the screen. Only one overlay is open at a time.
  - *Implemented as.* The cell hides its bubble from the first frame report for the open id until the overlay is removed, so the bubble is never missing before the copy is drawn or while it returns. Before the lift and while it reverses, the copy sits on the cell's bubble; lifted, it sits at its fitted position, so the group's move to fit is part of the same animation.
- **Values.** Measured from the iOS 26 system menu on the simulator (iPhone 17 Pro, light and dark), as the design source has no overlay; recorded in [docs/design/messages/README.md](../../design/messages/README.md) as new. The dim is the same tint in light and dark, with no blur, and is a `ChannelTheme` color, `overlayDim`, so a host can change it. Lift, spacing, and card come from the same measurement; the above view's gap mirrors the card's. Lift and dismissal use SwiftUI's default animation, not a custom duration. The haptic is the swipe's light impact, so both message gestures feel the same.
  - *Chosen in #141, as the measurement does not cover them.* The card's glass is tinted with `ChannelTheme.background`, like the header's name capsule, and has no padding above or below its rows. A row's label is `messageFont` in `composerText`, `failedIndicatorTint` for a destructive role, 16pt in from the card's side, with `replyBarCloseBackground` behind it while pressed. When the two views alone fill the space, the cut bubble keeps 44pt (a row's worth) in view so the user still sees which message they act on. The dim also covers the strip behind the default header's name capsule, which stays undimmed above it like the navigation bar.
- **VoiceOver.** The long press is not the only way in: a bubble with something to show carries a "Show actions" accessibility action that opens the overlay. The open overlay is modal: focus moves to the first element of the above view, or of the card when the above view is empty; the dim is a "Dismiss" button; and nothing in the list or the composer is reachable (`ChannelBody` is hidden from accessibility while the overlay is drawn).
- **Tests.** Placement is a pure function, `OverlayPlacement`, from the bubble frame, the two views' sizes, the container's bounds and insets, and the sender side to the three frames. Its unit cases: no above view, no below view, the bubble at the top and at the bottom edge, a view wider than its side, a bubble taller than the space, and two views taller than the screen. The "still presentable" rule (the message is in the rows and is not a system message) is a pure check on the rows. The UI test covers what needs the gesture: a long press over an attachment button opens the overlay without opening the attachment, a drag after it opens neither scrolls nor swipes, a tap on the dim dismisses it, and a default item acts and dismisses.
- **MCP.** The modifier, `MessageOverlayContext`, and the theme color are new public symbols with doc comments, so the catalog is regenerated and the `ChannelView` placement example gains the overlay. Showcase gets an emoji-bar demo.
- **Steps.** #141 implements this in one step: the recognizer, the overlay and its placement, the context, the modifier, the theme color, docs, MCP, the Showcase demo, and the tests above.

### 메시지 신호와 동작

```swift
ChannelView(channel: channel)
    .messageContextMenu { message, context in
        context.defaultItems
        Button("Report") { report(message) }
    }
    .failedMessageActions { message, context in
        context.defaultItems
    }
    .onMessageDoubleTapped { message, context in
        guard message.sendingStatus == nil else { return }
        react(to: message)
    }
```

**네 층을 섞지 않는다.**

| 층 | 뜻 | 여기서 |
|---|---|---|
| 신호 | 사용자가 무엇을 했나 | 길게 누르기, 실패한 메시지의 탭, 더블탭 |
| 보여 주기 | 무엇이 뜨나 | 메뉴, 오버레이, 확인 창, 없음 |
| 동작 | 무슨 일이 일어나나 | 호스트의 동작, 패키지의 `resend()` / `remove()` / `copy()` |
| 상태 | 메시지가 지금 어떤가 | `sendingStatus` |

Retry / Remove 는 동작 층이다. 보내기와 같은 패키지의 기능이고, 백엔드 경계(`resendMessage(id:)` / `removeFailedMessage(id:)`)까지 이어지며, 실패한 메시지에만 뜻이 있다. 어느 신호나 화면에도 묶이지 않는다. 그래서 호스트는 이 동작을 어느 신호에든 넣거나 뺄 수 있다.

**신호마다 체이닝 메서드가 하나다.** The long press is the exception, with the menu and the overlay; the overlay wins ("Long-press overlay"). 시스템 메시지는 어떤 신호도 받지 않는다. 내용 슬롯과 같은 범위다. 이름은 SwiftUI 관례를 따른다. 버튼을 받는 메서드는 받는 것을 명사로 부르고(`contextMenu`, 확인 창의 `actions`), 화면 없이 동작만 받는 메서드는 `on…` 으로 부른다. `on…` 은 동작을 쓰는 자리로 읽히므로, 버튼을 돌려줘야 하는 클로저에 붙이면 동작을 쓴 호스트 코드가 알기 어려운 컴파일 에러로 막힌다.

| 메서드 | 보여 주기 | 정하지 않았을 때 |
|---|---|---|
| `messageContextMenu` | 메뉴 | 실패한 메시지는 Retry(`canResend` 일 때만)와 Remove, 그 밖은 Reply(`canReply` 일 때만)와 텍스트가 있으면 Copy |
| `messageLongPressOverlay` | 오버레이 (overrides `messageContextMenu`) | Not set: the long press shows the menu |
| `failedMessageActions` | 확인 창(+ Cancel) | Retry(`canResend` 일 때만)와 Remove. 디자인 원본의 확인 창 |
| `onMessageDoubleTapped` | 없음 | 아무것도 하지 않고 인식기도 붙이지 않는다 |

- **메뉴와 확인 창의 항목은 글자만 쓴 SwiftUI `Button` 이다.** 클로저는 `@ViewBuilder` 로 `Button` 을 돌려준다. 확인 창은 아이콘을 그리지 않고 제목과 `role` 만 쓴다. 아이콘을 단 `Button` 은 확인 창에서 접근성 요소가 두 겹으로 잡히므로, 기본 항목과 예시는 글자만 쓴다.
- **`MessageActionContext` 가 상태와 동작을 싣는다.** `isMine`, `canResend`(실패했고 지금 보낼 수 있음), `canReply`("답장" → "When replying is possible"), `reply()`, `canCopy`(텍스트가 비어 있지 않음), `resend()`, `remove()`, `copy()`, 그리고 그 신호의 기본 항목 `defaultItems` 다. 메시지 상태는 클로저가 받는 `message.sendingStatus` 로 읽는다. `resend()` 와 `remove()` 는 Store 에 `.resendMessage` / `.removeFailedMessage` 를 보낸다. 실패하지 않은 메시지에는 Reducer 와 어댑터가 아무것도 하지 않는다([backend-boundary.md](../backend-boundary.md) 어댑터 규약 17). `copy()` 는 텍스트를 일반 붙여넣기 판에 쓰는 UI 동작이라 Store 를 거치지 않는다. 클로저를 싣는 값이라 `Hashable` 이 아니고, `MessageRowContext` 와 섞지 않는다.
- **신호를 정하면 그 신호의 기본값만 바뀐다.** `context.defaultItems` 를 넣으면 기본 항목이 상황에 맞게 그대로 들어가고, 빼면 호스트가 전부 정한다. 실패한 메시지의 두 신호에서 모두 `resend()` / `remove()` 를 빼면 사용자가 그 메시지를 복구할 수 없다. 문서 주석이 이를 경고한다.
- **아무 항목도 없으면 그 신호를 붙이지 않는다.** 기본값이 비면(텍스트 없는 첨부 메시지의 길게 누르기 등), 또는 호스트 클로저가 버튼을 하나도 돌려주지 않으면 메뉴도 확인 창도 뜨지 않는다. 호스트 클로저의 결과는 `Group(subviews:)` 로 풀어 개수를 본다.
- **더블탭은 정했을 때만 알아챈다.** 두 번 탭을 알아채려면 한 번 탭을 잠시 기다려야 한다. 그래서 정하지 않으면 인식기 자체를 붙이지 않고, 실패한 메시지의 탭은 바로 반응한다. 정하면 실패한 메시지의 탭은 두 번 탭이 아님이 확정된 뒤에 반응한다. 메시지 상태와 무관하게 불리므로, 백엔드에 무언가를 보내는 호스트는 `sendingStatus` 를 먼저 본다. 슬롯 안의 버튼과 기본 첨부 버튼은 행보다 먼저 탭을 받는다.
- **앱 고유의 상태는 클로저가 메시지의 `attributes` 나 앱의 모델에서 읽는다.** 패키지가 아는 상태는 `sendingStatus` 하나이고, 어댑터가 정한다. 메시지와 함께 오는 앱 상태(예: 신고됨)는 어댑터가 `message.attributes` 에 싣는다([backend-boundary.md](../backend-boundary.md) 어댑터 규약 22). 그래서 `Report` 항목은 `message.attributes[Moderation.self]?.isReported` 를 보고 `Undo report` 로 바뀔 수 있다. 이 기기에만 있는 상태는 앱의 모델에서 읽는다. `customContent` 는 렌더러를 고르는 값이라 상태용으로 겹쳐 쓰지 않는다. 그 상태를 말풍선 아래에 그리는 자리는 `messageAccessory` 다.
- **붙이는 자리.** 실패한 메시지의 탭, 더블탭, "Reply" 접근성 동작은 `MessageListRow` 가 행 전체에, 슬롯이 돌려준 뷰를 감싸 붙인다. 길게 누르기는 말풍선에 붙는다: 메뉴는 `MessageRow` 가 말풍선에 붙이고("길게 누르기 메뉴의 범위"), 오버레이는 셀이 알린 말풍선 영역에서 컬렉션 뷰의 인식기가 받는다("Long-press overlay"). 확인 창은 셀이 재사용되면 사라지므로 화면(`ChannelContent`)이 띄운다.

### 입력창 커스터마이즈

Three levels, from the smallest change to the largest. A host picks the smallest one that does the job, because each level keeps more of the default behavior.

```swift
ChannelView(channel: channel)
    .composerPlaceholder("Message…")
    .composerLeadingItems { context in
        if context.canOpenCamera {
            Button { context.openCamera() } label: { Image(systemName: "camera") }
                .accessibilityLabel("Camera")
        }
        context.defaultItems
    }
    .composerTrailingItems { context in
        Button { context.openPhotoLibrary() } label: { Image(systemName: "photo") }
            .accessibilityLabel("Photo library")
    }

// Or replace everything:
ChannelView(channel: channel)
    .composer { context in
        AgentComposer(send: { context.send(text: $0) }, isEnabled: context.canSend)
    }
```

**`composerPlaceholder(_:)`** sets the field's placeholder while the user can send. It takes a `String` the host has already localized, like the other text the package draws. While loading, the host's placeholder shows too. When the channel does not allow sending, the design source's "Chat is unavailable in this channel" still replaces it, because it explains the disabled field.

**`composerLeadingItems` / `composerTrailingItems`** put host views on either side of the text field. The package keeps the field, its draft, and the send button.

- **Order and placement.** Leading items, the field, then trailing items. In the default layout, leading items or the attachment button stay outside the field's glass surface; trailing items and the send button are inside. The send button replaces the trailing items while the trimmed draft is not empty. Controls stay bottom-aligned as the field grows. The default bar separates the leading controls from the field by 12pt; trailing controls share the field's surface.
- **Default items.** Setting the leading items replaces the default attachment (+) button; `context.defaultItems` puts it back. Inside an item slot the + button sits in the adopted environment, so there it applies no `.disabled` of its own and takes its enabled state from the copied `isEnabled`, like the host's items. This is the same rule as the message signals ("슬롯과 동작"). Leaving it out removes the + button, which also lets a text-only backend hide attachments. The trailing side has no default items, so its `defaultItems` is empty.
- **Disabled state.** While `canSend` is `false`, the items are disabled like the + button, without the host checking anything. This applies to the item slots only; a `composer` view decides for itself (below). The package sets `isEnabled` in the environment it gives the items rather than applying `.disabled` above them (see "Environment" below).

**`composerItemsInsideField()`** also moves the leading controls into the field's background, so all controls and the field read as one capsule. Trailing items and the send button are already inside in the default layout.

```swift
ChannelView(channel: channel)
    .composerItemsInsideField()
    .composerLeadingItems { context in
        if context.canOpenCamera {
            Button { context.openCamera() } label: { Image(systemName: "camera.fill") }
                .accessibilityLabel("Camera")
        }
    }
```

- **A switch, not a slot.** It takes no arguments; applying it turns the layout on. The background keeps the theme's `composerFieldBackground` and capsule shape, so no new theme value is added. A slot for the background's shape was set aside: the only need found is the items' placement, and a shape slot would add a second way to colour the field next to the theme.
- **What changes.** The host's leading items, or the default + button when they are not set, join the trailing items and send button inside the field. Order and the swap of trailing items for send stay the same. The capsule uses 12pt spacing between items and the field, and gives each item the minimum frame described below.
- **Sizes.** The design source has no such layout, so these values reuse the composer's existing ones.
  - The capsule keeps the field's 43pt minimum height and grows with the field's lines. Items stay bottom-aligned on the last line, as outside the capsule.
  - Inside the capsule the package puts each item in a frame of at least 32 × 32pt, centred, the default icon button's size and the same frame the send button label gets (below). A bare `Image(systemName:)` button is about 20–24pt; without the frame it would sit low in the capsule's rounded end and cross its curve. A larger item grows its frame, and an item taller than the field's minimum height can make the capsule taller.
  - A side has items when its slot renders at least one subview, counted with `Group(subviews:)` as `hostItems` already does; a slot that is set but renders nothing, such as `if context.canOpenCamera { … }` without a camera, counts as no items. While send shows, the trailing side has items.
  - On a side with items, the capsule adds a 2pt inset at the outer end and keeps the items bottom-aligned with no bottom inset. The field drops its 16pt horizontal padding there, and 12pt spacing separates it from the items. On a side without items, a spacer and that spacing preserve the field's 16pt inset.
  - The inside-field layout uses 12pt outer horizontal padding, compared with 28pt in the default bar (16pt while the keyboard is up). Its capsule width stays the same when send appears.
- **Unchanged.** The disabled state, the placeholder, the environment rule, and the bar's `composerBackground` behind everything. Tapping the capsule's padding does not focus the field, as tapping the field's padding does not today.
- **With `composer`.** No effect, like the other item modifiers.

**`composerSendButtonLabel(_:)`** replaces what the send button shows, for example the text "Send" in place of the icon. The package keeps the button.

```swift
ChannelView(channel: channel)
    .composerSendButtonLabel {
        Text("Send").font(.system(size: 16, weight: .semibold))
    }
```

- **Label only.** The closure takes no arguments and returns the label. The package wraps it in the `Button` that sends the trimmed draft, so a host cannot draw a send button that does not send ("슬롯과 동작"). This matches the channel list's `createChannelButtonLabel(_:)`. A slot receiving the send action, for example for a long press that schedules a message, was set aside until such a need appears.
- **When it shows.** As the default send button: while the composer is enabled and the trimmed draft is not empty, in place of the trailing items. It keeps the items' 2pt bottom inset and sits inside the capsule when `composerItemsInsideField()` is applied.
- **Size.** The package puts the label in a frame of at least 32 × 32pt, centred, the default icon button's size. A text label such as "Send" then sits where the icon sits, bottom-aligned on the field's last line like the other items, and its tap target is no smaller than the icon's. A wider or taller label grows the frame.
- **Look.** The label colours itself, as the items do. It is a host view and receives the adopted environment ("Environment" below), which replaces every value above it, so a tint the package set on the button would not reach the label, and a tint set between the environment and the label is the write that rule forbids. A label that wants the theme's colour reads `composerButtonTint` from `@Environment(\.channelTheme)`.
- **Accessibility.** The default icon is labelled "Send". A host label is read as it is drawn, so a text label needs nothing more and an icon-only label sets its own `.accessibilityLabel`, as with `createChannelButtonLabel`.
- **With `composer`.** No effect.

**`composerStopButton(isResponding:action:)`** turns the send button into a stop button while the host reports a response in progress, such as an assistant's streaming answer.

```swift
ChannelView(channel: channel)
    .composerStopButton(isResponding: assistant.isAnswering(channelID: channel.id)) {
        assistant.stopAnswering(channelID: channel.id)
    }
```

- **Screen state from the host.** Whether a response is in progress is not a backend fact the package reads; the host passes it on every update, like a newer `channel`. It travels in `ChannelSlots` to `ComposerPresentation.isResponding` and `onStop` on each update, so the button follows the host's observable state as it changes. The package stores and detects nothing. A modifier was chosen over a `ChatChannel` value because it is screen state, not a channel property.
- **Where it shows.** While `isResponding` is `true`, the stop button takes the send button's place: inside the field's background, in place of the trailing items, in both layouts, whether or not there is a draft. Stop wins over send so a response can always be stopped. It is the package's `IconButton` with `stop.circle.fill` at the send icon's size, tinted `composerButtonTint`, labelled "Stop" for VoiceOver. `composerSendButtonLabel` does not change it, and composer items are hidden while it shows; a host that wants another look draws the whole composer with `composer` from `ComposerContext.isResponding` and `stop()`.
- **While active.** The stop button works even while `canSend` is `false`, since it acts on the host's response, not on sending. The field stays editable and keeps its draft, so the user can write the next message; the return key adds a new line as it always does (the default field has no submit-to-send). Send comes back with the draft once `isResponding` turns `false`. `canSend` and `ComposerContext.send(text:)` are unchanged, so a host control can still send.
- **With `composer`.** No default stop button appears; the host view reads `context.isResponding` and calls `context.stop()`. Lumen does this: it keeps its own bar because the new-chat screen shares it before a channel exists and it has a tool chip, a floating card, and a voice button that the default composer does not draw.

**`composerBackground(_:)`** draws a host view behind the composer in place of the theme's `composerBackground` color, such as a gradient that fades the messages out under a floating composer.

```swift
ChannelView(channel: channel)
    .composerBackground {
        VStack(spacing: 0) {
            LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom)
                .frame(height: 32)
            Rectangle().fill(.white)
        }
    }
```

- **Name.** It shares its name with the theme color it replaces, as SwiftUI's `background(_:)` takes either a style or a view. The modifier is on `ChannelView` and the color on `ChannelTheme`, so the two never meet in one expression. A different name such as `composerBackdrop` would read as a second, separate layer next to the theme color, while there is only one area and one fill.
- **Area.** The view is laid out over the backdrop: from the composer's top edge, the reply bar included, down to the screen's bottom edge ("입력창" → "Composer background"). That area spans the home indicator while the keyboard is down and the space behind the keyboard (about 300pt) while it is up, so its height changes with the keyboard and a gradient's proportional stops move with it: stops that are opaque at 0.45 leave the strip behind the composer mostly clear while typing. The example therefore fades over a fixed height above a solid fill. It does not reach above the composer: the list's bottom inset already stops at the composer's top, so a fade drawn there would cover the newest message at rest. A host that wants the messages to fade gives its composer top padding and a fill that is clear at the top, as Lumen does.
- **Touches.** The host view takes none; the backdrop keeps taking touches below the composer as with the theme color, and the composer's controls above it keep their taps.
- **Default and `composer`.** Without it the theme color paints the same area, as before. It works with the default bar and with a `composer` view alike, and the theme color is not drawn under the host view.
- **Environment.** The host view adopts the screen's environment like the other composer host views ("Environment" below), so a gradient built from dynamic colors follows the color scheme.

**`composer`** replaces the whole bar. The host view owns the draft and every control, so `composerPlaceholder`, `composerLeadingItems`, `composerTrailingItems`, `composerItemsInsideField`, and `composerSendButtonLabel` have no effect alongside it. The package does not disable the host view: it reads `context.canSend` and decides which controls to disable, because some, such as a stop button for a streaming reply, must keep working while sending is unavailable. The package still places the view on the keyboard layout guide, paints `composerBackground` (the theme color or the `composerBackground(_:)` view) behind it down to the screen edge, insets the list by its height, shows the frozen banner, and returns the list to the bottom when the host calls `send`. The attachment menu and pickers stay attached around the host view, so `context.openAttachmentMenu()` and the other openers work there too. A custom composer that needs a stop button draws it from `context.isResponding` and `context.stop()`, set with `composerStopButton(isResponding:action:)` (product direction 4); stopping a reply is still the host's action against its own backend.

**`ComposerContext`** is the input-slot value ("슬롯과 동작"): state and actions, not `Hashable`, like `MessageActionContext`. Every composer slot receives the same type. The composer's root view builds it from `ComposerPresentation`, the way `MessageSignals` builds `MessageActionContext`.

- **Who presents the pickers.** Showing the menu or a picker is presentation state, so it stays out of the Store. The composer's root view owns the four flags (menu, camera, photo library, files) and `AttachmentPickers` takes them as bindings. It is attached to the whole composer bar, or around the host's `composer` view, not to the + button, so the openers work whether or not the + button is present. The menu's popover then rises from the composer bar instead of the button; on iPhone the menu is an action sheet either way.

| Member | Meaning |
|---|---|
| `canSend` | `ChannelState.canSend`: the Reducer accepts a send now. `false` while loading, during a Retry, and when the channel does not allow sending |
| `isUnavailable` | The channel itself does not allow sending (`canSendMessage == false`), as opposed to the list still loading. A custom composer uses it to explain the disabled state |
| `canOpenCamera` | The camera exists and the host app declares `NSCameraUsageDescription` ("입력창" → camera availability). `openCamera()` does nothing otherwise |
| `isResponding`, `stop()` | The `isResponding` and action passed to `composerStopButton(isResponding:action:)`. `stop()` does nothing while `isResponding` is `false` and works while `canSend` is `false` |
| `send(text:)` | Sends `.sendText` with the text trimmed; empty text and calls while `canSend` is `false` do nothing, as in the Reducer. It sends the given text, not the default field's draft |
| `openAttachmentMenu()`, `openCamera()`, `openPhotoLibrary()`, `openFiles()` | Present the default menu or one picker. Picked items go through the same preparation and alert as the + button |
| `defaultItems` | The package's items for that slot: the + button on the leading side, nothing on the trailing side and in `composer` |

- **Environment.** Host views in the composer receive the screen's whole environment, as message cells do, so they can read `channelTheme`, the host's own keys, and fonts. It is applied around each host view only. The package's own controls keep reading just the theme ("입력창" → "Environment"). The package must not apply `.disabled` or any other environment write between the adopted environment and the host view, because that is how the composer's own `.disabled(true)` earlier leaked back into the representable's `isEnabled`. For the item slots and the send button label, the disabled state is written into the copied value instead (`isEnabled = canSend`; the label shows only while it is `true`); a `composer` view gets the environment unchanged. #103 verifies this with a UI test that freezes and unfreezes a channel and then taps both a host item and the + button re-inserted through `defaultItems`, next to the existing `testComposerRecoversAfterTheChannelUnfreezes`. If the problem comes back anyway, host views receive only the theme and the context, and this section and the slot docs say so.
- **What stays out.** Drafts kept across screens and editing. Replies are covered in "답장". Replacing only the send button was left out at first, which made a messenger demo replace the whole composer for a "Send" label; `composerSendButtonLabel(_:)` now covers it.
- **Where it is verified.** Showcase demos show each level. The disabled-state test above needs a host item, so it lives in QuickStart under [ARCHITECTURE.md](../../../ARCHITECTURE.md) section 9's rule for slots that UI tests must verify.

### 말풍선 배경

```swift
ChannelView(channel: channel)
    .messageBubbleBackground { message, context in
        TailBubble(isMine: context.isMine, hasTail: [.single, .last].contains(context.groupPosition))
            .fill(context.isMine ? AnyShapeStyle(gradient) : AnyShapeStyle(.gray.opacity(0.2)))
    }
```

`messageBubbleBackground` replaces only what is drawn behind a text bubble, so a host can give it a tail, a gradient, or a material while the package keeps drawing the text, its padding, the width limit, attachments, the time, the receipt, and the sending status. A theme value was set aside: `ChannelTheme` is `Equatable`, and shapes and shape styles are not, so a theme could only offer a fixed list of styles.

- **Which bubbles.** Text bubbles drawn by the default content: a text message, the text below attachments, and the unsupported-content placeholder. Media thumbnails, the media grid, and file bubbles keep their default look; images usually keep plain corners, and in a message with attachments the text bubble is the last part, so a tail there ends the message. A `messageContent` or `messageRow` slot draws its own bubble, so this slot does not apply there. System messages are excluded.
- **What it receives.** The message and `MessageRowContext`, so the shape can follow `isMine` and `groupPosition` (for example a tail only on the last bubble of a run, which is `.single` or `.last`) and the fill can follow app state in `message.attributes`.
- **Size.** The returned view fills the bubble's frame, which the text and its padding decide; the background does not change the bubble's size. `messageBubbleLayout(insets:maxWidth:)` changes that padding and the width limit (below). The package reserves no room for a tail. A tail drawn outside the frame overlaps the spacing beside the bubble: 12pt to the avatar or 4pt to the time on the incoming side, the row's margin on the outgoing side. Keep a tail within that, or use a shape that fits inside the frame.
- **Text colour.** The text still uses `ChannelTheme.incomingMessageText` / `outgoingMessageText`. A host that draws a dark or busy fill sets those in the theme so the text stays readable.
- **Gestures.** The double tap and the failed-message tap belong to the row ("슬롯과 동작"), so the bubble's shape does not change where they land. The long-press menu is attached to the bubble ("길게 누르기 메뉴의 범위"); its preview is the bubble's rectangle with the system's corner radius, not the custom shape.

### 말풍선 여백과 너비

```swift
ChannelView(channel: channel)
    .messageBubbleLayout(insets: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16), maxWidth: 280)
```

`messageBubbleLayout(insets:maxWidth:)` changes the space between a text bubble's edge and its text, and the bubble's maximum width, while the package keeps drawing the bubble. Before it, a host that wanted roomier bubbles could only redraw every message with `messageContent`, which has no per-message fallback, so attachments lost their default views.

- **Why a modifier, not a theme value.** Layout numbers stay in views ("값을 두는 위치" in AGENTS.md), and `ChannelTheme` holds colours and fonts. The values are stored per view instance in `ChannelSlots.messageBubbleLayout`, like the slots, and reach `TextMessageContent` through `MessageBubbleContent`, so the long-press overlay's copy of the bubble gets them too.
- **Which bubbles.** The same as "말풍선 배경": a text message, the text below attachments, and the unsupported-content placeholder. Media, file bubbles, and the reply quote keep their 240pt widths; system messages and `messageContent` / `messageRow` views are untouched.
- **Partial values.** Both parameters are optional. `nil` keeps the default or what an earlier call set, so `.messageBubbleLayout(insets:)` and `.messageBubbleLayout(maxWidth:)` can be chained. The defaults are the design source's: 9pt vertical, 14pt horizontal, 240pt maximum width, and they are unchanged when the modifier is not used.
- **Size.** `maxWidth` limits the whole bubble, insets included. The minimum height follows the insets: one 22pt line plus the top and bottom insets, which is the 40pt of the default bubble.
- **Tail.** The default fill draws its tail inside the frame, so the package adds the tail's 7pt below the bottom inset on the last bubble of a run. A `messageBubbleBackground` view gets no tail room and fills the insets exactly. A host shape with a large corner radius needs insets that clear it: Lumen's 22pt rounded rectangle uses 12pt vertical and 16pt horizontal insets.

### 말풍선 아래 덧붙이기

```swift
ChannelView(channel: channel)
    .messageAccessory { message, context in
        if let reactions = message.attributes[Reactions.self] {
            ReactionBadge(reactions)
        }
    }
```

`messageAccessory` adds a view below the bubble without replacing the bubble or the row, such as reaction badges or a "reported" note. The data that drives it travels in `ChatMessage.attributes` ([domain-models.md](../domain-models.md)).

- **Placement.** The view sits 4pt below the bubble, or below the outgoing receipt/sending status when present, aligned to the sender-side edge. The 4pt is the existing accessory spacing; the reference has no accessory, so the nearest component's value is reused. Host avatars and times retain their alignment with the bubble, independent of the accessory. Receipts and sending status remain in their separate line below outgoing bubbles. The row grows by the accessory's height; run spacing is unchanged. Negative top padding can overlap the bubble, accounting for any intervening receipt/status line.
- **Which rows.** It applies to every non-system row drawn by the default bubble row, with the default content or a `messageContent` slot (typed or untyped). A `messageRow` slot draws the whole row, so the package does not know where its bubble is; that row draws its own accessory. System messages get none, the same range as the content slot.
- **Every state.** It is called for pending and failed messages too. A host that shows something only for sent messages checks `message.sendingStatus`.
- **Nothing means no space.** When the closure returns no view, for example when the message has no reactions, the row has no extra spacing. The result is resolved with `Group(subviews:)`, as the signal menus are.
- **Updates in place.** The closure reads the message the row holds. A changed attribute or any other field in a snapshot with the same id changes `MessageRowState`, so the row is reconfigured and the accessory redrawn.
- **Part of the row for taps, not for the menu.** The accessory is inside the view `MessageListRow` wraps, so double tap and the failed-message tap work on it like the rest of the row. The long-press menu is on the bubble alone ("길게 누르기 메뉴의 범위"), so a long press on the accessory opens nothing and the menu preview leaves it out. Buttons inside the accessory take their taps first ("슬롯과 동작"). There is no separate tap callback; a host that wants a tappable badge uses a `Button`.

### 보낸 사람 사진, 이름, 시각

```swift
ChannelView(channel: channel)
    .messageAvatar { message, _ in
        Initials(name: message.sender?.name)
            .frame(width: 32, height: 32)
    }
    .messageSenderName { message, _ in
        if channel.memberCount != 2, let name = message.sender?.name {
            Text(name).font(.caption)
        }
    }
    .messageTime { _, _ in
        EmptyView()
    }
```

The default row draws three parts around the bubble: the sender's picture, the sender's name, and the time. Each part has one slot, so a host changes one part and keeps the rest of the default row. Before these slots, the only way to change one part was `messageRow`, which also gives up the bubble, the grouping layout, and the sending status.

**Rules shared by the three slots.**

- **Empty hides the part.** When the closure returns no view, the part and the spacing that belongs to it are removed. The result is resolved with `Group(subviews:)`, as the accessory is. There is no option or theme flag for visibility (parent issue #109's decision). `Color.clear` is a view, not "no view", so it keeps its space.
- **Which rows.** Non-system rows drawn by the default bubble row, with the default content or a `messageContent` slot (typed or untyped). A `messageRow` slot, typed or untyped, draws the whole row, so none of the three is called for it. System messages have no picture, name, or time, so none is called.
- **What they receive.** The message and `MessageRowContext`, like the other message slots. The sender is `message.sender`, which can be `nil`; the time is `message.createdAt`, which the host formats. A slot that needs the channel, for example to tell a 1:1 channel from a group, captures it from the code that built the `ChannelView`. `MessageRowContext` gains nothing.
- **Look.** The package does not apply the theme's `senderNameFont` / `senderNameText`, `timeFont` / `timeText`, or avatar placeholder colors to a slot's view. A slot that wants them reads `@Environment(\.channelTheme)`; hosted cells receive the screen's environment ("스크롤").
- **Layout stays the package's.** Grouping, which rows carry each part, run spacing, and where each part sits beside the bubble do not change. Only what is drawn in that place changes. The row's height follows the slot views.
- **Gestures and updates.** The parts are inside the view `MessageListRow` wraps, so they behave like the accessory: the message signals cover them, buttons inside them take their taps first, and a changed message with the same id redraws them.

**`messageAvatar`** replaces the picture beside someone else's messages.

- **Called on every incoming row, shown on some.** The default row draws the picture on the `.single` and `.last` rows of a run and leaves an empty column of the same width on the `.first` and `.middle` rows. With the slot, the package calls it on every incoming row and hides the view on the `.first` and `.middle` rows (zero opacity, left out of accessibility). A hidden view keeps its size, so the column is as wide on every row of the run and the bubbles line up, whatever size the host draws (user, 2026-10-14). A host therefore returns a view of the same size for every message; a size that depends on the message misaligns the bubbles of a run.
- **Visibility follows the position only.** A message without a sender is always `.single` (grouping needs a sender id), so its row shows the slot's view. The slot decides what to draw for `message.sender == nil`.
- **Size.** The package gives the view no frame; its own size decides the column's width and height. The default picture is 26pt. The view keeps the default's place: 12pt from the bubble, bottom-aligned to the bubble's bottom edge with the 2pt lift.
- **Empty.** Returning no view removes the column and its 12pt spacing on every row, so the bubbles start at the row's leading margin. Return no view for every message of a screen, for example in a 1:1 channel; returning it for some messages only misaligns those rows.
- **Cost.** The view is built on hidden rows too. A picture loaded from a URL is requested for those rows as well.

**`messageSenderName`** replaces the name above someone else's run.

- **Rows.** Called where the default draws the name: incoming rows at `.single` and `.first`. It is called when `message.sender` or its name is `nil` too; the default draws nothing there.
- **Placement.** Above the bubble, 4pt from it, with the default name's 12pt leading inset.
- **Empty.** Returning no view removes the name and its 4pt spacing, so the bubble moves up. The example above hides names in a 1:1 channel and keeps them in groups.

**`messageTime`** adds a custom time beside the bubble; default per-message times are omitted.

- **Rows.** Called for sent messages (`sendingStatus == nil`) at `.single` and `.last`, incoming and outgoing. Pending and failed messages show sending status below their bubble, and do not call the time slot.
- **Placement.** Incoming times sit 4pt to the right of the bubble, flush with its bottom edge. Outgoing times sit 4pt to its left, lifted by the existing 2pt inset. Host pictures and times use the bubble-bottom alignment guide, so a receipt or accessory below it does not pull them down.
- **Empty.** Returning no view removes the time and its spacing. Outgoing receipts remain below the bubble.
- **What stays out.** The receipt, the sending status, and date separators (see "날짜 구분선"). The default `hh:mm` formatter is not exposed; a slot that keeps the format and changes the style formats `createdAt` itself.

**Where the rule lives.** Which rows carry each part is derived on `MessageRowState`, which already does this for the default row, and is tested there. `MessageBubbleRow` takes the three slot views as optional `AnyView` values next to the accessory and keeps every layout constant.

### 날짜 구분선

```swift
ChannelView(channel: channel)
    .messageDateSeparator { separator in
        Text(separator.day.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
```

`messageDateSeparator` replaces the separator above the first message of each day, or hides it. Before this slot a host could only change its colors and font through the theme, so an app that wants no separators (an AI chat, for example) could not remove them.

- **What it receives.** `MessageDateSeparatorContext`: `date` is the day's first message's `createdAt`, and `day` / `time` are the default separator's texts ("Today", "10:13 PM"; formats in "행"). A host restyles them without formatting the date again, or formats `date` itself for other wording or a locale. The row already carries this value as `dateSeparator`, so the slot gets what the default view draws. It is not a `ChatMessage` and `MessageRowContext` pair like the message slots: the separator belongs to the day, and the first message's id and group position say nothing about it. It carries no actions.
- **Which rows.** Every row that starts a day, the same rows as the default, including rows drawn by `messageRow` (that slot never drew the separator) and system messages. Unsent messages still never start a day. When a separator appears does not change.
- **Empty hides it.** Returning no view removes the separator and the 10pt spacing between it and the message below. The result is resolved with `Group(subviews:)`, as the accessory is. The row keeps its spacing above it (0 at the top of the list, 10pt otherwise), the same as a row that does not start a day. There is no option or theme flag for visibility (#147's decision: a slot, not a hide-only option).
- **Look and placement.** The view is centered in the row's width above the message. The package applies none of `dateSeparatorFont`, `dateSeparatorText`, or `dateSeparatorBackground` to it; a slot that wants them reads `@Environment(\.channelTheme)`. The theme values stay for the default.
- **Gestures and updates.** The separator is outside the view the message signals wrap, as the default is, so a double tap or long press on it does nothing. A row rebuilt with a new separator (a new day, a new year) redraws it.

### 헤더 크기

`channelHeader` places the host's view at the navigation bar's leading edge. That toolbar item proposes less width than the content wants, so a picture with a name and a subtitle was clipped down to the picture. The default header avoids this with `.fixedSize()`.

**The package sizes the slot's view like the default header**: it applies `.fixedSize()` to whatever the slot returns. One rule then covers both, and a host does not add it. The view takes its ideal width and height.

- **Long text.** The package does not truncate a long title, for the slot or for the default header. A host that needs a limit gives its view an explicit width (`.frame(width:)`) with a line limit.
- **Height.** The bar does not grow. A picture, a name, and a one-line subtitle must show in full.
- **Where it is verified.** A rendering claim in the toolbar needs a UI test, so it is verified in QuickStart under [ARCHITECTURE.md](../../../ARCHITECTURE.md) section 9's rule for slots that UI tests must verify. The implementing step gives QuickStart's channel screen a `channelHeader` slot with a picture, a name, and a subtitle, checks that all three are visible, and adds the slot to section 9's list.
- **Docs.** `channelHeader(_:)`'s doc comment says the view is shown at its ideal size.

### Empty channel

A channel with no messages shows "No messages" in the list's area (`.empty`, "Input 과 Effect"). `channelEmptyState { ... }` replaces it, so a host can draw its own view, such as an AI chat's suggestion cards above the composer.

- **Where.** Between the header and the composer ("입력창" → "Empty channel"), centered. The view is offered that whole area, so a `Spacer` moves it to the top or the bottom. The composer stays below it and works: `canSend` is `true` in `.empty`, as before. Both the slot's view and the default placeholder are drawn there; before this slot, the placeholder was centered on the whole screen and could sit behind the keyboard.
- **When.** Only in `.empty`. The view goes away with the first snapshot that holds a message, including the pending message an adapter reports right after a send ([backend-boundary.md](../backend-boundary.md) adapter rule 15). This is the Reducer's existing `.empty` ↔ `.loaded` transition; the slot adds no state. Loading and error keep the package's views.
- **The closure takes the screen's `ComposerContext`** (user, 2026-10-18). A view that sends, such as a suggestion card, needs the screen's own send path. A host on a third-party adapter has no contract that a message it sends some other way shows on the open screen. `send(text:)` goes through the composer's path (`.sendText`, scroll to bottom), and the picker actions open the composer's pickers, so an empty chat's own attach button works without a context built outside the screen. This follows the input-slot exception in "슬롯과 동작". The context is built from `ComposerPresentation`, the same source as the composer's, and read in the hosted view's body, so `canSend` and `isUnavailable` stay live (loading, a freeze). `defaultItems` is empty, as in `composer(_:)`. The channel itself is not passed; the host built the screen with it and can capture it.
- **Disabled state.** The package applies no `.disabled` to the view. A host disables its own buttons while `composer.canSend` is `false`, as the doc comment says; `send(text:)` and the pickers do nothing then anyway.
- **Where it is verified.** A layout claim, so QuickStart covers it: the sample data has an empty channel ("Book club"), and with the customization demo on, QuickStart draws its own view at the bottom of the area with a button that sends through the context. `testEmptyStateSlotStaysAboveTheComposerUntilTheFirstMessage` checks it stays above the composer with the keyboard up and goes away with the first message; `testEmptyChannelDragDismissesTheKeyboardAndTheSlotSends` checks a drag on blank space dismisses the keyboard and the button's send shows the message and removes the view; `testSwitchingTheOpenChannelToAnEmptyOneShowsTheEmptyState` swaps the open channel for the empty one on the same screen (`QUICKSTART_SWITCH_DEMO=1`), the path that crashed; `testEmptyChannelShowsNoMessagesByDefault` checks the default.

### 헤더 숨기기

A host can hide the header and put its own control at the leading edge, such as a menu button that opens a list of past chats. Before this, the slot's view was always wrapped in a leading toolbar item, so the host either put its button inside `channelHeader` (documented as the channel's picture and name) or left an empty item next to its own.

- **Empty hides it.** A `channelHeader` closure that returns no view adds no toolbar item at all. The result is resolved with `Group(subviews:)`, as the other slots that hide are. A present but empty `ToolbarItem` still takes the leading spot and its glass background, so the item is left out rather than drawn empty. The toolbar decides before it builds its items, so `ChannelContent` resolves the slot a second time in a background, draws none of it, and keeps whether it was empty in `@State`. A slot whose closure result changes between empty and not adds or removes the item; emptiness kept in the host view's own `@State` is not seen.
- **The host's item.** The host adds a `.toolbar` item on `ChannelView` with `.topBarLeading` placement. The package does not add a leading-items API (#152's decision: the header slot hides, nothing new).
- **The name capsule.** The default channel name below the bar (the `safeAreaInset` capsule) is drawn only when no `channelHeader` is set, so an empty slot shows no capsule and the list's top inset is 0, as for any slot. Nothing about it changes.
- **The default header.** With no `channelHeader`, nothing changes: the avatar and the name capsule are drawn in the top safe-area inset (see "Header inset").
- **Where it is verified.** QuickStart hides the header and adds its own leading button with `QUICKSTART_HIDDEN_HEADER_DEMO=1` (ARCHITECTURE.md section 9); `testEmptyChannelHeaderLeavesTheLeadingSpotToTheHost` checks that the button sits right after the back button with no empty item between them and that it takes taps. Showcase's slot demo hides it in the "Bubble" mode with a menu at the leading edge, and Lumen puts its drawer button there.

### 커스텀 내용

**바뀌는 내용과 커스텀 내용을 막지 않는다(제품 방향 3·4번).** 확인한 결과는 이렇다.

- 스트리밍으로 텍스트가 늘어나도 같은 `id` 의 행이 갱신될 뿐이라, 테마와 메시지 슬롯이 그대로 적용된다. 행이 길어질 때 바닥에 붙어 있는 것은 스크롤 모델이 맡는다.
- 메시지 내용 슬롯이 `ChatMessage` 전체를 받으므로, 호스트는 기본 말풍선 대신 무엇이든 그릴 수 있다.
- App-defined values travel in `ChatMessage.customContent`. `messageContent(Value.self)` registers a bubble content view for that value type; `messageRow(Value.self)` registers a whole row view. These registrations belong to each `ChannelView` instance. The last registration for a matching type wins, then the untyped slot is used, then the default view. A whole-row renderer takes precedence over any content renderer. Content renderers apply to non-system fallback content, matching the existing slot contract; system rows can be replaced with a whole-row renderer. Types without a renderer use `ChatMessage.content` as their fallback.
- `ChatMessage.attributes` never takes part in this matching. A poll message that is also reported carries the poll in `customContent` and the report state in `attributes`, so `messageRow(Poll.self)` still matches. Attributes are part of `MessageRowState` equality through the message, so a changed attribute updates the row in place.
- `MessageRowState` includes custom content in equality and hashing, while deriving grouping and date separators from the ordinary message fields. A custom payload change therefore updates the row even when its fallback text is unchanged. Row renderers can ignore the default bubble layout and group context, for example for a thinking indicator.

Example: the app owns both the custom value and its view. The repository supplies messages carrying that value, and the screen registers the corresponding renderer:

```swift
struct Thinking: Hashable, Sendable {
    var text: String
}

let message = ChatMessage(
    id: "thinking",
    createdAt: Date(),
    content: .text("Thinking"),
    customContent: Thinking(text: "Checking the details")
)

ChannelView(channel: channel)
    .messageRow(Thinking.self) { thinking, _, _ in
        Text(thinking.text)
    }
```

Use `messageContent(Thinking.self)` instead to keep the default bubble row's sender, time, and receipt layout. Updating `Thinking.text` in a new snapshot with the same message ID updates the existing row.

## 테스트

| 대상 | 더블 |
|---|---|
| `ChannelReducer` | 없음. Includes `.startReply` / `.cancelReply` acceptance, the reply id carried by both send paths, the check again at `.attachmentsPrepared`, and every rule that clears it |
| `ChannelStore` | `ChannelRepositorySpy`, and `AttachmentPreparationDouble` for the `prepareAttachments` and `discardAttachments` closures |
| `AttachmentPreparer` | None. Copies real files in the test's temporary folder and checks names, kinds, all-or-nothing failure, cleanup after cancellation, `discard(_:)`, and cleanup after a failed move |
| `MessageRowState` 파생 | 없음. `ChatMessage` 배열을 직접 만들어 넣는다. Includes the date separator's day, time, and date, and which rows carry the picture, the name, and the time, and on which rows the avatar slot is shown or hidden |
| `ChannelSlots` | None. Public slot modifiers are exercised with app-defined values to verify type matching, registration order, fallback, and view-instance ownership, and that the accessory, the bubble background, the avatar, the sender name, and the time are stored per view instance and receive the message and context, and the date separator its `MessageDateSeparatorContext`. The bubble layout is stored per view instance, and a later call keeps the value it leaves out. The composer's placeholder, items, items-inside-field switch, send button label, stop button, and whole composer are stored per view instance, and so is the jump-to-latest button, which receives the action. The scroll behavior defaults to `followsLatest` and is stored per view instance |
| `ScrollAnchor` | 없음. 스크롤 geometry 값을 직접 만들어 넣는다. Includes when the list counts as away from the bottom for the jump-to-latest button: past the distance, at it, and short content. For question to top: the anchor that puts a sent row at the top, and the space below for short and long content, a growing answer, the keyboard, an older page added above, and a row near the top that needs none |
| `MessageListContent.sentRowID(after:)` | None. Rows are built from messages. Checks a new pending row of the user's, the last of several, and that an existing row, someone else's row, and a sent (not pending) row are not chosen |
| `ComposerContext` | None. Checks that `send(text:)` trims and ignores blank text, and that every opener does nothing while the user cannot send and `openCamera()` without a camera. `stop()` reaches the host only while responding, also while the user cannot send |
| `ComposerPresentation.placeholderText`, `trailingControl(hasDraft:)` | None. Checks the default, the host's placeholder while loading and sending, and that the unavailable text wins; that send shows only while enabled with a draft and stop wins while responding |
| `MessageRowState.Attachments` 파생, grid cell corners | None. Attachments are built directly |
| `MessageSignals` | None. Checks each signal's default items for sent, pending, failed, text-less, and system messages, that a host closure replaces only its own signal and receives the context, that double tap has an action only while set and never for system messages, and that resend runs only for a failed message while the user can send |
| `MessageSwipeController.offset(forTravel:)` | None. Checks that the row follows the finger up to the threshold, moves a third as far past it, stops at its limit, and ignores travel toward the leading edge |
| `OverlayPlacement` | None. Checks the scale from the sender-side corner, an unscaled whole row, no above view, no card, the bubble at the top and at the bottom edge, a view wider than its side and wider than the screen, a bubble taller than the space, and two views taller than the screen |
| `MessageLongPressOverlay.presentableRow(id:in:)` | None. Checks that the overlay stays only for a user message in the rows, not for a system message or a removed one |
| `MessageSignals` overlay | None. Checks that the overlay's context carries the long press's state and default items, that its actions do not dismiss and `dismiss()` does, and that overlay views exist only while set and never for system messages |

The bridge, hosted cells, and composer are display-only. Sending text, the attachment menu, Retry / Remove on a failed message, the default long-press menu, the long-press overlay (opening, a default item acting and closing it, a tap on the dim, a long press over an attachment button that does not open it, a drag after it opens that neither scrolls nor swipes, a bubble that scrolled into a reused cell, and Retry / Remove on a failed message; QuickStart turns it on with `QUICKSTART_OVERLAY_DEMO=1`, as it replaces the menu that other tests use), double tap, the message accessory, the date separator slot replacing the default, the header slot shown in full, a host composer item and the re-inserted + button recovering after an unfreeze, the stop button replacing send while the sample assistant answers and ending its answer, the jump-to-latest button, question to top (`QUICKSTART_QUESTION_TO_TOP_DEMO=1`), and the disabled composer are verified in QuickStart; the camera is not, because the simulator has none. The collection view controller manages UIKit presentation state; domain state and backend effects remain in `ChannelStore`. Scroll calculations remain in `ScrollAnchor`, and actual rendering and scrolling are verified in QuickStart.

The default visual layout now follows the measured iOS 26 Messages reference in [design-system.md](../design-system.md#messages-layout-reference). Store, reducer, grouping, and backend contracts are unchanged. Custom slots retain their existing placement contracts.
