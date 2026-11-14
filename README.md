# claude-code-hardening

Claude Code を安全に使うための設定ファイルをまとめたリポジトリです。個人の Mac でも会社の Mac でも使えます。

| ファイル | 配置先 | 役割 |
| --- | --- | --- |
| [`managed/managed-settings.json`](managed/managed-settings.json) | `/Library/Application Support/ClaudeCode/managed-settings.json` | **絶対に緩めてはいけない制限だけ**を置く。どの階層からも上書きできない |
| [`user/settings.json`](user/settings.json) | `~/.claude/settings.json` | 好みと利便性のための設定。必要なら緩めてよいもの |
| [`user/statusline.sh`](user/statusline.sh) | `~/.claude/statusline.sh` | ステータスラインを表示するスクリプト |

**運用方針:** 設定はこの 2 ファイルだけで管理し、**プロジェクトごとの設定(`<repo>/.claude/settings*.json`)は使いません**(理由は後述)。

> 設定ファイルは `.claude/` ではなく `managed/` と `user/` に置いています。
> リポジトリ直下の `.claude/settings.json` に置くと、このリポジトリを開いたときに
> 「プロジェクト設定」として読み込まれてしまうためです。

---

## 設定ファイルの適用範囲

Claude Code は次の 5 つの階層から設定を読み込み、合成します。**上にあるものほど優先されます。**

| 優先度 | 階層 | 場所 | 適用範囲 | この構成での扱い |
| --- | --- | --- | --- | --- |
| 1 (最優先) | **Managed** | `/Library/Application Support/ClaudeCode/managed-settings.json`(会社の場合は MDM やサーバーから配信されることもある) | この Mac の全ユーザー・全プロジェクト | **使う** |
| 2 | コマンドライン引数 | `claude --model ...` など | その起動 1 回だけ | 必要なときだけ |
| 3 | ローカルプロジェクト | `<repo>/.claude/settings.local.json` | そのリポジトリだけ、自分だけ | 使わない |
| 4 | プロジェクト | `<repo>/.claude/settings.json` | そのリポジトリを使う全員(Git で共有) | 使わない。**ただし他人のリポジトリには入っていることがある** |
| 5 (最下位) | **User** | `~/.claude/settings.json` | 自分の全プロジェクト | **使う** |

### 合成ルール

- **単一の値**(`sandbox.enabled`、`model` など)は、優先度の高い階層の値で上書きされます。
- **配列**(`permissions.deny`、`allowedDomains` など)は、全階層の内容が足し合わされます。
- 権限ルールの評価順は **deny → ask → allow** です。どこかの階層に deny があれば、別の階層の allow では解除できません。

### Managed と User の分け方

User 設定は優先度が最も低い階層です。そのため、clone したリポジトリの `.claude/settings.json`
(作者を信頼できるとは限らない)で、単一の値はすべて上書きされ得ます。そこで次の基準で分けています。

| 置き場所 | 基準 | 例 |
| --- | --- | --- |
| **Managed** | 緩めると防御が崩れる**制限**。プロジェクトから上書きされては困るもの | サンドボックス有効化、サンドボックス外での実行の禁止、秘密情報の読み取り deny、`.git/hooks` への書き込み禁止、権限確認を全部飛ばすモードの無効化 |
| **User** | 好みや利便性の設定。**緩める方向の設定**もここに置く | モデル、テーマ、プラグイン、ask ルール、`allowLocalBinding`、`allowRead`/`allowWrite` の追加 |

**同じ設定キーを Managed と User の両方に書くことはしません。** Managed には「許可を広げる」設定(`allow*`、`autoAllow*`)を一切入れていません。

> ask ルールを User に置いているのは、評価順が deny → ask → allow なので、プロジェクト側の allow では ask を解除できないからです。

---

## プロジェクトごとの設定を使わない理由

- `.claude/settings.local.json` には、確認画面で「今後は確認しない」を選ぶと、その許可ルールが自動で書き込まれます。
  コマンドに API キーなどが含まれていると、**秘密情報がそのままファイルに残ります**。gitignore し忘れたり、
  リポジトリごと共有したりすると漏れます。
- プロジェクトごとに設定が散らばると、どこで何を許可したのかを把握できなくなります。

