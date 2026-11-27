# Codex Dev Container Feature

Dev ContainerでCodexを使うための設定を、各リポジトリの`.devcontainer`を変更せずに適用するFeatureです。
信頼できるリポジトリで使用してください。

このFeatureは次の設定を行います。

- `bubblewrap`を導入し、CodexのLinux sandboxに必要な権限を設定する
- コンテナの作成・起動・接続時に `coding-agents sync` を呼び、ツール・共通設定・作業リポジトリの設定を自動反映する
- Dev Containerごとの永続ボリュームをCODEX_HOMEとして利用する
- ホストの認証情報はマウントせず、各Dev Container内で個別にログインする
- VS Code拡張 `openai.chatgpt` をインストールする
- VS Code拡張 `wenbopan.vscode-terminal-osc-notifier`（Terminal Notification）をインストールする

## 自動反映と再反映

Feature 1.2.0以降は `postCreateCommand`、`postStartCommand`、`postAttachCommand` から共通の反映処理を呼びます。
ワークスペースを自動で渡すため、作業リポジトリごとの手動初期化は不要です。dotfilesの実行順やBashの起動にも依存しません。
更新内容・失敗時の動作は [coding-agents](https://github.com/NovanMondon/coding-agents#readme) に集約しています。

手動で反映し直す場合は、任意のディレクトリから次を実行します。

```bash
coding-agents sync
```

旧Featureを使う既存コンテナには、更新版を取得して一度再ビルドする必要があります。
その後の共通設定・ツール更新はsyncが取得します。マウント・権限・拡張などFeatureの構成変更は再ビルドで反映します。
Codexが読み込み済みの設定はCodex再起動後に有効になります。

## 認証

各Dev ContainerのCodex拡張からログインしてください。
CLIを利用する場合は、コンテナ内で `codex login` を実行します。
認証情報をホストや別のDev Containerからコピーしないでください。

ファイルに保存した認証情報は、同じ永続ボリュームを使う再構築後も保持されます。
ボリュームを削除した場合は、再度ログインが必要です。

## GitHub MCPのPAT

GitHub MCPの共通設定とPAT登録スクリプトは `coding-agents` で管理します。
発行・登録・確認の手順は [GitHub MCPの設定手順](https://github.com/NovanMondon/coding-agents/blob/main/docs/github-mcp.md) を参照してください。
Codexへのログインとは別に、PATの初回発行・入力が必要です。手動の `coding-agents sync` は未登録なら非表示入力を案内します。
自動実行は入力待ちにせず、登録済みPATを再利用します。更新時は同じ入口の `coding-agents sync --github-pat` を使います。
CLIとVS CodeのCodex拡張は、コンテナ内に登録した同じPATを使って接続します。

PATの保存先は`/var/lib/codex-home/secrets/github-pat`です。
同じ永続ボリュームを使う再構築後も保持されます。ボリュームを削除した場合は再登録が必要です。
このFeatureのビルド時にPATを渡す設定は不要です。

## CLIの完了通知

[Terminal Notification](https://marketplace.visualstudio.com/items?itemName=wenbopan.vscode-terminal-osc-notifier)はホスト側のVS Codeで動作し、コンテナの統合ターミナルから受け取ったOSC 9通知をホストOSに表示します。
Codex CLIの通知設定は、`coding-agents/codex/config.toml`で共有します。

VS Code 1.93以上とShell Integrationの有効化が必要です。OS側でも通知を許可してください。
拡張導入後に新しい統合ターミナルを開き、次のコマンドで通知を確認できます。

```bash
printf '\033]9;Codex notification test\007'
```

## 開発

`AGENTS.md` の完了条件に従い、機能追加は自動反映への接続まで含めます。
`install.sh` はOS依存と固定ランチャーだけを用意し、ツールやCodex設定の本体はcoding-agentsへ集約します。
個人用環境のため、自動テストは致命的な問題の防止に絞ります。それ以外は構文チェックと必要な実操作での確認で済ませ、テスト追加やCIを一律の完了条件にはしません。詳細は `AGENTS.md` を参照してください。
ライフサイクル処理を変更した場合は、必要に応じて実際の起動・接続時の動作を確認します。
