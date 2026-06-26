local M = {}

local has_ansible_lint = vim.fn.executable("ansible-lint") == 1

M.servers = {
  bashls = {
    filetypes = { "sh" },
  },
  jsonls = {
    filetypes = { "json", "jsonc" },
  },
  yamlls = {
    filetypes = { "yaml" },
  },
  marksman = {
    filetypes = { "markdown" },
  },
  pyright = {
    filetypes = { "python" },
  },
  lua_ls = {
    filetypes = { "lua" },
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
  return vim.lsp.protocol.make_client_capabilities()
end

M.capabilities = build_capabilities()

function M.with_capabilities(server_opts)
  local opts = vim.tbl_deep_extend("force", {}, server_opts or {})
  opts.capabilities = vim.tbl_deep_extend("force", {}, M.capabilities, opts.capabilities or {})

  return opts
end

function M.filetype_to_server()
  local mapping = {}

  for server_name, server_opts in pairs(M.servers) do
    for _, filetype in ipairs(server_opts.filetypes or {}) do
      mapping[filetype] = server_name
    end
  end

  return mapping
end

return M
