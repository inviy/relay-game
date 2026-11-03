# RELAY 기체 일러스트 · 아이콘 마스터 스틸

카드·도감·아이콘용 1024×1024 알파 PNG. 애니메이션 없음. `index.html`에는 아직 연결하지 않았다.

## 생성 경로

- 도구: Agent Sprite Forge v0.4.0 `generate2dsprite/scripts/master_still.py` (generate → approve)
- 이미지 경로: `local:codex-cli`. 로컬 Codex CLI 0.163.0의 `image_gen` 도구(OpenAI)가 사용자 본인의 ChatGPT 로그인으로 돌았다. 구독 쿼터를 쓰고 API 크레딧은 쓰지 않았으며 호출당 USD는 0이다.
- 모든 테이크가 실제 생성이다. `FORGE_ROUTE_MEDIA_FAKE`는 쓰지 않았다.
- 2026-11-03, 각 3테이크. 실행 순서: warden → (warden 승인본을 style 참조로) rover, pulse → (warden 승인본을 identity 참조로) icon.
- 편집(edit) 패스는 없다. 고른 테이크를 그대로 승인했다.
- 승인 처리: 키 색 제거, 6px 여백 크롭, LANCZOS로 1024 캔버스에 배치. 기체는 세로 720px에 상단 152px, 아이콘은 세로 904px에 상단 60px(링 바깥이 가장자리에서 약 60px).
- 키 색: warden·icon은 마젠타, rover는 초록(보라 보조색 때문), pulse는 파랑(핑크 때문).

## 상업 이용

