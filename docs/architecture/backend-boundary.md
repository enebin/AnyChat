# 백엔드 경계와 어댑터 규약

[ARCHITECTURE.md](../../ARCHITECTURE.md) 4·5절의 하위 문서다. `AnyChatCore/Domain` 의 경계 프로토콜과, 패키지 밖의 어댑터가 지킬 규약을 정한다. 경계를 오가는 값은 [domain-models.md](domain-models.md) 에 있다.

## `ChatBackend`

`@MainActor public protocol ChatBackend: AnyObject, Sendable`. 백엔드 하나를 나타내며 앱에서 한 번 등록한다([ARCHITECTURE.md](../../ARCHITECTURE.md) 7절).

- `currentUserID: String?`
- `makeChannelListRepository() -> any ChannelListRepository`
- `makeChannelRepository(channelID: String) -> any ChannelRepository` — 채널 하나의 메시지를 보는 Repository 를 만든다.

화면이 늘면 `make…Repository()` 가 늘어난다.

## 스냅샷 스트림

두 Repository 모두 관찰 결과를 **전체 스냅샷**으로 싣는다.

- **스트림은 스냅샷 값을 싣는다.** 모델이 `Sendable` 이므로 `AsyncStream` 에 그대로 실을 수 있다. 버퍼 정책이 `.bufferingNewest(1)` 이라 이벤트가 몰리면 중간 스냅샷은 버려지지만, 마지막 스냅샷이 전체이므로 손실이 없다.
- **delta 가 아니라 전체 스냅샷인 이유.** SwiftUI `ForEach(id:)` 는 스냅샷 diff 로 삽입과 삭제를 처리하므로 delta 정보가 필요 없다. 어댑터 구현도 단순해진다.
- **스트리밍처럼 자주 바뀌는 내용도 전체 스냅샷으로 싣는다.** 스냅샷이 Store 가 소비하는 속도보다 빨리 오면 중간 것은 버려지고 마지막 것만 남는다. 그래서 화면 갱신 빈도는 MainActor 가 소비하는 속도를 넘지 않는다. 비용은 갱신마다 배열 복사와 행 재계산이다([screens/channel.md](screens/channel.md) "행").

## `ChannelListRepository`

`@MainActor public protocol`. 동작은 id 로 지정한다.

- `startObserving() -> AsyncStream<[ChatChannel]>`
- `loadMore() async throws -> ChannelListPage`
- `leave(channelID:)`, `setNotificationLevel(_:channelID:)`
- `stopObserving()`

`ChannelListPage` — `channels: [ChatChannel]`, `hasNext: Bool`. 배열은 페이지 증분이 아니라 **목록 전체 스냅샷**이다.

`ChannelListRepositoryError` — `.notObserving`, `.unavailable`(백엔드가 준비되지 않음), `.channelNotFound`.

## `ChannelRepository`

`@MainActor public protocol`.

- `startObserving() -> AsyncStream<[ChatMessage]>`
- `loadPrevious() async throws -> MessagePage`
- `sendMessage(text: String, replyTo: String?)`
- `sendMessage(attachments: [ChatOutgoingAttachment], replyTo: String?)` — one message holding every attachment, in order.
- `resendMessage(id: String)`
- `removeFailedMessage(id: String)`
- `stopObserving()`

`replyTo` is the id of the message being answered, or `nil` for an ordinary message. Both text and attachments can be replies. The screen passes an id only when the channel's `canReply` is `true` and the id belongs to a sent, non-system message it holds (adapter rules 23–25).

**The four sending requirements return at once and do not throw.** Every outcome, including a failure before the request reaches the backend, arrives as a snapshot: a pending message, then the sent message or a failed one. A thrown error would report the same failure a second time, on a different path. So the Store has no completion Input and no late completion to drop for sending. The screen calls them only while observing, with `text` trimmed and non-empty and `attachments` non-empty, and with `replyTo` as described above; `resendMessage` and `removeFailedMessage` only for a message whose `sendingStatus` is `.failed`. An unknown id does nothing, because the snapshot that removed the message may still be on its way.

