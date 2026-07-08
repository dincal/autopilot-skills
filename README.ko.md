# Autopilot 사용설명서

목표 주도 자율 개발을 위한 Claude Code 플러그인입니다. 사용자가 목표(goal)를 정하면, 오토파일럿이 프로젝트 문서를 최신으로 유지하면서 **기능 선정 → 병렬 개발 → PR → 리뷰 → 머지** 루프를 사용자가 멈출 때까지(또는 목표를 달성할 때까지) 반복합니다.

- `CLAUDE.md`와 `.autopilot/` 문서 세트(goal, design, todo, 브랜치 문서, changelog)를 프로젝트의 단일 진실 원천으로 유지
- 루프마다 **N개 기능을 병렬 개발** — 각 기능은 독립된 git worktree + 백그라운드 에이전트
- **기능당 PR 1개**, 전담 코드리뷰 에이전트와 앱을 실제 구동하는 E2E 에이전트가 리뷰
- 리뷰는 중립·증거 기반: 입증된 결함만 차단, 거부를 위한 리뷰는 금지
- 승인 게이트(goal prompt / plan / merge)를 `ask` ↔ `auto`로 조절 가능

---

## 1. 요구사항

| 항목 | 설명 |
|---|---|
| Claude Code v2.1+ | 플러그인/스킬/훅 지원 버전 |
| GitHub 원격 + `gh` CLI 인증 | 개발 루프가 실제 PR을 만들고 머지합니다. 없으면 개발 스킬은 안내 후 중단 |
| `python3` | goal.md 보호 훅, 루프 유지 훅이 사용 |
| (권장) Claude Design MCP | `/autopilot-design`과 루프 내 디자인 결정에 사용. 일반 터미널에서 `claude mcp add --scope user --transport http claude-design https://api.anthropic.com/v1/design/mcp` 후 `/design-login` (Pro/Max/Team/Enterprise) |
| (권장) 브라우저 MCP | 웹 프로젝트라면 chrome-devtools 또는 playwright MCP가 있어야 E2E 에이전트가 UI를 직접 조작합니다. 없으면 HTTP 수준 검증으로 강등 |

## 2. 설치

마켓플레이스 설치:

```
/plugin marketplace add dincal/autopilot-skills
/plugin install autopilot@autopilot-marketplace
```

업데이트:

```
/plugin marketplace update autopilot-marketplace
/plugin update autopilot
```

> **주의**: 훅(goal.md 보호, 루프 유지)은 **세션을 재시작해야** 새 버전이 로드됩니다.

로컬 개발용 로드: `claude --plugin-dir /path/to/autopilot-skills`

## 3. 빠른 시작

```
/autopilot-init dincal/my-app 커플 가계부 웹앱, 지출 공유와 정산이 핵심
   → 저장소 연결/생성 → config 설정 → 골 인터뷰 → 문서 스캐폴드 → CLAUDE.md
오토파일럿으로 개발해
   → 루프 시작. 멈추려면 "멈춰", 마무리하고 main에 머지하려면 /autopilot-stop
```

단일 기능만: `이 기능만 오토파일럿으로 개발해줘: 다크모드`
무인으로: `무인모드로 오토파일럿 돌려`

---

## 4. 슬래시 커맨드

### `/autopilot-init [github-repo] [프로젝트 개요]`

`.autopilot/` 전체와 CLAUDE.md 관리 섹션을 초기화합니다. 재실행해도 사용자 콘텐츠를 파괴하지 않습니다(멱등).

- **저장소 인자**(`owner/repo` 또는 URL): GitHub에 이미 있으면 origin으로 연결(빈 디렉토리면 clone), 없으면 공개/비공개를 물은 뒤 `gh`로 생성
- **개요 인자**: 저장소 인자 뒤의 나머지 텍스트. 없으면 README/코드에서 도출하고, 그것도 안 되면 직접 물어봅니다(지어내지 않음)
- goal.md가 없으면 골 인터뷰를 인라인으로 진행 (동의 게이트 포함)
- `.gitignore`에 런타임 파일(state.json, logs/, .goal-consent, .stop-guard) 등록
- GitHub 저장소의 **"머지된 PR 브랜치 자동 삭제"** 설정을 켬 (`delete_branch_on_merge`) — 리모트에 피처/런 브랜치가 쌓이지 않도록. 권한이 없으면 경고 후 루프의 `--delete-branch` 플래그에 의존

