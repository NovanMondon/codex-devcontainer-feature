# Codex Dev Container Feature

Dev ContainerでCodexを使うための設定を、各リポジトリの`.devcontainer`を変更せずに適用するFeatureです。
信頼できるリポジトリで使用してください。

このFeatureは次の設定を行います。

- `bubblewrap`を導入し、CodexのLinux sandboxに必要な権限を設定する
- codex-homeディレクトリを作成しCODEX_HOMEとして利用する
- 現在のWSLディストリビューションにある `~/.codex/auth.json` をread/writeでbind mountする
- VS Code拡張 `openai.chatgpt` をインストールする
- VS Code拡張 `wenbopan.vscode-terminal-osc-notifier`（Terminal Notification）をインストールする

## CLIの完了通知

[Terminal Notification](https://marketplace.visualstudio.com/items?itemName=wenbopan.vscode-terminal-osc-notifier)はホスト側のVS Codeで動作し、コンテナの統合ターミナルから受け取ったOSC 9通知をホストOSに表示します。
Codex CLIの通知設定は、`coding-agents/codex/config.toml`で共有します。

VS Code 1.93以上とShell Integrationの有効化が必要です。OS側でも通知を許可してください。
拡張導入後に新しい統合ターミナルを開き、次のコマンドで通知を確認できます。

```bash
printf '\033]9;Codex notification test\007'
```
