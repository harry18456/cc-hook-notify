# hook-notify

Claude Code 回應完成、或等待你輸入時,跳出 **Windows 原生 Toast 通知 + 系統音效**。
多專案並行時,通知標題會帶專案名與 session 短碼、內文顯示完整工作目錄,一眼分辨是哪個視窗在叫你。

- 零依賴:全走 Windows 內建 API(WinRT Toast + SoundPlayer)
- 不寫檔、不連網、不需管理員
- 掛在兩個事件:`Stop`(回應完成)與 `Notification`(等待輸入 / 需要授權)

> ⚠️ **僅支援 Windows**。Mac / Linux 安裝後 hook 會嘗試呼叫 `powershell` 而失敗。

## 安裝

```
/plugin marketplace add harry18456/cc
/plugin install hook-notify@harry18456
```

重開 Claude Code 生效。

### ⚠️ 裝之前:先移除舊的手動 hooks

如果你先前是用手動改 `settings.json` 的方式裝這個通知腳本,請先把那段 `Stop` / `Notification` hooks 移除,否則同一事件會**響兩次**。

## 測試

裝好後在 cmd 執行(應「響鈴 + 跳通知」):

```
echo {"cwd":"C:\\test\\demo","session_id":"demo1234"} | powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/hook-notify.ps1" -HookEvent Stop
```

## 注意事項

- **編碼**:`scripts/hook-notify.ps1` 必須維持 UTF-8 with BOM(內含中文)。本 repo 已用 `.gitattributes`(`*.ps1 -text`)保護,clone 下來不會壞。
- **檔案被封鎖**:從 Teams / 網頁下載的腳本可能被標記封鎖;command 已帶 `-ExecutionPolicy Bypass` 通常可跑,仍失敗時執行 `Unblock-File <路徑>`。
- **公司 GPO**:若 MachinePolicy 強制鎖定 ExecutionPolicy,Bypass 會被覆蓋,需洽 IT。
- **音效缺失**會優雅降級:通知照跳、只是無聲。
- **通知不可點擊**:點了只會關閉(可點擊跳回是規劃中的 v2)。
- **隱私**:通知內文會顯示完整工作目錄路徑;螢幕分享 / 錄影時他人看得到。

## 這個 plugin 還能加哪些組件

目前 hook-notify 只用了 **hooks**。plugin 這個容器還能包以下組件——本 repo 已建好對應的**空目錄骨架**,日後擴充直接往裡放檔案即可(多數組件 Claude Code 會**自動發現**,不必在 plugin.json 宣告):

| 組件 | 位置 | 放什麼 |
|------|------|--------|
| **Slash commands** | `commands/` | `*.md`,每個成為 `/hook-notify:<name>` 指令 |
| **Subagents** | `agents/` | `*.md`(帶 frontmatter 的子代理定義) |
| **Skills** | `skills/<name>/` | `SKILL.md` + 資源(漸進式揭露能力包) |
| **Output styles** | `output-styles/` | `*.md`,改 Claude 的輸出風格 |
| **Executables** | `bin/` | 可執行檔,plugin 啟用時加入 Bash 的 `$PATH` |
| **Hooks** | `hooks/hooks.json` | 事件掛鉤(← 目前用這個) |
| **MCP servers** | `.mcp.json` | 綁外部工具 / 資料源 |
| **LSP servers** | `.lsp.json` | 語言伺服器(補全 / 診斷) |
| **Themes**(實驗) | `themes/` | `*.json` 配色,出現在 `/theme`;需 plugin.json `experimental.themes` |
| **Monitors**(實驗) | `monitors/monitors.json` | 背景監控;需 plugin.json `experimental.monitors` |

> ⚠️ `commands/`、`agents/`、`skills/`、`output-styles/`、`bin/` 這幾個目錄**自動發現**,不用在 plugin.json 宣告。
> 特別注意:**別**在 plugin.json 的 `hooks` 欄位再指標準的 `hooks/hooks.json`(會自動載入,重複宣告會 `duplicate load failed`)——只有「額外路徑」的 hook 檔才需要宣告。