### `/autopilot-goal [대략적인 지침]`

goal.md 작성/수정을 위한 사용자 인터뷰. **goal.md를 바꿀 수 있는 유일한 경로**입니다.

1. 2~3라운드 인터뷰: 궁극 목표·타깃·성공 기준 → 단기 목표(각각 "done when" 조건) → 비목표·제약
2. 초안 전문을 보여주고 **Approve / Edit first / Cancel** 동의 게이트
3. Approve 시에만 일회성 동의 토큰을 만들고 파일 작성

### `/autopilot-todo [기능 아이디어]`

인터뷰로 todo 항목을 추가합니다. 여기서 추가된 항목은 `source: user`로 기록되어 **기능 선정에서 에이전트 생성 항목보다 항상 우선**합니다. 유저스토리·인수 기준은 에이전트가 초안을 제안하고 사용자가 확인하며, 이미 구현됐거나 중복인 아이디어는 알려주고 스킵/병합/추가를 선택받습니다.

### `/autopilot-config [변경 요청]`

현재 설정을 그룹별로 요약해 보여주고 인터뷰로 config.json을 갱신합니다. `merge auto`, `parallel 3`처럼 구체 요청을 주면 바로 해당 키로 매핑합니다. 스키마 검증(타입·enum·범위)을 통과한 변경만, before→after diff 확인 후 적용됩니다.

### `/autopilot-project-review`

**냉정한 시장 반응 평가**. 베이스레이트 회의주의(대부분의 제품은 출시해도 주목받지 못한다는 전제, "아무것도 안 하기"를 포함한 경쟁 구도, 근거 없는 칭찬 금지)로 지금 출시하면 어떤 반응일지 평가합니다. 리포트 전문은 `.autopilot/reviews/`에 저장되고, 권고안을 인터뷰로 하나씩 수락/거부받아 goal.md(동의 게이트 경유)와 todo.md에 반영합니다.

### `/autopilot-dev-run [stop | restart | status]`

현재 프로젝트를 **dev 모드로 실행**하는 관리형 백그라운드 프로세스를 띄웁니다 (커맨드는 `testing.e2e.runCommand` 또는 자동 감지, 로그는 `.autopilot/logs/dev-run.log`).

핵심은 **자동 재실행 보장**: 플러그인의 PostToolUse 훅이 세션에서 `gh pr merge` 또는 `git pull`이 성공할 때마다 dev 프로세스를 자동 재시작합니다(10초 디바운스). 오토파일럿 런 중 메인 체크아웃은 런 브랜치에 있으므로, **기능이 머지될 때마다 dev 서버가 새 코드로 다시 뜹니다** — 프롬프트가 아니라 훅이 보장하므로 잊어버릴 수 없습니다.

한계: Claude Code 세션 밖에서 한 머지(GitHub 웹 UI 등)는 이 세션에서 pull이 일어나기 전까지 트리거되지 않습니다. 핫리로드 dev 서버는 로컬 파일 수정을 자체적으로 반영합니다.

참고: 오토파일럿 런이 시작되면 이 커맨드를 직접 치지 않아도 **자동으로 기동**됩니다 (`devRun.autoStart`, 기본 true) — 단, 이미 dev-run이 살아 있으면 건드리지 않습니다. 런이 끝나도 서버는 계속 떠 있으며, 종료는 `/autopilot-dev-run stop`.

### `/autopilot-design [디자인 방향 힌트]`

프로젝트의 **전체적인 룩앤필**을 다듬습니다. 디자인 도구는 **Claude Design 전용**입니다(Figma 등 다른 툴은 사용하지 않음).

