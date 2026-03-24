return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    event = "VeryLazy",
    opts = function()
      local ok, ctp_bufferline = pcall(require, "catppuccin.special.bufferline")
      if not ok then
        ok, ctp_bufferline = pcall(require, "catppuccin.groups.integrations.bufferline")
      end

      local highlights = {}
      if ok and ctp_bufferline and ctp_bufferline.get_theme then
        highlights = ctp_bufferline.get_theme()
      end

      return {
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
        },
        highlights = highlights,
      }
    end,
  },
}
