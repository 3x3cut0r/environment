return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {}

      if vim.fn.executable("ruff") == 1 then
        lint.linters_by_ft.python = { "ruff" }
      end

      if vim.fn.executable("ansible-lint") == 1 then
        lint.linters_by_ft.ansible = { "ansible-lint" }
        lint.linters_by_ft["yaml.ansible"] = { "ansible-lint" }
      end

      if vim.fn.executable("shellcheck") == 1 then
        lint.linters_by_ft.bash = { "shellcheck" }
        lint.linters_by_ft.sh = { "shellcheck" }
      end

      local lint_augroup = vim.api.nvim_create_augroup("nvim_lint", { clear = true })

      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = lint_augroup,
        callback = function()
          require("lint").try_lint()
        end,
      })
    end,
  },
}