1. **감사**: 앱을 직접 구동해(가능하면 스크린샷 포함) 현재 구현된 디자인 상태와 비일관성, 디자인 결정이 필요한 예정 기능들을 파악
2. **방향 인터뷰** (최대 2라운드): 방향·톤 → 비주얼 기초(팔레트 hex, 타이포, 밀도). 세부는 목업에서 시각적으로 결정
3. **Claude Design 목업 핑퐁 (핵심)**: 저장소 이름의 Claude Design 프로젝트를 재사용하거나 생성 → 핵심 화면들의 목업 제작 → 사용자가 Claude Design에서 직접 확인 → 피드백 반영 → **사용자가 명시적으로 승인할 때까지 무제한 반복**. 승인 전에는 Style Guide에 아무것도 쓰지 않습니다
4. **기록** (승인 후에만): 승인된 목업에서 추출한 구체 규칙을 `design.md`의 **Style Guide 섹션**(살아있는 계약, 제자리 갱신)으로 작성 + Decisions 로그에 프로젝트 링크와 함께 날짜 엔트리 추가. 기존 UI가 새 가이드를 위반하는 부분은 리스타일 todo로 제안(수락한 것만 추가)

이후 개발 루프는 모든 UI 기능의 Goal Prompt에 Style Guide 규칙을 제약으로 복사하므로 **기능이 쌓여도 디자인 일관성이 유지됩니다**. 루프 중 가이드가 답하지 못하는 새 디자인 질문이 나오면: **일반 모드에서는 Claude Design 목업 후보를 만들어 사용자가 결정**하고, **무인모드에서는 에이전트가 추천안으로 결정한 뒤 Claude Design 프로젝트를 직접 갱신**해 두므로 나중에 무엇이 디자인됐는지 눈으로 검토할 수 있습니다(PR의 임의 결정 섹션에도 표기).

### `/autopilot-stop`

지금 돌고 있는(또는 중단·무인 종료된) 오토파일럿 런을 **명시적으로 마무리하고 main에 머지**하는 커맨드입니다.

1. **미완료 피처 정리**: 실행 중인 백그라운드 에이전트를 멈추고, 피처별로 사용자에게 한 번에 물어 처리합니다 — 리뷰 승인됨 → 런 브랜치에 지금 머지(권장) / 리뷰 중 → 파킹(PR 열어둠, todo `blocked`) 또는 폐기(PR 닫고 todo `pending` 복귀) / 개발 중 → 폐기 또는 브랜치 보존. worktree는 정리
2. **런 문서 마무리**: todo/CHANGELOG/브랜치 문서를 런 브랜치에 커밋·푸시
3. **런 PR 확정**: 런 PR(런 브랜치 → base)을 생성/최종화 — 상단 ⚠️ 임의 결정 집계 포함. 머지된 피처가 0개면 PR 없이 런 브랜치 삭제 제안
4. **사용자 승인 게이트**: PR 링크와 요약을 보여주고 **Merge now / 열어두기 / 취소** — 명시적 승인 없이는 절대 머지하지 않습니다
5. **정리**: 원래 브랜치로 복원, state를 `idle`로, 종료 보고 (머지/파킹/폐기 목록과 재개 방법)

무인모드 런이 파킹해 둔 런 PR을 배송하는 표준 경로이자, 세션이 끊긴 런을 새 세션에서 마무리하는 방법입니다.

### `/autopilot-sync`

모든 autopilot 문서를 저장소의 실제 상태(코드, git 히스토리, 머지된 PR)와 동기화합니다. 구현 완료된 todo 제거, design/tech-design에 관찰된 결정 추가(잘못 들어간 항목 1회 이동 포함), CHANGELOG에 머지분 반영, 브랜치 문서 갱신·아카이브, CLAUDE.md 마커 섹션 재생성. **goal.md는 읽기 전용** — 낡았으면 `/autopilot-goal`을 권할 뿐입니다.

---

## 5. 개발 스킬 (오토파일럿 모드)

슬래시 커맨드가 아니라 **명시적 발화로만** 발동하는 스킬입니다. "오토파일럿으로 개발해", "run autopilot" 등 오토파일럿을 지명해야 하며, 일반 기능 요청("로그인 버그 고쳐줘")에는 절대 발동하지 않습니다.

