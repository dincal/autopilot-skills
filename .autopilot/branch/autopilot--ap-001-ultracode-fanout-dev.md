# Branch: autopilot/ap-001-ultracode-fanout-dev

- created: 2026-07-08
- base: main
- features: AP-001
- pr: #1
- status: in-review   <!-- in-progress | in-review | merged | abandoned -->

## Goal Prompt

### Objective
울트라코드 모드에서 여러 파일에 걸친 대형 피처의 개발 단계(Phase C)가 fan-out/fan-in
워크플로우로 병렬 구현되도록 프로토콜 가이드를 추가한다.

### User story
오토파일럿 사용자로서, 여러 파일에 걸친 큰 피처를 울트라코드 모드에서 fan-out/fan-in으로
병렬 구현해, 계약(WORK SUMMARY·테스트·커버리지)을 유지한 채 더 빠르게 개발되기를 원한다.

### Acceptance criteria
- [ ] loop-protocol.md 울트라코드 섹션에 Phase C development 항목 추가 (사용 조건 ≥3 서브태스크,
      서로소 파일 소유권 fan-out, fan-in 통합 스테이지, 실패 처리, WORK SUMMARY 계약 유지,
      오케스트레이터 worktree/push/PR 소유권 유지)
- [ ] SKILL.md 울트라코드 요약과 영·한 README ultracode 설명에 개발 fan-out 반영
- [ ] plugin.json 0.20.0 + CHANGELOG [0.20.0] + tech-design.md 결정 기록
- [ ] 정적 검증 통과 (frontmatter YAML / JSON / bash -n)

### Constraints
플러그인 콘텐츠 English. 기존 가드 불변: 워크플로우 push·머지·.autopilot 쓰기 금지,
fastMode가 리뷰에서 ultracode 우선, Workflow 도구 없으면 표준 폴백.

### Out of scope
Phase C 외 단계 변경, 워크플로우 러너 구현, 새 config 키.

## Plan

loop-protocol.md 울트라코드 섹션 Phase B~D 사이에 Phase C 항목 신설(+도입부 문구 조정),
SKILL.md 요약·README 영/한 반영, plugin.json 0.20.0, CHANGELOG, tech-design 기록,
브랜치 문서. 테스트: 정적 검증(frontmatter/JSON/bash) + 내용 grep 단언.

## Autonomous Decisions

- fan-out 임계값을 "독립 서브태스크 3개 이상"으로 설정 — 사용자가 임계값 수치는 지정하지
  않았음. 근거: 2개 이하는 파티션 오버헤드가 병렬 이득을 상쇄
- 병렬 안전성 메커니즘으로 "서로소 파일 소유권 + 공유 표면 편집 금지"를 채택 — 사용자는
  fan-out/fan-in 방향만 지정, 구체 규칙은 에이전트 설계

## Work Summary

- feature-id: F-2026-07-08-a
- tests: passing — 정적 검증 + 내용 단언 12건 전부 통과 (frontmatter YAML 13파일, JSON 6파일, bash -n 3스크립트, 내용 grep 단언 9건)
- coverage: not measured — docs 전용 피처 (커버리지 도구 없음; 내용 단언으로 대체)
- files-changed: loop-protocol.md(Phase C 항목 신설 + 도입부 조정), SKILL.md(요약), README.md/README.ko.md(ultracode 설명), plugin.json(0.20.0), CHANGELOG, tech-design, 본 문서
- deviations-from-plan: 없음
- how-to-verify: `git diff main...HEAD` 후 loop-protocol.md 울트라코드 섹션의 "Phase C development" 항목 확인; 정적 검증 배터리 재실행

## Review Log

- code-review r1: APPROVE (blocking 0, notes 4 — 감사 메타 구분, single-feature 미적용 명시 제안, 프로세스 메타 기입, CHANGELOG 스타일 일관)
- e2e r1: APPROVE (blocking 0, notes 2 — 미커밋 todo.md 정리 대상, 문서 언어 관례 일치)
