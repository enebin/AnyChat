# AGENTS.md

`AnyChat` — 백엔드를 모르는 **네이티브 SwiftUI 채팅 UI Kit** 레포지토리 지침. 도구 중립적이며 모든 기여자와 코딩 에이전트에 적용된다.

## 문서 관계

- `ARCHITECTURE.md` 와 그 하위 문서(`docs/architecture/`) — **구조 설계(어떻게)의 단일 출처.** 레이어 / 폴더 / 격리 경계 / DI / 테스트 경계는 이 문서들을 따른다. `ARCHITECTURE.md` 는 공통 원칙과 목차를, 하위 문서는 타입과 화면별 상세를 담는다.
- `AGENTS.md`(이 문서) — **작업 방식과 규칙.** 구조 결정은 `ARCHITECTURE.md` 로 위임하며 여기서 재서술하지 않는다.
- `CLAUDE.md` — `AGENTS.md` 로의 포인터.
- 기능 요구사항은 이슈 / PR 본문이 담는다. 별도 spec 문서는 두지 않는다.

## 프로젝트 개요

- **제품**: `AnyChatUI`. 백엔드 SDK 를 의존하지 않는 순수 SwiftUI 채팅 UI 다. 백엔드는 패키지 밖의 어댑터가 경계 프로토콜을 구현해 꽂는다. 구성은 `ARCHITECTURE.md` 2절을 따른다.
- **백엔드 어댑터와의 관계**: 특정 채팅 SDK 를 연결하는 어댑터는 이 패키지를 의존하는 **별도 패키지**이며 이 레포에 넣지 않는다. 이 레포에서는 어댑터가 꽂힐 수 있는 구조만 지킨다.
- **배포 형태**: SPM 라이브러리(제품 `AnyChatUI`)와, 고객이 그 대신 설치하는 MCP 서버(`MCP/`, npx 배포). 데모 앱은 `Examples/QuickStart`. MCP 구조는 `ARCHITECTURE.md` 11절을 따른다.
- **외부 의존성**: 목록은 SDK 는 `Package.swift`, MCP 는 `MCP/package.json` 이 단일 출처다. 다른 UI Kit 같은 외부 SDK 는 화면과 동작을 참고하되 직접 의존하지 않는다. 서드파티 추가는 반드시 먼저 묻는다.
- **툴체인**: iOS 18.0+, Xcode 26.4, Swift 6.3, Swift 6 언어 모드. MCP 는 TypeScript 이며 Node 버전은 `MCP/package.json` 이 정한다.

## 제품 방향

당장 구현할 범위가 아니라, 구조를 결정할 때 어긋나면 안 되는 장기 방향이다. 번호 순서가 우선순위다.