발화 수식어가 그 런의 모드를 결정합니다:

| 발화 | 효과 |
|---|---|
| "오토파일럿으로 개발해" | config의 `mode` (기본 loop) |
| "이 기능만 오토파일럿으로" | single-feature 모드 |
| "빠르게" / "fast" | `fastMode: true` |
| "무인모드로" / "묻지 말고 알아서" | `unattended: true` |
| "울트라코드로" / "ultracode" | `ultracode: true` |

### 브랜치 구조

```
main (base)
 └─ autopilot/run-20260708-0930      ← 런 브랜치: 실행마다 1개 생성
     ├─ autopilot/ap-012-...         ← 기능 브랜치 → PR은 런 브랜치 대상
     └─ autopilot/ap-013-...
```

- 기능 PR은 **런 브랜치로** 머지되고, base 브랜치는 오직 **런 PR 1개**(런 브랜치 → base)로만 닿습니다
- 런 PR은 첫 기능 머지 직후 열려서 이터레이션마다 본문이 갱신되며, 런 종료 시 `approvals.runMerge` 게이트를 거칩니다
- 머지된 기능이 0개인 런은 런 PR 없이 런 브랜치가 삭제됩니다
- single-feature 모드는 런 브랜치 없이 기능 브랜치 → base PR (worktree 없이 현재 세션에서 직접 개발)
- 런 중에는 메인 체크아웃이 런 브랜치로 전환되며, 런이 끝나면 원래 브랜치로 복원됩니다

### 한 이터레이션의 흐름

1. **Select** — goal.md와 todo.md를 대조하고 **앱을 실제 구동**해서 성공 기준과의 갭을 찾아 todo를 갱신한 뒤, 다음 기능 N개 선정 (`parallelFeatures`, user 항목 우선, 작은 todo는 유저스토리 단위로 병합)
2. **Plan** — 필요하면 디자인 방향(옵션+추천)을 잡아 사용자에게 결정 요청, 기능별 Goal Prompt와 구현 Plan 작성 (`approvals.goalPrompt`/`plan` 게이트)
3. **Develop** — 기능별 worktree + 백그라운드 개발 에이전트. **테스트 필수**: 인수 기준 + 엣지 케이스 + 에러 경로, 변경 코드 커버리지 `testing.coverage.target`(기본 80%) 지향
4. **Ship & Review** — push, PR 생성. 코드리뷰 + E2E 에이전트가 병렬 리뷰(결과는 PR 코멘트로 게시). REQUEST_CHANGES면 차단 항목만 고치는 수정 사이클, `maxReviewIterations` 초과 시 사용자 에스컬레이션
5. **Merge & Close** — 승인된 기능 PR을 런 브랜치로 순차 머지(+잔여 브랜치 rebase), todo/CHANGELOG/브랜치 문서/CLAUDE.md 갱신, worktree 정리
6. **반복** — 루프가 기본값. 종료 조건은 사용자 중지 / `loop.maxIterations` 도달 / `stopOnFailure` 발동 / 목표 달성(모든 성공 기준을 실행 중인 앱에 대해 증거와 함께 검증)뿐

### PR 본문 규칙

모든 PR은 반드시 이 순서로 시작합니다:

```markdown
## ⚠️ 사용자 동의 없이 임의로 결정한 사항
- <결정> — <이유, 사용자가 개입했다면 달라졌을 지점>

## 작업 요약
- ...
```

auto로 통과한 게이트, 에이전트가 정한 디자인, 플랜 이탈, 리뷰 중재 강등이 모두 이 섹션에 수집됩니다. 머지 전에 "나 대신 뭐가 결정됐는지" 감사할 수 있습니다.

### 무인모드 (`unattended: true`)

루프 중 사용자에게 **아무것도 묻지 않습니다**. 모든 게이트가 auto로 동작하고, 질문이 필요했던 지점은 문서화된 안전 기본값으로 해소됩니다(dirty tree 자동 stash 후 복원, 디자인은 에이전트 추천안, 고아 worktree 자동 정리 등). 단 두 가지는 예외입니다:

