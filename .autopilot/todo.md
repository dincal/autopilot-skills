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

- [ ] AP-002 | P0 | user | pending
  - story: 오토파일럿 사용자로서, 승인 게이트에서 승인 대상을 확실히 보고 결정하길 원한다: Goal Prompt·Plan 초안은 승인을 묻기 전에 branch 문서에 먼저 기록되고, 동의는 그 문서를 근거로 이뤄져야 하며, 게이트 질문 UI에도 전문이 보여야 한다 (채팅 중간 텍스트는 렌더되지 않을 수 있음).
  - acceptance:
    - loop-protocol Phase B: Goal Prompt·Plan 초안을 승인 질문 전에 branch/<브랜치>.md에 작성하고, 게이트 질문은 그 파일 경로를 명시 + Approve 옵션 preview에 전문 포함을 의무화
    - Edit 시 branch 문서를 제자리 갱신 후 재질문, Drop 시 문서를 abandoned 처리(또는 미개발이면 삭제)하는 규칙 명시
    - autopilot-goal 동의 게이트, autopilot-config diff, autopilot-stop 런 PR 요약 등 모든 ask 게이트에 preview 규칙 적용
    - dev SKILL.md 하드 룰: 승인 대상은 파일로 먼저 기록 + 질문에 전문 포함, 채팅 텍스트 의존 금지
  - notes: 실런 발생 (2026-07-08, PR #1 플랜 게이트). 수정 2026-07-08: 승인 전 branch 문서 선작성 방식으로 보강 (파일 = 진실 원천, preview = 즉시 확인)
