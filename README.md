# Media Auto-Import for Mac

GoPro / DJI Osmo / iPhone（AirDrop）/ ギガファイル便などの動画を、SDカードや Downloads を監視して **撮影日 × 機種** で自動振り分けする macOS 用ツール。

## 保存先のフォルダ構造

```
~/Movies/
  GoPro/
    2026/
      2026-05-29/
        HERO12/...
  DJI/
    2026/
      2026-05-29/
        Pocket4/
          DJI_20260529_0001_D.MP4
        Action5/
          DJI_20260529_0002_S.MP4
  iPhone/
    2026/
      2026-05-29/
        iPhone15ProMax/...
  Other/
    2026/
      2026-05-29/...   (機種判別できなかった動画)
```

## インストール（各 Mac で1回だけ）

```bash
git clone <このリポジトリのURL> ~/.import-media
cd ~/.import-media
./install.sh
```

インストーラが以下を自動でやります:

- `~/Library/LaunchAgents/` に取り込み用 + 自動更新用の LaunchAgent を生成（**パスは $HOME ベース、ハードコードなし**）
- `launchctl load` で常駐開始
- 必要なディレクトリ作成

インストール後に **1つだけ手動でやること**:

### macOS のフルディスクアクセスを `/bin/bash` に付与

1. システム設定 → プライバシーとセキュリティ → **フルディスクアクセス**
2. `+` ボタン → `Cmd + Shift + G` → `/bin` と入力 → `bash` を選択 → 「開く」
3. 追加された `bash` のトグルを **ON**

これをやらないと launchd が外部ボリュームや Downloads にアクセスできず、無音で何も起きません。

## 使い方

- **GoPro / DJI / Osmo の SDカード** をカードリーダーで接続 → 自動取り込み
- **iPhone の動画** を AirDrop で Mac に送る → 自動振り分け
- **ギガファイル便などのダウンロード動画** → ダウンロード完了したら自動振り分け

### 通知

- 開始 / 完了で macOS 通知センターにメッセージ
- 完了時に Finder で保存先フォルダが自動で開く
- 完了音（Glass）が鳴る

### 動作確認

```bash
tail -f ~/Library/Logs/import-media.log
```

## 自動アップデート

毎日 **04:00 に `git pull`** して、リポジトリに更新があれば自動でインストールし直します。最新化されたら通知が出ます。

手動で更新したいとき:
```bash
~/.import-media/update.sh
```

## 設定ファイル

スクリプト先頭の以下を編集すれば挙動を変えられます:

```bash
DELETE_FROM_CARD="true"   # SDカード側を取り込み後に削除するか
VERIFY_MODE="size"        # 削除前の検証: size / hash / none
```

機種別のフォルダ名を変えたいときは `device_folder_name()` のマッピングテーブルを編集。

## アンインストール

```bash
~/.import-media/uninstall.sh
```

LaunchAgent だけ削除します。`~/Movies/` のファイルとリポジトリは残ります。

## トラブルシューティング

### 自動取り込みが走らない

- 「フルディスクアクセス」に `/bin/bash` が追加されているか確認
- `launchctl list | grep importmedia` で常駐確認
- `~/Library/Logs/import-media.err.log` でエラー確認

### 「○月○日のフォルダに 1970-01-01 のファイルが入った」

- 古い SDカードのファイル mtime が壊れているケース → スクリプトはファイル名から日付抽出するフォールバックを持っているので、最新版を使ってください

### 通知が出ない

- システム設定 → 通知 → 「スクリプトエディタ」 → 通知を許可 + 「アラート」スタイルに

## ファイル構成

```
.import-media/
├── README.md
├── install.sh            ← 初回セットアップ
├── update.sh             ← 自動更新（毎日4時に実行される）
├── uninstall.sh          ← 削除
├── import-media.sh       ← 本体スクリプト
└── .gitignore
```
