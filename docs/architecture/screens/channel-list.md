# 채널 리스트 화면

[ARCHITECTURE.md](../../../ARCHITECTURE.md) 6절의 하위 문서다. Reducer / State / Store 의 공통 계약은 6절이 정하고, 여기는 이 화면에만 해당하는 것을 적는다. Repository 계약은 [backend-boundary.md](../backend-boundary.md) "`ChannelListRepository`" 에 있다.

## 타입

| 타입 | 접근 | 하는 일 |
|---|---|---|
| `ChannelListView` | public | 진입점. 기본 `init(options:)` 은 Environment 에 등록된 백엔드를 쓰고, `init(repository:currentUserID:options:)` 는 그것을 덮어쓴다([ARCHITECTURE.md](../../../ARCHITECTURE.md) 7절). 슬롯 클로저와 이벤트 콜백을 저장하고, 슬롯과 콜백은 `ChatChannel` 을 넘긴다 |
| `ChannelListTheme` / `ChannelListOptions` | public | 화면 테마와 옵션 |
| `ChannelListReducer` / `ChannelListState` / `ChannelListStore` | internal | 상태와 전이 |
| `ChannelRowState` | internal | 행이 바로 그릴 수 있는 `Hashable` 파생 값. `ChatChannel` 에서 표시 문자열(시각, 개수, 미리보기)을 한 번만 계산해 둔다. 현재 시각에 따라 바뀌는 값이 있으므로 diff 는 모델이 아니라 이 타입으로 한다 |

스와이프 액션 라벨은 SwiftUI 가 항상 흰색으로 그린다. `foregroundStyle` 이 무시되므로 테마는 배경색만 노출하고, 모든 액션 배경은 흰 내용이 읽히도록 어둡게 유지한다. 라벨 아이콘의 크기는 [design-system.md](../design-system.md) "아이콘 크기" 를 따른다.

## Input 과 Effect

- **Input**
  - 사용자 의도: `.start`, `.retry`, `.refresh`, `.loadNextPage`, `.retryNextPage`, `.leave(channelID:)`, `.toggleNotifications(channelID:)`
  - 외부 사실: `.channelsChanged([ChatChannel])` — Store 가 연 스트림의 스냅샷
  - Effect 완료: `.pageLoaded(ChannelListPage)`, `.pageFailed(message:)`, `.leaveFinished(ChatChannel, failure:)`, `.notificationLevelSet(_:channel:failure:)`
- **Effect**: `.startObserving`(관찰을 열고 첫 페이지를 읽는다), `.loadMore`, `.leave(ChatChannel)`, `.setNotificationLevel(_:channel:)`, `.notify(ChannelListEvent)`

채널 동작의 Effect 와 완료 Input 은 id 가 아니라 시작 시점의 `ChatChannel` 값을 싣는다. 나가기의 삭제 스냅샷은 완료보다 먼저 올 수 있어서, 완료 시점에 `channels` 에서 채널을 찾으면 호스트 콜백에 넘길 값이 없어지기 때문이다. Repository 호출은 여전히 id 로 한다.

`ChannelListEvent` 의 실패는 `.failed(message:)` 다. View 는 그 문자열을 `LocalizedError` 로 감싸 `onError` 에 넘긴다. 백엔드의 원본 에러 타입은 호스트에 전달되지 않는다.

State 는 `phase`, `channels`, `hasNext`, `isRefreshing`, `loadMoreError`, `pendingActionChannelIDs` 다. 예전 ViewModel 의 상태 프로퍼티를 그대로 옮긴 것이다.

## Store

Task 슬롯은 `.observing`(`.startObserving`), `.page`(`.loadMore`), 채널별 슬롯(채널 동작)이다. 공통 규칙은 [ARCHITECTURE.md](../../../ARCHITECTURE.md) 6절 "Store 가 맡는 것" 이다.

**새로고침 대기.** `refresh() async` 는 `send(.refresh)` 뒤 `state.isRefreshing` 이 `false` 가 될 때까지 기다린다. Store 는 상태를 저장할 때마다 대기 중인 continuation 을 확인해 깨운다. 그래서 `refreshable` 의 스피너가 새 첫 페이지까지 유지된다. View 가 `store.send(_:)` 말고 부르는 유일한 메서드다.

`channels` 나 pending 집합이 바뀌었으면 `rows` 를 다시 만든다. 시각은 Store 가 주입받은 `now` 로 잰다.

**호스트 콜백.** `.notify` Effect 는 Store 의 `outboundEvent` 로 내보내고, View 가 그것을 보고 현재 콜백을 부른다. 콜백 클로저는 View 가 다시 그려질 때마다 바뀔 수 있어 Store 에 저장하지 않는다.

**관찰을 다시 열 때(`.startObserving`)는 `.page` 슬롯도 취소한다.** 새로고침과 Retry 뒤에 옛 페이지 완료가 새 목록에 섞이지 않게 하기 위해서다.

## 최초 로드와 실시간 갱신