### 運用上のルール

- 確認画面では**「今回だけ許可」を選び、「今後は確認しない」は選ばない**(`settings.local.json` が作られるのを防ぐ)。
- 自分のリポジトリに `.claude/settings.local.json` ができていたら、中身を確認して削除する。
  `.gitignore` に `.claude/settings.local.json` を入れておく。
- **他人のリポジトリ**を clone したら、Claude Code を起動する前に `.claude/settings.json` を確認する。
  特に `hooks`、`statusLine`、`mcpServers`、`enabledPlugins`、`extraKnownMarketplaces`、`env`、
  `permissions.allow`、`sandbox.network.allowedDomains` はサンドボックスの外で何かを動かしたり、許可を広げたりできます。
  このリポジトリの設定では、これらを完全には防げません。

---

## 通信の許可

Managed、User のどちらにも `allowedDomains`(通信許可リスト)は**書きません**。

- 上位の階層で許可すると、全プロジェクトに効いてしまう。ドメインの運営者が変わったり乗っ取られたりした場合、
  すべてのプロジェクトがそのドメインへの持ち出し経路を持つことになる。
- プロジェクトごとの設定も使わないので、通信は**毎回その場で確認**する方式にしています。

### 許可リストにないドメインは「その都度確認」

`strictAllowlist` は設定していません。そのため、許可リストにないドメインへの通信は**その都度、許可するか尋ねられます**。

| 設定 | 許可リストにないドメインへの通信 |
| --- | --- |
| `strictAllowlist` なし(この構成) | その都度、許可するか尋ねられる |
| `strictAllowlist: true` | 確認なしで拒否される(`403 host is not on the allow list`) |

確認画面では次の点に気を付けてください。

- **ホスト名をよく見る。** `registry.npmjs.org` に似せた別ドメインや、作業内容と関係のないドメインは拒否する。
- 上の運用ルールの通り、「今回だけ許可」を選ぶ。
- `claude -p` などの対話しないモードでは確認ができないため、通信は失敗します。

> 確認なしで拒否する方式に変えたい場合は、Managed の `sandbox.network` に `"strictAllowlist": true` を追加します
> (制限なので Managed に置いてよい設定です)。

### 確認画面で判断するときの目安

| 用途 | ドメイン |
| --- | --- |
| npm | `registry.npmjs.org` |
| Cargo | `index.crates.io`、`static.crates.io`、`crates.io` |
| GitHub から clone・取得 | `github.com`、`codeload.github.com`、`objects.githubusercontent.com`、`release-assets.githubusercontent.com` |
| GitHub API | `api.github.com`(トークンがあれば、Gist や Issue 経由の持ち出し経路になり得る) |
| 脆弱性情報の調査 | `services.nvd.nist.gov`、`cveawg.mitre.org`、`api.osv.dev`、`api.first.org`、`www.cisa.gov`、`access.redhat.com` |

---

## Managed 設定