- **goal.md는 절대 쓰지 않음** (훅으로도 차단)
- **base 브랜치로 절대 머지하지 않음** — 런 PR은 요약 코멘트와 함께 열어두고 사용자가 머지. 리뷰 상한을 초과한 기능은 강제 머지 대신 **파킹**(PR 열어둠 + 사유 코멘트 + todo `blocked` 처리)

모든 자율 결정은 런 로그에 기록되고 종료 보고서에 목록으로 나옵니다.

### 울트라코드 (`ultracode: true`)

멀티에이전트 Workflow 오케스트레이션으로 단계를 업그레이드합니다 (토큰 비용 大):

- 갭 분석: 성공 기준별 병렬 파인더 → 중복 병합
- 플래닝: 관점이 다른 독립 플랜 2~3개 → 저지 채점 → 승자 합성
- 코드리뷰: 차원별 파인더 팬아웃 → **모든 차단 후보를 회의적 에이전트 2~3개가 반박 시도, 과반 검증 통과만 BLOCKING**

Workflow 도구가 없는 세션이면 표준 프로토콜로 폴백합니다. `fastMode`가 켜져 있으면 리뷰 단계에서는 fast가 우선합니다.

---

## 6. 설정 레퍼런스 (`.autopilot/config.json`)

`/autopilot-init`이 생성하고 `/autopilot-config`로 수정합니다. JSON 스키마: `templates/config.schema.json`.

| 키 | 기본값 | 의미 |
|---|---|---|
| `language` | `ko` | 생성 문서·PR 본문 언어 (코드·커밋·PR 제목은 항상 영어) |
| `mode` | `loop` | `loop`(중지까지 반복) / `single-feature`(기능 1개, 루프·worktree 없음) |
| `fastMode` | `false` | 리뷰 최소화: E2E 생략, 리뷰 1라운드, 치명 결함만 검사 |
| `unattended` | `false` | 무인모드 (위 참조) |
| `ultracode` | `false` | Workflow 오케스트레이션 (위 참조) |
| `parallelFeatures` | `2` | 이터레이션당 병렬 개발 기능 수 (1–4) |
| `approvals.goalPrompt` | `ask` | 기능별 Goal Prompt 승인 |
| `approvals.plan` | `ask` | 기능별 구현 Plan 승인 |
| `approvals.newTodos` | `auto` | 에이전트 생성 todo 승인 |
| `approvals.merge` | `ask` | 기능 PR → 런 브랜치 머지 승인 |
| `approvals.runMerge` | `ask` | 런 PR → base 머지 승인 (무인모드는 설정 무관 절대 자동 머지 안 함) |
| `review.codeReview` | `true` | 코드리뷰 에이전트 실행 |
| `review.e2eTest` | `true` | E2E 에이전트 실행 |
| `review.reviewerModel` | `null` | 리뷰 에이전트 모델 오버라이드 — 개발과 다른 모델로 맹점 상관 완화 (예: `"opus"`) |
| `review.maxReviewIterations` | `3` | 수정-재리뷰 사이클 상한, 초과 시 사용자 에스컬레이션 |
| `testing.requireTests` | `true` | 모든 기능은 테스트 동반 필수 |
| `testing.testCommand` | `null` | 테스트 커맨드 (null = 자동 감지) |
| `testing.coverage.target` | `80` | 변경 코드 최소 커버리지 % (null = 수치 게이트 없음) |
| `testing.coverage.command` | `null` | 커버리지 측정 커맨드 (init이 자동 감지 시도) |
| `testing.e2e.runCommand/readyCheck/url` | `null` | 앱 기동 커맨드 / 준비 확인 / 기본 URL |
| `devRun.autoStart` | `true` | 오토파일럿 런 시작 시 dev 서버 자동 기동 (실행 가능한 프로젝트 + 이미 떠 있지 않을 때만) |
| `git.baseBranch` | `main` | 런 브랜치의 fork 원점이자 런 PR의 대상 |
| `git.branchPrefix` | `autopilot/` | 생성 브랜치 접두어 |
| `git.mergeMethod` | `rebase` | rebase / squash / merge |
| `git.deleteBranchAfterMerge` | `true` | 머지 후 브랜치 삭제 |
| `git.worktreeRoot` | `null` | worktree 위치 (null = `../<repo>__autopilot/`) |
| `loop.maxIterations` | `0` | 이터레이션 상한 (0 = 무한) |
| `loop.stopOnFailure` | `true` | 기능 실패 시 해당 이터레이션 후 루프 중단 |

