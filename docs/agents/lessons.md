# Lessons — flutter_inactive_timer 실증

이 repo 가 `theflow` 의 각 단계에서 실제로 **무엇을 놓쳤나** 의 기록 — 규칙에 무게를 주는
근거. 전부 이 repo 에서 실제로 일어났다. 단계 번호는 `theflow` SKILL.md 와 일치. 바인딩
(`theflow.md`)이 추상으로 읽히면 여기 사건과 대조하라.

---

## 반복 실패: `await` 뒤에는 세상이 이미 바뀌어 있다

이 패키지는 **비동기 네이티브 읽기 위의 타이머**다. `getIdleDuration()` 을 `await` 하는
사이 사용자가 `stopMonitoring()`·`continueSession()`·`dispose()` 를 부를 수 있다. **같은
모양의 버그가 네 번** 났다:

- **`07ac425`** — `_checkInactivity` 가 await 뒤 `isMonitoring` 을 다시 안 봐서 stop 이후에
  콜백이 발화했다.
- **`9759514`** — example 앱이 await 뒤 `BuildContext` 를 그대로 썼다.
- **`8c03f6f` (#5)** — await 뒤 타이머를 arm 해서 선점된 스케줄이 유령 타이머를 남길 수
  있었다. **generation 카운터**로 봉했다.
- **`a6abd0f`** — `remaining()` 이 idle 읽기에 park 된 사이 `stopMonitoring()` 이 끼어들었다.

→ **await 를 새로 넣거나 옮겼으면 재개 지점에서 읽는 모든 상태**(`isMonitoring`,
generation, `mounted`)를 다시 확인하고, 그 경쟁을 재현하는 테스트를 붙인다.

## Step 1 — 이슈 먼저 (본문 근거도 실증 대상)

- **#5 (근거가 이미 거짓)**: 본문은 `_scheduleNextCheck()` 가 두 `Timer` 를 만들어 유령
  타이머가 샌다고 단언했다. 착수해 보니 그 누수는 **이미 #3 의 `InactivityPolicy` 추출로
  사라져 있었다** — `_arm` 이 재할당 전에 cancel 하고 `_pump` 가 await 뒤 상태를 다시 읽는다.
  실제 변경은 "누수 수정" 이 아니라 generation 카운터를 통한 **불변식의 명시화**가 됐고,
  커밋 메시지에 정정을 남겼다.

## Step 2 — 추측 금지 (네이티브·하네스도 실측)

- **ADR-0001 (네이티브 소스를 직접 읽는다)**: Windows 의 `getSystemTickCount` 는 64비트
  `GetTickCount64` 에서, `getLastInputTime` 은 **32비트** `GetLastInputInfo.dwTime` 에서
  왔다. 후자는 약 **49.7일**마다 wrap 하고, 그 뒤 Dart 뺄셈은 쓰레기값을 낸다. macOS 는
  마침 둘 다 `systemUptime` 기준이라 계약이 암묵적·비강제로 굴러가고 있었다. **"두 클럭을
  Dart 에서 뺀다" 는 계약 자체를 없애고** 네이티브가 idle duration 하나를 반환하게 했다.
- **#17 (테스트 하네스도 검증 대상)**: 새 테스트가 계속 실패해 대상 코드를 의심했는데 범인은
  fake 였다 — `GatedIdlePlatform.releaseHeldRead` 가 읽기가 park 되는 순간 `_hold` 를 null
  로 만들어 park 된 read 를 **release 할 방법이 없었다.** `_held` 로 따로 추적해 고쳤다.
  기존 유령 타이머 테스트는 generation 가드가 재개된 읽기를 버려 이 버그를 못 드러냈다.

## Step 3 — 설계 판단 코드 전에 (ADR 세 개가 코드보다 먼저)

- **ADR-0002 (표현 가능한 불법 상태를 없앤다)**: "`notificationPer` 를 deprecated 로 한
  릴리스 병존" 을 기각한 건 코드 전이었다 — 두 방식이 공존하면 생성자에서 "둘 다 세팅됨"
  이라는 불법 상태가 되살아나, sealed `NotificationTrigger` 를 도입한 이유를 무너뜨린다.
- **ADR-0003 (시그니처는 red 전에)**: `remaining()` 이 pull/push·sync/async 인지는 red
  전에 정해야 했다. 동기 getter 는 fresh idle 을 못 읽어 Notification 이전 구간의 사용자
  활동을 반영 못 한다 — 그 사실이 시그니처를 `Future<Duration>` 으로 확정했다.

## Step 5 — 테스트 신뢰 (커버리지가 두 번 거짓말한다)

- **#17 (라인 커버리지가 분기 갭을 가린다)**: `remaining()` 의 await 뒤 not-monitoring
  가드는 **줄로는 이미 커버돼** 있었다 — 그 줄은 실행됐지만 `Duration.zero` 를 돌려주는
  분기는 한 번도 안 탔다. 읽기를 park 시킨 뒤 stop 을 끼운 테스트를 넣어서야 그 분기가 탔다.
- **#16 (미커버 = 주입 seam 의 지도)**: `lib/` 미커버 3 줄은 전부 *테스트가 주입으로 대체한
  기본값의 본문* — `init()` 의 빈 콜백 둘과 기본 `Stopwatch` 클럭 람다. 미커버 목록은 버그가
  아니라 주입 seam 이 어디까지 뚫렸는지의 지도로 읽는다.
- **네이티브는 Dart 커버리지 분모에 없다.** `flutter test --coverage` 는 `lib/` 만 본다 —
  Dart 100% 여도 `windows/` C++·`macos/` Swift 는 0 줄 검증일 수 있다.

## Step 6/7 — 정합성 & 게이트

- **#10 (새 API 는 example 에서 쓰이는지 본다)**: `NotifyBefore` 는 구현·테스트가 끝난 뒤에도
  example 에 없었고, 별도 이슈로 채웠다.
- **`db4a8be` (`.pubignore` 가 `.gitignore` 를 무력화)**: 다른 repo 에서 복붙된
  `.pubignore` 가 존재하지도 않는 `CODE.md` 를 나열해, `.gitignore` 의 `build/` 가 아카이브에
  실렸다 — 테스트 하네스가 만든 **42 MB `flutter_windows.dll`** 포함 **64 MB** 패키지. 고친
  뒤 **216 KB**. `docs/` 를 빼면서 README 의 ADR 링크도 GitHub 절대경로로 돌려야 했다.
  **아카이브가 수 MB 를 넘으면 뭔가 새고 있는 것.**
