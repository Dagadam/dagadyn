# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · **한국어** · [中文](README.zh.md)

객체를 움직이게 하는 SketchUp 확장 프로그램입니다. 그룹, 컴포넌트, 단면 평면의 모든 속성이 선택한 시간 동안, 직접 그린 곡선을 따라 한 상태에서 다른 상태로 바뀌고, 그 모습을 장면에서 볼 수 있습니다. 열리는 문, 올라가는 엘리베이터, 켜지는 조명, 건물을 가로지르는 단면.

⬇ **다운로드**: [최신 버전](https://github.com/Dagadam/dagadyn/releases/latest) (모든 버전: [Releases](https://github.com/Dagadam/dagadyn/releases))

🛏 **예제**: [모든 것이 움직이는 침실](examples/README.md) (`examples/bedroom.skp`), DagaDyn의 모든 기능을 담았습니다.

## 기능

- **속성**: 이동(현재 자리에서), 위치, 회전, 크기(너비·깊이·높이), 배율, 색, 불투명도, 표시, 태그. 단면 평면은 이동하고 켜지고 꺼집니다.
- **상태와 곡선**: 각 속성에 시작 상태, 끝 상태, 길이가 있고, 상태를 더하면 연속 동작이 됩니다. 전환은 곡선을 따릅니다: 직선, 가속, 감속, 지나쳤다 복귀, 튕김, 탄성, 계단, 또는 곡선 편집기에서 점을 끌어 그린 나만의 곡선.
- **타임라인**: 재생, 일시 정지, 정지와 아무 순간이나 볼 수 있는 막대. 한 번, 반복, 왕복을 원하는 속도로.
- **시간의 속도**: 타임라인 옆의 **⏱** 버튼으로, 전환과 같은 곡선으로 모델 전체의 시간 흐름을 정합니다. 가파르면 타임랩스, 완만하면 슬로 모션이며, 재생은 타임라인보다 짧거나 길 수 있습니다.
- **시작**: 타임라인과 함께, 다른 객체가 끝난 뒤(대기 시간 추가), 또는 **작동할 때**: *작동* 도구로 클릭. 매번 처음부터 시작하거나, 앞으로 갔다가 다음에는 뒤로 갈 수 있습니다(문, 서랍).
- **따라가는 연쇄**: 앞으로 갔다가 뒤로 가는 객체 뒤에 연쇄로 이어진 객체는 그 방향을 따라 갈 때도 돌아올 때도 움직이며, 각각 앞의 객체가 끝난 뒤에 시작합니다(레버, 이어서 도개교).
- **프로젝트는 바뀌지 않습니다**: 애니메이션은 모델을 건드리지 않고 객체를 움직입니다. *정지*하면 모두 제자리로 돌아가고 파일에는 항상 정지 상태가 저장됩니다. *유지*는 객체를 지금 모습 그대로 둡니다(Ctrl+Z로 실행 취소).
- **객체 안에**: 애니메이션은 `.skp` 파일에 저장되고 객체와 함께 복사됩니다. 여러 객체를 선택하면 변경 사항이 모두에 적용되며, 위치와 크기는 각각에 맞춰집니다.
- **뷰에 궤적**: 움직이는 객체의 경로와 상태마다 점 하나(SketchUp 2023 이상).
- **편집할 때 미리 보기**: 상태의 값을 바꾸면 객체가 그 상태로 표시됩니다.
- **단독으로 또는 [DagaWASD](https://github.com/Dagadam/dagawasd)와 함께**: DagaDyn은 다른 것이 필요 없습니다. DagaWASD 1.3.0 이상도 설치되어 있으면 걷기, 탐색, 경로 재생, 동영상 내보내기 중에도 객체가 움직입니다(동영상 시간에 맞춰 프레임마다). 움직이는 발판이 당신을 태워 가고, 작동 키로 ‘작동할 때’ 시작하는 객체를 움직일 수 있습니다.
- 36개 언어의 패널. DagaWASD가 설치되어 있으면 그 언어와 모양을 따릅니다.
- **접근성**: [ACCESSIBILITY.md](.github/ACCESSIBILITY.md) 참고.

요구 사항: SketchUp 2023 이상. Windows에서 개발하고 테스트했으며, Mac에서는 아직 테스트하지 않았습니다.

## 사용법

1. *확장 프로그램 › DagaDyn › 애니메이션 패널…* (또는 도구 모음).
2. 그룹, 컴포넌트 또는 단면 평면을 선택합니다. *애니메이션 › 객체*에서 애니메이션할 속성을 고르고 *추가*를 누릅니다.
3. 시작 상태와 끝 상태(*⌖ 현재*는 객체의 지금 값을 가져옵니다), 길이를 입력하고 곡선을 고릅니다. 작은 곡선을 클릭하면 직접 그릴 수 있습니다.
4. **▶**(또는 패널에서 Space)를 누릅니다. **⏹**는 모두 제자리로 돌립니다.

‘작동할 때’ 시작하는 객체는 *작동* 도구(도구 모음 또는 메뉴)를 고른 뒤 모델에서 객체를 클릭합니다. Esc로 도구를 끝냅니다. 마우스 아래에서 시작될 객체는 테두리와 이름으로 표시됩니다. 타임라인과 함께 시작하는 객체가 없으면 **▶** 버튼이 **☝**(*작동* 도구)로 바뀝니다.

## 설치

[최신 버전](https://github.com/Dagadam/dagadyn/releases/latest)(*Assets* 아래)에서 **`dagadyn-<버전>.rbz`**를 내려받아 *확장 프로그램 › Extension Manager › 확장 프로그램 설치*로 설치합니다.

설정은 `%APPDATA%\DagaDyn\settings.json`에 저장되며 업데이트해도 지워지지 않습니다. 애니메이션은 확장 프로그램이 아니라 모델 안에 있습니다.

## 개발

코드, 주석, 변경 기록은 이탈리아어입니다. 확장 프로그램의 내부 구조는 [SVILUPPO.md](SVILUPPO.md)에 있습니다.

- `installa.bat`는 찾은 모든 SketchUp의 Plugins 폴더에 소스를 복사합니다.
- `tools\run_tests.bat`로 테스트를 실행합니다(SketchUp을 흉내 낸 Ruby, 곡선 테스트에는 Node.js도 필요).
- `ruby tools\test_live.rb`는 DagaWASD의 브리지를 통해 실제 SketchUp에서 테스트합니다(새 모델(*파일 › 새로 만들기*)이 열려 있어야 하며, 끝나면 새 모델로 남깁니다).
- `ruby tools\crea_rbz.rb`로 `dist\`에 패키지를 만듭니다.
- 버전 번호는 `dagadyn.rb`(`VERSION`)에만 있고, 버전마다 `CHANGELOG.md`에 절이 있습니다.
- 이 README는 여러 언어로 되어 있습니다(`README.md`는 영어, `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`, `.ru`, `.ja`, `.ko`, `.zh`). 변경은 모두에 반영하세요.

기여를 환영합니다: [CONTRIBUTING.md](.github/CONTRIBUTING.md) 참고.

## 연락처

버그와 아이디어는 다른 사람도 보고 따라갈 수 있는 [issue](https://github.com/Dagadam/dagadyn/issues)로 남겨 주세요. 보안 문제는 [보안 정책](.github/SECURITY.md)을 따라 주세요. [DagaWASD@icloud.com](mailto:DagaWASD@icloud.com)으로 메일을 보낼 수도 있습니다.

DagaDyn이 유용했다면 [Ko-fi](https://ko-fi.com/dagadam)에서 개발을 후원할 수 있습니다.

## 라이선스

[MIT](LICENSE) © 2026 Dagadam. 상업적 용도를 포함해 코드를 자유롭게 사용, 수정, 재배포할 수 있습니다. 단, 모든 사본에 저작권 고지와 라이선스 문구를 남겨야 합니다.
