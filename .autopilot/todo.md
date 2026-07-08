# Autopilot Todo

<!-- autopilot:todo schema v1

Each item is one top-level checklist entry:

- [ ] <ID> | P<0-3> | <user|agent> | <status>
  - story: As a <role>, I want <capability> so that <benefit>.
  - acceptance:
    - <observable behavior>
  - depends-on: <ID> (optional)
  - notes: <free text> (optional)

Rules:
- ID: AP-### — monotonically increasing, never reused (check the whole file AND
  .autopilot/branch/ + CHANGELOG for the highest ID before allocating).
- source: "user" items ALWAYS rank above "agent" items, regardless of priority.
- Ordering within the file: source (user first) → priority (P0 highest) → ID (lowest first).
- status: pending | selected | in-progress | in-review | blocked
- The story line is mandatory: every item must be at least user-story sized.
  Anything smaller gets batched with related items into one feature.
- acceptance bullets must be observable behaviors — the E2E review agent
  verifies exactly these.
- Completed items are REMOVED from this file. This file lists only what is
  NOT yet built; finished work lives in .autopilot/branch/ docs and CHANGELOG.md.
-->

## Items

- [ ] AP-003 | P0 | user | pending
  - story: 플러그인 사용자로서, dev-run이 켜진 프로젝트에서 gh pr merge/git pull 후 세션이 행에 걸리지 않기를 원한다. PostToolUse 훅은 dev 서버 수명과 무관하게 즉시 반환되어야 한다.
  - acceptance:
    - dev-run.sh restart가 서버를 완전 분리로 기동: 래퍼 서브셸 없이 nohup + stdin </dev/null + 로그 리다이렉트, pid는 실제 서버 프로세스 (파이프 fd를 물고 살아있는 부모 금지)
    - hook 경로는 재시작을 백그라운드로 완전 분리 실행하고 즉시 exit 0
    - 실프로세스 테스트: 장수 서버가 살아있는 동안 hook 호출이 3초 내 반환, 기존 8종 테스트 회귀 없음
  - notes: pacer_game 실사용 발생 (2026-07-08), 머지마다 행

- [ ] AP-002 | P0 | user | pending
  - story: 오토파일럿 사용자로서, 승인 게이트에서 승인 대상을 확실히 보고 결정하길 원한다: Goal Prompt·Plan 초안은 승인을 묻기 전에 branch 문서에 먼저 기록되고, 동의는 그 문서를 근거로 이뤄져야 하며, 게이트 질문 UI에도 전문이 보여야 한다 (채팅 중간 텍스트는 렌더되지 않을 수 있음).
  - acceptance:
    - loop-protocol Phase B: Goal Prompt·Plan 초안을 승인 질문 전에 branch/<브랜치>.md에 작성하고, 게이트 질문은 그 파일 경로를 명시 + Approve 옵션 preview에 전문 포함을 의무화
    - Edit 시 branch 문서를 제자리 갱신 후 재질문, Drop 시 문서를 abandoned 처리(또는 미개발이면 삭제)하는 규칙 명시
    - autopilot-goal 동의 게이트, autopilot-config diff, autopilot-stop 런 PR 요약 등 모든 ask 게이트에 preview 규칙 적용
    - dev SKILL.md 하드 룰: 승인 대상은 파일로 먼저 기록 + 질문에 전문 포함, 채팅 텍스트 의존 금지
  - notes: 실런 발생 (2026-07-08, PR #1 플랜 게이트). 수정 2026-07-08: 승인 전 branch 문서 선작성 방식으로 보강 (파일 = 진실 원천, preview = 즉시 확인)

- [ ] AP-004 | P1 | user | pending
  - story: 오토파일럿 사용자로서, 머지 후 branch 문서가 실제 상태와 일치하길 원한다. 승인하면 머지되는 플로우이므로 PR 생성 시점에 status를 merged로 선기록한다.
  - acceptance:
    - loop-protocol Phase D: PR 생성 시 branch 문서 status를 merged로 기록 + "PR이 머지 없이 닫히면 abandoned로 정정" 규칙 명시
    - 리뷰 중 실시간 상태는 state.json이 추적함을 명시 (문서는 최종 상태 기록용)
    - abandon/파킹 경로(review-protocol, autopilot-stop)의 문서 정정 규칙 갱신
  - notes: 사용자 결정 2026-07-08 — 머지 후 in-review로 남는 문제의 해법으로 선기록 방식 채택