`managed/managed-settings.json`

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "enableAllProjectMcpServers": false,
  "disableClaudeAiConnectors": true,
  "strictKnownMarketplaces": [],
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "disableAutoMode": "disable",
    "blockReadsOutsideWorkingDirectories": true,
    "blockWritesOutsideWorkingDirectories": true,
    "deny": [
      "Bash(git push)",
      "Bash(git push *)",
      "Bash(gh *)",
      "Bash(wrangler *)",
      "Bash(npx wrangler *)",
      "Bash(security *)",
      "Bash(op *)",
      "Bash(ssh *)",
      "Bash(scp *)",
      "Edit(**/.git/hooks/**)",
      "Edit(**/.git/config)",
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/.envrc)",
      "Read(**/.dev.vars)",
      "Read(**/secrets/**)",
      "Read(**/*.pem)",
      "Read(**/*.key)",
      "Read(**/*.p12)",
      "Read(**/*.pfx)",
      "Read(**/*.keystore)",
      "Read(**/*.jks)",
      "Read(**/*.tfvars)",
      "Read(**/credentials*)",
      "Read(**/*service-account*.json)",
      "Read(**/mise.local.toml)",
      "Read(**/.mise.local.toml)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)",
      "Read(~/.netrc)",
      "Read(~/.npmrc)",
      "Read(~/Library/Preferences/.wrangler/**)",
      "Read(~/Library/Keychains/**)"
    ]
  },
  "sandbox": {
    "enabled": true,
    "allowUnsandboxedCommands": false,
    "filesystem": {
      "denyRead": [
        "~/.ssh",
        "~/.aws",
        "~/Library/Keychains",
        "~/Library/Preferences/.wrangler",
        "~/Library/Group Containers/2BUA8C4S2C.com.1password"
      ],
      "denyWrite": [
        "**/.git/hooks",
        "**/.git/config",
        "**/.github",
        "**/.vscode",
        "**/.envrc"
      ]
    }
  }
}
```

| 設定 | 目的 |
| --- | --- |
| `sandbox.enabled` と `allowUnsandboxedCommands: false` | プロジェクト側からサンドボックスを外せないようにする |
| `disableBypassPermissionsMode` と `disableAutoMode` | 権限確認を飛ばすモードを使えなくする |
| `blockReads/WritesOutsideWorkingDirectories` | 作業ディレクトリ外への読み書きを禁止する |
| `enableAllProjectMcpServers: false` | リポジトリの `.mcp.json` に書かれた MCP サーバー(サンドボックス外で動く)を自動では有効にしない |
| `disableClaudeAiConnectors` | claude.ai のコネクタ経由で外部サービスにつながらないようにする |
| `strictKnownMarketplaces: []` | プラグインの入手元(マーケットプレイス)を**すべて**禁止する。公式マーケットプレイスも含む。clone したリポジトリの `.claude/settings.json` からプラグインを入れられる経路(サンドボックスの外で動く hooks や MCP サーバーを持ち込める)を塞ぐ |
| `deny` の `Read(...)` と `filesystem.denyRead` | 秘密情報の読み取りを禁止する |
| `deny` の `Edit(.git/hooks、.git/config)` と `filesystem.denyWrite` | 後で**サンドボックスの外**で実行されるファイル(git hooks、VS Code のタスク、direnv など)を仕込まれるのを防ぐ |
| `deny` の `Bash(...)` | push や認証情報を扱う CLI の実行を禁止する |

### プラグインの禁止(strictKnownMarketplaces)について

`[]`(空の許可リスト)にすると、どのマーケットプレイスからもプラグインを追加・インストール・更新できなくなります。
インストール済みのプラグインも、セッション開始時に読み込まれなくなります。
`.claude/skills/` にある、プラグインの形式(`.claude-plugin/plugin.json` を持つ)のスキルも読み込まれません。
通常のスキル(`SKILL.md` だけのもの)には影響しません。

これだけでは塞げない経路もあります(今回は入れていません)。

| 経路 | 塞ぐ設定(Managed) |
| --- | --- |
| `claude --plugin-dir` や `--plugin-url` で、その場でプラグインを読み込む | `disableSideloadFlags: true` |
| claude.ai のアカウントで有効にしたプラグインが同期される | `syncClaudeAiPlugins: false` |

後で公式マーケットプレイスを許可し直しても、**自動では再登録されません**(禁止されていた記録が残るため)。
使いたくなったら、`/plugin marketplace add` で手動で追加してください。

### auto mode を無効にしている理由

auto mode は、操作のたびにユーザーに尋ねる代わりに、別の AI(判定モデル)が操作を見て、安全そうなら自動で許可する権限モードです。

| 良い点 | 悪い点 |
| --- | --- |
| 確認がほとんど出なくなる。確認疲れでよく見ずに許可してしまう問題を減らせる | 判定モデルが間違える可能性がある。読み込んだファイルや Web ページに仕込まれた指示に誘導される危険も残る。何が許可されたかを自分の目で見ない |

auto mode では**通信先ドメインの許可も判定モデルが行う**ため、この構成の「通信は毎回自分で確認する」方針と両立しません。そのため無効にしています。

> 確認が多すぎて、**よく見ずに許可を押す癖がついてきたら**見直してください。形だけの確認は、判定モデルの確認より弱くなります。

### 注意点

- `**/.git/config` と `**/.git/hooks` への書き込みを禁止しているため、**Claude のセッション内では `git init` や `git remote add` が失敗します**。これらはターミナルで自分で実行してください(プロンプトで `! git init` と入力しても実行できます)。`git add` や `git commit` は動きます。
- `.github` と `.vscode` は Bash からは書き込めませんが、Edit ツールからは確認付きで書き込めます(User 設定の ask ルール)。
- Bash の deny は前方一致の判定なので、`git -C . push` や `sh -c '...'` のような書き方で抜けられる可能性があります。本当の境界はサンドボックス(ファイルとネットワークの制限)だと考えてください。
- `git push` と `gh` の禁止を外したい環境では、このファイルから deny を削ってから配置してください。Managed に入れた deny は、どの階層からも解除できません。

---

## User 設定

`user/settings.json`

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "model": "opus",
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  },
  "tui": "fullscreen",
  "theme": "dark",
  "env": {
    "NPM_CONFIG_IGNORE_SCRIPTS": "true"
  },
  "permissions": {
    "defaultMode": "default",
    "ask": [
      "Edit(**/.github/**)",
      "Edit(**/.vscode/**)",
      "Edit(**/.envrc)",
      "Bash(curl *)",
      "Bash(npm install *)",
      "Bash(npm i *)",
      "Bash(npm ci *)",
      "Bash(npx *)",
      "Bash(pnpm *)",
      "Bash(yarn *)",
      "Bash(bun *)",
      "WebFetch"
    ]
  },
  "sandbox": {
    "autoAllowBashIfSandboxed": true,
    "network": {
      "allowLocalBinding": true
    },
    "filesystem": {
      "allowRead": [
        "~/.local/share/mise"
      ],
      "allowWrite": [
        "~/.npm"
      ]
    }
  }
}
```

