# Codex Dev Container Feature

Dev ContainerでCodexを使うための設定を、各リポジトリの`.devcontainer`を変更せずに適用するFeatureです。
信頼できるリポジトリで使用してください。

このFeatureは次の設定を行います。

- `bubblewrap`を導入し、CodexのLinux sandboxに必要な権限を設定する
- codex-homeディレクトリを作成しCODEX_HOMEとして利用する
- 現在のWSLディストリビューションにある `~/.codex/auth.json` をread/writeでbind mountする
- VS Code拡張 `openai.chatgpt` をインストールする
