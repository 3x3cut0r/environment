return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    event = "VeryLazy",
    opts = {
      options = {
        mode = "buffers",
        diagnostics = "nvim_lsp",
      },
      highlights = require("catppuccin.groups.integrations.bufferline").get_theme(),
    },
  },
}
