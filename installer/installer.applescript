-- 動画取り込みインストーラ
-- Double-clickable, no-terminal installer for the media auto-import system.
-- Build with installer/build-installer.sh (uses osacompile).

property appTitle : "動画取り込みインストーラ"
property repoURL : "https://github.com/yoshiyuki-ohori/import-media-dist.git"

on run
	-- 1. Confirm.
	try
		display dialog "動画自動取り込みシステムをこのMacにインストールします。" & return & return & "SDカードを差すだけで、撮影日ごとに自動でクラウドへ取り込まれるようになります。" buttons {"キャンセル", "インストール"} default button "インストール" cancel button "キャンセル" with title appTitle with icon note
	on error number -128
		return
	end try

	-- 2. Make sure git (Command Line Tools) is available.
	set gitReady to false
	try
		do shell script "/usr/bin/git --version >/dev/null 2>&1"
		set gitReady to true
	end try
	if gitReady is false then
		try
			do shell script "/usr/bin/xcode-select --install"
		end try
		display dialog "このMacには開発ツール（git）が入っていません。" & return & return & "いま表示された画面で『インストール』を押してください。完了したら、もう一度このアプリを開いてください（数分かかります）。" buttons {"OK"} default button "OK" with title appTitle with icon caution
		return
	end if

	-- 3. Clone or update the repo, then run the per-user installer.
	--    install.sh pops a folder picker on first run (choose where videos go),
	--    generates the LaunchAgents + MediaImport.app, and loads the agents.
	try
		do shell script my installCommand()
	on error errMsg number errNum
		display dialog "インストール中にエラーが発生しました（コード " & errNum & "）。" & return & return & errMsg & return & return & "ネットワーク接続を確認して、もう一度お試しください。" buttons {"OK"} default button "OK" with title appTitle with icon stop
		return
	end try

	-- 4. Open the Full Disk Access pane and the Applications folder so the user
	--    can drag MediaImport in. (This grant cannot be automated by Apple design.)
	try
		do shell script "/usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles'; /usr/bin/open " & quoted form of (POSIX path of (path to home folder) & "Applications")
	end try

	-- 5. Final manual step instructions.
	display dialog "インストールが完了しました ✅" & return & return & "最後に1ステップだけ手動操作が必要です（これをしないと取り込みが動きません）:" & return & return & "1. いま開いた『フルディスクアクセス』の画面へ" & return & "2. ＋ボタンを押し、別ウィンドウの『MediaImport』を選んで追加" & return & "3. MediaImport のスイッチを ON にする" & return & return & "その後、SDカードを差すと自動で取り込みが始まります。" buttons {"完了"} default button "完了" with title appTitle with icon note
end run

-- Idempotent install command: fresh clone, or hard-sync an existing checkout,
-- then run the per-user installer.
on installCommand()
	return "set -e
DIR=\"$HOME/.import-media\"
if [ -d \"$DIR/.git\" ]; then
  /usr/bin/git -C \"$DIR\" fetch --quiet origin
  /usr/bin/git -C \"$DIR\" reset --hard --quiet origin/main
else
  /bin/rm -rf \"$DIR\"
  /usr/bin/git clone --quiet " & repoURL & " \"$DIR\"
fi
/bin/chmod +x \"$DIR\"/*.sh
/bin/bash \"$DIR/install.sh\""
end installCommand
