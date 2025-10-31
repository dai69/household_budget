# Household Budget (MVP)

軽量で素早く立ち上げられる家計簿のMVP（Flutter Web）です。

## 概要
- 目的: 日々の収支を素早く記録・確認できる最小限の家計簿アプリ（MVP）
- 提供ページ:
  - 入力ページ（収支の登録・編集）
  - リストページ（月次表示、フィルタ／ソート、編集・削除）
  - レポートページ（カテゴリ別の円グラフや月次集計）
- 機能ハイライト:
  - Firebase Authentication によるユーザー管理
  - Firestore によるエントリ／カテゴリ永続化
  - カテゴリごとの色を Firestore に保存
  - CSV のインポート（ペースト or ファイル選択）／エクスポート（ダウンロード or クリップボードフォールバック）
  - Material 3 + Riverpod を使ったシンプルな UI

## デプロイ URL
- 現在のデプロイ先 URL: `https://household-budget-b003a.web.app`

## 技術スタック
- フレームワーク: Flutter (Web 対応)
- UI: Material 3
- 状態管理: Riverpod
- バックエンド: Firebase Authentication, Cloud Firestore
- グラフ: fl_chart
- CSV 入出力: アプリ内実装（引用、エスケープ対応）、Web の場合はブラウザのダウンロードAPI/クリップボードへフォールバック

## リポジトリ構成（抜粋）
- `lib/main.dart` — エントリポイント
- `lib/presentation/pages/` — UI ページ群（`list_page_clean.dart`, `report_page.dart`, `categories_page.dart` など）
- `lib/data/` — Firestore リポジトリ実装
- `lib/domain/` — ドメインモデル（Entry, Category のインターフェース）
- `lib/utils/` — プラットフォーム依存のファイル入出力ヘルパー等

## ローカルでの開発（クイックスタート）
以下は Windows + PowerShell 環境を前提にしています。

1. リポジトリをクローン

```powershell
git clone <this-repo-url>
cd household_budget
```

2. Flutter SDK のセットアップ

 - Flutter がインストールされていること（推奨: 最新の安定版）。
 - PATH に flutter が通っていること。

確認:

```powershell
flutter --version
```

3. 依存パッケージを取得

```powershell
flutter pub get
```

4. Firebase 設定

 - `lib/firebase_options.dart` がプロジェクトに含まれていますが、ローカルで独自の Firebase を使う場合は Firebase コンソールで新しいプロジェクトを作り、FlutterFire CLI（または手動）で設定ファイルを生成してください。
 - Web の場合は `web/index.html` や `firebase.json` の設定、`google-services.json` / `GoogleService-Info.plist`（Android/iOS）が必要になります。

5. 開発モードで起動（Web）

```powershell
flutter run -d chrome
```

6. 解析（静的チェック）

```powershell
flutter analyze
```

## デプロイ（Firebase Hosting の例）
1. Firebase CLI にログイン

```powershell
npm install -g firebase-tools
firebase login
```

2. ビルドとデプロイ（Web）

```powershell
flutter build web
firebase deploy --only hosting
```

※ Firebase Hosting のターゲット・設定は `firebase.json` を確認してください。

## 開発上の注意点 / トラブルシューティング
- `list_page_clean.dart` が実装中に幾つかのリファクタが行われています。もしコンパイルエラーが出る場合は、最新の `flutter analyze` の出力を参考に、未定義の変数や build-context まわりの非同期利用を確認してください。
- Web 固有の API（ファイルダウンロードや file input）はブラウザ環境のみで動作します。非Web 環境はクリップボードへのフォールバックを利用します。

## 変更履歴（主要）
- MVP 実装: 入力・リスト・レポート・CSV 入出力・カテゴリ色。
- リファクタ: 編集ダイアログからリポジトリ呼び出しを切り離し、ダイアログ内で BuildContext を跨ぐ非同期処理による警告を解消。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