`MessagePage` — `messages: [ChatMessage]`, `hasPrevious: Bool`. 채널 리스트처럼 **지금까지 읽은 메시지 전체 스냅샷**이다.

`ChannelRepositoryError` — `.notObserving`, `.unavailable`, `.channelNotFound`(채널이 없어졌거나 볼 수 없다).

- 스냅샷은 **오래된 것부터 최신 순**이다(보내는 중 / 실패 메시지는 예외로 맨 뒤에 둔다. 어댑터 규약 8번). 관찰은 항상 최신 메시지를 포함하고, 페이지는 과거 방향으로만 읽는다. 특정 메시지로 건너뛰기는 없으므로 최신 방향의 페이지(`hasNext`)는 두지 않는다.
- `startObserving()` 뒤 **첫 `loadPrevious()` 는 최신 페이지를 돌려준다.** 그 뒤의 호출마다 한 페이지씩 과거로 간다. 채널 리스트의 첫 `loadMore()` 와 같은 역할이다.
- **스트림의 스냅샷도 지금까지 읽은 페이지를 모두 담는다.** 최신 구간만 담은 스냅샷은 보내지 않는다. 그래서 `.pageLoaded` 와 `.messagesChanged` 가 모두 `messages` 를 통째로 바꿔도 읽은 페이지를 잃지 않는다.

## 어댑터 규약

어댑터는 이 패키지 밖(별도 패키지)에 있다. 이 패키지는 어댑터를 모르지만, 어댑터가 지켜야 할 규약은 여기서 정한다. 경계 프로토콜의 동작이 이 규약을 전제로 하기 때문이다.

```
<어댑터 패키지>                    예: 특정 채팅 SDK 를 연결하는 패키지
  ├─ 의존: AnyChatUI 제품 + 백엔드 SDK
  ├─ ChatBackend 구현               앱이 한 번 등록하는 객체
  ├─ ChannelListRepository 구현     SDK 객체 → ChatChannel 매핑 포함
  ├─ ChannelRepository 구현         SDK 객체 → ChatMessage 매핑 포함
  └─ (선택) ChannelListView 확장     화면별 옵션이 필요한 진입점. 예: init(query:options:)
       └─ self.init(repository: <구현>, currentUserID: <현재 사용자>, options:)
```

