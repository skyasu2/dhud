# DHUD Lite - Project Guide

## 프로젝트 목적

기존 [DHUD](https://www.curseforge.com/wow/addons/dhud) WoW 애드온이 **WoW 12.0.0(Midnight)** 패치에서 동작하지 않아,
최신 애드온 정책 및 API 변경점에 맞게 **DHUDLITE**로 리팩토링하는 프로젝트.

- **핵심 목표**: 기존 DHUD의 UI/UX를 최대한 유지하면서 12.0.0에서 동작하게 만듦
- **원본**: `/DHUD/` - 원본 DHUD 소스 (참조용, 수정 대상 아님)
- **작업 대상**: `/DHUDLITE/` - 리팩토링된 신규 애드온

## 원본 DHUD가 동작하지 않는 이유

1. **Ace3 라이브러리 의존** - AceDB, AceGUI, AceConfig 등 외부 라이브러리에 의존
2. **deprecated WoW API 사용** - `UnitIsTapped()`, `GetComboPoints()`, `table.getn()` 등
3. **구버전 Interface 타겟** - Interface 110105 기준, 12.0.0 비호환
4. **Secret Values 미지원** - 12.0.0의 보안 정책 변경에 대응 불가

## 리팩토링 방향

| 항목 | DHUD (원본) | DHUDLITE (리팩토링) |
|------|-------------|---------------------|
| 파일 규모 | 54파일, ~21,000줄 | 25파일, ~3,600줄 |
| 외부 의존성 | Ace3, LibStub | 없음 |
| OOP | MCCreateClass (58줄) | CreateClass (12줄) |
| 이벤트 | MADCATEventDispatcher (860줄) | EventBus (40줄) |
| 설정 | AceDB 기반 복잡한 계층 | 플랫 테이블 + SavedVariables |
| WoW 버전 | 다중 버전 호환 | 12.0.0 전용 |
| Secret Values | 미지원 | 호환 (주기적 업데이트 방식) |

## 디렉토리 구조

```
/mnt/d/dev/dhud/
├── DHUD/           # 원본 DHUD (참조용)
├── DHUDLITE/       # 리팩토링 대상 (작업 디렉토리)
│   ├── Core.lua           # CreateClass, EventBus, 유틸리티
│   ├── Settings.lua       # SavedVariables 설정
│   ├── AlphaManager.lua   # 상태별 투명도
│   ├── HUDManager.lua     # 슬롯-트래커 배선
│   ├── Main.lua           # 부팅, 슬래시 커맨드
│   ├── Data/              # 데이터 트래커 (Health, Power, Cast, Combo, UnitInfo)
│   ├── GUI/               # 렌더링 (Textures, BarRenderer, Layout 등)
│   └── Slots/             # UI 슬롯 (Bar, CastBar, Resource, UnitInfo, Icon)
└── README.md
```

## 개발 규칙

- **UI/UX 보존 우선**: 원본 DHUD의 외형과 동작을 최대한 유지
- **12.0.0 전용**: Classic/Cata 등 구버전 호환 코드 불필요
- **무의존성**: 외부 라이브러리(Ace3 등) 사용 금지
- **Secret Values 호환**: 직접 API 호출 대신 주기적 업데이트(OnUpdate) 패턴 사용
- **경량 유지**: 불필요한 추상화 최소화, 단순한 구조 유지

## 주요 패턴

- **커브드 바 렌더링**: `SetTexCoord` + `SetHeight`로 텍스처를 잘라 곡선 표현
- **EventBus**: `ns.events:On(event, obj, func)` / `Fire(event, ...)` 패턴
- **트래커 → 슬롯**: HUDManager가 데이터 트래커를 슬롯에 바인딩
- **알파 상태 머신**: 전투 > 타겟 > 휴식 > 대기 우선순위로 투명도 전환

## 빌드 & 테스트

- 빌드 도구 없음 - Lua 파일을 WoW `Interface/AddOns/DHUDLITE/`에 직접 복사
- 테스트는 WoW 클라이언트에서 직접 실행
- `/dhudlite reset` - 설정 초기화 후 리로드
- `/dhudlite show` / `hide` / `alpha` - HUD 제어

## 현재 상태

- Phase 1-4 (핵심 기능) 구현 완료
- Phase 5 (Options UI) - 별도 LoadOnDemand 애드온으로 분리 예정
