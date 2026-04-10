return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "ms-jpq/coq_nvim",
      "ms-jpq/coq.artifacts",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      local lsp = require("config.lsp")

      for server_name, server_opts in pairs(lsp.servers) do
        vim.lsp.config(server_name, lsp.with_capabilities(server_opts))
        vim.lsp.enable(server_name)
      end
    end,
  },
}