1. **SDK 객체는 어댑터 밖으로 나가지 않는다.** MainActor 에서 SDK 객체를 읽고 곧바로 도메인 값으로 바꾼다.
2. **SDK 콜백에서는 값을 들고 hop 하지 않는다.** delegate 메서드는 `nonisolated` 로 두고 본문은 `Task { @MainActor in ... }` 로 건너뛰기만 한다. 건너간 뒤 MainActor 에서 원본을 다시 읽어 매핑한다.
3. **백엔드 사정은 매핑에서 정규화한다.** [domain-models.md](domain-models.md) "값의 의미는 어댑터가" 를 따른다. 종류별 차이(Group / Open 등)는 어댑터 안에서 폴더로 나눈다.
4. **동작은 id 로 SDK 객체를 찾아 수행한다.** 없으면 `.channelNotFound` 를 던진다.
5. **SDK 가 객체를 제자리에서 고치는 동작 뒤에는 새 스냅샷을 스트림에 싣는다.** 알림 설정 변경이 그렇다. 백엔드가 별도 이벤트를 보낸다고 가정하지 않는다. Store 는 값만 가지므로 스냅샷이 오지 않으면 화면이 갱신되지 않는다.
6. **스트림이 끝나면 백엔드 자원을 정리한다.** 소비자가 Task 를 취소하면 `AsyncStream.onTermination` 이 불리므로, 그 안에서 관찰 자원(SDK 의 메시지 컬렉션 등)을 해제한다.
7. **메시지가 제자리에서 바뀌면 같은 `id` 로 새 스냅샷을 싣는다.** 수정, 수신 확인 변화, 스트리밍, `attributes` 변화가 그렇다. 바뀔 때마다 보내도 된다. 몰리면 스트림 버퍼가 마지막 것만 남긴다("스냅샷 스트림").
8. **메시지 스냅샷은 오래된 것부터 최신 순이다.** 정렬은 어댑터가 한다. 화면은 받은 순서대로 그린다. Pending and failed messages from this device are the one exception: they follow every sent message, in the order they were sent. The `ChannelRepository` and `MessagePage` doc comments say the same.
9. **페이지를 읽은 뒤에는 그 결과를 담은 새 스냅샷을 스트림에도 싣는다.** 페이지 완료와 스트림 스냅샷은 서로 다른 Task 에서 Store 로 들어오므로, 페이지보다 먼저 만들어진 스냅샷이 페이지 뒤에 적용될 수 있다. 그때 방금 붙인 과거 페이지가 잠깐 사라지는데, 이 규칙이 있으면 바로 다음 스냅샷이 바로잡는다.
10. **채널을 잃으면 스트림을 끝낸다.** 채널이 삭제되거나 사용자가 내보내져 더 볼 수 없으면 `finish()` 한다. 빈 스냅샷을 보내지 않는다. 빈 목록은 "메시지가 없다" 는 뜻이기 때문이다.
11. **`make…Repository()` 와 Repository 의 init 은 백엔드 자원을 열지 않는다.** 바깥 뷰는 `body` 가 다시 그려질 때마다 Repository 를 만들고, `@State` 는 처음 것만 남기고 나머지를 버린다. 버려진 Repository 는 `startObserving()` 이 불린 적이 없어 6번의 정리가 일어나지 않는다. 그래서 관찰 자원은 `startObserving()` 에서 열고 스트림이 끝날 때 닫는다. 두 화면의 Repository 모두에 적용된다.
12. **`onTermination` 은 자기 스트림이 연 자원만 닫는다.** Retry 는 같은 Repository 에 `startObserving()` 을 다시 부른다. 새 관찰이 열린 뒤에 옛 스트림의 `onTermination` 이 불릴 수 있으므로, "지금 열린 자원" 을 닫으면 새 관찰이 끊긴다. 자원 참조의 동일성으로 판별하며, 세대 식별자는 두지 않는다(`AGENTS.md` "아키텍처 작업 원칙").
13. **관찰을 연 뒤 첫 페이지 호출(`loadMore()` / `loadPrevious()`)이 페이지를 만들기 전에는 스냅샷을 싣지 않는다.** 그사이 생긴 변화는 그 첫 페이지에 담는다. 화면은 첫 페이지를 받은 뒤에야 스트림을 읽으므로, 그 전에 실은 스냅샷은 버퍼에 남았다가 페이지 뒤에 적용되어 더 오래된 내용으로 목록을 되돌린다. 첫 페이지를 담은 스냅샷(9번)은 페이지와 같으므로 괜찮다. 두 화면의 Repository 모두에 적용된다.
14. **이미지 URL 은 내용이 고정된 주소다.** 이미지 캐시는 URL 문자열 전체를 그림의 식별자로 삼고, 디스크에 저장한 썸네일은 HTTP 캐시 헤더와 무관하게 만료되지 않는다([design-system.md](design-system.md) "이미지"). 그래서 그림이 바뀌면 새 URL 을 넘긴다. 예를 들어 버전이나 수정 시각을 쿼리로 붙인다. 같은 그림에 매번 바뀌는 토큰을 붙인 URL 은 캐시에 맞지 않아 매번 다시 받는다. `ChatSender.profileImageURL`, `ChatChannel.coverURL`, `ChatAttachment.url` 모두에 적용된다.

