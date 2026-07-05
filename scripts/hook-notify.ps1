<#
Claude Code Windows 通知 hook —— hook-notify plugin 的通知腳本
  Claude 回應完成(Stop)/ 等你輸入(Notification)時:系統音效 + 原生 Windows Toast
  標題含專案名與 session 短碼、內文含完整工作目錄 → 多專案並行也分得清是誰
  零依賴(全 Windows 內建 API)、不寫檔、不連網、不需管理員

本檔由 plugin 的 hooks/hooks.json 透過 ${CLAUDE_PLUGIN_ROOT} 自動呼叫,不需手動安裝。
安裝(見 plugin README):
  /plugin marketplace add harry18456/cc
  /plugin install hook-notify@harry18456

【本機測試】在 cmd 執行下行,應「響鈴 + 跳出通知」:
  echo {"cwd":"C:\\test\\demo","session_id":"demo1234"} | powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>\scripts\hook-notify.ps1" -HookEvent Stop

【注意事項】
 - 本檔必須維持 UTF-8 with BOM 編碼(含中文,否則 PS 5.1 以 cp950 誤讀 → 亂碼且語法錯誤);repo 已用 .gitattributes(*.ps1 -text)保護,clone 不會壞。
   若不慎變成無 BOM,修復:
   $p='<本檔路徑>'; $c=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8); [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding $true))
 - 除錯:設 $env:CC_HOOK_NOTIFY_DEBUG=1 可把內部錯誤寫到 %TEMP%\cc-hook-notify.log;平時全靜默。
 - 從 Teams/網頁下載的檔案可能被標記封鎖:command 已帶 -ExecutionPolicy Bypass 通常可跑;仍失敗時執行 Unblock-File <本檔路徑>。
 - 公司 GPO 若強制鎖定 ExecutionPolicy(MachinePolicy),Bypass 會被覆蓋 → 需洽 IT。
 - 音效缺失會優雅降級:通知照跳、只是無聲。
 - 通知「不可點擊」:點了只會關閉(可點擊跳回為規劃中的 v2)。
 - 通知內文會顯示 session 的完整工作目錄路徑;螢幕分享/錄影時他人看得到,介意者請留意。
#>
param([Parameter(Mandatory)][string]$HookEvent)

# opt-in 診斷:設 $env:CC_HOOK_NOTIFY_DEBUG 時把內部錯誤寫到 %TEMP%\cc-hook-notify.log;平時全靜默
function Write-DebugLog([string]$Message) {
    if ($env:CC_HOOK_NOTIFY_DEBUG) {
        try {
            $log = Join-Path $env:TEMP 'cc-hook-notify.log'
            "$(Get-Date -Format o) [$HookEvent] $Message" | Out-File -FilePath $log -Append -Encoding utf8
        } catch { }
    }
}

# 以 UTF-8 讀取 stdin 的事件 JSON(避免 cp950 中文亂碼);try/finally 確保 reader 釋放
$stdin  = ''
$reader = $null
try {
    $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
    $stdin  = $reader.ReadToEnd()
} catch {
    Write-DebugLog "read stdin failed: $_"
} finally {
    if ($reader) { $reader.Dispose() }
}

# 用 ConvertFrom-Json 穩健解析(空輸入 / 壞 JSON 都不致命,直接沿用預設值)
$cwd = ''; $proj = '?'; $sid = ''; $msg = ''; $ntype = ''
try {
    $evt = $stdin | ConvertFrom-Json
    if ($evt.cwd)               { $cwd = [string]$evt.cwd; $proj = Split-Path -Leaf $cwd }
    if ($evt.session_id)        { $sid = [string]$evt.session_id; if ($sid.Length -gt 8) { $sid = $sid.Substring(0, 8) } }
    if ($evt.message)           { $msg = [string]$evt.message }
    if ($evt.notification_type) { $ntype = [string]$evt.notification_type }
} catch {
    Write-DebugLog "parse json failed: $_"
}

$title = "Claude Code · $proj"
if ($sid) { $title += " ($sid)" }

# 音效目錄用 $env:SystemRoot,不寫死 C:(非 C 槽系統也能響)
$mediaDir = Join-Path $env:SystemRoot 'Media'

function Invoke-Sound([string]$Wav) {
    try {
        $path = Join-Path $mediaDir $Wav
        if (Test-Path -LiteralPath $path) {
            (New-Object Media.SoundPlayer $path).PlaySync()
        }
    } catch { Write-DebugLog "play sound '$Wav' failed: $_" }
}

# 原生 WinRT Toast(零安裝;借用系統已註冊的 PowerShell AppID)
function Show-Toast([string]$Title, [string]$Body, [string]$Detail) {
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.ToastNotification,        Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument,                 Windows.Data.Xml.Dom,     ContentType = WindowsRuntime] | Out-Null
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        $t = [System.Security.SecurityElement]::Escape($Title)
        $b = [System.Security.SecurityElement]::Escape($Body)
        $d = [System.Security.SecurityElement]::Escape($Detail)
        $detailText = if ($Detail) { "    <text>$d</text>" } else { '' }
        $xml = @"
<toast>
  <visual><binding template="ToastGeneric">
    <text>$t</text>
    <text>$b</text>
$detailText
  </binding></visual>
  <audio silent="true"/>
</toast>
"@
        $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $doc.LoadXml($xml)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $doc
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    } catch { Write-DebugLog "show toast failed: $_" }
}

switch ($HookEvent) {
    'Stop' {
        Show-Toast $title '回應完成' $cwd   # 先彈通知
        Invoke-Sound 'chimes.wav'             # 再響(PlaySync 阻塞,但 toast 已彈出)
    }
    'Notification' {
        # 以結構化 notification_type 為主判斷,message 僅作 fallback
        $body = ''
        switch -Regex ($ntype) {
            'idle'         { $body = '閒置等待你的輸入'; break }
            'permission'   { $body = '需要你的授權';    break }
            'needs_input'  { $body = '需要你的輸入';    break }
            'auth_success' { $body = '';                break }   # 登入成功:不驚動,靜音
            default {
                if     ($msg -match 'waiting for your input') { $body = '閒置等待你的輸入' }
                elseif ($msg -match 'permission')             { $body = '需要你的授權' }
                elseif ($msg)                                 { $body = $msg }
                else                                          { $body = '需要你的注意' }
            }
        }
        if ($body) {
            Show-Toast $title $body $cwd
            Invoke-Sound 'chord.wav'
        }
    }
    default {
        # SubagentStop / PreCompact / PostCompact — 靜音不動作
    }
}
