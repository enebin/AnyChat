# ARCHITECTURE

`AnyChat` 의 구조 설계 단일 출처(SoT)다. 레이어 / 폴더 / 격리 경계 / 의존성 규칙 / DI / 테스트 경계는 이 문서와 하위 문서를 따른다. 구조를 바꿔야 하면 코드보다 이 문서들을 먼저 갱신한다.

이 문서는 모든 화면에 공통인 원칙과 규칙만 담는다. 타입 하나하나의 모양과 화면별 흐름은 하위 문서에 둔다. 같은 내용을 두 곳에 쓰지 않고 링크로 잇는다.

| 하위 문서 | 내용 |
|---|---|
| [domain-models.md](docs/architecture/domain-models.md) | 도메인 모델 원칙, `ChatChannel` / `ChatSender` / `ChatMessage` |
| [backend-boundary.md](docs/architecture/backend-boundary.md) | `ChatBackend`, 화면별 Repository 와 Page / Error, 스냅샷 스트림, 어댑터 규약 |
| [design-system.md](docs/architecture/design-system.md) | 토큰, 원자, 이미지 로딩 |
| [screens/channel-list.md](docs/architecture/screens/channel-list.md) | 채널 리스트 화면 |
| [screens/channel.md](docs/architecture/screens/channel.md) | 채널 화면(메시지 목록) |
| [mcp.md](docs/architecture/mcp.md) | MCP server: tools, division of work, component catalog, keeping it in step with the SDK, versioning |

새 화면을 만들면 `docs/architecture/screens/` 에 문서를 하나 더하고 위 표에 올린다.

작업 방식과 규칙은 `AGENTS.md` 를 본다.

## 1. 개요 / 설계 목표

이 패키지는 **백엔드를 모르는 SwiftUI 채팅 UI** 다(`AnyChat`). 채팅 백엔드(채팅 SDK 등)는 이 패키지 밖의 어댑터가 공개된 경계 프로토콜을 구현해 꽂는다. 이 패키지에는 어떤 백엔드 SDK 의존도 없다.

UIKit 채팅 UI 를 `UIViewControllerRepresentable` 로 감싸고 SwiftUI 뷰를 `UIHostingController` 로 UIKit 서브뷰 자리에 끼워 넣는 래퍼는 전역 가변 컨버터 레지스트리, 런타임 tag 기반 슬롯 식별, 테이블뷰와 호스팅뷰의 터치 충돌, 네비게이션 바 탐색 해킹을 구조에 남긴다. 이 패키지는 그 방식을 쓰지 않고 화면들을 **네이티브 SwiftUI 로 쓴다.** 화면은 채널 리스트와 채널(메시지 목록) 둘이며, 그 규모에 맞는 최소 레이어만 둔다.

