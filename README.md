# Media Auto-Import for Mac

SDカードを差したり AirDrop で動画を受信するだけで、**撮影日 × 機種** で自動振り分けする macOS 用ツール。GoPro / DJI / iPhone / Sony / Canon など主要メーカーを自動判別。

---

## 目次

1. [何ができるツールか](#1-何ができるツールか)
2. [インストール](#2-インストール)
3. [初回セットアップ（重要・5分）](#3-初回セットアップ重要5分)
4. [日常の使い方](#4-日常の使い方)
5. [コマンド一覧](#5-コマンド一覧)
6. [保存先のフォルダ構造](#6-保存先のフォルダ構造)
7. [設定ファイル](#7-設定ファイル)
8. [自動アップデート](#8-自動アップデート)
9. [トラブルシューティング](#9-トラブルシューティング)
10. [アンインストール](#10-アンインストール)

---

## 1. 何ができるツールか

| 入力 | 動作 |
|---|---|
| SDカード接続（GoPro / DJI / Sony / Canon 等） | 確認ダイアログ → 自動で日付別フォルダにコピー |
| 外部SSD / USBドライブ | 同上（動画ファイルがあれば検知） |
| iPhone から AirDrop で動画 | ~/Downloads から自動移動 |
| ギガファイル便でダウンロード | 同上 |

**SDカードのファイルは削除されません**（コピーのみ。安全）。

---

## 2. インストール

### 初回（1回だけ）

ターミナルで:

```bash
git clone https://github.com/yoshiyuki-ohori/import-media-dist.git ~/.import-media
cd ~/.import-media
./install.sh
```

### 既にインストール済みの場合の更新

```bash
~/.import-media/update.sh
```

---

## 3. 初回セットアップ（重要・5分）

`install.sh` 実行中・実行後に以下を行ってください。

### 3-1. 保存先フォルダの選択

インストーラ実行中に Finder のフォルダ選択ダイアログが出ます。動画を保存したい場所を選択。
- Mac の内蔵 SSD（例: `~/Movies`）
- 外付けSSD
- Google Drive 等のクラウド同期フォルダ
- どこでもOK、後から変更可能

### 3-2. フルディスクアクセス権限の付与（**必須**）

これをやらないと**裏で何も動きません**。

1. システム設定 → プライバシーとセキュリティ → **フルディスクアクセス**
2. 左下「+」ボタン → パスワード or Touch ID で認証
3. Finder で `Cmd + Shift + G` → `~/Applications` と入力 → Enter
4. **`MediaImport`** アプリを選択 → 「開く」
5. リストに追加された MediaImport のトグルを **ON**

### 3-3. 通知の確認

- 通知が見えにくければ、システム設定 → 通知 → 「スクリプトエディタ」を許可

---

## 4. 日常の使い方

### 普通に動画を取り込む

1. SDカードをカードリーダーに挿す
2. 数秒後にダイアログ「N件あります。取り込みますか？」が出る
3. **「取り込む」** をクリック
4. 完了通知（Glass音）が鳴って、Finder で保存先が自動表示

### AirDrop で iPhone 動画を受信

iPhoneから AirDrop で送る → ~/Downloads に着弾 → 自動振り分け開始 → ~/Movies/iPhone/ へ

### ギガファイル便などでダウンロードした動画

ブラウザで ~/Downloads にダウンロード → zip 解凍 → 自動振り分け

---

## 5. コマンド一覧

すべて `~/.import-media/` フォルダ内のスクリプト。コピペで実行できます。

| コマンド | やること |
|---|---|
| `~/.import-media/show-destination.sh` | 現在の保存先を表示 + ファイル数集計 + Finder で開く |
| `~/.import-media/show-imports.sh` | 過去の取り込み履歴を確認 (どのSDから何を取り込んだか) |
| `~/.import-media/set-destination.sh` | フォルダ選択ダイアログで保存先を変更 |
| `~/.import-media/import-now.sh` | 接続中メディアから手動で取り込み（無視リストにあっても可） |
| `~/.import-media/ignore-volume.sh` | 接続中メディアを一覧表示 → 選んで無視リストに追加 |
| `~/.import-media/unignore-volume.sh` | 無視リストから削除（再度自動取り込み対象に） |
| `~/.import-media/update.sh` | 最新版にアップデート |
| `~/.import-media/uninstall.sh` | LaunchAgent を削除（取り込んだ動画は残る） |

---

## 6. 保存先のフォルダ構造

```
<保存先>/
├── GoPro/
│   └── 2026/
│       └── 2026-05-31/
│           └── HERO12/
│               └── GX01_xxxx.MP4
├── DJI/
│   └── 2026/
│       └── 2026-05-31/
│           ├── Pocket/
│           │   └── DJI_xxx_D.MP4
│           └── Action5/
│               └── DJI_yyy_S.MP4
├── iPhone/
│   └── 2026/
│       └── 2026-05-31/
│           └── iPhone15Pro/
│               └── IMG_xxxx.MOV
├── Sony/ ...   Canon/ ...   Nikon/ ...
└── Downloads/
    └── 2026/2026-05-31/...   ← 機種判別できないAirDrop等
```

**振り分けロジック:**
1. ファイルの MP4 メタデータ（メーカー名）を読む
2. メタデータが無ければファイル名パターンで判定
3. それでも不明なら取得元名（Downloads / SDカードのボリューム名）を使う

---

## 7. 設定ファイル

### 7-1. 保存先 (`~/.config/import-media/dest-base.txt`)

`set-destination.sh` で書き換え。フォルダパスを1行記載しているだけのテキストファイル。手動編集も可。

### 7-2. 無視リスト (`~/.config/import-media/ignore-volumes.txt`)

無視したい外部メディア名を1行ずつ記載。**`ignore-volume.sh` で GUI 操作で追加できる**ので手動編集は不要（GUI推奨）。

例:
```
BackupSSD
WorkSSD
Time Machine Backups
# コメント行
```

無視対象でも `import-now.sh` で手動取り込みは可能。

### 7-3. 詳細設定 (`~/.config/import-media/config.sh`)

高度な設定。例えば正規表現で複雑な条件にしたい場合は `should_ignore_volume` 関数を上書き:

```bash
should_ignore_volume() {
  case "$1" in
    *Backup*|*Archive*) return 0 ;;   # "Backup" or "Archive" を含むもの全部
    *) return 1 ;;
  esac
}
```

定義すると ignore-volumes.txt より優先されます。

### 7-3. スクリプト本体の設定（先頭付近）

```bash
DELETE_FROM_CARD="false"   # "true"にするとコピー成功後にSDカード側を削除
VERIFY_MODE="size"          # コピー検証: "size"(速い) / "hash"(完全だが遅い) / "none"
```

これらは git pull で上書きされるので、長期的な変更は config.sh の `DEST_BASE_OVERRIDE` などで。

---

## 8. 自動アップデート

- **毎日 04:00** に自動でリポジトリから最新版を取得（`git pull`）
- 更新があると通知「取り込みシステムを更新しました」
- 個人設定（`~/.config/import-media/*`）は**上書きされない**

すぐ最新化したい時:
```bash
~/.import-media/update.sh
```

現在のバージョン確認:
```bash
cd ~/.import-media && git log --oneline | head -3
```

---

## 9. トラブルシューティング

### SDカード差しても何も起きない

1. システム設定 → プライバシーとセキュリティ → フルディスクアクセス で `MediaImport` がONになっているか確認
2. `launchctl list | grep importmedia` で常駐確認
3. `tail -20 ~/Library/Logs/import-media.log` でエラー確認

### 同じカードでダイアログが何度も出る

最新版（commit `c3ad0f7` 以降）で対策済み。 `~/.import-media/update.sh` を実行。

### 外部SSDが毎回反応してしまう

`should_ignore_volume` に SSD 名を追加（[7-2](#7-2-詳細設定-configimport-mediaconfigsh)参照）。

### 1970-01-01 のフォルダにファイルが入った

SD カードのファイル mtime が壊れているケース。最新版はファイル名から日付抽出するフォールバックを持ってます。
更新後、誤って入ったファイルは手動で正しい日付フォルダへ移動してください。

### 通知が出ない

システム設定 → 通知 → 「スクリプトエディタ」を確認。「持続的（アラート）」スタイルにすると見逃しにくくなります。

### ログの場所

```
~/Library/Logs/import-media.log       ← 取り込み履歴
~/Library/Logs/import-media.err.log   ← エラー出力
~/Library/Logs/import-media-update.log ← 自動更新の履歴
```

---

## 10. アンインストール

```bash
~/.import-media/uninstall.sh
```

LaunchAgent のみ削除。保存済み動画と Git リポジトリは残します。完全に削除したい場合は手動で:

```bash
rm -rf ~/.import-media
rm -rf ~/.config/import-media
rm -rf ~/Applications/MediaImport.app
```

---

## ファイル構成

```
~/.import-media/                          ← Git リポジトリ（自動更新）
├── README.md                              ← このファイル
├── install.sh                              ← 初回セットアップ
├── update.sh                               ← 自動更新（毎日4時に実行）
├── uninstall.sh                            ← 削除
├── import-media.sh                         ← 本体スクリプト
├── set-destination.sh                      ← 保存先変更（GUI）
├── import-now.sh                           ← 手動取り込み
└── show-destination.sh                     ← 保存先確認 + Finder で開く

~/.config/import-media/                    ← 個人設定（git pull で上書きされない）
├── dest-base.txt                           ← 保存先パス
└── config.sh                                ← 詳細設定

~/Applications/MediaImport.app             ← FDA 用ラッパー（install.sh が自動生成）

~/Library/LaunchAgents/
├── com.user.importmedia.plist              ← 取り込みエージェント
└── com.user.importmedia.update.plist       ← 自動更新エージェント

~/Library/Logs/
├── import-media.log                        ← 取り込み履歴
├── import-media.err.log                    ← エラー
└── import-media-update.log                 ← 更新履歴
```