| 設定 | 内容と、User に置く理由 |
| --- | --- |
| `statusLine` | 画面下部の表示(`statusline.sh`)。Claude の動作には影響しない |
| `env.NPM_CONFIG_IGNORE_SCRIPTS` | npm の install スクリプトを止める(下記)。必要なパッケージもあるので、Managed には置かず外せるようにしておく |
| `permissions.ask` | プロジェクト側の allow では解除できないので、Managed に置く必要がない |
| `autoAllowBashIfSandboxed`、`allowLocalBinding`、`allowRead`、`allowWrite` | 許可を広げる設定なので Managed には置かない |

### NPM_CONFIG_IGNORE_SCRIPTS を設定している理由

Claude が実行する npm で、`preinstall` や `postinstall` などのスクリプトを実行しないようにします。

- install スクリプトは、npm のサプライチェーン攻撃で最もよく使われる入口です。
- サンドボックスがあるので秘密情報の読み取りや外部送信は防げますが、**プロジェクト内のファイルは書き換えられます**。
  不正なコードをソースに紛れ込ませられると、後で自分がサンドボックスの外でアプリを動かしたときに実行されます。
- 欠点: esbuild、sharp、playwright、husky など、install スクリプトが必要なパッケージは正しく入りません。
  その場合は、内容を確認した上で自分のターミナルから `npm rebuild <パッケージ名>` などを実行してください。

### プラグインを使わない理由

プラグインは使いません。`enabledPlugins` も設定せず、Managed の `strictKnownMarketplaces: []` でインストール自体を禁止しています。
すでにプラグインを入れている場合は、`/plugin` からアンインストールしてください。

代表的な例として、LSP プラグイン(`swift-lsp`、`rust-analyzer-lsp`、`clangd-lsp` など)の危険性を説明します。

LSP プラグインを有効にすると、Claude が定義へのジャンプ、参照の検索、コンパイルエラーの取得といった機能を使えるようになります。
ただし、LSP は**サンドボックスの外**で動きます。

- `rust-analyzer` は `build.rs` と proc-macro を実行する
- `sourcekit-lsp` は SwiftPM のプラグインを実行し得る

そのため、他人のリポジトリを開いただけでサンドボックスの外でコードが動く可能性があります。
プロジェクトごとに有効にする運用はしないので、使わないことにしました。なくても Claude は grep やファイルの読み込みでコードを追えます。

`enabledPlugins` は「プラグイン名 → true/false」の一覧で、`"enabledPlugins": false` のような一括の無効化はできません。
プラグインを入れないこと自体で管理します。

