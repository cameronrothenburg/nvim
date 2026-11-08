return {
  {
    "olimorris/codecompanion.nvim",
    version = "v20.0.1",
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCodeReview" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>aa", "<cmd>CodeCompanionChat Toggle<cr>", desc = "AI discussion (toggle)" },
      { "<leader>an", "<cmd>CodeCompanionChat<cr>", desc = "AI discussion (new)" },
      { "<leader>as", "<cmd>CodeCompanionChat Add<cr>", mode = "x", desc = "Send selection to discussion" },
      { "<leader>ae", ":CodeCompanion<cr>", mode = "x", desc = "AI edit selection" },
      { "<leader>ap", "<cmd>CodeCompanionActions<cr>", desc = "AI actions" },
    },
    opts = function() return require("config.ai").options() end,
  },
}