```
View .task
  └─ send(.start) → reduce: phase == .idle 일 때만 phase = .loading, effects = [.startObserving]
       └─ Store: .observing 슬롯에서 repository.startObserving() 후 loadMore()
            ├─ 첫 페이지 → send(.pageLoaded(page)) / send(.pageFailed(message:))
            │    └─ reduce: 전체 스냅샷으로 교체, phase = .empty / .loaded(false), hasNext 갱신
            └─ for await snapshot in stream → send(.channelsChanged(snapshot))
                 └─ reduce: channels 가 같으면 상태를 그대로 둔다
```

## 페이지네이션

행 `onAppear` 가 끝에서 10 번째 또는 마지막에 닿으면 View 가 `send(.loadNextPage)` 를 부른다. Reducer 는 `canLoadNextPage`(`phase == .loaded(isLoadingNext: false) && hasNext && loadMoreError == nil`)일 때만 `.loadMore` 를 낸다. 그래서 이중 로드와 실패 후 자동 반복이 막힌다. 실패는 목록을 유지한 채 `loadMoreError` 만 세우고 푸터에 Retry 를 띄운다. `.retryNextPage` 는 `loadMoreError != nil` 을 요구한다.

## 새로고침

`.refresh` 는 관찰을 처음부터 다시 연다(`.startObserving`). 기존 목록은 새 첫 페이지가 올 때까지 화면에 남고, 옛 관찰 Task 는 교체되어 그 결과가 버려진다.

## 나가기 / 알림 토글

`.leave` 와 `.toggleNotifications` 는 State 의 채널별 pending 집합으로 중복 실행을 막는다. 나가기 성공 뒤 행 제거는 다음 스냅샷이 담당한다. 알림 토글은 `.off ↔ .all` 이며, 새 값은 어댑터가 보내는 스냅샷으로 들어온다. `notificationLevel == nil` 이면 토글을, `canLeave == false` 면 나가기를 띄우지 않는다.

## 스트림 종료

채널 리스트는 취소되지 않은 스트림 종료를 무시한다. 목록 자체를 잃는 경우가 없기 때문이다. 채널 화면은 다르다([channel.md](channel.md) "채널을 잃었을 때").

## 정체성

안쪽 뷰의 `.id` 는 `ObjectIdentifier(backend)` 다([ARCHITECTURE.md](../../../ARCHITECTURE.md) 7절).

## 목록 머리

```swift
ChannelListView()
    .channelListHeader {
        NotesStrip(notes: notes)
    }
```

`channelListHeader` puts a host view at the top of the list, above the first row, such as a strip of notes or stories. It scrolls with the rows. A view placed above `ChannelListView` by the host stays fixed while the rows scroll, which is the gap this slot closes.

- **What it receives.** Nothing. Its content is the host's own data, not a channel, like `createChannelButtonLabel`. The closure is stored on the view, so when the host redraws `ChannelListView` with new data, the header shows it.
- **Placement.** The first item inside the `List`, outside the `ForEach` of rows. It has zero row insets and the theme's `background`, like the rows. It has no separators: none around it and none between it and the first row. A host that wants a divider draws it in its view. Pull to refresh pulls it down with the list.
- **Not a row.** It is not a button, has no swipe actions, and does not open a channel.
- **Buttons inside it.** In a `List` row, buttons with the automatic style make the whole row their tap target, so a tap on blank space fires them, and with two buttons both fire. The package therefore applies `.buttonStyle(.borderless)` around the header, so each button takes only its own taps and looks as it does outside a list. A style the host sets inside its view takes precedence. The channel rows avoid the same problem with `.buttonStyle(.plain)` on their own button.
- **Pagination.** Not affected. The header is not in `rows`, so the row indices that `loadNextPageIfNeeded(at:)` compares are unchanged, and the header itself never triggers a page.
- **Every state.** It shows in every `phase`: loading, empty, error, and loaded (user, 2026-10-14). Its content does not come from the channel list, so it does not disappear with it. The spinner, "No channels", and the error with Retry stay an overlay centered over the list, as now. The overlay is drawn on top, so a header tall enough to reach the middle of the screen sits under it.
- **What stays out.** A footer, section headers between rows, a header that stays pinned while the rows scroll, and search.

## 테스트

| 대상 | 더블 |
|---|---|
| `ChannelListReducer` | 없음 |
| `ChannelListStore` | `ChannelListRepositorySpy` |
| 포매터 / `ChannelRowState` | 없음. `ChatChannel` 값을 직접 만들어 넣는다 |
| `ChannelListSlots` | None. Checks that the list header is stored per view instance |

Store 테스트는 공통 항목에 더해 `refresh()` 대기와 `.notify` 의 `outboundEvent` 전달을 본다.

The list header is display-only. That it scrolls with the rows, that two buttons in it each take only their own taps, and that pagination and swipe actions keep working is verified in QuickStart, under [ARCHITECTURE.md](../../../ARCHITECTURE.md) section 9's rule for slots that UI tests must verify; the step that adds the slot adds it to that section's list.

The default visual layout now follows the measured iOS 26 Messages reference in [design-system.md](../design-system.md#messages-layout-reference). Store, reducer, grouping, and backend contracts are unchanged. Custom slots retain their existing placement contracts.