15. **A sending call puts a pending message in the next snapshot.** It belongs to the current user, carries `sendingStatus == .pending`, and sits after every sent message, behind earlier pending and failed ones (rule 8). A message received while it waits goes before it, among the sent messages. Do not wait for the upload to start.
16. **A message keeps its `id` from pending to sent.** When the backend assigns a new id on success, keep using the request id the pending message had. A changed id would remove one row and insert another, which breaks the scroll anchor and replays the row's appearance.
17. **A send that fails becomes a failed message.** This includes failures before the request leaves the device, such as `.unavailable`, a file over the size limit, or a channel that turned frozen after the screen opened. `resendMessage(id:)` turns it back into a pending message with the same id; `removeFailedMessage(id:)` removes it from later snapshots. Both act only on failed messages this device sent; on a pending or sent message they do nothing, so a repeated tap never uploads twice.
18. **An outgoing attachment's file belongs to the adapter after the call.** The package copies each picked item into its own temporary folder and hands over the copy; it never reads or deletes that file again. Keep the file as long as a resend may need it, and move it elsewhere if that must survive a relaunch. The pending message's `ChatAttachment.url` may point at it until the upload finishes; the image loader reads `file:` URLs ([design-system.md](design-system.md)).
19. **`canSendMessage` holds every rule for sending.** Frozen channels, broadcast channels for non-operators, and muted members all set it to `false`. The screen does not combine `isFrozen` or `isBroadcast` itself.
20. **Pending and failed messages outlive the repository that sent them.** The package stores no outgoing message, so the adapter must keep them in the backend object or the SDK, not in one repository instance. Leaving and reopening a channel makes a new repository (rule 11), and Retry restarts observation and paging. The first page and every snapshot of any later observation of the same channel include this device's pending and failed messages, placed as rule 8 says. A send keeps running after `stopObserving()` or after its stream ends. Whether they survive a relaunch is the adapter's choice (rule 18).
21. **`ChatChannel.lastMessage` holds only sent messages.** Do not put a pending or failed message there. The channel list draws its text, time, and receipt with no sending status, so an unsent message would read as delivered.
22. **The adapter sets `ChatMessage.attributes`.** Messages reach the screen only through snapshots, and the package keeps no copy of them, so app state that travels with a message, such as a "reported" flag kept in backend message metadata, is mapped into attributes by the adapter. Decoding backend metadata into the app's types is the adapter's job; the package defines no attribute types. A change, such as the user reporting a message, arrives as a new snapshot with the same message `id` (rule 7). State that never leaves the app, such as messages pinned on this device only, does not belong here; host closures read it from the app's own model.

23. **A reply carries `replyTo` from its first snapshot.** The pending message of a send with `replyTo` holds a `ChatMessage.ReplyReference` built from the original the adapter already knows, so the quote appears with the pending row. It keeps the reference when it is sent, fails, or is resent; `resendMessage(id:)` sends it as the same reply. When the original is not in the adapter's own collection, it builds the reference from the backend's reply link once the message is sent, and until then sends the pending message with `isUnavailable == true`. A backend that rejects the reply turns it into a failed message (rule 17).
24. **`canReply` is `true` only when the adapter sends replies.** The screen never passes `replyTo` while it is `false`, and an adapter that sets it to `false` may ignore the parameter. A backend that allows replies in some channels only sets it per channel, like `canSendMessage` (rule 19).
25. **Every message with a backend reply link carries `replyTo`**, including messages from other users and messages on earlier pages, whether or not `canReply` is `true` now. A deleted or hidden original keeps the reference with `isUnavailable == true` ([domain-models.md](domain-models.md) "`ChatMessage.ReplyReference`"). An edit or deletion of the original sends the replies again with the same ids (rule 7).

특정 SDK 의 구체 매핑 규칙(기본 채널 이름, 샘플 커버와 기본 프로필 URL, 밀리초 시각, 음성 메시지 태그, 대형 / 브로드캐스트 채널의 수신 확인 등)은 어댑터 패키지의 문서가 갖는다.

어댑터가 던지는 에러 중 화면에 그대로 보여 줄 것은 `LocalizedError` 로 만들고 `errorDescription` 에 표시 문구를 담는다. Store 는 그 문구를 쓰고, 그 밖의 에러는 일반 문구로 바꾼다.
