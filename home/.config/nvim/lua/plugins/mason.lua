return {
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = {
        "lua_ls",
        "bashls",
        "jsonls",
        "yamlls",
        "marksman",
        "pyright",
        "ansiblels",
        "groovyls",
      },
      automatic_installation = true,
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
      "williamboman/mason.nvim",
    },
    opts = {
      ensure_installed = {
        "ruff",
        "ansible-lint",
      },
      auto_update = false,
      run_on_start = true,
      start_delay = 3000,
      debounce_hours = 5,
    },
  },
}
