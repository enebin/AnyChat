# 도메인 모델

[ARCHITECTURE.md](../../ARCHITECTURE.md) 4절의 하위 문서다. `AnyChatCore/Domain` 의 값 타입을 정한다. 백엔드 경계 프로토콜은 [backend-boundary.md](backend-boundary.md) 에 있다.

## 원칙

UI 가 그리는 데 필요한 **의미**만 담는 값 타입이다. 모두 `nonisolated` 이고 `Sendable`, `Hashable` 이다.

- **채널 종류로 나누지 않는다.** Group / Open / Feed 같은 구분은 백엔드의 분류이지 UI 의 분류가 아니다. 모델은 `ChatChannel` 하나다. 백엔드가 제공하지 않는 기능의 필드는 `nil` 이다(예: 안 읽은 수를 세지 않는 채널의 `unreadMessageCount`).
- **종류 대신 할 수 있는 일을 적는다.** "알림 채널이다" 대신 `canLeave == false`, `notificationLevel == nil` 로 적는다. UI 는 이 값을 보고 액션을 띄울지 정하므로 백엔드의 분류를 알 필요가 없다.
- **필드는 지금 화면이 쓰는 것만 둔다.** 새 화면이나 새 채널 종류가 필요로 할 때 추가한다. 선택적 필드를 기본값과 함께 추가하면 소스 호환이 유지된다.
- **이름에 `Chat` 접두어를 붙인다.** 백엔드 SDK 와 함께 import 해도 `User` 같은 이름이 모호해지지 않는다.
- **값의 의미는 어댑터가, 표시 모양은 UI 가 정한다.** "SDK 기본 이름인가", "샘플 커버인가", "밀리초인가 초인가" 같은 백엔드 사정은 어댑터가 정규화해 없앤다. 시각 문자열, 개수 축약, 미리보기 단어, 이름이 없을 때 멤버 이름으로 제목을 만드는 규칙은 UI 에 남는다.

## `ChatChannel`

| 필드 | 타입 | 뜻 |
|---|---|---|
| `id` | `String` | 채널 식별자 |
| `name` | `String?` | 사용자가 정한 이름. 없으면 `nil` |
| `coverURL` | `URL?` | 사용자가 정한 커버. 없으면 `nil` |
| `createdAt` | `Date` | 생성 시각 |
| `memberCount` | `Int?` | 멤버 수. 세지 않으면 `nil` |
| `members` | `[ChatSender]` | 알려진 멤버 |
| `lastMessage` | `ChatMessage?` | The latest sent message. Pending and failed messages are not put here ([backend-boundary.md](backend-boundary.md) adapter rule 21) |
| `typingUsers` | `[ChatSender]` | 지금 입력 중인 사용자 |
| `unreadMessageCount` | `Int?` | 안 읽은 메시지 수 |
| `unreadMentionCount` | `Int?` | 안 읽은 멘션 수 |
| `notificationLevel` | `NotificationLevel?` | `.all` / `.mentionsOnly` / `.off`. 바꿀 수 없으면 `nil` |
| `isBroadcast` | `Bool` | 운영자만 보낼 수 있다 |
| `isFrozen` | `Bool` | 보낼 수 없게 잠겼다 |
| `canLeave` | `Bool` | 사용자가 나갈 수 있다 |
| `canReply` | `Bool` | The current user can reply to messages in this channel. The adapter sets it when its backend links a message to the one it answers. Defaults to `false`, so a backend without replies shows no reply action. Sending still depends on `canSendMessage` |
| `canSendMessage` | `Bool` | The current user can send messages now. The adapter folds every backend rule into this one value: a frozen channel, a broadcast channel for a non-operator, a muted member. Defaults to `true` |

## `ChatSender`

A participant that can send messages, including a person, bot, or agent. Channel membership and typing indicators use the same value. `ChatUser` remains a deprecated type alias for source compatibility.

