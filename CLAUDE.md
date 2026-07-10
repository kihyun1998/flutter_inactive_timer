## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`kihyun1998/flutter_inactive_timer`), managed via the `gh` CLI. External PRs are **not** a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical label vocabulary — `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` (no overrides). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## 작업 flow

*Substantive 변경*(버그 수정·기능 추가·동작 변경)이면 이 8단계로 짠다. 단계를 *생략*하려면 (건너뛰는 게 아니라) *왜 이 변경엔 해당 없는지를 명시*한다 — 조용한 스킵 금지.

괄호 안 실증은 그 단계를 건너뛰었다면 놓쳤을 것이다. 전부 이 repo 에서 실제로 일어났다.

### 0. 이 repo 의 반복되는 실패 형태: `await` 뒤에는 세상이 이미 바뀌어 있다

이 패키지는 **비동기 네이티브 읽기 위에 올라간 타이머**다. `getIdleDuration()` 을 `await` 하는 사이에 사용자가 `stopMonitoring()`·`continueSession()`·`dispose()` 를 부를 수 있다. 같은 모양의 버그가 네 번 났다.

- `07ac425` — `_checkInactivity` 가 await 뒤 `isMonitoring` 을 다시 안 봐서, stop 이후에 콜백이 발화했다.
- `9759514` — example 앱이 await 뒤 `BuildContext` 를 그대로 썼다.
- `8c03f6f` — await 뒤 타이머를 arm 해서, 선점된 스케줄이 유령 타이머를 남길 수 있었다(#5). generation 카운터로 봉했다.
- `a6abd0f` — `remaining()` 이 idle 읽기에 park 된 사이 `stopMonitoring()` 이 끼어들었다.

**`await` 를 새로 넣거나 옮겼으면, 재개 지점에서 읽는 모든 상태를 다시 확인한다** — `isMonitoring`, generation, `mounted`. 그리고 그 경쟁을 재현하는 테스트를 붙인다(`test/ghost_timer_test.dart` 의 `GatedIdlePlatform` 이 읽기를 원하는 지점에 세워 둔다).

### 1. 이슈 먼저 — 실측 숫자·기각한 대안·부정 결과

측정한 숫자를 이슈에 박고, **기각한 대안과 그 이유**를 함께 적는다. 안 그러면 같은 대안이 다시 제안된다.

- **이슈 본문에 쓴 근거도 실증 대상이다.** 틀린 근거가 리포 기록에 남으면 다음 사람이 그걸 믿고 판단한다. 실증(#5): 본문은 `_scheduleNextCheck()` 가 두 개의 살아있는 `Timer` 를 만들어 유령 타이머가 샌다고 단언했다. 착수해 보니 그 누수는 **이미 #3 의 `InactivityPolicy` 추출로 사라져 있었다** — `_arm` 이 재할당 전에 cancel 하고 `_pump` 가 await 뒤 상태를 다시 읽는다. 재현 테스트가 그걸 확인했다. 실제 변경은 "누수 수정" 이 아니라 generation 카운터를 통한 **불변식의 명시화**가 됐고, 커밋 메시지에 그 정정을 남겼다.
- **삭제·단순화에는 도달 불가의 *적극적 증명*을 요구한다.** 커버리지 부재는 증거가 아니다.
- **부정 결과·범위 밖 발견도 재현과 함께 남긴다.** 그 자리에서 안 고칠 거면 별도 이슈로 연다.

### 2. 추측 금지 — 실측한다

**코드를 *읽어서* 얻은 확신은 확신이 아니다.**

- **네이티브 API 문서·소스를 직접 확인한다.** 기억·요약 금지. 실증(ADR-0001): Windows 의 `getSystemTickCount` 는 64 비트 `GetTickCount64` 에서, `getLastInputTime` 은 **32 비트** `GetLastInputInfo.dwTime` 에서 왔다. 후자는 약 **49.7 일**마다 wrap 한다 — 그 뒤 Dart 쪽 뺄셈은 쓰레기값을 낸다. macOS 는 마침 둘 다 `systemUptime` 기준이라 계약이 암묵적이고 강제되지 않은 채로 굴러가고 있었다. "두 클럭을 Dart 에서 뺀다" 는 계약 자체를 없애고 네이티브가 idle duration 하나를 반환하게 했다.
- **버리는 프로브 / 재현 테스트로 확인한다.** 프로브는 버리되 **숫자는 이슈/PR 에 남긴다**.
- **테스트 하네스도 검증 대상이다.** 실증(#17): 새 테스트가 계속 실패해서 대상 코드를 의심했는데, 범인은 fake 였다. `GatedIdlePlatform.releaseHeldRead` 가 읽기가 park 되는 순간 `_hold` 를 null 로 만들어, park 된 read 를 **release 할 방법이 없었다**. `_held` 로 따로 추적해 고쳤다. 기존 유령 타이머 테스트는 generation 가드가 재개된 읽기를 버리기 때문에 이 버그를 드러내지 못했다.
- **외부 사실도 조회 대상이다.** pub.dev 상태는 `curl -s https://pub.dev/api/packages/flutter_inactive_timer`.
- **"확인했다" 가 정말 확인인지 본다.** 어느 쪽이든 빈 결과가 나오는 검사(grep 오타·못 맞춘 유니코드 문자)는 검사가 아니다.

**"확인 못 했다" ≠ "없다".** 미확인 사실은 갭이다. 이슈로 surfacing 하거나 사용자에게 묻는다 — 조용히 설계 가정으로 승격시키지 마라.

### 3. 설계 판단은 코드 전에 사용자와 확정

**TDD 는 "무엇이 옳은가" 를 답해주지 않는다.** 기대값을 발명하기 전에 정책을 못 박는다. *결정 유형으로 라우팅*한다.

- **순수 메커니즘**(자료구조·클럭 선택·훅 위치 — 소스로 도출 가능) → 직접 결정하고 **검증 결과만** 제시. 답이 코드에 있는 걸 묻는 건 일 떠넘기기다.
- **계약·정책**(공개 API 표면, 폴백 동작, 테스트 seam, 동작 변경 허용 여부) → **묻는다.** 이 패키지의 ADR 세 개는 전부 코드보다 먼저 나왔다.
  - 실증(ADR-0002): "`notificationPer` 를 deprecated 로 한 릴리스 병존시킨다" 를 기각한 건 코드를 쓰기 전이었다. 두 방식이 공존하면 생성자에서 "둘 다 세팅됨" 이라는 표현 가능한 불법 상태가 되살아나고, 그건 sealed `NotificationTrigger` 를 도입한 이유 자체를 무너뜨린다.
  - 실증(ADR-0003): `remaining()` 이 pull 인지 push 인지, sync 인지 async 인지는 red 테스트를 쓰기 *전에* 정해야 했다. 동기 getter 는 fresh idle 을 못 읽어서 Notification 이전 구간에서 사용자 활동을 반영하지 못한다 — 그 사실이 시그니처를 `Future<Duration>` 으로 확정했다.
- **`/grilling` 으로 설계 트리를 먼저 흔든다.**

### 4. `/tdd` 로 RED→GREEN 수직 슬라이스

한 번에 하나 — 테스트 하나 → 최소 구현 → 반복.

- **functional core / imperative shell 을 지킨다.** 결정은 `lib/src/inactivity_policy.dart` 의 순수 함수로, 시간·채널·타이머는 `FlutterInactiveTimer` 셸로. 실증(ADR-0002): `NotificationTrigger` 는 셸에서 `notifyAtMs` 하나로 해석돼 policy 에 들어간다 — policy 는 trigger 종류를 모르고, 새 종류가 생겨도 안 바뀐다. **새 결정 규칙은 policy 의 순수 테스트로 덮고, 셸 테스트는 배선만 본다.**
- **공개 seam 에서 관찰한다.** 내부 필드를 읽지 말고, 관측 가능한 사실(발화한 콜백, `remaining()` 이 돌려준 값)을 읽는다.
- **시간은 `fake_async` 와 주입한 clock 으로 흘린다.** 실제로 기다리지 않는다.
- **RED 가 정말 RED 인지 본다.** 처음부터 초록불인 단언은 아무것도 지키지 않는다.
- **규칙을 어겼으면 되돌린다.** TDD 의 가치는 코드가 아니라 "이 테스트가 정말 실패하는가" 를 보는 순간에 있다.

### 5. 테스트 신뢰 게이트 — 두 질문은 다르다

- **구분력이 있는가.** 통과하는 테스트는 그 자체로 아무것도 증명하지 않는다. 경쟁 테스트라면 "정말 그 순간에 끼어들었는가" 를 먼저 단언한다.
- **옳은 이유로 통과하는가.** 부수 조건까지 단언해 우연한 순서로 통과할 수 없게 만든다.
- **커버리지는 "무엇을 안 봤는지" 를 알려주지, "본 것이 옳은지" 는 말해주지 않는다.**
  - 실증(#17): `remaining()` 의 await 뒤 not-monitoring 가드는 **줄로는 이미 커버돼 있었다** — 그 줄은 실행됐지만 `Duration.zero` 를 돌려주는 분기는 한 번도 타지 않았다. 라인 커버리지가 분기 갭을 가린 것이다. 읽기를 park 시킨 뒤 stop 을 끼워 넣는 테스트를 넣어서야 그 분기가 실행됐다.
  - 실증(#16 기준선): `lib/` 미커버 3 줄은 전부 *테스트가 주입으로 대체해 버린 기본값의 본문*이다 — `FlutterInactiveTimer.init()` 의 빈 콜백 두 개와 기본 `Stopwatch` 클럭의 람다. 미커버 목록은 버그가 아니라 **주입 seam 이 어디까지 뚫려 있는지의 지도**로 읽는다.
- **네이티브 코드는 Dart 커버리지 분모에 없다.** `flutter test --coverage` 는 `lib/` 만 본다. `windows/` 의 C++ 와 macOS 의 Swift 는 각자의 네이티브 테스트(Step 8)로만 지켜진다 — Dart 커버리지가 100% 여도 네이티브는 0 줄 검증일 수 있다.

### 6. `/code-review`

구현·테스트가 끝나고 릴리스 전에 돌린다. 지적은 고치거나, 안 고치면 *왜 안 고치는지*를 남긴다.

### 7. 정합성 스윕 — 동작을 기술하는 모든 표면

코드만 고치고 끝나는 변경은 없다. 아무도 안 보므로 **명시적으로 훑는다**.

- **`CHANGELOG.md`** — pub.dev 는 *발행 시점의* CHANGELOG 를 스냅샷으로 박는다. 이미 발행된 버전(1.1.2 ~ 3.0.0)의 항목을 고치지 말고 새 버전을 연다. breaking 변경엔 **복붙 가능한 마이그레이션 줄**을 넣는다(3.0.0 의 `notificationPer: 50` → `notification: NotifyAtPercent(50)` 처럼).
- **`README.md`** — 공개 API 표면이 바뀌면 예제도 바뀐다.
- **`example/`** — 새 API 는 example 에서 실제로 쓰이는지 본다. 실증(#10): `NotifyBefore` 는 구현·테스트가 끝난 뒤에도 example 에 없었고, 별도 이슈로 채웠다.
- **`docs/adr/`** — 결정이 뒤집히면 ADR 도 뒤집는다. ADR 의 Consequences 는 "그때 그렇게 생각했다" 가 아니라 **지금 참인 문장**이어야 한다.
- **`CONTEXT.md` 용어집** — 도메인 용어의 source of truth. 용어집이 개념을 덜 정의하면 코드가 그 빈칸을 임의로 채운다. 새 개념(NotificationTrigger, Idle duration, InactivityDecision …)은 여기부터 정의한다.
- **`.pubignore`** — `.pubignore` 가 존재하면 pub 은 **git 기반 파일 목록을 끈다.** `.gitignore` 는 더 이상 적용되지 않는다. 실증(`db4a8be`): `.pubignore` 가 다른 repo 에서 복붙된 잔해였고(존재하지도 않는 `CODE.md` 를 나열), 그 결과 `.gitignore` 에 있던 `build/` 가 아카이브에 실렸다 — 테스트 하네스가 만든 **42 MB `flutter_windows.dll`** 을 포함해 **64 MB** 짜리 패키지. 고친 뒤 **216 KB**. `docs/` 를 빼면서 README 의 ADR 링크도 GitHub 절대경로로 돌려야 했다. **pub.dev 아카이브는 한 번 올라가면 내릴 수 없다.**
- **낡은 근거 회수** — 연속 PR 에서 앞선 이슈·PR·ADR 에 적은 근거가 뒤 작업에 의해 거짓이 된다(Step 1 의 #5).

### 8. 게이트 & PR & 릴리스

게이트 전부 — CI(`.github/workflows/ci.yml`)가 매 PR 에서 **세 잡**을 돌린다. Flutter 버전은 `FLUTTER_VERSION` 으로 핀돼 있다.

**Dart (ubuntu)**

```
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
awk … coverage/lcov.info   # 라인 커버리지 < 90% 면 실패
```

**Windows** — `flutter precache --windows` → `cmake -S windows/test` → `ctest`. gtest 하네스가 Flutter Windows 엔진과 client wrapper 를 링크한다.
**macOS** — `example` 에서 `flutter build macos --debug` **먼저**(안 그러면 생성되는 `Flutter/ephemeral/*.xcfilelist` 가 없어 Xcode 빌드가 깨진다) → `xcodebuild test`.

- **포맷 검사는 `pub get` 뒤여야 한다.** `dart format` 은 `.dart_tool/package_config.json` 에서 언어 버전을 읽는다. 패키지 설정이 없으면 포매터가 최신 언어 버전을 가정해 레포 전체를 재포맷한다. 로컬엔 `.dart_tool` 이 항상 있어 이 실패는 절대 재현되지 않는다 — 깨끗한 `git worktree` 에서만 보인다.
- **커버리지 게이트는 self-contained 다.** 외부 서비스(Codecov) 없이 `lcov.info` 의 `LF`/`LH` 를 awk 로 합산한다. 계정도 토큰도 필요 없다.
- **커버리지 바닥은 90 이고 현재는 97.7% (126/129) 다.** 이 7.7%p 는 **그만큼의 회귀를 조용히 허용한다** — 게이트를 통과하면서 테스트를 지울 수 있다는 뜻이다. 커버리지를 내리는 변경이면 그 사실을 PR 에 명시한다.
- **덮을 수 없는 줄은 `// coverage:ignore-start` / `ignore-end` 로 감싼다.** 그 줄들은 미커버로 세는 게 아니라 **분모에서 빠진다**. 실증(프로브): 기본 clock 람다 한 줄을 감싸자 `flutter_inactive_timer.dart` 의 `LF` 가 84 → 83 으로 줄고 `LH` 는 126 그대로였다 — 전체는 97.7% (126/129) → 98.4% (126/128). 예외가 조용한 침식이 아니라 diff 에 남는 명시적 편집이 된다.
- **네이티브를 건드렸으면 네이티브 테스트를 건드린다.** Dart 게이트는 `windows/`·`macos/` 를 한 줄도 보지 않는다.
- **릴리스 전 `flutter pub publish --dry-run` 이 경고 0 개**여야 하고, 아카이브에 `build/`·`.dart_tool/`·`coverage/`·`docs/`·`.github/` 가 없어야 한다(Step 7 의 `.pubignore` 항목). 아카이브 크기가 수 MB 를 넘으면 뭔가 새고 있는 것이다.
- **태그는 커밋을 가리키는 불변 포인터다.** 문서까지 다 들어간 뒤에 단다. 발행되지 않은 태그를 옮기는 비용은 0 이다.
- 브랜치 → `fix(<scope>): …` / `feat!: …` → PR(`Closes #issue`) → CI 그린 확인 → 머지.
- **`flutter pub publish` 는 되돌릴 수 없고 pub.dev 는 버전 삭제가 없다(retract 만). 에이전트가 실행하지 않는다 — 사용자가 직접.**
