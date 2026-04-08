return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "helix",
    delay = 500,
    plugins = {
      marks = true,
      registers = true,
      spelling = {
        enabled = true,
        suggestions = 20,
      },
      presets = {
        operators = true,
        motions = true,
        text_objects = true,
        windows = true,
        nav = true,
        z = true,
        g = true,
      },
    },
    win = {
      border = "rounded",
      padding = { 2, 2, 2, 2 },
    },
    layout = {
      width = { min = 20 },
      spacing = 6,
    },
    icons = {
      breadcrumb = "»",
      separator = "➜",
      group = "+",
    },
    show_help = true,
    show_keys = true,
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    wk.add({
      { "<leader>a", group = "ai" },
      { "<leader>b", group = "buffer" },
      { "<leader>c", group = "code" },
      { "<leader>f", group = "file/find" },
      { "<leader>g", group = "git" },
      { "<leader>h", group = "help" },
      { "<leader>n", group = "notifications" },
      { "<leader>q", group = "quit/session" },
      { "<leader>s", group = "search" },
      { "<leader>t", group = "toggle/terminal" },
      { "<leader>u", group = "ui" },
      { "<leader>w", group = "window" },
      { "<leader>x", group = "diagnostics" },
      { "[t", desc = "Previous todo comment" },
      { "]t", desc = "Next todo comment" },
    })
  end,
}
