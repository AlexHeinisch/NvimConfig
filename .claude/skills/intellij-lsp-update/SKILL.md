---
name: intellij-lsp-update
description: Check for new intellij-lsp.nvim commits, summarise what changed, and grill me on whether each change fits this config before updating.
disable-model-invocation: true
---

# Update intellij-lsp.nvim

The plugin lives in `~/.local/share/nvim/lazy/intellij-lsp.nvim` (detached HEAD, pinned in `lazy-lock.json`). This config bends it in several places, so an update is a *review* first and a `:Lazy update` second.

## 1. Find the delta

```sh
cd ~/.local/share/nvim/lazy/intellij-lsp.nvim
git fetch -q
git log HEAD..origin/HEAD --format='=== %h %cd %s%n%b' --date=short
git diff HEAD origin/HEAD --stat
git diff HEAD origin/HEAD -- README.md   # the `setup({...})` option block and the Shortcuts table
```

No commits ahead: say so and stop.

## 2. Read this config's side of it

Read `lua/custom/plugins/intellij-lsp.lua` and `lua/custom/plugins/blink.lua`: they hold every deviation, with the reason beside it. Read the `REMOVE when` condition at the top of `lua/custom/utils/intellij-lombok-workaround.lua`.

Tag each commit against that code with exactly one verdict:

- **collides**: touches something this config overrides (a keymap it unmaps, an option it sets, a renamed or removed `:IntellijLsp*` command that `<leader>l` maps call, the native-completion switch-off, the Lombok workaround's remove condition).
- **new**: a feature this config does not use yet.
- **neutral**: fixes and internals with no visible effect here.

Watch for options whose *meaning* shifted under the same name. One real case: `keymaps = false` once dropped five maps and later dropped all of them.

Note server bundle bumps and anything that forces a reindex or a fresh download.

## 3. Grill

Invoke `/mattpocock-skills:grilling` and grill me on every **collides** and **new** commit, one question at a time, each with your recommended answer: does this change make sense *for this config*? Adopt, adapt the config, or skip?

Done when every commit carries my verdict. Neutral commits get one line in the final summary, with no question.

## 4. Apply

Run the update, then make the config edits we agreed on:

```sh
nvim --headless "+Lazy! update intellij-lsp.nvim" +qa
```

Verify with a headless start that loads the edited files without errors. List the leftovers I have to check by hand in a Java buffer (keymaps, completion, run/debug). Leave committing to me.