OpenAI 이용약관상 출력물의 권리는 사용자에게 귀속되며 상업 이용이 가능하다(ChatGPT 구독 계정 경유, https://openai.com/policies/terms-of-use). 다만 저작권 등록 가능성은 관할에 따라 다르다.

## 산출물

| 파일 | 테이크 | 고른 이유 |
|---|---|---|
| `forms/warden.png` | `warden-gen` take 3 | 3테이크 중 가장 단순(내부 패널 음영 없음), 기수 돌기가 길어 방향이 읽힘 |
| `forms/rover.png` | `rover-gen` take 2 | 날개가 가장 넓은 삼각 실루엣, 패널 디테일 최소 |
| `forms/pulse.png` | `pulse-gen` take 2 | 하이라이트·광택 없이 가장 평평함 |
| `icon/master.png` | `icon-gen` take 1 | 링이 가장 굵고 간격이 넓어 48px에서 끊김이 보임 |

- `forms/*.master.json`, `icon/master.json`: Sprite Forge `generate2dsprite.master.v1` 기록(경로, 변환, 매트 QA). 안의 상대 경로는 생성 당시 `_work/` 기준이며, `_work/`는 커밋하지 않았다.
- `specs/*.json`: 생성 스펙. `style_ref`·`identity_ref`가 가리키는 `../_work/warden/master.png`는 커밋하지 않았다.
- `compare-48px.png`: 48×48 축소본. 윗줄은 컬러 ×4, 가운데 줄은 흑백 ×4, 아랫줄은 실제 크기 컬러와 흑백이다. 배경은 `#0b1024`.

## 검수 메모

- 4장 모두 1024×1024 RGBA이고 모서리 알파는 0, bbox 중심은 (512, 512)이다. 기수는 위를 향한다.
- 흑백 48px에서 화살촉(rover), 돌기 달린 육각(warden), 동심원과 위성 4개(pulse)로 구분된다.
- 선 굵기는 세 장이 비슷하다. 흑백 휘도는 warden(금·흰 코어)이 가장 밝고 rover·pulse는 한 단계 어둡다. 색상 자체의 휘도 차이일 뿐 발광 처리는 같다.
- 지시서의 "네온 발광"은 실제로는 단색 라인과 검은 외곽선의 플랫한 그림으로 나왔다. 블러 글로우가 없어 48px에서 깔끔하지만, 발광 느낌이 필요하면 통합 단계에서 캔버스 shadowBlur로 얹는 편이 낫다.
- icon 승인 시 경고 1건: `the subject is upscaled x1.05 (863 px source height): detail will be soft`. 1.05배라서 육안으로는 차이가 없다.

## 프롬프트 원문

<details><summary>warden</summary>

```text
Create exactly ONE square image (1024x1024).

Style: premium HD 2D game art for a top-down neon arcade shooter (card and codex illustration): a clean, high-resolution hand-painted sprite illustration with crisp sharp edges, a clean dark outline, rich but controlled colours, cel shading with soft highlights and clear light and shadow shapes, fine readable detail, no blur, no photo-realism, no 3D render look. No text, no letters, no numbers, no logo, no watermark, no signature, no UI, no border, no frame, no grid, no stars, no nebula, no space background, no ground, no cast shadow, no motion blur.

Subject: the RELAY "warden" ship, a defensive armored spacecraft, top-down view seen from directly above, nose pointing up toward the TOP edge, perfectly centered and symmetric. A thick regular hexagonal armored hull in dark navy #111834 with bold neon gold #ffd166 edge lines. Six short, blunt gold prongs point straight outward, one from the middle of each hexagon side. A bright white circular core sits at the exact center, ringed by small orange #ff9f43 accents. The nose is marked by the top prong being slightly longer. Hard-edged flat geometric silhouette, clean bold lines of one even weight, no realistic texture, no metal shading, no panel detail. Glow only on the hull edges and the core.

Size and position: one single object, the top of the object (including every attached part) about 20 percent below the top edge of the canvas and its lowest point about 20 percent above the bottom edge (the object about 60 percent of the canvas height), centred horizontally, generous empty magenta margin on every side, nothing touching or crossing the edges. The whole object is drawn with solid, fully opaque pixels: no transparency, no semi-transparent glow, no soft aura, nothing blended with the background.

Background: solid flat pure magenta #FF00FF everywhere outside the object, no shadow, no ground, no glow on the background.
```
</details>

<details><summary>rover</summary>

```text
Create exactly ONE square image (1024x1024).

Style: premium HD 2D game art for a top-down neon arcade shooter (card and codex illustration): a clean, high-resolution hand-painted sprite illustration with crisp sharp edges, a clean dark outline, rich but controlled colours, cel shading with soft highlights and clear light and shadow shapes, fine readable detail, no blur, no photo-realism, no 3D render look. No text, no letters, no numbers, no logo, no watermark, no signature, no UI, no border, no frame, no grid, no stars, no nebula, no space background, no ground, no cast shadow, no motion blur.

Reference image: the attached image is an approved in-game sprite from the same game (the approved warden ship of the same game): match its art style, outline weight, shading, figure size and position on the canvas; do NOT copy its hexagonal shape, its prongs, its gold and orange colours.

Subject: the RELAY "rover" ship, a fast agile interceptor spacecraft, top-down view seen from directly above, nose pointing up toward the TOP edge, perfectly centered and symmetric. A long, slender arrowhead hull in dark navy #111834 with bold neon cyan #4ff0d8 edge lines and violet #a86bff secondary accents. A sharp narrow nose points straight up. Two swept-back wings flare out wide behind the middle of the hull, ending in sharp tips. Two thin separate tail streaks trail straight down from the rear, like afterimage ribbons. A small bright cyan core in the hull center. Thin and fast-looking, much narrower than it is tall. Hard-edged flat geometric silhouette, clean bold lines of one even weight, no realistic texture, no metal shading, no panel detail. Glow only on the hull edges and the core.

Size and position: one single object, the top of the object (including every attached part) about 20 percent below the top edge of the canvas and its lowest point about 20 percent above the bottom edge (the object about 60 percent of the canvas height), centred horizontally, generous empty green margin on every side, nothing touching or crossing the edges. The whole object is drawn with solid, fully opaque pixels: no transparency, no semi-transparent glow, no soft aura, nothing blended with the background.

Background: solid flat pure green #00FF00 everywhere outside the object, no shadow, no ground, no glow on the background.
```
</details>

<details><summary>pulse</summary>

```text
Create exactly ONE square image (1024x1024).

Style: premium HD 2D game art for a top-down neon arcade shooter (card and codex illustration): a clean, high-resolution hand-painted sprite illustration with crisp sharp edges, a clean dark outline, rich but controlled colours, cel shading with soft highlights and clear light and shadow shapes, fine readable detail, no blur, no photo-realism, no 3D render look. No text, no letters, no numbers, no logo, no watermark, no signature, no UI, no border, no frame, no grid, no stars, no nebula, no space background, no ground, no cast shadow, no motion blur.

Reference image: the attached image is an approved in-game sprite from the same game (the approved warden ship of the same game): match its art style, outline weight, shading, figure size and position on the canvas; do NOT copy its hexagonal shape, its prongs, its gold and orange colours.

Subject: the RELAY "pulse" ship, a resonance spacecraft, top-down view seen from directly above, nose pointing up toward the TOP edge, perfectly centered and symmetric. A round central core: a solid circular disc in dark navy #111834 with a bright neon pink #ff5c8a center. Around it, three thin concentric rings in neon pink with small gaps, evenly spaced, like a sound wave ringing outward. Four small separate floating devices (small diamond-shaped pods in navy with cyan #4ff0d8 edge lines) hover just outside the rings at the top, bottom, left and right, not touching the rings. A short pointed notch on the top of the core marks the nose. Hard-edged flat geometric silhouette, clean bold lines of one even weight, no realistic texture, no metal shading, no panel detail. Glow only on edges and the core.

Size and position: one single object, the top of the object (including every attached part) about 20 percent below the top edge of the canvas and its lowest point about 20 percent above the bottom edge (the object about 60 percent of the canvas height), centred horizontally, generous empty blue margin on every side, nothing touching or crossing the edges. The whole object is drawn with solid, fully opaque pixels: no transparency, no semi-transparent glow, no soft aura, nothing blended with the background.

Background: solid flat pure blue #0000FF everywhere outside the object, no shadow, no ground, no glow on the background.
```
</details>

<details><summary>icon</summary>

```text
Create exactly ONE square image (1024x1024).

Style: premium HD 2D game art for a top-down neon arcade shooter (app icon): a clean, high-resolution hand-painted sprite illustration with crisp sharp edges, a clean dark outline, rich but controlled colours, cel shading with soft highlights and clear light and shadow shapes, fine readable detail, no blur, no photo-realism, no 3D render look. No text, no letters, no numbers, no logo, no watermark, no signature, no UI, no border, no frame, no grid, no stars, no nebula, no space background, no ground, no cast shadow, no motion blur.

Reference image: the attached image is the approved warden ship; copy the hexagonal hull shape, the six prongs, the line weight and the colours of the hull exactly.

Subject: an app icon emblem: the RELAY warden ship inside a broken gold ring, top-down view seen from directly above, nose pointing up toward the TOP edge, perfectly centered and symmetric. In the center, the warden ship from the FIRST image, drawn smaller (about 60% of the ring diameter): the same dark navy #111834 hexagonal hull with gold #ffd166 edge lines and six short gold prongs, but its core is now a bright glowing cyan #4ff0d8 circle instead of white. Around the ship, a thick bold gold #ffd166 ring broken into exactly four equal arcs with four equal gaps, the gaps at the top-left, top-right, bottom-left and bottom-right diagonals. The ring does not touch the ship. Hard-edged flat geometric shapes, clean bold lines of one even weight, no realistic texture, no metal shading.

Size and position: one single object, the top of the object (including every attached part) about 20 percent below the top edge of the canvas and its lowest point about 20 percent above the bottom edge (the object about 60 percent of the canvas height), centred horizontally, generous empty magenta margin on every side, nothing touching or crossing the edges. The whole object is drawn with solid, fully opaque pixels: no transparency, no semi-transparent glow, no soft aura, nothing blended with the background.

Background: solid flat pure magenta #FF00FF everywhere outside the object, no shadow, no ground, no glow on the background.
```
</details>