1. **UI 컴포넌트는 백엔드를 모른다.** UI 컴포넌트 레이어는 Chat SDK 같은 백엔드의 존재 자체를 모르게 만든다. Chat 의존성은 완전히 추상화한다. UI 는 추상 경계에만 의존하고, Chat SDK 는 그 경계의 구현 중 하나일 뿐이다. 채널 / 메시지 같은 SDK 타입 대신 원시 값이나 자체 값 타입을 받는다. 모델은 Group / Open 같은 채널 종류로 나누지 않고, 종류별 차이는 어댑터 안에만 둔다. 백엔드 어댑터는 이 레포 밖에 둔다. 참고 모델은 [exyte/chat](https://github.com/exyte/chat) 이다. 그래서 UI 컴포넌트에 특정 백엔드 전용 가정(SDK 타입, 서버 규칙, 비공개 API)을 넣지 않는다.
2. **고객은 사람 손으로 구현하지 않는다.** 고객은 SDK 문서를 읽는 대신 MCP 서버를 설치하고, 고객의 코딩 에이전트가 그 MCP 를 따라 튜토리얼 → 셋업 → UI 커스텀 → 백엔드 연결을 끝낸다. 그래서 public API 는 사람이 읽기 좋은 것만큼 에이전트가 틀리지 않고 쓸 수 있어야 한다. 에이전트가 맞게 했는지 스스로 확인할 수단(검사 도구, 계약 테스트)이 설명보다 우선이다.
3. **디자인은 디자인 원본(iOS 26 메시지 앱 시안)을 따르고, 커스터마이즈는 지금처럼 제공한다.** 색상 등은 테마로 바꿀 수 있어야 한다. 세부 규칙은 "디자인 기준" 절을 따른다. 화면을 설계할 때는 색·폰트뿐 아니라 크기·레이아웃 변경과 실시간으로 바뀌는 내용(스트리밍 텍스트 등)도 사용자가 테마나 슬롯으로 감당할 수 있는지 검토한다. 기본 제공은 하지 않더라도 막지는 않는다.
4. **(낮은 우선순위) AI Agent UI 까지 흡수한다.** 커스터마이즈만으로 AI Agent 의 UI 를 만들 수 있을 만큼 유연한 것이 장기 목표다. 이 수준의 커스터마이즈가 경쟁력이라고 본다. 다만 가능할지 확실하지 않으므로 이것만을 위한 추상화를 미리 만들지 않는다. 구조 결정이 이 방향을 막는지만 검토한다.
5. **구조는 TCA 스타일 Reducer 패턴과 클린 아키텍처를 따른다.** 세부 구조는 `ARCHITECTURE.md` 가 정한다. 패턴을 따른다는 뜻이며, TCA 라이브러리를 의존성으로 들이는 것은 별개 결정이다(서드파티 추가 규칙).

## 핵심 원칙

- 기본 언어는 영어다. 코드 식별자 / 코드 주석 / 테스트 이름 / 커밋 메시지 / 에이전트·스킬 프롬프트 / 작업 로그는 영어로 쓴다. 사용자에게 하는 대답만 한국어로 쓴다.
- 새 작업을 시작할 때는 `ARCHITECTURE.md`, `Package.swift`, `Examples/QuickStart/project.yml` 을 먼저 읽고 기존 구조를 우선한다.
- 빌드 가능성과 public API 안정성을 최우선으로 한다.
- 미래 확장성만을 위한 추상화 / 레이어 / 의존성을 만들지 않는다. UseCase 레이어 없음, DI 컨테이너 없음, Coordinator 없음.
- 이 SDK 는 UI 구현만 고려한다. 읽음 처리, 안 읽은 수 계산 같은 구체적인 백엔드 기능을 어떻게 동작시킬지는 고려하지 않는다. 그런 기능은 어댑터와 호스트가 정한다. 백엔드 경계에는 화면이 그리고 사용자 동작을 전달하는 데 필요한 것만 둔다.
- 기능 구현에 기술 옵션이 여러 개 있을 때는 임의로 고르지 말고 묻는다.
- 위험한 작업을 실행하기 전에 확인한다.
- 구조를 바꿔야 하는 상황이면 코드보다 `ARCHITECTURE.md` 와 해당 하위 문서를 먼저 갱신한다.

## 디자인 기준

UI 의 시각적 기준인 **디자인 원본**은 iOS 26 메시지 앱 UI 키트를 옮긴 시안이다. 수치는 [`docs/design/messages/README.md`](docs/design/messages/README.md) 의 표에서 읽고, 화면 모습은 같은 폴더의 `boards/` 와 그 README 가 가리키는 Claude 디자인 캔버스에서 본다. 색상 / 타이포그래피 / 간격 / 아이콘 / 상태별 표현은 임의로 정하지 말고 원본을 따른다. 작업이 다른 원본을 지정하면 그것을 따른다.

원본에 없는 부분을 새로 정하면 키트의 값으로 만들고, 그 값을 같은 README 에 "new" 로 표시해 더한다. 답장의 인용과 답장 줄이 그렇게 정한 예다.

### 수치는 눈대중으로 맞추지 않는다

화면이나 컴포넌트를 구현할 때는 원본에서 대응하는 요소를 열어 실제 수치를 읽고 그대로 옮긴다. 스크린샷만 보고 값을 어림하지 않는다.

- 요소의 x / y / width / height 를 읽는다. 패딩과 간격은 형제 요소의 좌표 차이로 계산한다.
- 색상과 폰트는 원본의 토큰 정의에서 읽는다.
- 맞출 대상: 좌우 / 상하 패딩, 요소 간 간격, 고정 크기(아바타 / 아이콘 / 배지), 구분선 inset, 폰트 크기와 굵기.
- 구현한 뒤 같은 요소를 다시 읽어 수치를 대조한다. 어긋나면 원본을 따른다. 원본과 다르게 둔 값은 이유를 PR 본문에 적는다.
- 값을 확인할 수 없으면 사용자에게 묻는다. 색상 코드 / 폰트 / 간격을 추측해서 채우지 않는다.

### 값을 두는 위치

- **화면과 무관한 값**(색 / 타이포그래피 / 아이콘)은 `Sources/AnyChatDesignSystem/Token` 에 둔다. 이름 규칙은 `docs/architecture/design-system.md` 를 따른다.
- **화면 테마**(`ChannelListTheme` 등)는 `Sources/AnyChatUI/Theme` 에 두고 기본값으로 위 토큰을 참조한다. 뷰 코드에 색상 / 폰트 리터럴을 직접 쓰지 않는다. 레이아웃 수치는 해당 뷰에 둔다.
- 여러 화면에 같은 모양으로 놓이는 원자 컴포넌트는 `Sources/AnyChatDesignSystem/Atom` 에 두고 색과 폰트를 파라미터로 받는다. 화면 단위 조합은 화면 폴더에 둔다.
- 원본에 없는 화면 / 상태(로딩, 빈 목록, 에러 등)는 가장 가까운 컴포넌트의 토큰과 수치를 재사용하고, 새로 만든 값은 PR 본문에 근거를 남긴다.

## Public API 규율

이 레포는 SDK 다. 한 번 공개한 API 는 고객 코드를 깨뜨리지 않고는 되돌릴 수 없다.

- `public` 은 `AnyChatUI` 의 **View / ViewModifier / Theme / Options / Formatter / 슬롯 문맥 값** 과 백엔드 등록 모디파이어, 덮어쓰기용 진입점, `AnyChatCore` 의 **도메인 모델과 백엔드 경계 프로토콜**에만 붙인다. `Reducer` / `State` / `Store` / `RowState` 는 `internal`, DesignSystem 은 `package` 다. 타겟별 표는 `ARCHITECTURE.md` 2절에 있다.
- 모든 신규 public 심볼에 `///` 문서 주석과 `/// - Since: 1.0.0` 태그를 단다. MCP 의 컴포넌트 카탈로그가 이 주석을 고객 에이전트에게 그대로 보여 준다.
- **MCP 가 알아야 하는 구성이 바뀌면 같은 PR 에서 MCP 쪽도 고친다.** 화면이나 컴포넌트를 더하거나 빼는 일, 생성자 / 슬롯 / 콜백 / 테마 / 옵션과 그 문서 주석, 도메인 모델, 백엔드 경계, 화면이 필요로 하는 것, 셋업 순서가 그렇다. 화면이 나타나기 전에 필요한 것(백엔드 등록, `Info.plist` 키 등)은 그 View 의 문서 주석에 적는다. 무엇을 고칠지는 `docs/architecture/mcp.md` 의 "Keeping the MCP in step with the SDK" 표를 따른다. 고객 에이전트는 MCP 가 말한 대로만 코드를 쓰므로, 둘이 어긋나면 고객 빌드가 깨진다.
- 화면 타입 이름에 채널 종류(Group / Open)를 넣지 않는다(`ChannelListView`). 종류가 드러나는 이름은 백엔드 어댑터(패키지 밖)에만 둔다. 타입 이름에 약어 접두어(대문자 두세 글자)를 붙이지 않는다. 약어는 대문자를 유지한다(`channelURL`, `userID`).
- **전역 가변 레지스트리 금지.** 전역 뷰 컨버터 세트 같은 전역 타입 세트 / 싱글턴 config 는 만들지 않는다. 커스터마이즈는 뷰 모디파이어 체이닝과 Environment 로만 제공한다.
- 기존 public 심볼의 시그니처 / 접근 수준을 바꾸지 않는다. 새 심볼을 추가하고 `@available(*, deprecated, renamed:)` 로 이전 경로를 남긴다.
- `@_exported`, `@_spi` 등 언더스코어 속성을 쓰지 않는다. 유일한 예외는 `AnyChatUI/Common/Exports.swift` 의 `@_exported import AnyChatCore` 다. 사용자가 `import AnyChatUI` 한 줄로 쓰게 하기 위해서다.
- 도메인 모델은 백엔드와 무관한 자체 값 타입(`ChatChannel`, `ChatMessage`, `ChatSender`)이다. 이 패키지에는 백엔드 SDK 타입이 없다. 모델 규칙은 `docs/architecture/domain-models.md`, 어댑터가 지킬 규약은 `docs/architecture/backend-boundary.md` 를 따른다.

## 동시성

- Swift 6 언어 모드에서 경고 0 을 유지한다.
- 도메인 모듈(`AnyChatCore`)은 nonisolated 기본, 나머지 모듈(`AnyChatDesignSystem`, `AnyChatUI`)은 MainActor 기본이다. 자세한 규칙은 `ARCHITECTURE.md` "격리 경계" 를 따른다.
- 패키지 안을 오가는 값은 모두 `Sendable` 이다. 백엔드 SDK 객체를 패키지 안으로 들이지 않는다.
- `nonisolated(unsafe)` 와 `@unchecked Sendable` 래퍼를 쓰지 않는다.
- `AnyChatUI` / `AnyChatDesignSystem` 에 클래스를 더하면 `nonisolated deinit {}` 를 선언한다. 빠뜨리면 iOS 18 에서 해제 시 크래시한다. 이유는 `ARCHITECTURE.md` 3절.
- 비동기는 `async`/`await` 를 쓴다. Combine 과 RxSwift 는 쓰지 않는다. 상태 관찰은 `@Observable` 이다.

## 아키텍처 작업 원칙

구조 자체는 `ARCHITECTURE.md` 가 단일 출처이며, 아래는 구조와 무관하게 유지되는 작업 규칙이다.

- 백엔드는 SwiftUI Environment(`chatBackend(_:)`)에 한 번 등록하고, 그 밖의 의존성은 생성자로 주입한다. DI 컨테이너와 서드파티 DI 라이브러리를 쓰지 않는다. 근거는 `ARCHITECTURE.md` 7절.
- 이 패키지는 구체 백엔드를 조립하지 않는다. 조립과 등록은 패키지 밖(호스트 앱, 어댑터)에서 한다.
- 백엔드 미등록은 크래시가 아니라 화면 상태와 `.fault` 로그로 알린다. `assertionFailure` / `fatalError` 로 막지 않는다.
- 프로토콜은 백엔드 경계와 테스트 더블이 필요한 I/O 경계(시간, 난수)에만 둔다.
- **유효성 확인을 위해 세대 식별자(generation / epoch / token)를 만들지 않는다.** Task 동일성, 자원 참조 동일성, 상태의 현재 case 처럼 이미 있는 동일성으로 판별한다. 취소는 협조적이라 취소한 작업의 완료도 도착하므로, 상태를 쓰기 직전에 확인한다.
- 화면 상태는 Reducer 패턴으로 관리한다. 전이 규칙은 순수 `Reducer` 가 `(State, Input) -> Decision` 으로 정하고, 화면별 `Store` 가 상태를 단독 소유하며 Effect 를 실행한다. 상태가 바뀌는 곳은 Store 가 `nextState` 를 저장하는 한 곳뿐이다. Effect 완료 지점에서 상태를 직접 바꾸지 않고 새 Input 으로 보낸다. View 와 Row 는 표시 전용이다. 계약은 `ARCHITECTURE.md` 6절.
- Reducer 에 `async`, `throws`, I/O, 상태 저장 프로퍼티를 두지 않는다. 무시하는 Input 도 명시적인 Decision 으로 처리하고, 넓은 `default` 나 `nil` 로 넘기지 않는다.
- 제네릭 `Store<R>` 와 공용 `Reducer` 프로토콜을 만들지 않는다. Reducer 패턴 타입 중 화면 사이에 공유하는 것은 `Decision` 하나다. 근거는 `ARCHITECTURE.md` 6절.
- 백엔드 연결(초기화, 로그인)은 호스트 앱이나 어댑터가 소유한다. 이 패키지는 스스로 연결하지 않는다.

## 프로젝트 설정

- 라이브러리는 `Package.swift` 가 단일 출처다. 레포 루트에 `.xcodeproj` 를 두지 않는다.
- 데모 앱은 `Examples/QuickStart/project.yml` 이 단일 출처다. `.xcodeproj` 는 생성물이며 gitignore 대상이다. 설정을 바꾼 뒤 `xcodegen generate` 로 재생성하고 `xcodebuild -list` 로 검증한다.
- 의존이 있으면 `Package.resolved` 를 커밋한다. `.build/`, `.swiftpm/`, `DerivedData/` 는 무시한다.

## 테스트 / 검증

- XCTest 를 쓴다. 테스트 케이스는 Given / When / Then 3 분할로 쓰고 이름은 영어로 쓴다.
- 테스트 더블은 각 테스트 타겟의 `Support/Doubles/` 에 둔다. 공용 헬퍼는 `Support/` 아래 용도별 enum 네임스페이스로 모은다.
- 여러 단언에서 같은 의미로 반복되는 리터럴은 하드코딩하지 않는다. 테스트 상수나 헬퍼로 한 번 정의해 공유한다.
- **상태를 다루는 타입은 테스트 없이 머지하지 않는다.** Reducer 는 Input 마다 정상 / 무시 / 실패 / 늦은 완료를 테스트한다. Store 는 Effect 실행, Task 교체, 늦은 완료 버리기, 스트림 소비를 테스트한다. Formatter / Resolver 같은 순수 로직도 같다. 표시 전용 View 와 Row 는 예외다.
- Reducer 테스트는 더블 없이 State 와 Input 만으로 쓴다. Store 테스트는 Repository 더블을 주입한다. **단위 테스트가 실제 백엔드에 접속하지 않는다.**
- 비동기 대기에 `Task.sleep` 을 쓰지 않는다. Store 의 `async` 메서드는 직접 `await` 하고, 그 밖의 상태는 `Support/WaitHelpers.swift` 의 `waitUntil(_:)` 로 기다린다.

### UI 테스트

화면 전환과 실제 렌더링은 `Examples/QuickStart` 의 `QuickStartUITests` 타겟이 덮는다. 라이브러리 타겟에는 앱 호스트가 없어 XCUITest 를 올릴 수 없다.

- UI 테스트 타겟은 `SWIFT_DEFAULT_ACTOR_ISOLATION: nonisolated` 를 쓴다. 프로젝트 기본값인 MainActor 를 두면 `XCTestCase` 의 nonisolated 오버라이드와 격리 수준이 어긋나 컴파일되지 않는다.
- `UserDefaults` 를 실행 인자(`-key value`)로 덮어 초기 상태를 만들지 않는다. 인자 도메인이 앱이 쓴 값보다 우선이라 화면에서 입력해도 값이 바뀌지 않는다. 상태는 화면에서 직접 만든다.
- Apple 계정에 로그인된 시뮬레이터는 시스템 알림을 띄워 탭을 가로챈다. `addUIInterruptionMonitor` 로 넘기되 버튼 제목은 지역화되므로 위치로 누른다.
- UI 테스트는 데모 앱의 메모리 샘플 백엔드로 돌아 네트워크가 필요 없다. 네트워크가 필요한 테스트를 더하면 문서 주석에 그렇다고 적는다.
- 화면을 검증한 테스트는 `XCTAttachment(screenshot:)` 으로 스크린샷을 남긴다. 디자인 원본과 대조할 근거가 된다.
- 전체 스위트는 몇 분이 걸린다. 고치는 동안에는 바뀐 화면을 덮는 테스트만 `-only-testing` 으로 돌리고, 전체 스위트는 스텝을 끝내기 전에 한 번만 돌린다.

```bash
xcodebuild test -project QuickStart.xcodeproj -scheme QuickStart -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:QuickStartUITests/ChannelListUITests/testSendingTextShowsTheMessage
```

- 검증 명령:

```bash
xcodebuild build -scheme AnyChat -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -scheme AnyChat -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

cd Examples/QuickStart && xcodegen generate
xcodebuild build -project QuickStart.xcodeproj -scheme QuickStart -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -project QuickStart.xcodeproj -scheme QuickStart -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild build -project QuickStart.xcodeproj -scheme Showcase   -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

  시뮬레이터 이름은 `xcrun simctl list devices available` 로 확인한 것으로 바꿔 쓴다. **`swift build` 와 `swift test` 는 쓸 수 없다.** 이유는 `ARCHITECTURE.md` 8절에 있다.
- MCP 검증 명령:

```bash
cd MCP && npm ci && npm test
cd MCP && npm run catalog:check
```

  `catalog:check` 는 Xcode 로 SDK 를 빌드해 `MCP/catalog/components.json` 이 public API 와 맞는지 보고, `MCP/catalog/examples` 의 배치 예시가 경고 0 으로 컴파일되는지 본다. public 심볼이나 그 문서 주석을 바꿨다면 `npm run catalog` 로 다시 생성해 함께 커밋한다.

  `MCP/src/guide.ts` 의 Swift 예시 코드를 바꾸면, 그 코드를 이 패키지를 의존하는 임시 iOS 패키지에 넣고 `xcodebuild build` 로 경고 0 을 확인한다. 고객 에이전트가 그대로 옮겨 쓰는 코드라 컴파일되지 않으면 셋업이 멈춘다.
- 빌드나 테스트를 실행하지 못했다면 그 이유를 작업 결과에 남긴다.

### Independent UI QA

- Rendered UI and interaction QA runs before each release and whenever the user requests screen QA (`qa.bundle: release` in `GROUNDWORK.md`). Every UI change still needs UI tests with screenshots that the implementer inspects.
- Run it with `/groundwork:ui-qa`. Launch notes are under "UI QA notes" in `GROUNDWORK.md`. Do not keep repository copies of QA instructions.
- The QA agent owns execution and evidence; the implementation agent owns source and test fixes. Give QA exclusive use of its simulator. After a UI fix, return the affected checks to QA against the rebuilt app.
- Run each UI test once per build. The implementation agent runs the targeted UI tests and hands QA the `.xcresult` path with the commit and dirty state it was built from. QA reuses that result when its provenance matches the current tree and runs only the checks it does not cover. Neither side reruns a test the other already ran on the same build.
- UI work is complete only when required checks pass and relevant screenshots have been inspected. A blocked or unavailable independent check must be reported as unverified, with its reason; do not claim QA passed. Keep code review and its Skeptic Review rules separate.

## 작업 진행

- 이슈 트래커는 GitHub Issues 다.
- PR 하나로 끝나지 않는 작업은 부모 이슈 하나와 스텝별 sub-issue 로 나눈다. 분할과 이슈 생성은 `/groundwork:plan` 이 한다.
- 스텝 하나는 sub-issue 하나, PR 하나다. 각 스텝은 혼자 빌드되고 테스트가 통과해야 한다.
- 진행 맥락(결정, 남은 일, 리뷰 라운드 결과)은 이슈에 남긴다. 세션이 바뀌어도 이슈만 읽고 이어갈 수 있어야 한다. 구조 결정은 이슈가 아니라 `ARCHITECTURE.md` 와 하위 문서에 반영한다.
- 스텝 진행은 `/groundwork:step` 이 한다. 검증 명령 통과 → 리뷰 → 수정을 반복한다. 완료 기준은 검증 명령 통과와 리뷰에서 확인된 🔴/🟠 0 건이다. 🟡 와 nit 는 막지 않고 이슈에 남긴다. 3 라운드가 지나도 🔴/🟠 가 남으면 멈추고 묻는다.

## Git / GitHub

- 커밋 메시지는 제목과 본문 모두 영어로 쓴다. 제목은 `[TAG] Description` 형식이고 80 자 이내로 유지한다.

| Tag | 용도 |
|-----|------|
| `[ADD]` | 새 기능 / 파일 |
| `[MOD]` | 기존 기능 수정 |
| `[FIX]` | 버그 수정 |
| `[REFACTOR]` | 리팩토링 |
| `[DOCS]` | 문서 |
| `[TEST]` | 테스트 |
| `[CHORE]` | 빌드 / 의존성 / 설정 |
| `[DEL]` | 삭제 |

- **커밋 메시지에 `Co-Authored-By` 트레일러를 절대 넣지 않는다.** "Generated with" 류의 문구도 넣지 않는다.
- 기본 브랜치는 `main`, 통합 브랜치는 `develop` 이다. 작업 브랜치는 `develop` 에서 따고 PR 도 `develop` 으로 연다. 릴리스는 `release/x.y.z` 를 거쳐 `main` 으로 간다. 커밋과 푸시는 사용자가 요청할 때만 한다.
- PR 이 squash merge 되면 그 브랜치를 로컬과 원격에서 모두 지운다. squash 된 브랜치는 git 이 머지되지 않은 것으로 보므로, 지우기 전에 `gh pr view <branch>` 로 PR 이 `MERGED` 인지 확인하고 `git branch -D` 를 쓴다.

<!-- groundwork:begin implementation -->
## Implementation rules

### Implementation and tests

- A type that holds or transitions state is not merged without tests. Test each input for the normal path, the ignored case, the failure case, and a completion that arrives late. Pure logic (formatters, resolvers, parsers) is tested the same way. Display-only views are exempt.
- Write each test as Given / When / Then. Name tests in plain language that states the behavior.
- Do not hard-code the same literal across several assertions. Define it once as a test constant or helper.
- Unit tests never reach a real backend, network service, or production data. Replace I/O at its boundary with a test double.
- Do not wait with sleeps. Await async calls directly, or poll for the expected state with a bounded wait helper.
- Write meaningful tests with behavior changes and regression tests for bug fixes. During implementation, run the affected tests. Before declaring work done, run every `verification.commands` entry and the required UI suite. Follow the effective groundwork mode for targeted versus full UI runs; no mode removes required tests or screenshot inspection.
- Every changed screen has a UI test that attaches a screenshot. UI work is done only when the implementer has opened those screenshots and checked them. Checks no test can make go into the UI coverage ledger with the reason. A check may go to "Why QA must look" only when no UI test can make it, after considering all three ways: asserting a value (sizes, frames, visibility, text), launching with a different condition (dark appearance, largest text size, locale, an empty or error state), and attaching a screenshot that the implementer opens. The reason must say why each of the three fails. A missing test hook is not a reason: when a check needs one (a launch argument, an injectable clock or store), add it in debug or test builds only, then write the test. Only a rule in this document that forbids the hook lets the check go, and the reason names that rule. What remains is human judgment: whether wording reads naturally, whether a flow feels easy, how an animation feels.
- Run each UI test once per build. Record the result path with the commit and dirty state it was built from, so later checks on the same build reuse it.
- Keep compiler and type-checker warnings at zero. A new warning is a failure.
- If any verification could not run (missing tool, no simulator), say which one and why in the work result. Report it as unverified. Never report it as passed.
<!-- groundwork:end implementation -->

<!-- groundwork:begin ci-gate -->
### CI gate

- Work is done only after every CI check on its pull request has passed. Local verification is required first, but it does not replace CI.
- A PR with no CI checks is not done. Say so and ask; do not treat "no checks" as "checks passed".
- A failing or flaky check is fixed at its root cause. Do not rerun until green, skip the check, or mark it optional to get through.
- When CI fails and the same command passed locally, record the difference (environment, version, missing file) in the issue before fixing it.
<!-- groundwork:end ci-gate -->

<!-- groundwork:begin design-fidelity -->
### Design fidelity

The design source is `verification.design_source`. When a task names another source, that one wins for the task.

- Read real values from the design source. Do not estimate them from a screenshot.
  - Read each element's x / y / width / height. Derive paddings and gaps from the coordinate difference between sibling elements.
  - Read colors and fonts from the source's token definitions, not from sampled pixels.
  - Match: horizontal and vertical padding, gaps between elements, fixed sizes (avatars, icons, badges), divider insets, font size and weight.
- After implementing, read the same elements again and compare. Where they differ, follow the source. If you keep a different value on purpose, give the reason in the PR body.
- A value the source does not have (a new state, a new screen, a loading or empty or error view) is built from the nearest existing component's tokens and values. Add it to the design reference marked "new", with the reason.
- If a value cannot be read, ask. Never fill in a color, font, or spacing by guessing.
- Do not write color or font literals in view code. Use the project's tokens or theme. When a token is missing, add it to the token source first.
<!-- groundwork:end design-fidelity -->

<!-- groundwork:begin api-contract -->
### Public API contract

- Every public symbol has a doc comment that says what it does, and a since-version tag (for example `- Since: 1.0.0`).
- An automated check compares the published API surface with the docs or component catalog. It runs in `verification.commands` and in CI. When a public symbol or its doc comment changes, regenerate the docs or catalog in the same PR.
- Example code that ships with the library (README, guides, catalog examples) compiles with zero warnings against the current source. A changed example is compiled before merge.
- Do not change the signature or access level of an existing public symbol. Add the new symbol, keep the old one working, and mark it deprecated with a pointer to the replacement. Remove it only in a major version.
- Things a user must do before a component works (registration, configuration keys, permissions) are written in that component's doc comment.
<!-- groundwork:end api-contract -->
