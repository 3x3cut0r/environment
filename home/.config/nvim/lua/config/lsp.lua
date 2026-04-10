local M = {}

local has_ansible_lint = vim.fn.executable("ansible-lint") == 1

M.servers = {
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

local function build_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, coq = pcall(require, "coq")

  if not ok then
    return capabilities
  end

  return coq.lsp_ensure_capabilities({ capabilities = capabilities }).capabilities
end

M.capabilities = build_capabilities()

function M.with_capabilities(server_opts)
  local opts = vim.tbl_deep_extend("force", {}, server_opts or {})
  opts.capabilities = vim.tbl_deep_extend("force", {}, M.capabilities, opts.capabilities or {})

  return opts
end

function M.filetype_to_server()
  local ok, lspconfig = pcall(require, "lspconfig")
  if not ok then
    return {}
  end

  local mapping = {}

  for server_name, server_opts in pairs(M.servers) do
    local filetypes = server_opts.filetypes

    if not filetypes then
      local config = lspconfig[server_name]
      filetypes = config and config.document_config and config.document_config.default_config.filetypes or {}
    end

    for _, filetype in ipairs(filetypes or {}) do
      mapping[filetype] = server_name
    end
  end

  return mapping
end

return M
