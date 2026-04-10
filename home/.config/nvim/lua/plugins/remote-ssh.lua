return {
  {
    "inhesrom/remote-ssh.nvim",
    branch = "master",
    dependencies = {
      "inhesrom/telescope-remote-buffer",
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      local lsp = require("config.lsp")

      require("telescope-remote-buffer").setup()
      require("remote-ssh").setup({
        capabilities = lsp.capabilities,
        filetype_to_server = lsp.filetype_to_server(),
      })
    end,
  },
}
