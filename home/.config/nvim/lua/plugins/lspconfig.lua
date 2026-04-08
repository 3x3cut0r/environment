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
      local coq = require("coq")
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local has_ansible_lint = vim.fn.executable("ansible-lint") == 1

      local servers = {
        bashls = {},
        jsonls = {},
        yamlls = {},
        marksman = {},
        pyright = {},
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
                  enabled = has_ansible_lint,
                  path = "ansible-lint",
                },
              },
            },
          },
        },
        groovyls = {
          filetypes = { "groovy", "Jenkinsfile" },
          root_markers = { "Jenkinsfile", ".git" },
        },
      }

      for server_name, server_opts in pairs(servers) do
        server_opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server_opts.capabilities or {})
        vim.lsp.config(server_name, coq.lsp_ensure_capabilities(server_opts))
        vim.lsp.enable(server_name)
      end
    end,
  },
}
