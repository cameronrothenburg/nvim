# Cameron's Neovim

LazyVim with **CodeCompanion + Codex**, using ChatGPT sign-in. You write the structure and function signatures; select the implementation you want help with. Discuss the codebase in a normal Neovim buffer.

## Install on Ubuntu

Run this in a regular user account, not a root shell:

```bash
curl -fsSL https://raw.githubusercontent.com/cameronrothenburg/nvim/master/setup.sh -o /tmp/cameron-nvim-setup.sh && bash /tmp/cameron-nvim-setup.sh
```

Checks GitHub for the **latest stable Neovim** on every run and installs it under `~/.local`. Installs Git, curl, a C/C++ compiler, ripgrep, fd, fzf, Python, archive tools, a standalone Tree-sitter CLI, Node 24 LTS if your Node is older than 22, the config at `~/.config/nvim` (or `$XDG_CONFIG_HOME/nvim`), and the pinned Codex bridge. Supports Linux x86_64 and arm64. Restores plugins from the lockfile. Adds `~/.local/bin` to your shell PATH, including `nvim`, `tree-sitter` and `codex-acp`. Restart your shell afterwards.

Use a Nerd Font in your terminal for LazyVim's icons. Project-specific compilers and SDKs (Rust, Go, game engines, etc.) are separate from this editor setup.

## Install on Windows

Run in PowerShell:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/cameronrothenburg/nvim/master/setup.ps1 -OutFile "$env:TEMP\cameron-nvim-setup.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\cameron-nvim-setup.ps1"
```

Checks GitHub for the **latest stable Neovim** on every run. Reuses an exact matching installation or downloads that release. An older standard Program Files installation is upgraded through winget to prevent it shadowing the new executable (Windows may request elevation). Uses winget for missing Git, Node LTS, ripgrep, fd, fzf and the standalone Tree-sitter CLI; installs WinLibs GCC if no GCC, Clang or MSVC compiler is available. Requires Node 22+; an older existing Node must be upgraded. Config lives at `%LOCALAPPDATA%\nvim`. Persists executable directories, including `nvim` and `codex-acp`, in your user PATH and updates the current process PATH. Restart your terminal afterwards. Windows compiler fallback targets x64; ARM64 users need a compatible C compiler already installed.

Both installers check that required commands resolve on PATH and refuse to overwrite unrelated configs or discard uncommitted changes. An existing clean checkout is updated with `git pull --ff-only`. An existing config from elsewhere must be moved aside manually first. Neovim tracks stable releases; plugins and the Codex bridge remain locked for repeatability.

## Sign in to Codex

Do this once on **each machine**. The bridge runs Codex's browser login. No API key is required for the ChatGPT subscription route, and no credentials belong in this repo.

Ubuntu:

```bash
node "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/tools/node_modules/@agentclientprotocol/codex-acp/dist/index.js" login
```

Windows:

```powershell
node "$env:LOCALAPPDATA\nvim\tools\node_modules\@agentclientprotocol\codex-acp\dist\index.js" login
```

Append `cli login status` instead of `login` to check the account method. Don't copy your Windows token files to GitHub or to Ubuntu; sign in again on Ubuntu.

## Daily workflow

Open Neovim **from your project's directory** (`cd project`, then `nvim`). The leader is **Space**.

| Shortcut | Action |
| --- | --- |
| `Space aa` | Show/hide your discussion buffer |
| `Space an` | Start a new discussion |
| Select code, `Space as` | Add that selection to discussion |
| Select code, `Space ae` | Describe an edit to those lines |
| `Space ap` | CodeCompanion actions |
| Chat: `Ctrl-s` | Send your message |
| Chat: `q` | Stop the current response |
| Inline diff: `ga` / `gr` | Accept / reject this hunk |
| Inline diff: `g2` / `g3` | Accept / reject all remaining hunks |

### Edit

Write a function signature and comments, select the stub with `V`, then `Space ae`. For example: "Implement this function. Ignore depleted resources and return None when no reachable resource exists. Preserve the signature."

CodeCompanion edits a temporary copy, filters returned changes to the selected **whole lines**, and shows a diff. It rejects inline permission requests for shell commands and other file edits. Keep the supplied read-only Codex mode: granting broad agent permissions undermines this boundary. Don't edit the source buffer while generation is running; stale responses are discarded.

`Space ae` is deliberately visual-mode only. The underlying `:CodeCompanion` command without a selection can edit the whole supplied buffer. Select only the body when you want the signature excluded from the editable range.

### Discuss and research

`Space aa` opens an ordinary chat buffer: move, search, select and yank as usual. Ask about code, design trade-offs, or current documentation. The discussion adapter starts Codex in **read-only** mode, with live web search enabled and instructions to discuss rather than implement. It can inspect the project. Save files before asking about their on-disk contents; send an explicit selection for unsaved snippets.

Read-only mode can still request elevated permission. Reject write/installation requests and don't switch its permission mode if you want the conversation to remain read-only. Existing user-configured Codex MCP tools retain their own permissions; this configuration doesn't add any.

Use `/acp_session_options` for available session settings. The model follows your Codex default; no model or reasoning tier is hard-coded. ACP sessions are stored by Codex; use `/resume` in a new chat. CodeCompanion's HTTP-only `/save` isn't supported for these sessions. To keep a readable note, select and yank the useful part into a project Markdown file.

## Update

Ubuntu:

```bash
bash "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/setup.sh"
```

Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\nvim\setup.ps1"
```

If you have local config edits, commit/push them first. To refresh only plugins after pulling, run `:Lazy restore`. Use `:Lazy update` only when you intend to update plugin versions, then review and commit `lazy-lock.json`.

The Codex bridge is pinned by `tools/package-lock.json`; `npm ci --prefix tools` restores it. CodeCompanion is pinned to **v20.0.1**. `setup.ps1 -SkipUpdate` allows testing a local config checkout; `-SkipPlugins` skips plugin restore. On Ubuntu, `NVIM_SKIP_SYNC=1` skips plugin restore. `NVIM_CONFIG_DIR` / `-ConfigDir` override the config destination (custom destinations also require launching Neovim with matching XDG_CONFIG_HOME/NVIM_APPNAME).

## Checks and troubleshooting

- `:checkhealth codecompanion` checks the plugin.
- `:messages` shows startup failures.
- If the bridge is missing, rerun setup or `npm ci --prefix tools` from this config directory.
- If authentication expires, rerun the login command above.
- Upstream references: [CodeCompanion inline edits](https://codecompanion.olimorris.dev/usage/inline), [ACP configuration](https://codecompanion.olimorris.dev/configuration/adapters-acp), [Codex bridge](https://github.com/agentclientprotocol/codex-acp), [official Codex authentication](https://developers.openai.com/codex/auth/).

The previous OpenCode plugin/keybindings have been replaced. Normal Vim `Ctrl-a` / `Ctrl-x` number operations are available again.

Validation for this update: Windows Neovim 0.12.6 startup and repeatable plugin restore passed; live ChatGPT/Codex selection-edit, diff rejection and discussion tests passed using a synthetic file. The permission/selection smoke test can be rerun from the config directory with `nvim --headless '+luafile tests/smoke.lua' +qa`. PowerShell and Bash installers passed syntax checks; a fresh Ubuntu installation has not yet been exercised.
