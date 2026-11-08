-- Run in an installed config: nvim --headless '+luafile tests/smoke.lua' +qa
local function run()
require("lazy").load({ plugins = { "codecompanion.nvim" } })
local function check(condition, message) assert(condition, message) end
local config = require("codecompanion.config")
check(config.interactions.chat.adapter == "codex_discuss", "Discussion must be the default chat")
check(config.interactions.inline.adapter == "codex_edit", "Inline must use its separate adapter")
local adapters = require("codecompanion.adapters")
for _, name in ipairs({ "codex_discuss", "codex_edit" }) do
  local adapter = adapters.resolve(name)
  check(adapter.type == "acp", "Expected the Codex ACP adapter")
  check(adapter.defaults.auth_method == "chat-gpt", "Expected browser-based ChatGPT authentication")
  check(adapter.env.INITIAL_AGENT_MODE() == "read-only", "Must not default to automatic workspace writes")
  check(vim.fn.filereadable(adapter.commands.default[2]) == 1, "Missing installed bridge")
end

-- Exercise the real upstream permission filter and selected-line merge.
local ACP = require("codecompanion.interactions.inline.adapters.acp")
local original = { "local untouched = 10", "function answer()", "  return nil", "end", "return untouched" }
local instance = ACP.new({ inline = {
  adapter = adapters.resolve("codex_edit"),
  target = { lines = original, editable = { first = 3, last = 3 } },
} })
local merged = instance:keep_editable_changes({ "local untouched = 99", "function answer()", "  return 42", "end", "return untouched" })
check(merged[1] == original[1] and merged[3] == "  return 42", "Out-of-scope changes must be dropped")
instance.copy_path = vim.fn.tempname()
vim.fn.writefile(original, instance.copy_path)
local function permission(kind, path)
  local decision
  instance:respond_to_permission({
    tool_call = { kind = kind, locations = { { path = path } } },
    options = { { kind = "allow_once", optionId = "yes" }, { kind = "reject_once", optionId = "no" } },
    respond = function(value) decision = value end,
  })
  return decision
end
check(permission("edit", instance.copy_path) == "yes", "Temporary-copy edit should be allowed")
check(permission("edit", vim.fn.stdpath("config") .. "/init.lua") == "no", "Real file edit must be denied")
check(permission("execute", instance.copy_path) == "no", "Inline shell execution must be denied")
vim.fn.delete(instance.copy_path)
local spec = require("plugins.codecompanion")[1]
for _, key in ipairs(spec.keys) do
  if key[1] == "<leader>ae" then check(key.mode == "x", "Edit shortcut must require a selection") end
end
print("PASS: configuration, ChatGPT adapter, selection merge and edit permissions")
end
local ok, err = pcall(run)
if not ok then
  print("FAIL: " .. tostring(err))
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
