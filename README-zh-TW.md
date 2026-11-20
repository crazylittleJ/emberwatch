# 餘燼林境 · 灰苔遺跡

這是原版 Canvas 2D 戰鬥沙盒的 Godot 4.6.3 移植版。專案使用 GDScript 與 Compatibility 渲染器，包含 17×17 格戰場、三種魔物、餘燼斬、霜星箭、範圍預覽、技能冷卻、勝敗和重開。戰鬥以 60 Hz 更新。角色、道具與地面都是 2D 像素素材。

## 直接開啟專案

1. 解壓縮後在 Godot 4.6.3 的 Project Manager 選 **Import**，指定本資料夾的 `project.godot`。
2. 等素材匯入完成，按 **F5** 執行 `main.tscn`。macOS 鍵盤若把 F5 當成系統功能，可用 Godot 工具列的執行按鈕。
3. 遊戲主場景為 `main.tscn`。HUD 和響應式排版在 `scripts/main.gd` 裡建立，可用 Godot 的腳本編輯器或 VS Code 修改。

專案執行時使用隨附的素材與字型。重做美術時才需要 Node.js 或像素編輯器。

## 操作

| 動作 | 鍵盤與滑鼠 | 手機觸控 |
| --- | --- | --- |
| 移動 | WASD 或方向鍵 | 按住方向鍵 |
| 瞄準 | 滑鼠移到戰場上 | 點戰場瞄準並施放，按住後拖曳只調整瞄準 |
| 施放 | 滑鼠左鍵或空白鍵 | 點戰場，或按「施放」朝目前的瞄準方向攻擊 |
| 切換技能 | Q 選餘燼斬，E 選霜星箭 | 點技能按鈕 |
| 顯示技能範圍 | V 或點「範圍」 | 點「範圍」 |
| 從頭開始 | 點「重開」或結算畫面的「再玩一次」 | 同左 |

手機可以用一指按住移動，另一指點戰場或施放。直向在戰場下方顯示觸控控制，橫向在戰場右側顯示。滑鼠與觸控共用技能命中判定。

## 執行已匯出的 Web 版

在解壓後的上層資料夾執行下列指令，再到瀏覽器開啟 [http://localhost:8000/](http://localhost:8000/)。

```bash
python3 -m http.server 8000 --directory Emberwatch-Web
```

Windows 可以用 `py -m http.server 8000 --directory Emberwatch-Web`。手機若要從同一個 Wi-Fi 測試，可以把 `localhost` 換成電腦的區網 IP。要公開分享時，把 `Emberwatch-Web` 的完整內容放在靜態 HTTPS 主機，例如 GitHub Pages。保留所有相對路徑；WebAssembly 應由伺服器以 `application/wasm` 提供。透過網站網址開啟遊戲。

## 修改後重新匯出

1. Godot 的 **Editor → Manage Export Templates** 安裝與 4.6.3 對應的模板。
2. **Project → Export** 選現成的 **Web** 預設。使用 Compatibility 和單執行緒，適用於一般靜態主機。
3. 選 **Export Project**，匯出成同一資料夾下的 `index.html`，並一併發布其他匯出檔。可用新版桌面 Chrome、Edge、Firefox 或支援 WebGL 2.0 與 WebAssembly 的手機瀏覽器開啟。實機驗收建議涵蓋 iPhone Safari 和 Android Chrome。

命令列做法（從 Godot 專案目錄執行）

```bash
godot --headless --editor --import --quit
godot --headless --export-release Web ../Emberwatch-Web/index.html
```

## 修改檔案的位置

| 路徑 | 用途 |
| --- | --- |
| `scripts/battle_data.gd` | 技能數值、玩家出生點、敵人配置、道具碰撞格。搬動道具時可改 `cell`，並沿用指向原圖的 `sprite_key`。 |
| `scripts/battle.gd` | 移動、地圖碰撞、技能命中、投射物、敵人 AI、緩速、勝敗。 |
| `scripts/projection.gd` | 28×14 菱形投影與滑鼠座標反算。 |
| `scripts/arena_view.gd` | 像素圖繪製、腳底深度排序、火把動畫、範圍預覽、戰鬥特效。 |
| `scripts/main.gd` | HUD、選單、鍵鼠、觸控輸入、直向及橫向排版。 |
| `assets/` | 67 張 PNG，包含普通與受擊角色圖、地面／背景、場景道具、火把動畫格與技能圖示。另附繁中子集字型。 |
| `tools/generate_art.mjs` 和 `tools/reference/` | 從原版色盤、像素字串及繪圖程式重新輸出 PNG。 |
| `tests/smoke.gd` | Godot 冒煙測試，包含開場傷害、冷卻、霜星箭命中／遮擋、勝敗、觸控與重開。 |

像素角色圖的原點是腳底。地面兩張 PNG 使用 576×340 座標。戰鬥權威座標以格為單位，傷害、移動與碰撞可獨立於畫面縮放調整。同步調整視覺道具和碰撞時，請一併修改地圖資料與素材位置。

如需重新生產 PNG，可在 `tools/` 安裝 `@napi-rs/canvas` 後執行 `node generate_art.mjs`。也可直接編輯 PNG。字型 `EmberwatchSans.otf` 包含當前 UI 文字所需的繁中字形。新增台詞時可換入完整的繁中字型，授權見 `assets/fonts/OFL.txt`。

測試指令（從 Godot 專案目錄執行）

```bash
godot --headless --script res://tests/smoke.gd
```
