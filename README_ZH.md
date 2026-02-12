# Claude Code macOS 通知器

為 [Claude Code](https://claude.ai/code) Hooks 打造的原生 macOS 通知系統，搭配自訂 clawd 圖示。

![macOS 展示 Claude Code 通知](assets/claude-code-notifier-demo.png)

## 為何需要這個專案

Claude Code 的 `Notification` Hook 會在終端機**不在前景**且 Claude 需要你注意時觸發。挑戰在於如何發送帶有自訂圖示的 macOS 通知：

| 方案 | 自訂圖示 | 問題 |
|------|:--------:|------|
| **osascript** (`display notification`) | 否 | 永遠顯示 Script Editor 的圖示 — macOS 將通知圖示綁定在**發送程序的身份** |
| **terminal-notifier** (`-appIcon`) | 否 | 依賴 Apple 私有 API，macOS Big Sur (11.0) 後失效（[issue #287](https://github.com/julienXX/terminal-notifier/issues/287)） |
| **原生 Swift .app**（本專案） | **是** | macOS 使用 .app 自身的圖示 — 完全可控 |

## 檔案結構

```
~/.claude/hooks/claude-code-notifier/
├── Claude Code.app/             # macOS 應用程式套件
│   └── Contents/
│       ├── Info.plist           # Bundle 設定（LSUIElement: true 隱藏 Dock 圖示）
│       ├── MacOS/
│       │   └── Claude Code      # 編譯後的 Swift 執行檔
│       └── Resources/
│           └── AppIcon.icns     # clawd 圖示（85% 白色圓角矩形背景）
├── notify.sh                    # Hook 進入點（前景偵測 → 解析 JSON → 通知）
├── notify.conf                  # 使用者設定（覆蓋 notify.sh 中的英文預設）
├── notifier.swift               # 通知發送程式原始碼（NSUserNotification）
├── generate_icon.swift          # 圖示生成腳本（CoreGraphics 合成）
├── assets/                      # 圖示生成用來源圖片
│   └── clawd-normal.png         # clawd 來源圖片
├── README.md                    # English documentation
└── README_ZH.md                 # 繁體中文文件（本檔）
```

### 各檔案用途

| 檔案 | 用途 |
|------|------|
| `notify.sh` | Hook 進入點。偵測終端機前景狀態（iTerm2 分頁感知）、載入設定、解析 stdin JSON、呼叫 .app 執行檔 |
| `notify.conf` | 使用者設定檔。覆蓋 `notify.sh` 中的英文預設訊息與音效。格式詳見[自訂訊息](#自訂訊息) |
| `notifier.swift` | 通知執行檔的 Swift 原始碼。使用 `NSApplication` + `NSUserNotificationCenterDelegate` 發送通知並處理點擊切回（使用者點擊通知橫幅時自動切回終端機） |
| `generate_icon.swift` | 生成應用程式圖示。載入來源圖片，以 85% 比例合成到 1024x1024 白色圓角矩形畫布（cornerRadius: 180），輸出 PNG |
| `Claude Code.app` | 編譯後的 .app 套件。`LSUIElement: true` 防止出現在 Dock。Bundle ID: `com.claude-code.notifier` |

## 前置需求

- macOS 10.10+（已在 macOS 14 Sonoma 上測試）
- Xcode Command Line Tools（`xcode-select --install`）
- clawd 來源圖片（如 `~/.claude/hooks/claude-code-notifier/assets/clawd-normal.png`）
- Python 3（macOS 預裝，`notify.sh` 用於解析 JSON）

## 從原始碼建置

### 步驟一：建立 .app 套件結構

```bash
APP_DIR="$HOME/.claude/hooks/claude-code-notifier/Claude Code.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
```

### 步驟二：建立 Info.plist

```bash
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.claude-code.notifier</string>
	<key>CFBundleName</key>
	<string>Claude Code</string>
	<key>CFBundleDisplayName</key>
	<string>Claude Code</string>
	<key>CFBundleExecutable</key>
	<string>Claude Code</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.10</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
EOF
```

> `LSUIElement: true` 防止應用程式在 Dock 中顯示。

### 步驟三：編譯通知執行檔

```bash
swiftc notifier.swift \
  -o "$APP_DIR/Contents/MacOS/Claude Code" \
  -framework Cocoa
```

### 步驟四：生成圖示

編譯並執行 `generate_icon.swift`：

```bash
swiftc generate_icon.swift -o /tmp/generate_icon -framework Cocoa

# 用法：generate_icon [輸出路徑] [來源圖片路徑]
/tmp/generate_icon /tmp/clawd-1024.png ~/.claude/hooks/claude-code-notifier/assets/clawd-normal.png
# 若不帶參數：輸出 ./clawd-1024.png，使用 ~/.claude/hooks/claude-code-notifier/assets/clawd-normal.png
```

輸出 1024x1024 PNG 後，轉換為 `.icns`：

```bash
PNG_PATH="/tmp/clawd-1024.png"
ICONSET_DIR="/tmp/icon.iconset"
mkdir -p "$ICONSET_DIR"

for size in 16 32 128 256 512; do
  sips -z $size $size "$PNG_PATH" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$PNG_PATH" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR" /tmp/generate_icon "$PNG_PATH"
```

### 步驟五：設定 notify.sh 執行權限

```bash
chmod +x notify.sh
```

## 向 macOS 註冊

.app 必須先向 macOS 註冊，通知才會正常顯示。

### 首次註冊

```bash
open "$HOME/.claude/hooks/claude-code-notifier/Claude Code.app"
```

接著前往**系統設定 → 通知 → Claude Code**，啟用通知。

![macOS 通知設定 — Claude Code](assets/Application%20Notifier.png)

### 重新註冊（移動 .app 或更換圖示後）

```bash
# 取消舊的註冊
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$HOME/.claude/hooks/claude-code-notifier/Claude Code.app"

# 重新註冊
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  "$HOME/.claude/hooks/claude-code-notifier/Claude Code.app"

# 重新整理圖示快取
killall Dock

# 重新開啟以啟用
open "$HOME/.claude/hooks/claude-code-notifier/Claude Code.app"
```

### 從啟動台移除（若出現）

```bash
defaults write com.apple.dock ResetLaunchPad -bool true && killall Dock
```

> 此操作會重設所有 App 的啟動台排列。由於 .app 位於隱藏目錄（`~/.claude/`），不會再次出現。

## Claude Code Hook 整合

在 `~/.claude/settings.json` 中加入：

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/claude-code-notifier/notify.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/claude-code-notifier/notify.sh"
          }
        ]
      }
    ]
  }
}
```

### 支援的事件

| 事件 | 觸發時機 | 內建前景偵測 |
|------|---------|:----------:|
| `Notification` | Claude 需要注意時（等待授權、閒置提示等） | 是（僅在終端機不在前景時觸發） |
| `Stop` | Claude 完成回應時 | 否（每次都觸發） |

兩個事件共用同一個 `notify.sh` 腳本。腳本內建**終端機前景偵測**，讓 `Stop` 事件在你正在使用終端機時也會被抑制。

### 運作流程

1. Claude Code 觸發 `Notification` 或 `Stop` 事件
2. Hook 將 stdin JSON 傳送給 `notify.sh`
3. `notify.sh` 偵測終端機是否在前景（詳見下方終端機前景偵測）
4. 載入使用者設定檔（若存在）
5. 解析 JSON 取得 `hook_event_name`、`notification_type` 和可選的 `message`
6. 依優先級決定通知訊息：
   - `hook_event_name` 為 `Stop` → 設定的完成訊息（預設："Task completed"）
   - `notification_type` 對應設定訊息（來自 `notify.conf`，或英文預設）：

| notification_type | 預設訊息 |
|------|---------|
| `permission_prompt` | Waiting for your approval |
| `idle_prompt` | Waiting for your response |
| `auth_success` | Authentication successful |
| `elicitation_dialog` | Waiting for your selection |
| *（其他）* | stdin JSON 的 `message` 欄位（若有），否則 "Needs your attention" |

7. .app 執行檔發送帶有 clawd 圖示和設定音效的 macOS 通知
8. 使用者點擊通知橫幅時，App 自動啟動終端機（依優先序：iTerm2 → Terminal.app → WezTerm → Alacritty → kitty，找到第一個即啟動）

### 終端機前景偵測

腳本針對 iTerm2 使用**智慧分頁偵測**，其他終端機則使用 App 層級偵測：

```
前景 App 是 iTerm2？
├─ 否 → 發送通知
└─ 是 → 從 claude 進程往上遍歷父進程鏈，
         檢查任何祖先是否在可見分頁的 tty 上
    ├─ 找到祖先在可見 tty → 抑制（你正在看 Claude）
    └─ 無祖先匹配 → 發送通知（你在其他分頁）

