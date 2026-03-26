return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local util = require("lspconfig.util")

      local capabilities = vim.lsp.protocol.make_client_capabilities()

      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                checkThirdParty = false,
              },
              telemetry = {
                enable = false,
              },
            },
          },
        },
        ansiblels = {
          filetypes = { "yaml.ansible", "ansible", "yaml" },
          settings = {
            ansible = {
              ansible = {
                path = "ansible",
              },
              executionEnvironment = {
                enabled = false,
              },
              python = {
                interpreterPath = "python",
              },
              validation = {
                enabled = true,
                lint = {
                  enabled = true,
                  path = "ansible-lint",
                },
              },
            },
          },
        },
        groovyls = {
          filetypes = { "groovy", "Jenkinsfile" },
          root_dir = util.root_pattern("Jenkinsfile", ".git"),
        },
      }

      for server_name, server_opts in pairs(servers) do
        server_opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server_opts.capabilities or {})
        lspconfig[server_name].setup(server_opts)
      end
    end,
  },
}