### ステータスライン(statusline.sh)

表示例:

```
[/Users/you/projects/app] Opus 5.5
ctx 95k/200k (47%) | セッション 23% (16:00) | 今週 41% (11/20 金 09:53)
```

| 表示 | 意味 | 元のデータ |
| --- | --- | --- |
| `[...]` | 作業ディレクトリ | `workspace.current_dir` |
| `ctx 95k/200k (47%)` | 今のコンテキスト使用量 / このモデルで使える上限。文字色が精度の目安(下記) | `context_window.total_input_tokens`、`context_window_size`、`used_percentage` |
| `セッション 23% (16:00)` | セッション(現在は 5 時間の枠)の利用上限に対する使用率と、リセット時刻 | `rate_limits.five_hour` |
| `今週 41% (11/20 金 09:53)` | 7 日間の利用上限に対する使用率と、リセット日時(曜日つき) | `rate_limits.seven_day` |

色の意味:

- コンテキスト(精度の目安): 上限の 40% 未満は緑(精度は十分)、80% 未満は黄(精度が落ち始める)、それ以上は赤(精度が下がっている)
- セッションと今週の使用率: 50% 未満は緑、80% 未満は黄、それ以上は赤

注意点:

- **黄になる 40% の境目は公式の値ではありません。** コンテキストが長くなるほど回答の質が落ちやすいことを踏まえた目安です。
  `statusline.sh` の `SMART_RATIO` で変えられます。黄になったら `/compact` や `/clear` を検討してください。
- **セッションと今週の使用率**は claude.ai のサブスクリプション(Pro/Max など)のときだけ表示されます。API キーで使っている場合や、
  セッションで最初の応答が返ってくるまでは表示されません。リセット時刻を過ぎた枠は、次の応答まで表示されません。
- スクリプトは**サンドボックスの外**で、表示が更新されるたびに実行されます。そのため、リポジトリへのリンクではなくコピーで配置します。
- jq が必要です(macOS 15 以降は標準で入っています)。jq がない場合は、値が `?` や `0` で表示されます。

---

## 日常の使い勝手(手作業になること)

安全側に倒しているため、次の作業は Claude に任せられず、自分で行う必要があります。

| 作業 | 理由 | 対処 |
| --- | --- | --- |
| `git clone`、`git init`、`git remote add`、`git config` | `.git/config` と `.git/hooks` への書き込みを禁止している | 自分のターミナルで実行する |
| `git push`、`gh` | deny にしている | 自分のターミナルで実行する |
| 外部への通信 | 許可リストがない | ドメインごとに確認が出る。ホスト名を見て「今回だけ許可」 |
| install スクリプトが必要な npm パッケージ(esbuild など) | `NPM_CONFIG_IGNORE_SCRIPTS` | 内容を確認し、自分のターミナルで `npm rebuild <パッケージ名>` |
| `.github/`、`.vscode/` の編集 | Bash からの書き込みを禁止している | Edit ツールなら確認付きで編集できる |
| `credentials.ts` のような名前のソースファイルを読む | `Read(**/credentials*)` に一致する | 必要なら自分で開いて内容を貼る |
| npm 以外のキャッシュ(`~/.cargo`、`~/.cache/pip` など)への書き込み | 作業ディレクトリ外への書き込みを禁止している | 必要なら User 設定の `sandbox.filesystem.allowWrite` に追加する |

---

## 適用方法

**シンボリックリンクではなくコピーで配置してください。** このリポジトリを Claude の作業ディレクトリとして開くと、
サンドボックス内から書き込めます。Managed 設定をリンクで配置すると、Claude がリポジトリ内のファイルを書き換えるだけで
全体のポリシーを変えられてしまいます。

### 個人の Mac

`sudo` のパスワード入力があるため、**Claude Code の外の、普通のターミナル**で、このリポジトリのディレクトリに移動してから実行してください。

#### 1. JSON に誤りがないか確認する

```sh
jq empty managed/managed-settings.json user/settings.json && echo OK
```

`OK` と出てから先に進んでください。Managed のファイルが JSON として壊れていると、**Claude Code が起動しなくなります**。

#### 2. User 設定とステータスラインを配置する

