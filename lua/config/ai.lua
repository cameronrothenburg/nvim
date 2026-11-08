local M = {}

-- Launch Node directly: Windows .cmd shims cannot be spawned like executables.
function M.command()
  local node = vim.fn.exepath("node")
  if node == "" and vim.fn.has("win32") == 1 then
    local candidate = (vim.env.ProgramFiles or "C:/Program Files") .. "/nodejs/node.exe"
    if vim.fn.executable(candidate) == 1 then node = candidate end
  end
  local bridge = vim.fs.joinpath(vim.fn.stdpath("config"), "tools", "node_modules",
    "@agentclientprotocol", "codex-acp", "dist", "index.js")
  if node == "" or not vim.uv.fs_stat(bridge) then
    error("Codex tools are missing. Run setup.ps1 (Windows) or setup.sh (Ubuntu) from your nvim config.")
  end
  return { node, bridge }
end

local function adapter(kind)
  local discussion = kind == "discuss"
  local instructions = discussion
      and "Discuss and research the codebase with an experienced engineer. Read relevant files and cite file locations. Use web search for current documentation and cite sources. Do not edit files, install software, or execute a plan. The user owns the architecture. Answer directly; no beginner lessons unless requested."
    or "Implement only the requested change in the supplied temporary buffer copy. Preserve function signatures and surrounding design unless explicitly asked. Do not edit other files or run commands. Suggest any necessary wider change in your reply."
  local result = require("codecompanion.adapters").extend("codex", {
    name = "codex_" .. kind,
    formatted_name = discussion and "Codex Discussion" or "Codex Selection Edit",
    commands = { default = M.command() },
    defaults = { auth_method = "chat-gpt", timeout = 60000 },
  })
  -- Replace, rather than merge, the preset API-key environment.
  result.env = {
    INITIAL_AGENT_MODE = function() return "read-only" end,
    CODEX_CONFIG = function()
      return vim.json.encode({ developer_instructions = instructions, web_search = discussion and "live" or "disabled" })
    end,
  }
  return result
end

function M.options()
  return {
    adapters = {
      acp = {
        codex_discuss = function() return adapter("discuss") end,
        codex_edit = function() return adapter("edit") end,
      },
    },
    interactions = {
      chat = { adapter = "codex_discuss" },
      inline = { adapter = "codex_edit" },
      background = { chat = { opts = { enabled = false } } },
    },
    display = {
      chat = { window = { layout = "vertical", width = 0.4 } },
      diff = { enabled = true },
    },
  }
end

return M