## 7. `.autopilot/` 파일 구조

| 파일 | 커밋 | 설명 |
|---|---|---|
| `config.json` | O | 실행 설정 |
| `goal.md` | O | 궁극 목표 + 단기 목표. **에이전트가 동의 없이 절대 수정 불가** |
| `design.md` | O | **Style Guide**(살아있는 룩앤필 계약, `/autopilot-design`이 관리) + UI/UX 결정 로그(append-only) |
| `tech-design.md` | O | 개발/기술 디자인 결정 (아키텍처, 데이터 모델, 스택) |
| `todo.md` | O | **미구현** 기능만. user 항목이 agent 항목보다 항상 우선. 완료 항목은 삭제됨 |
| `CHANGELOG.md` | O | Keep-a-Changelog 관례, git 태그 기준 버전 |
| `branch/<이름>.md` | O | 브랜치별 Goal Prompt·Plan·임의 결정·작업 요약·리뷰 로그. 머지 후 `archive/`로 |
| `reviews/` | O | `/autopilot-project-review` 리포트 보관 |
| `state.json` | X | 런타임 상태 (phase, 기능 상태, 재개 정보) |
| `logs/` | X | 런별 오케스트레이션 로그 |
| `.goal-consent`, `.stop-guard` | X | 훅용 일회성 토큰 / 루프 유지 카운터 |
| `dev-run.json` | X | `/autopilot-dev-run` 프로세스 상태 (커맨드, pid, 자동 재시작) |

todo 항목 형식:

```markdown
- [ ] AP-012 | P1 | user | pending
  - story: As a shopper, I want ... so that ...
  - acceptance:
    - 관찰 가능한 행위 (E2E 에이전트가 이걸 검증)
  - depends-on: AP-009
```

## 8. 안전장치 (Guarantees)

1. **goal.md는 사용자의 것** — 모든 스킬·에이전트에 금지 명문화 + PreToolUse 훅이 이중 차단. `/autopilot-goal`의 동의 직후 발급되는 일회성 토큰(15분 유효)이 있어야만 쓸 수 있고, Bash 리다이렉트 우회도 감지합니다. 무인모드에도 예외 없음.
2. **base 브랜치 절연** — 기능은 런 브랜치에 쌓이고, base는 런 PR 하나로만 닿습니다. 무인모드는 그 런 PR조차 머지하지 않고 열어둡니다.
3. **PR은 먼저 자백** — 모든 PR 상단에 "사용자 동의 없이 임의로 결정한 사항" 섹션이 강제됩니다.
4. **루프는 조용히 죽지 않음** — Stop 훅이 런 활성 중 턴 종료를 차단하고 루프로 되돌립니다. 단, **백그라운드 에이전트 대기는 예외**: 진행 중인 태스크 id가 state.json(`features[].agentTask`)에 기록되어 있으면 턴 종료를 허용하고, 태스크가 끝나면 하네스가 자동 재호출합니다. 그 외 정당한 종료는 Run end 완료(`idle`) 또는 명시적 일시정지(`paused`)뿐이며, 같은 지점에서 3회 진전이 없으면 안전밸브가 정지를 허용합니다.
5. **CLAUDE.md의 사용자 텍스트 불가침** — `<!-- AUTOPILOT:BEGIN/END -->` 마커 사이만 재생성합니다.
6. **테스트 실패 상태로는 아무것도 머지되지 않음** — 커버리지 목표(기본 80%)까지 포함.
7. **리뷰는 중립·증거 기반** — 입증된 결함은 작업량과 무관하게 차단하고, 입증 못 한 우려는 절대 차단하지 못합니다(입증 책임은 차단하는 쪽에). 거부를 위한 리뷰는 금지. 차단은 화이트리스트 5종(버그/보안·데이터손실/핵심 경로 테스트 부재/인수 기준 미충족/기존 기능 파괴)만 가능하고, 스타일 트집으로는 머지를 막을 수 없습니다.