`id`, `name: String?`(없으면 `nil`), `profileImageURL: URL?`(사용자가 정한 사진이 없으면 `nil`).

## `ChatMessage`

채널 리스트 미리보기와 채널 화면의 목록에 필요한 만큼만 둔다.

- `id: String`, `sender: ChatSender?`, `createdAt: Date`.
- `sender` 는 보낸 사람이다. 백엔드가 쓴 메시지(시스템 메시지 등)는 `nil` 이다. 행에 이름과 사진을 그려야 하므로 id 만이 아니라 `ChatSender` 를 싣는다. 처음에는 `senderID: String?` 였으나 릴리스 전이라([ARCHITECTURE.md](../../ARCHITECTURE.md) 2절) 교체했다.
- `content: Content` — `.text(String)`, `.system(String)`, `.file(FileKind)`, `.files`, `.unsupported`. `FileKind` 는 `.image` / `.gif` / `.video` / `.audio` / `.voice` / `.other`. 파일 종류 판별은 어댑터가 한다. 채널 화면은 `.text` 와 `.system`, 그리고 첨부가 있는 메시지를 그린다. 첨부 메타데이터가 없는 `.file` / `.files` 와 `.unsupported` 는 자리표시 행으로 그린다.
- Ordinary messages combine a text body (`content: .text`) with `attachments: [ChatAttachment]`. The new `init(text:attachments:)` accepts text-only, attachment-only, or mixed content. The corresponding custom-content initializer retains both the attachments and the app-defined value. System notices remain `.system(String)`; existing initializers and all `Content` cases remain available, so existing exhaustive switches still compile. Existing initializers create an empty attachment list. Attachments belong to ordinary messages; system notice rendering does not use them.
- `customContent: ChatMessage.CustomContent?` preserves an app-defined Swift value conforming to `Hashable` and `Sendable`. The generic initializer accepts the value directly; `value(as:)` retrieves it using its original type. Equality and hashing include both the concrete type and its value, so in-place updates reach the Store. `content` remains the fallback for channel previews and rows without a matching custom renderer. The existing initializer and `Content` cases stay unchanged. Custom data contains no View or backend SDK objects.
- `attributes: ChatMessage.Attributes` carries app-defined state, such as "reported" or "pinned", apart from `customContent`. It holds at most one value per type, each `Hashable` and `Sendable`, so a message can carry a custom renderer value and several state values together. Read and write by type: `message.attributes[Moderation.self]?.isReported`, `message.attributes[Moderation.self] = value`, and `= nil` removes it. Attributes never pick a renderer; typed renderers still match on `customContent` alone. They are separate rather than folded into one collection with `customContent`, because a renderer needs exactly one value to match on, and a collection would need a rule for which of several values wins. Each value is boxed in `CustomContent` and keyed by its type, so equality and hashing include every type and value regardless of insertion order, and a changed attribute updates the row in place. Initializers do not take attributes; set them after creating the message, like `sendingStatus`. No default view reads them, the channel list preview included; only host closures and slots do.
- `replyTo: ReplyReference?` — the message this one answers, or `nil` for an ordinary message. The adapter fills it from its backend's reply link (see "`ChatMessage.ReplyReference`" below). It is part of equality and hashing, so a change to the quoted original reaches the row.
- `receipt: Receipt?` — `.sent` / `.delivered` / `.read`. 수신 확인을 제공하지 않으면 `nil` 이다. 내가 보낸 메시지에만 표시하는 규칙과 옵션 스위치는 UI 가 적용한다.
- **같은 메시지가 제자리에서 바뀌면 같은 `id` 로 다시 온다.** 수정, 수신 확인 변화, 스트리밍으로 늘어나는 텍스트가 모두 그렇다. 새 메시지가 아니라 같은 행의 갱신이다. 스트리밍 전용 필드는 두지 않는다(제품 방향 4번은 막지 않는지만 본다).
- `sendingStatus: SendingStatus?` — `.pending` / `.failed`. `nil` means the message has reached the backend, or it was not sent from this device. The adapter owns this value and carries it in snapshots; the package keeps no local copy of an outgoing message ([backend-boundary.md](backend-boundary.md#어댑터-규약) 15–20). A pending message that is sent keeps its `id` and only loses its status, so its row updates in place. `receipt` applies only after the status is `nil`. Upload progress is not modelled.

## `ChatMessage.ReplyReference`

What a reply shows of the message it answers: `messageID: String`, `sender: ChatSender?`, `content: ChatMessage.Content`, `attachments: [ChatAttachment]`, and `isUnavailable: Bool`. `Hashable` and `Sendable`, like the other models.

- **A summary, not the original message.** It carries what a quote draws and nothing else, so a receipt or attribute change on the original does not redraw every reply to it, and the value is not recursive. A quote can be drawn even when the original sits on a page the screen has not read.
- **`content` and `attachments` mean what they mean on `ChatMessage`.** A quote of a custom message uses `content` as its fallback, as the channel list preview does; `customContent` and `attributes` are not copied.
- **`isUnavailable` means the original can no longer be shown**, because it was deleted or the user cannot see it. The adapter then leaves `content` empty and `attachments` empty, and the quote shows the design source's unavailable text. `messageID` stays so the reply keeps pointing at the same message. The initializer always makes an available reference, and `ReplyReference.unavailable(messageID:)` makes one already empty (`.text("")`, no attachments). The fields stay writable, so keeping an unavailable reference empty is the adapter's rule, not one the type enforces.
- **The adapter keeps it current.** When the original is edited or deleted, the adapter sends the reply again with the same `id` and an updated reference ([backend-boundary.md](backend-boundary.md) adapter rule 7).

## `ChatAttachment`

A backend-neutral attachment value: `id: String`, `kind: ChatMessage.FileKind`, `url: URL`, optional `fileName: String`, optional `fileSize: Int64` in bytes, and optional `imageSize: ImageSize` with integer pixel width and height. The adapter supplies file classification, metadata, and usable URLs. The value carries no image object, download task, or loading state. Attachments and their order participate in message equality and hashing.

The default channel row draws attachments as described in [the channel screen](screens/channel.md#행). It uses `kind`, `url`, and `fileName`; `fileSize` and `imageSize` remain for custom slots. Video thumbnails are generated from `url`, so the value needs no separate thumbnail URL. A message content or whole-row slot receives the full message, including its text and attachments. Channel previews use a nonempty text body first, then the attachment kind for a single attachment or the existing multiple-file preview for several.

## `ChatOutgoingAttachment`

A file the user picked to send: `fileURL: URL` (a local `file:` URL), `kind: ChatMessage.FileKind`, and `fileName: String`. The package fills it after copying the picked item into its temporary folder ([channel screen](screens/channel.md#보내기)). **When the file's type is known, `fileName` ends in an extension that matches it**, so an adapter can derive the MIME type from it; there is no separate MIME field. Picked files keep their name; one without an extension gets the preferred extension of its type appended. A Files pick whose type cannot be determined keeps its name as is with `kind == .other`; treat it as `application/octet-stream`. Photo library items and camera captures without a name get a generated one with the extension of their type. Photo library items keep the format they were picked in. A camera photo is saved as JPEG and a camera video as MOV. Converting any of them for a backend is the adapter's job. The package sets `kind` from the file's type: GIF is `.gif`, other images `.image`, movies `.video`, audio `.audio`, everything else `.other`. It never produces `.voice`. The value carries no `Data`, so a large video is never held in memory.

It differs from `ChatAttachment` on purpose. `ChatAttachment` describes a file the backend can serve and may carry metadata the backend computed. An outgoing attachment is only a local file waiting for upload. Once the adapter has the pending message in its snapshot, that message carries ordinary `ChatAttachment` values, usually pointing at the same local file until the upload finishes.