前景 App 是其他終端機（Terminal / WezTerm / Alacritty / kitty / tmux）？
└─ 抑制（無分頁偵測，一律跳過）
```

iTerm2 分頁偵測原理：
1. 透過 AppleScript 取得目前可見 session 的 tty（`/dev/ttysXXX`）
2. 透過 `ps` 找到 `claude` 進程的 PID
3. 沿著父進程鏈往上遍歷（PPID → PPID → ...），檢查每個祖先的 tty
4. 若任何祖先的 tty 與可見分頁的 tty 匹配 → 抑制通知（使用者在 Claude 分頁）

> **為何要遍歷進程樹？** `claude` 自行分配子偽終端（如 `/dev/ttys011`），與 iTerm2 session 的 tty（如 `/dev/ttys008`）不同。但 claude 的祖先 shell 運行在 session 的 tty 上，因此往上遍歷可以找到匹配。

若要為其他終端機新增分頁偵測，請擴展 `notify.sh` 中的 `case` 區塊。

### 自訂訊息

預設訊息為英文（寫在 `notify.sh` 中）。若要自訂，在 notifier 目錄中建立 `notify.conf` 檔案：

```bash
~/.claude/hooks/claude-code-notifier/notify.conf
```

範例 — 繁體中文：

```bash
# 通知音效
# 可用：Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
NOTIFY_SOUND=Glass

