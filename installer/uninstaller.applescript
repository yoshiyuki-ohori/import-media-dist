-- 動画取り込みアンインストーラ
-- Double-clickable, no-terminal uninstaller. Self-contained: does NOT rely on the
-- installed repo's scripts, so it works even on old versions of the system.
-- Build with installer/build-installer.sh (uses osacompile).

property appTitle : "動画取り込みアンインストーラ"

on run
	-- Confirm.
	try
		display dialog "このMacから動画自動取り込みシステムを削除します。" & return & return & "・自動取り込みは停止します" & return & "・取り込み済みの動画はそのまま残ります" & return & return & "削除してよろしいですか？" buttons {"キャンセル", "削除する"} default button "削除する" cancel button "キャンセル" with title appTitle with icon caution
	on error number -128
		return
	end try

	-- Remove everything (self-contained, defensive: catches old/renamed variants).
	try
		do shell script my removeCommand()
	on error errMsg number errNum
		display dialog "削除中にエラーが発生しました（コード " & errNum & "）。" & return & return & errMsg buttons {"OK"} default button "OK" with title appTitle with icon stop
		return
	end try

	-- Open Full Disk Access so the user can remove the leftover MediaImport entry
	-- (Apple does not allow this to be removed automatically).
	try
		do shell script "/usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles'"
	end try

	display dialog "アンインストールが完了しました ✅" & return & return & "最後に1つだけ手動操作をお願いします:" & return & return & "いま開いた『フルディスクアクセス』の一覧に『MediaImport』が残っていたら、選んで『−』ボタンで削除してください。" & return & return & "（取り込み済みの動画は保存先フォルダにそのまま残っています）" buttons {"完了"} default button "完了" with title appTitle with icon note
end run

on removeCommand()
	return "set -e
LA=\"$HOME/Library/LaunchAgents\"
UID_NUM=$(/usr/bin/id -u)
# Unload & remove every import-media LaunchAgent (any name variant).
for p in \"$LA\"/com.user.importmedia*.plist \"$LA\"/*importmedia*.plist; do
  [ -e \"$p\" ] || continue
  /bin/launchctl unload \"$p\" 2>/dev/null || true
  /bin/rm -f \"$p\"
done
# Modern bootout fallback for the known labels.
/bin/launchctl bootout gui/$UID_NUM/com.user.importmedia 2>/dev/null || true
/bin/launchctl bootout gui/$UID_NUM/com.user.importmedia.update 2>/dev/null || true
# Remove installed artifacts (harmless if a path is absent). Videos are NOT touched.
/bin/rm -rf \"$HOME/.import-media\"
/bin/rm -rf \"$HOME/.config/import-media\"
/bin/rm -rf \"$HOME/Applications/MediaImport.app\"
/bin/rm -rf \"$HOME/Desktop/取り込み設定.app\"
/bin/rm -f  \"$HOME/Library/Caches/import-media.pid\"
/bin/rm -rf \"$HOME/Library/Caches/import-media-vols\"
/bin/rm -f  \"$HOME/Library/Caches/import-media-volumes-mtime\"
/bin/rm -f  \"$HOME\"/Library/Logs/import-media*.log
echo done"
end removeCommand
