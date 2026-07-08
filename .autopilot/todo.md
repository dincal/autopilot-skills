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

- [ ] AP-001 | P1 | user | in-progress
  - story: 오토파일럿 사용자로서, 여러 파일에 걸친 큰 피처를 울트라코드 모드에서 fan-out/fan-in 워크플로우로 병렬 구현해, 계약(WORK SUMMARY·테스트·커버리지)을 유지한 채 더 빠르게 개발되기를 원한다.
  - acceptance:
    - loop-protocol.md 울트라코드 섹션에 Phase C 개발 가이드가 추가된다 (파일 소유권 분할 fan-out, 통합 fan-in 스테이지, 사용 조건 임계값, 실패 처리, WORK SUMMARY 계약 유지)
    - autopilot-dev SKILL.md의 울트라코드 요약과 영·한 README의 ultracode 설명에 개발 fan-out이 반영된다
    - 정적 검증(frontmatter/JSON/bash)이 통과하고 plugin.json 버전이 minor bump된다
  - notes: 사용자 요청 2026-07-08 (오토파일럿 단일 피처 모드)