# 自訂訊息
L_PERMISSION="有個操作需要你的許可才能執行 ✋"
L_IDLE="目前等待中，需要你的回覆 💬"
L_AUTH="認證已通過，流程繼續 🛂"
L_ELICITATION="出現了選項，需要你來做決定 🤔"
L_STOP="任務完成，請過目 ✅"
L_DEFAULT="有個環節需要你確認一下 👀"
```

可只覆蓋部分變數 — 未設定的值會使用英文預設。

> **重要**：`notify.conf` 檔案必須使用 Unix 換行（LF）。若使用 CRLF（`\r\n`），`\r` 會黏在變數值尾端導致訊息無法正常顯示。修正方式：`perl -pi -e 's/\r\n/\n/g' notify.conf`

### 手動測試

```bash
# 模擬 permission_prompt 事件
echo '{"notification_type":"permission_prompt"}' | ~/.claude/hooks/claude-code-notifier/notify.sh

# 模擬未知類型（fallback 到 message 欄位）
echo '{"notification_type":"some_new_type","message":"自訂訊息內容"}' | ~/.claude/hooks/claude-code-notifier/notify.sh

# 直接呼叫執行檔
~/.claude/hooks/claude-code-notifier/"Claude Code.app"/Contents/MacOS/"Claude Code" "標題" "訊息" "Glass"

# 測試點擊切回（3 秒內切到其他 App，出現通知後點擊橫幅）
(sleep 3 && ~/.claude/hooks/claude-code-notifier/"Claude Code.app"/Contents/MacOS/"Claude Code" "Claude Code" "點我切回終端機" "Glass") &
```

## 自訂設定

### 變更圖示大小

編輯 `generate_icon.swift` 中的 `clawdScale`（0.0 ~ 1.0，預設：0.85），然後重新建置圖示（步驟四）。

### 變更通知音效或訊息

建立或編輯 `notify.conf` 檔案，設定 `NOTIFY_SOUND` 或各個 `L_*` 訊息。詳見[自訂訊息](#自訂訊息)段落。

### 通知顯示樣式

前往**系統設定 → 通知 → Claude Code** 選擇：

| 樣式 | 行為 |
|------|------|
| **橫幅**（Banners） | 出現數秒後自動消失 |
| **提示**（Alerts） | 停留直到手動關閉 |

## 疑難排解

| 問題 | 解決方式 |
|------|---------|
| 沒有通知出現 | 執行 `open "$HOME/.claude/hooks/claude-code-notifier/Claude Code.app"` 註冊，再到系統設定 → 通知中啟用 |
| 移動後圖示消失 | 重新註冊：`lsregister -u` → `lsregister` → `killall Dock` → `open`（見上方重新註冊段落） |
| App 出現在啟動台 | 執行 `defaults write com.apple.dock ResetLaunchPad -bool true && killall Dock` |
| `NSUserNotification` 棄用警告 | macOS 11+ 預期行為。macOS 14 Sonoma 仍可正常使用。未來版本可能需遷移至 `UNUserNotificationCenter` |
| `notify.sh: bad interpreter` | 修正換行符號：`perl -pi -e 's/\r\n/\n/g' notify.sh` |
| `notify.conf` 設定被忽略（仍顯示英文） | `notify.conf` 檔案可能使用了 CRLF（`\r\n`）換行。修正：`perl -pi -e 's/\r\n/\n/g' notify.conf` |

## 解除安裝

### 從通知設定中移除

```python
python3 -c "
import plistlib
path = '$HOME/Library/Preferences/com.apple.ncprefs.plist'
with open(path, 'rb') as f:
    data = plistlib.load(f)
data['apps'] = [a for a in data.get('apps', []) if a.get('bundle-id') != 'com.claude-code.notifier']
with open(path, 'wb') as f:
    plistlib.dump(data, f)
print('已從通知設定中移除')
"
killall NotificationCenter 2>/dev/null
killall usernoted 2>/dev/null
```

### 從 Launch Services 取消註冊

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$HOME/.claude/hooks/claude-code-notifier/Claude Code.app"
```

### 刪除所有檔案

```bash
rm -rf "$HOME/.claude/hooks/claude-code-notifier"
```

### 從 settings.json 移除 Hook

從 `~/.claude/settings.json` 中移除 `Notification` 和 `Stop` 項目。

## 備註

- `NSUserNotification` 自 macOS 11 起已被標記為棄用，但在 macOS 14 Sonoma 上仍可正常運作
- `Notification` Hook 僅在終端機**不在前景**時觸發 — 你正在使用 Claude Code 時不會看到通知
- 點擊通知橫幅會自動切回正在執行 Claude Code 的終端機。無論 App 仍在執行中（delegate 回呼）或已結束（macOS 重新喚起 App 處理點擊），皆可正常運作
