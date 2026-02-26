# Clipnyx - Claude Code ガイド

## プロジェクト概要
macOS メニューバー常駐のクリップボード履歴マネージャー。SwiftUI + Swift 6、macOS 15.0+対象。

## ビルド
```
cd Clipnyx
xcodebuild build -scheme Clipnyx -configuration Debug -destination 'platform=macOS' -quiet
```

## プロジェクト構造
```
Clipnyx/Clipnyx/
├── ClipnyxApp.swift              # アプリエントリポイント
├── Managers/
│   ├── ClipboardManager.swift    # クリップボード監視・履歴管理
│   ├── HotKeyManager.swift       # グローバルホットキー（Carbon API）
│   └── PopupPanelController.swift # ホットキーパネル表示制御
├── Models/
│   ├── ClipboardItem.swift       # 履歴アイテムモデル
│   ├── ClipboardContentCategory.swift # 11カテゴリ分類
│   └── PasteboardRepresentation.swift # ペーストボードデータ表現
├── Views/
│   ├── MenuBarView.swift         # メニューバーポップアップUI
│   ├── PopupContentView.swift    # ホットキーパネルUI
│   ├── SettingsView.swift        # 設定画面
│   └── ItemDetailView.swift      # アイテム詳細ポップオーバー
└── Extensions/
    ├── CollectionExtension.swift  # safe subscript
    └── ColorExtension.swift       # Color ユーティリティ
```

## アーキテクチャ
- **@Observable** パターン（Observation framework）を使用
- ClipboardManager が中心。0.5秒間隔で NSPasteboard をポーリング
- ホットキーは Carbon `RegisterEventHotKey` で登録（イベント消費のため）
- ペースト: Accessibility API で直接テキスト挿入 → 失敗時は CGEvent ⌘V フォールバック
- 履歴は JSON で `~/Library/Application Support/Clipnyx/` に永続化

## CI/CD
- **Xcode Cloud**: タグ `v*` プッシュ → Archive → TestFlight アップロード
- **ci_scripts/ci_post_clone.sh**: タグからバージョン抽出して pbxproj を更新
- **Fastlane**: `fastlane metadata` でApp Storeメタデータ・スクリーンショットをアップロード
- **GitHub Pages**: `docs/` 配下を自動デプロイ（プライバシーポリシー）

## コミット規約
- コミットメッセージは日本語
- Co-Authored-By は付けない
