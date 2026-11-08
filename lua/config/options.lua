-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Tree-sitter's compiler discovery otherwise assumes an MSVC developer shell.
-- Honour an explicit CC, then use the standalone compiler installed by setup.
if vim.fn.has("win32") == 1 and not vim.env.CC and vim.fn.executable("cl") == 0 then
  if vim.fn.executable("gcc") == 1 then
    vim.env.CC = "gcc"
  elseif vim.fn.executable("clang") == 1 then
    vim.env.CC = "clang"
  end
end