## 9. 트러블슈팅 / FAQ

**Q. 루프가 말없이 멈췄어요.**
0.14.0의 keep-alive 훅이 이 문제를 막습니다 — 업데이트 후 **세션을 재시작**했는지 확인하세요. 그래도 멈췄다면 안전밸브(같은 지점 3회 무진전)가 발동한 경우입니다: "오토파일럿으로 개발해"를 다시 입력하면 preflight가 상태를 감지하고 **Resume / Clean up / Fresh start**를 제안합니다.

**Q. 설치 시 "Duplicate hooks file detected" 에러가 나요.**
0.3.0 이하의 버그입니다. 마켓플레이스와 플러그인을 업데이트하세요.

**Q. goal.md를 고치려는데 거부돼요.**
의도된 동작입니다. `/autopilot-goal`로 인터뷰를 거쳐 수정하세요. (사용자가 에디터로 직접 고치는 것은 훅과 무관하게 언제나 가능합니다 — 훅은 Claude의 쓰기만 차단합니다.)

**Q. 무인모드로 돌렸더니 PR이 머지 안 되고 쌓여 있어요.**
의도된 동작입니다. 무인모드는 base로 머지하지 않습니다. 런 PR을 열어 상단의 임의 결정 섹션을 확인하고 직접 머지하세요. 파킹된 기능 PR은 코멘트에 막힌 사유가 있습니다. 해당 todo는 `blocked` 상태이므로, 처리 후 상태를 `pending`으로 되돌리거나 `/autopilot-sync`로 정리하세요.

**Q. 런이 끝났는데 체크아웃이 런 브랜치에 있어요.**
정상적으로 끝나면 원래 브랜치로 복원됩니다. 중간에 끊긴 경우 `git switch <원래 브랜치>`로 돌아가면 되고, 다음 실행의 preflight가 나머지를 정리합니다.

**Q. worktree가 남아 있어요.**
`git worktree list`로 확인하세요. 다음 오토파일럿 실행의 preflight가 state.json과 대조해 고아 worktree 제거를 제안합니다.

**Q. E2E 리뷰가 부실해요.**
웹 프로젝트라면 브라우저 MCP(chrome-devtools/playwright)를 세션에 연결하세요. 없으면 curl 수준 검증으로 강등됩니다. `testing.e2e.runCommand/readyCheck/url`을 채워두면 정확도가 올라갑니다.

**Q. 리뷰 품질을 더 올리고 싶어요.**
`review.reviewerModel`로 리뷰어를 개발과 다른 모델로 돌리거나(맹점 상관 완화), `ultracode: true`로 반박 검증 기반 리뷰 워크플로우를 쓰세요. 둘 다 토큰 비용이 올라갑니다.

**Q. 토큰이 너무 많이 나가요.**
`fastMode: true`(E2E 생략, 리뷰 1라운드), `parallelFeatures: 1`, `loop.maxIterations`로 상한 설정을 조합하세요.

## 10. 저장소 구조 (플러그인 개발자용)

```
.claude-plugin/     plugin.json, marketplace.json
skills/             autopilot-goal / init / todo / config / project-review / sync (슬래시 커맨드)
                    autopilot-dev (모델 인보크 루프) + references/ (loop·worktree·review 프로토콜, 스키마)
agents/             feature-dev, code-reviewer, e2e-tester
hooks/              guard-goal-md.sh (goal.md 보호), keep-loop-alive.sh (루프 유지)
templates/          config 스키마/기본값, 문서 템플릿, CLAUDE.md 관리 섹션
```