```sh
# 今の設定をバックアップしてから置き換える
cp ~/.claude/settings.json ~/.claude/settings.json.bak 2>/dev/null
install -m 755 user/statusline.sh ~/.claude/statusline.sh
cp user/settings.json ~/.claude/settings.json
```

#### 3. Managed 設定を配置する(root 所有・読み取り専用)

```sh
sudo mkdir -p "/Library/Application Support/ClaudeCode"
sudo install -m 644 -o root -g wheel managed/managed-settings.json \
  "/Library/Application Support/ClaudeCode/managed-settings.json"
```

配置できたか確認します。

```sh
ls -l "/Library/Application Support/ClaudeCode/managed-settings.json"
# -rw-r--r--  1 root  wheel  ... と表示されれば成功
```

> **vim などで直接編集しないでください。** `/Library/Application Support/ClaudeCode/` は root しか書き込めないため、
> 普通の権限で開いて保存すると `E212: Can't open file for writing` になります(フォルダがない場合も同じエラーになります)。
> root しか書き換えられないことが、Managed 設定を Claude やリポジトリから守る仕組みそのものです。
> 開いてしまった場合は `:q!` で保存せずに終了し、上の `sudo install` で配置してください。

#### 設定を変更するとき

配置先のファイルを直接編集せず、**リポジトリのファイルを直して commit してから、上の手順 1〜3 をやり直します**。
こうすることで、Git の履歴と実際に配置されている設定が常に一致します。

配置済みの設定とリポジトリに差がないかは、次のコマンドで確認できます(何も表示されなければ一致しています)。

```sh
diff managed/managed-settings.json "/Library/Application Support/ClaudeCode/managed-settings.json"
diff user/settings.json ~/.claude/settings.json
diff user/statusline.sh ~/.claude/statusline.sh
```

> `~/.claude/settings.json` は、`/model` や `/config` で設定を変えると Claude Code 自身が書き換えます。
> 差が出ていたら、残したい変更はリポジトリ側にも反映して commit してください。

### 会社の Mac

まず Claude Code で `/status` を実行し、`Setting sources` の行に Managed の設定元が出ていないか確認してください。

- Managed の設定元は 3 種類あり、**通常はそのうち 1 つだけが使われます**。優先順は
  サーバー配信(claude.ai の管理画面)→ MDM → `managed-settings.json` ファイルです。
  会社のアカウント(Team / Enterprise)でサーバー配信の設定がある場合、**このリポジトリの `managed-settings.json` を置いても無視されます**。
- 会社の Managed 設定がある場合や、`/Library/Application Support/ClaudeCode/` に既存のファイルがある場合は、
  **上書きせず情報システム部門に相談してください**。会社の端末のシステム領域に、自分の判断で設定を置かないでください。
- その場合は User 設定だけを配置します。`managed/managed-settings.json` の内容は、
  会社の設定に入っていない項目を提案するための材料として使えます。
- 会社の設定で `allowManagedPermissionRulesOnly` が有効になっていると、User 設定の ask ルールは無視されます。

### 適用後の確認

1. Claude Code を再起動し、`/doctor` と `/config` で警告や無視された設定キーが出ていないか確認する
   (キー名を打ち間違えると、エラーにならず黙って無視されることがあります)。
   `disableClaudeAiConnectors`、`tui` は特に確認してください。
2. Claude のセッション内で次のコマンドが**失敗する**ことを確認する。
   - `echo test > .git/hooks/x` — denyWrite が効いているか
   - `cat ~/.ssh/config` — 作業ディレクトリ外の読み取りが禁止されているか
   - `git push --dry-run` — deny が効いているか。加えて、サンドボックス内で認証が通らないか
3. `python3 -c "import urllib.request as u; u.urlopen('https://example.com')"` を実行させ、
   **ドメインの許可を求める確認が出る**ことを確認する(出ずに拒否される場合は、どこかの階層で `strictAllowlist` が有効になっている)。
4. `/plugin` でプラグインが 1 つも入っていないこと、マーケットプレイスを追加しようとすると
   `blocked by enterprise policy` で拒否されることを確認する。
5. `/status` の `Setting sources` に `Enterprise managed settings` が出ていることを確認する。
   Managed のファイルが JSON として壊れていると、**Claude Code が起動しなくなります**。