**The only UIKit exceptions are the channel screen's scrolling container, the composer's placement above the keyboard, the row swipe that starts a reply and the long press that opens the message overlay, and the camera picker.** `ChannelBody` connects an internal container view controller through `UIViewControllerRepresentable`. Prepending older messages requires correcting the offset before drawing; SwiftUI `ScrollView` does not expose that point. The composer is pinned to UIKit's `keyboardLayoutGuide`, which follows the keyboard while the user drags the list to dismiss it; SwiftUI's keyboard safe area is not reported during that drag. A backdrop behind the composer, from its top down to the screen edge, paints the theme color or hosts the host's `composerBackground` view. The reply swipe is a pan recognizer on that collection view: a SwiftUI drag gesture inside a hosted cell cannot be ordered against the collection view's own pan or the navigation controller's back swipe, so it either blocks vertical scrolling or loses to it ([the channel screen](docs/architecture/screens/channel.md#답장)). The long press that opens the message overlay is a recognizer on the same collection view: it must fire over buttons inside a bubble and cancel their touch, and stop the list's pan once the overlay opens, which a SwiftUI gesture in a hosted cell cannot do ([the channel screen](docs/architecture/screens/channel.md#long-press-overlay)). SwiftUI has no camera capture view, so the camera picker wraps `UIImagePickerController`. The jump-to-latest button is hosted above the composer so it follows the keyboard during an interactive dismissal, which a SwiftUI overlay is not told about. An empty channel's view is hosted in the list's background view, so a drag on it still reaches the list's pan and dismisses the keyboard while its buttons keep their taps. The controllers own only placement, scrolling, that swipe, and that long press. Message cells, the composer itself, the header, navigation, loading, empty, and error views remain SwiftUI. Slots remain on each view instance, and hosted message cells receive the host's environment. The package's own composer controls receive only the theme, while host views placed in the composer, the empty channel's view, and the jump-to-latest button receive the whole environment ([the channel screen](docs/architecture/screens/channel.md#입력창-커스터마이즈)). Ownership, scroll, and composer rules are defined in [the channel screen](docs/architecture/screens/channel.md#스크롤). Any further UIKit use requires documenting the behavior SwiftUI cannot provide first.

핵심 원칙:

- **의존 방향은 한 방향.** `Presentation → Domain ← 백엔드 어댑터`. Domain 은 Foundation 외에 아무것도 의존하지 않는다. 어댑터는 이 패키지 밖에 있다.
- **도메인 모델은 백엔드와 무관한 자체 값 타입이다.** 백엔드 SDK 객체는 어댑터 밖으로 나오지 않고, 어댑터가 `ChatChannel` 같은 값으로 바꿔 넘긴다. 모델은 채널 종류(Group / Open / Feed)로 나누지 않는다.
- **전이 규칙은 순수 Reducer 가 정하고, 상태는 화면별 Store 가 소유한다.** View 와 Row 는 표시 전용이다.
- **커스터마이즈는 인스턴스에 머문다.** 전역 레지스트리 대신 뷰 모디파이어에 저장한 클로저를 쓴다.

## 2. 모듈 · 폴더 구조

```
AnyChat/
├─ Package.swift                      타겟/의존성 단일 출처. 백엔드 SDK 의존 없음
├─ ARCHITECTURE.md                    구조 허브. 하위 문서는 docs/architecture/
├─ Sources/
│  ├─ AnyChatCore/                    nonisolated 기본. SwiftUI 를 import 하지 않는다
│  │  └─ Domain/                      도메인 모델 + 백엔드 경계 프로토콜
│  ├─ AnyChatDesignSystem/            MainActor 기본. 도메인을 모른다
│  │  ├─ Token/                       Palette / Typography / Icon
│  │  ├─ Atom/                        Avatar, Badge, DividerLine, IconButton, Placeholder
│  │  └─ Image/                       RemoteImage / RemoteImageLoader
│  └─ AnyChatUI/                      MainActor 기본. 제품 타겟
│     ├─ Common/                      Decision, TaskBag, ErrorMessage, Exports.swift, 두 화면이 함께 쓰는 Formatting 과 View
│     │  └─ Public/                   백엔드 등록과 테마 Environment 키
│     ├─ ChannelList/                 화면별 폴더: Reducer, State, Store, RowState, Formatting, View
│     │  └─ Public/                   View, 커스터마이즈 모디파이어, Options, Theme
│     └─ Channel/                     채널 화면(메시지 목록). 폴더 구성은 ChannelList 와 같고, 보낼 첨부를 준비하는 Sending/ 이 더 있다
├─ Tests/
│  ├─ AnyChatCoreTests/               Custom message value equality and hashing
│  ├─ AnyChatDesignSystemTests/
│  └─ AnyChatUITests/                 Support/Doubles 포함
├─ Examples/QuickStart/               xcodegen 데모 앱. 메모리 안 샘플 백엔드를 쓴다
└─ MCP/                               고객이 설치하는 MCP 서버. TypeScript, npx 배포. 11절
```

의존 방향:

```
AnyChatCore          ──▶ (없음)
AnyChatDesignSystem  ──▶ (없음)
AnyChatUI            ──▶ AnyChatCore, AnyChatDesignSystem
```

**타겟을 나누는 기준.** 타겟 경계는 컴파일러가 강제해 주는 것만 둔다.

1. **패키지 전체가 백엔드 SDK 를 모른다.** `Package.swift` 에 백엔드 SDK 의존이 없으므로, 어디에든 SDK 타입이 들어오면 컴파일이 깨진다. 제품 방향 1번(UI 는 백엔드를 모른다)을 리뷰가 아니라 컴파일러로 지키는 방법이다.
2. **Core 는 SwiftUI 를 모르고 격리 기본값이 다르다.** 도메인 값과 경계 프로토콜은 nonisolated 기본에서 정의한다(3절). 백엔드 어댑터는 Core 만 보고도 구현할 수 있어야 한다.
3. **DesignSystem 은 도메인을 모른다.** Core 를 의존하지 않으므로 원자 컴포넌트에 채널 / 메시지 개념이 새어 들면 컴파일이 깨진다. 원자는 원시 값만 받는다.

**DesignSystem 에 무엇을 두는가.** 디자인 원본이 **화면과 무관하게** 정의한 것만 둔다. 색 / 타이포그래피 / 아이콘 토큰과, 어느 화면에 놓이든 모양이 같은 원자다. 화면 단위 조합(행, 헤더, 입력창)은 그 화면 폴더에 둔다. 원자를 미리 만들어 두는 것이 허용되는 이유는 추측이 아니라 디자인 원본에 이미 확정된 정의를 옮기는 일이기 때문이며, 접근 수준이 `package` 라 시그니처를 언제든 바꿀 수 있기 때문이다.

**제품과 import.** 제품(`products`)은 `AnyChatUI` 하나다. 사용자는 `import AnyChatUI` 한 줄로 모든 public 타입을 쓴다. 이를 위해 `AnyChatUI/Common/Exports.swift` 한 파일에서 `@_exported import AnyChatCore` 를 한다. 언더스코어 속성 금지 규칙(`AGENTS.md`)의 유일한 예외다. DesignSystem 은 public 심볼이 없으므로 다시 내보내지 않는다.

**접근 수준.**

| 타겟 | `public` | `package` / `internal` |
|---|---|---|
| `AnyChatCore` | 도메인 모델, 백엔드 경계 프로토콜(`ChatBackend`, `ChannelListRepository`, `ChannelRepository`)과 그 값 타입 | 없음 |
| `AnyChatDesignSystem` | 없음 | 전부 `package` |
| `AnyChatUI` | View / ViewModifier / Theme / Options / Formatter / 슬롯 문맥 값, 백엔드 등록 모디파이어 `chatBackend(_:)`, 덮어쓰기용 `init(repository:...)` | Reducer / State / Store / RowState / Decision / TaskBag 은 `internal` |

**public 은 폴더로 드러낸다.** `AnyChatUI` 의 public 선언은 각 폴더의 `Public/` 안에만 둔다. 파일 목록만 보고 공개 API 를 찾을 수 있게 하기 위해서다. 그래서 한 파일에 public 타입과 internal 타입을 섞지 않는다. Core 는 타겟 전체가 public 이고 DesignSystem 은 public 이 없으므로 `Public/` 폴더를 두지 않는다. 컴파일러가 강제하지 않는 규칙이라 리뷰에서 확인한다.

경계 프로토콜과 등록 API 가 public 인 이유는 어댑터가 **다른 패키지**에 있기 때문이다. `package` 접근은 패키지 경계를 넘지 못한다. 아직 릴리스 전이므로 public 이라도 모양은 바뀔 수 있다. public 약속은 첫 릴리스 태그부터 시작한다.

`Network` 레이어는 없다. 통신은 백엔드 어댑터의 일이다.

## 3. 격리(Isolation) 경계

백엔드 SDK 의 모델은 대개 Sendable 이 아니다(예: Objective-C 기반 SDK 의 모델은 `@objc open class` 다). 콜백도 SDK 가 정한 큐에서 온다. Swift 6 에서 가장 큰 위험은 이런 non-Sendable 객체가 액터 경계를 넘는 것이다.

해법은 경계를 만들지 않는 것이다.

1. **패키지 안에는 Sendable 값만 있다.** 어댑터가 SDK 객체를 값으로 바꿔 넘기므로, 이 패키지 안에서 non-Sendable 객체가 경계를 넘을 일이 없다. 어댑터 쪽 규칙은 [backend-boundary.md](docs/architecture/backend-boundary.md#어댑터-규약) 에 있다.
2. **백엔드 경계 프로토콜 전체를 `@MainActor` 로 격리한다.** `ChatBackend` 는 Environment 값으로 실리므로 `Sendable` 도 요구한다. MainActor 클래스는 그 자체로 `Sendable` 이라 어댑터에 추가 부담이 없다. 어댑터가 SDK 객체를 만지는 곳이 MainActor 라야 값으로 바꾸는 일까지 한 격리 안에서 끝난다. 출력이 값인데도 격리를 풀지 않는 이유는 Repository 를 부르는 Store 가 MainActor 라 풀어서 얻는 것이 없기 때문이다.
3. **`TaskBag` 은 nonisolated 이고 `Mutex` 로 보호한다.** `operation` 은 `@MainActor () async -> Void` 다. `deinit` 에서 `cancelAll()` 을 부를 수 있어야 하므로 MainActor 클래스로 두지 않는다.
4. `nonisolated(unsafe)` 와 `@unchecked Sendable` 래퍼는 쓰지 않는다.
5. Core 의 nonisolated 기본값은 **도메인 값과 순수 규칙**에 의미가 있다.
6. **Reducer 와 State / Input / Effect 는 UI 타겟 안에 있지만 `nonisolated` 로 선언한다.** 격리와 무관한 순수 계산이라, 테스트가 액터 없이 동기로 부를 수 있어야 한다.
7. **MainActor 기본 모듈의 클래스는 `nonisolated deinit {}` 를 선언한다.** `defaultIsolation(MainActor)` 에서는 따로 쓰지 않은 `deinit` 도 MainActor 격리 deinit 으로 컴파일되고, 그 경로(`swift_task_deinitOnExecutor` 백디플로이)는 iOS 18.4 런타임에서 객체가 해제될 때 크래시한다. 클래스의 deinit 은 Swift 6.2 이전처럼 격리 없이 돌아도 문제가 없으므로 명시적으로 풀어 둔다. 본문이 필요한 deinit 도 MainActor 상태에 기대지 않게 쓴다.

요약: **도메인 = `AnyChatCore`(nonisolated 기본) · UI = `AnyChatUI` / `AnyChatDesignSystem`(MainActor 기본) · 백엔드 경계 = `@MainActor` 프로토콜 · 오가는 것은 Sendable 값뿐.**

## 4. 레이어별 책임

### Domain (`AnyChatCore/Domain`)

백엔드와 무관한 도메인 모델과 백엔드 경계 프로토콜이다. 어댑터가 구현하는 지점이자 테스트 더블이 붙는 지점이다.

- **도메인 모델**은 UI 가 그리는 데 필요한 의미만 담는 값 타입이다. 채널 종류로 나누지 않고, 종류 대신 할 수 있는 일을 적는다. 원칙과 타입별 필드는 [domain-models.md](docs/architecture/domain-models.md).
- **백엔드 경계**는 화면마다 Repository 를 하나 둔다. Repository 는 전체 스냅샷 스트림과 페이지 읽기를 제공하고, `ChatBackend.make…Repository()` 가 만든다. 프로토콜별 계약은 [backend-boundary.md](docs/architecture/backend-boundary.md).

### DesignSystem (`AnyChatDesignSystem`)

디자인 원본의 화면 독립 정의(토큰, 원자, 이미지 로딩)를 옮겨 둔 곳이다. 무엇을 두는지는 2절, 타입별 규칙은 [design-system.md](docs/architecture/design-system.md).

### Presentation (`AnyChatUI`)

화면마다 폴더 하나를 두고, 그 안의 `Public/` 에 public 진입점(View / 커스터마이즈 모디파이어 / Options / Theme / 슬롯 문맥 값)을, 나머지 자리에 internal Reducer / State / Store / RowState 를 둔다(2절). 화면별 타입과 흐름은 `docs/architecture/screens/` 의 화면 문서에 있다. 모든 화면에 공통인 규칙은 이렇다.

- **테마는 `Environment` 로 내려보내고, 슬롯과 콜백은 뷰 인스턴스에 저장한다.** 슬롯을 Environment 에 두지 않는 이유는 상속을 원하지 않기 때문이다. 한 화면의 커스터마이즈가 그 아래 화면까지 따라가면 안 된다.
- **화면 테마는 public 이고 프로퍼티 타입은 `Color` 와 `Font` 뿐이다.** 기본값은 DesignSystem 의 `package` 토큰을 읽지만, public 시그니처에 `package` 타입이 새지 않으므로 문제가 없다. 그래서 토큰 타입은 `nonisolated` 여야 한다([design-system.md](docs/architecture/design-system.md)).
- **슬롯은 public 값만 받는다.** RowState 는 `internal` 이므로 슬롯 클로저에 넘기지 않는다. 슬롯이 도메인 값 외에 화면이 파생한 표시 정보를 알아야 하면 **슬롯 문맥 값**(2절 표의 public 범주)으로 넘긴다. 슬롯 문맥 값은 보통 `Hashable` 한 표시 정보다(`MessageRowContext`). 화면 동작을 호스트 클로저에 넘겨야 하는 곳(채널 화면의 메시지 신호, 앞으로의 입력 슬롯)은 동작을 싣는 별도의 문맥 값을 쓴다(`MessageActionContext`). 이 값은 클로저를 실어 `Hashable` 이 아니고 MainActor 에 묶이며, 표시용 문맥 값과 섞지 않는다. Store 를 노출하지 않고 Store 에 보낼 Input 만 감싼다.
- Custom message payloads are `Hashable`, `Sendable` Swift values in Core. UI renderers are view-instance slots, registered by payload type; Core never stores a View. The value container and rendering precedence are defined in [domain-models.md](docs/architecture/domain-models.md) and [channel.md](docs/architecture/screens/channel.md).
- **Rows are diffed using RowState.** Screen State holds domain values. Store builds each message row from its original `ChatMessage` and derived presentation values. Sender identity and content remain in the message; grouping, visibility, and formatted dates belong to the row. Views and slots read the message from the row rather than pairing separate arrays by index.
- **여러 화면이 함께 쓰는 포매터는 `Common/Formatting` 에 둔다.**
- **이름에 채널 종류를 넣지 않는다.** 화면 타입은 `ChannelListView` / `ChannelListTheme` / `ChannelListOptions`, `ChannelView` / `ChannelTheme` 처럼 종류와 무관하게 짓는다.

## 5. 백엔드 어댑터 규약

어댑터는 이 패키지 밖(별도 패키지)에 있다. 이 패키지는 어댑터를 모르지만, 어댑터가 지켜야 할 규약은 이 패키지가 정한다. 경계 프로토콜의 동작이 이 규약을 전제로 하기 때문이다. 규약 전체는 [backend-boundary.md](docs/architecture/backend-boundary.md#어댑터-규약) 에 있다. 요점은 이렇다.

- SDK 객체는 어댑터 밖으로 나가지 않고, MainActor 에서 곧바로 도메인 값으로 바뀐다.
- 바뀐 것이 있으면 전체 스냅샷을 다시 싣는다. 백엔드가 별도 이벤트를 보낸다고 가정하지 않는다.
- 관찰 자원은 `startObserving()` 에서 열고 그 스트림이 끝날 때 닫는다.

## 6. 상태 · 데이터 흐름

상태 관리는 **Reducer 패턴**이다(TCA 와 같은 모양이지만 라이브러리는 쓰지 않는다). 화면마다 세 조각을 둔다. 아래 예시 타입은 채널 리스트의 것이다. 화면별 Input / Effect / State 는 화면 문서에 있다.

| 조각 | 타입 | 하는 일 |
|---|---|---|
| Reducer | `ChannelListReducer` — `nonisolated struct` | `(State, Input) -> Decision`. 다음 상태와 실행할 Effect 를 정하는 동기 순수 함수 |
| State | `ChannelListState` — `nonisolated struct`, `Equatable`, `Sendable` | 전이 판단에 필요한 값 |
| Store | `ChannelListStore` — `@MainActor @Observable final class` | State 를 단독 소유한다. Input 을 받아 Reducer 를 부르고, Decision 을 저장한 뒤 Effect 를 실행한다 |

```
View ─▶ store.send(Input) ─▶ reducer.reduce(state, input) ─▶ Decision
                                   ┌───────────────────────────────┘
                                   ├─ state = decision.nextState      @Observable → View
                                   └─ run(effect) …                   Repository 호출, Task 시작
                                        └─ 완료 ─▶ store.send(완료 Input) ─▶ …
```

### 계약

- **Reducer 는 상태를 보관하지 않고 I/O 를 하지 않는다.** `async`, `throws`, Repository, `TaskBag`, `Date` 를 모른다. 같은 `(State, Input)` 은 항상 같은 `Decision` 을 만든다.
- **`Decision` 은 `nextState` 와 `effects: [Effect]` 다.** Effect 가 없으면 빈 배열이다. 무시하는 Input 도 `Decision(nextState: state)` 로 명시한다. `nil` 이나 넓은 `default` 로 넘기지 않는다. 두 화면이 같은 모양을 쓰므로 `Common` 의 `nonisolated struct Decision<State, Effect>` 하나를 함께 쓴다.
- **상태가 바뀌는 곳은 Store 가 `nextState` 를 저장하는 한 곳뿐이다.** Effect 완료 지점에서 상태를 직접 바꾸지 않고, 결과를 새 Input 으로 보낸다.
- **Store 는 `await` 전에 다음 상태를 저장하고, Effect 는 선언 순서대로 실행한다.**
- **Reducer 가 쓰는 설정은 생성 후 바뀌지 않는 것만 init 에서 받는다.** 바뀔 수 있는 값은 State 나 Input 으로 넘긴다.
- **State, Input, Effect, Decision 은 `nonisolated` 이고 `Equatable`, `Sendable` 이다.** Reducer 테스트가 Decision 을 그대로 비교하기 위해서다. 그래서 오류는 Store 가 Input 으로 바꾸기 전에 표시용 문자열로 바꾼다. `any Error` 는 비교할 수 없다.

### Store 가 맡는 것

화면별 Task 슬롯과 추가 책임(호스트 콜백, 대기 등)은 화면 문서에 있다. 모든 Store 에 공통인 것은 이렇다.

- **Task 와 늦은 완료.** Effect 는 `TaskBag` 의 슬롯에서 실행한다. 같은 슬롯의 새 작업은 이전 Task 를 취소한다. 취소는 협조적이라 완료가 그대로 도착하므로, Store 는 완료 Input 을 보내기 직전에 `Task.isCancelled` 를 확인해 버린다. Reducer 는 Task 를 모르므로 이 판단은 Store 의 몫이다. 세대 카운터는 두지 않는다.
- **스냅샷 스트림 소비.** 스트림은 `.startObserving` 으로 Store 가 직접 연 자원이다. 그래서 Store 가 소비해 "바뀌었다" Input 으로 바꾼다. 관찰 Task 가 취소되면 스트림도 끝난다.
- **rows 파생.** State 는 도메인 값만 담는다. Store 는 상태를 저장할 때 행에 영향을 주는 값이 바뀌었으면 `rows` 를 다시 만들어 함께 둔다.

View 는 `store.state` 와 `store.rows` 를 읽고 `store.send(_:)` 를 부르기만 한다. 예외는 화면 문서에 적는다.

### 예전 Reducer/Store 와 다른 점

이 레포는 한때 Reducer/Store 를 썼다가 ViewModel 로 되돌렸다. 그때의 실패가 되풀이되지 않도록 아래를 지킨다.

- **제네릭 `Store<R>` 를 두지 않는다.** Store 는 화면마다 구체 타입이다. 실행부(Task 슬롯, 스트림, 대기)는 화면마다 달라서 제네릭으로 묶어도 얻는 것이 없었다.
- **Reducer 는 의존성을 들지 않는다.** 예전 Reducer 는 Repository 와 `TaskBag` 을 들고 Effect 를 직접 실행했다. 그래서 순수하지 않았고 테스트가 Store 를 거쳐 `await` 해야 했다. 이제 Effect 실행은 Store 만 한다.
- **전이를 두 곳에 쓰지 않는다.** 예전에는 State 의 변경 메서드(`beginObserving()` 등)와 reduce 분기가 같은 전이를 나눠 들었다. 이제 전이는 reduce 안에만 있다. 읽기 쉽게 하려는 Reducer 내부 private helper 는 괜찮다.
- **공용 `Reducer` 프로토콜은 두지 않는다.** 두 번째 화면이 생긴 시점에 다시 판단했다. Store 가 화면마다 구체 타입이라 프로토콜을 통해 Reducer 를 부르는 곳이 없고, 그래서 프로토콜이 강제할 것이 없다. 두 화면이 똑같이 반복하는 `Decision` 만 공용 제네릭 타입으로 올린다. 제네릭 코드가 Reducer 를 부를 필요가 생기면 그때 프로토콜을 만든다.

남는 비용도 적어 둔다. 비동기 동작 하나를 더하면 Input(의도), Effect, Store 의 실행 분기, Input(완료), reduce 분기를 고친다. 대신 모든 전이를 I/O 없이 테스트할 수 있다는 이득이 실제로 회수된다(8절). 예전에는 비용만 있고 이 이득이 없었다.

**Reducer 가 커질 때.** 한 Reducer 안에 독립된 수명(예: 메시지 목록과 입력창 업로드)이 섞여 State 와 Input 조합이 계속 늘면 Reducer 를 나눈다. 파일 길이만으로 나누지 않는다. 플래그 하나마다 State case 를 곱해 늘려야 한다면 모델링이 잘못됐다는 신호다.

### 관찰 수명

관찰 수명은 **Store 수명**과 같다. `.task` 는 관찰을 시작만 하고, 화면이 push 로 가려져도 관찰을 끊지 않는다(복귀 시 재로딩 깜빡임 방지). Store 가 해제되면 `TaskBag.deinit` → 관찰 Task 취소 → `AsyncStream.onTermination` → 어댑터의 자원 정리로 이어진다. 별도의 teardown 메서드는 없다.

## 7. 의존성 주입 / 합성 루트

**백엔드는 SwiftUI Environment 에 한 번 등록하고, 그 밖의 의존성은 생성자로 주입한다.** DI 컨테이너와 전역 레지스트리는 두지 않는다. 이 패키지는 구체 백엔드를 모르므로 **조립은 패키지 밖**에서 한다.

```
<호스트 앱 루트>
  └─ .chatBackend(MyChatBackend())                          ← 합성 루트. 한 번 등록
       └─ ChannelListView()                                    @Environment(\.chatBackend) 로 읽는다
            └─ ChannelListContent(repository:currentUserID:)  internal. .id(ObjectIdentifier(backend))
                 └─ @State ChannelListStore

ChannelListView(repository:currentUserID:options:)            ← 덮어쓰기. Environment 를 보지 않는다
```

`ChannelView` 도 같은 모양이다. 화면별 경로는 화면 문서에 있다.

**전역 컨테이너(Swinject 류)가 아니라 Environment 인 이유.**

- 등록을 빠뜨려도 앱이 죽지 않는다. 컨테이너는 꺼내는 순간 실패하지만, Environment 값은 `nil` 이라는 기본값이 있어 화면이 그 상태를 처리할 수 있다.
- 전역 가변 상태가 없다. Swift 6 에서 잠금이나 격리를 따로 설계할 필요가 없다.
- 범위가 뷰 트리를 따른다. 프리뷰, 테스트, 화면 일부에만 다른 백엔드를 끼울 수 있고, 백엔드 둘을 한 앱에 띄울 수도 있다.
- 서드파티 의존이 없다. 테마도 같은 방식으로 내려보낸다.

슬롯과 달리 백엔드는 하위 화면으로 **상속되기를 원하는** 값이라 Environment 가 맞다(4절 Presentation).

**두 겹 구조.** 뷰의 `init` 에서는 Environment 를 읽을 수 없다. 그래서 화면 진입점은 `body` 에서 백엔드를 읽어 Store 를 가진 안쪽 뷰에 넘긴다. Store 는 안쪽 뷰가 `@State` 로 소유한다. 부모 뷰가 다시 그려질 때 Store 가 재생성되면 목록이 초기화되므로 이 규칙을 지킨다.

**백엔드가 바뀌면 화면을 새로 만든다.** `@State` 는 처음 값을 유지하므로, 로그아웃 뒤 새 백엔드를 등록해도 옛 Store 가 남는다. 안쪽 뷰에 `.id(ObjectIdentifier(backend))` 를 걸어 백엔드가 바뀌면 Store 를 새로 만든다.

**Store 를 정하는 다른 입력이 바뀌어도 새로 만든다.** 백엔드 외에 화면이 받는 식별자(채널 화면의 `channel.id` 등)도 안쪽 뷰의 `.id` 에 넣는다. 같은 자리에서 그 입력만 바뀌면 `@State` 가 옛 Store 를 유지하기 때문이다. 화면별 키는 화면 문서의 "정체성" 에 있다.

**등록을 빠뜨렸을 때.** `EnvironmentValues.chatBackend` 는 `(any ChatBackend)?` 이고 기본값은 `nil` 이다. `nil` 이면:

- 화면은 죽지 않고 `Placeholder` 로 "채팅을 불러올 수 없음" 상태를 그린다.
- DEBUG 빌드에서는 그 아래에 "`chatBackend(_:)` 가 등록되지 않았다" 는 개발자용 안내를 덧붙인다. 릴리스 빌드에는 개발자용 문구를 보이지 않는다.
- 화면이 나타날 때마다 `Logger`(subsystem `AnyChatUI`, category `Backend`)로 `.fault` 로그를 남긴다. Xcode 콘솔에 눈에 띄게 표시되고, 릴리스 빌드의 기기 로그에도 남는다.
- `assertionFailure` / `fatalError` 는 쓰지 않는다. 프리뷰와 호스트 앱의 디버그 실행을 멈추게 하기 때문이다.

덮어쓰기 init 을 쓴 화면은 Environment 를 보지 않으므로 이 경고가 나오지 않는다.

백엔드 연결(초기화, 로그인)은 호스트 앱이나 어댑터가 소유한다. 이 패키지는 등록된 백엔드가 쓸 수 있는 상태라고 가정한다. 등록은 됐지만 준비되지 않은 백엔드는 Repository 가 `.unavailable` 을 던지고, 화면은 에러 상태로 보여 준다.

## 8. 테스트 경계

| 테스트 대상 | 실물 | 더블 |
|---|---|---|
| 화면 Reducer | 순수 함수 | 없음. State 와 Input 을 직접 만들어 Decision 을 비교한다 |
| 화면 Store | Store 본체 | 화면 Repository 의 Spy, 채널 화면은 첨부 준비 클로저도 |
| 포매터 / RowState 파생 | 순수 함수 | 없음. 도메인 값을 직접 만들어 넣는다 |
| 토큰 카탈로그 | `ChatIcon` / `ChatPalette` / `ChatTypography` | 없음 |

화면별 대상과 더블 이름은 화면 문서의 "테스트" 에 있다.

- `AnyChatCoreTests` verifies custom message value storage, equality, and hashing without UI or backend dependencies.
- UI 테스트 타겟(`AnyChatUITests`)은 Reducer / Store / 포매터를 검증한다. 입력은 `ChatChannel` 과 `ChatMessage` 값이다.
  - **Reducer 테스트**는 `(State, Input) -> Decision` 만 본다. Store, Repository, 실제 시간을 만들지 않고 `await` 도 없다. Input 을 더할 때는 정상 전이뿐 아니라 무시, 실패, 늦은 완료도 확인한다. 전이 규칙의 테스트는 여기에 모은다.
  - **Store 테스트**는 Reducer 가 볼 수 없는 것만 본다. Effect 실행과 순서, `await` 전 상태 저장, Task 교체와 늦은 완료 버리기, 스트림 소비다. 화면에만 있는 책임(채널 리스트의 `refresh()` 대기 등)은 화면 문서에 적는다.
  - Store 없이 전이를 검증할 수 없다면 판단이나 I/O 가 잘못된 층에 섞였다는 신호다.
- DesignSystem tests (`AnyChatDesignSystemTests`) verify that every SF Symbol resolves, semantic colors follow appearance and contrast traits, and the typography uses system text styles. 원자 컴포넌트의 테스트 기준은 [design-system.md](docs/architecture/design-system.md) "원자" 에 있다.
- 어댑터와 매핑 테스트는 어댑터 패키지에 둔다.
- 비동기 대기에 `Task.sleep` 을 쓰지 않는다. `refresh()` 처럼 `async` 인 메서드는 직접 `await` 하고, `send(.start)` 처럼 백그라운드 관찰을 띄우는 Input 은 `Support/WaitHelpers.swift` 의 `waitUntil(_:)` 로 기대 상태를 기다린다.
- 더블은 각 테스트 타겟의 `Support/Doubles/` 에 둔다. 테스트는 SUT 를 직접 생성자 주입으로 조립한다.
- 테스트 타겟에는 `defaultIsolation` 을 걸지 않는다. `XCTestCase` 서브클래스가 MainActor 로 격리되면 상속받은 nonisolated 이니셜라이저와 충돌한다. MainActor 가 필요한 테스트 타입에는 `@MainActor` 를 직접 붙인다.
- 패키지 스킴은 `AnyChat` 이다. `swift build` / `swift test` 는 쓸 수 없다. 패키지가 iOS 만 선언하므로 macOS 호스트 빌드는 기본 최소 버전으로 컴파일되어 `AsyncStream` 등의 가용성 검사에서 실패하고, DesignSystem 은 UIKit 을 쓴다. macOS 지원을 넣을 이유가 생길 때까지 `xcodebuild` 로 시뮬레이터에서 검증한다.

## 9. 데모 앱 (`Examples/QuickStart`)

xcodegen 으로 생성하며 로컬 패키지를 `path: ../..` 로 링크한다. 이 레포는 공개될 예정이므로 데모 앱도 백엔드 SDK 를 의존하지 않는다. 한 `project.yml` 에 앱 타겟이 둘 있다.

- `QuickStart` — 최소 연동 예제. 앱 루트에서 샘플 백엔드를 `.chatBackend(_:)` 로 등록하고, 채널 리스트에서 채널을 고르면 `onChannelSelected` 로 채널 화면을 push 한다. 테마는 쓰지 않는다. 슬롯은 `QuickStartUITests` 가 그 렌더링이나 제스처를 검증해야 할 때만 쓴다. Showcase 에는 UI 테스트 타겟이 없기 때문이다. 지금은 메시지 아래 덧붙이기(`messageAccessory`), 날짜 구분선(`messageDateSeparator`, 사용자화 데모일 때만), 입력창 앞쪽 항목(`composerLeadingItems`), 채널 헤더(`channelHeader`), 빈 채널(`channelEmptyState`, 사용자화 데모일 때만, 샘플의 빈 채널 "Book club" 에서), 채널 리스트 머리(`channelListHeader`), 길게 누르기 오버레이(`messageLongPressOverlay`, 기본 메뉴를 대신하므로 `QUICKSTART_OVERLAY_DEMO=1` 일 때만), 입력창 정지 버튼(`composerStopButton`, 샘플 어시스턴트가 답하는 동안), 빈 채널 헤더(`channelHeader` 가 비면, `QUICKSTART_HIDDEN_HEADER_DEMO=1` 일 때만), 보낸 메시지를 위로 올리는 스크롤(`messageScrollBehavior(.questionToTop)`, `QUICKSTART_QUESTION_TO_TOP_DEMO=1` 일 때만)이 그렇다. 렌더링 검증은 `QuickStartUITests` 가 맡는다.
- `Showcase` — public API 만으로 바꿀 수 있는 것(테마, 슬롯, 스트리밍 텍스트, 채널 값 갱신, 커스텀 콘텐츠로 만든 에이전트 대화)을 보여주는 데모 모음. 데모마다 자기 샘플 백엔드를 등록하거나 자기 Repository 를 덮어쓰기 init 으로 넘겨, 한 데모의 변경이 다른 데모로 새지 않게 한다. 데모마다 `Showcase/<Name>/` 폴더 하나를 쓰고, 그 데모만 쓰는 Repository 같은 파일도 그 폴더에 둔다. 사람이 눈으로 보는 용도라 UI 테스트 타겟은 없다. 데모가 public API 로 할 수 없는 것을 만나면 `Sources/` 에 API 를 더하지 않고 이슈에 남긴다. 데모는 MCP 서버가 고객 에이전트에게 참고 예시로 함께 싣는다([mcp.md](docs/architecture/mcp.md#demos)). 그래서 데모의 본 뷰는 `<Name>Demo` 라는 이름과 `///` 첫 문장의 설명을 지킨다. 데모끼리는 Showcase 파일을 나눠 쓰지 않는다. 두 데모가 같은 작은 도우미를 쓰면 각자 `private` 으로 둔다. 데모가 폴더 밖에서 쓰는 것은 `Shared/` 의 샘플 백엔드와 샘플 값뿐이고, 그 이름은 모두 `Sample` 로 시작한다.

메모리 안 샘플 백엔드(`ChatBackend` 구현)와 그 첨부 파일은 `Shared/` 에 두고 두 타겟이 같이 컴파일한다.

## 10. 프로젝트 설정 메모

- `Package.swift` 의 tools-version 은 `6.2` 다. 타겟별 기본 격리를 지정하는 `SwiftSetting.defaultIsolation(_:)` 이 `_PackageDescription 6.2` 부터 제공되기 때문이다.
- 언어 모드는 패키지 레벨 `swiftLanguageModes: [.v6]` 로 고정한다.
- 외부 의존이 없어 `Package.resolved` 가 없다. 의존이 생기면 커밋한다. xcodebuild 가 따로 만드는 `.swiftpm/` 아래 resolved 파일은 무시 대상이다.

## 11. MCP server (`MCP/`)

The MCP server is the entry point customers install instead of the SDK. Their coding agent follows it from the tutorial to a running screen with no manual step. It is a separate TypeScript package in this repository, shipped with npx under the same version as the SDK. Its tools, its division of work with the agent, and its versioning rules are in [mcp.md](docs/architecture/mcp.md). The rules that hold here are these.

- The customer's agent writes the customer's code. The server says what to do, checks it, and edits only project settings files that are risky to edit by hand.
- The server's guidance stays backend-neutral, like the rest of this repository.
- A change the server must know about (components, their public API and doc comments, domain models, the backend boundary, the setup order) updates the server's side in the same PR, following the checklist in [mcp.md](docs/architecture/mcp.md#keeping-the-mcp-in-step-with-the-sdk).
