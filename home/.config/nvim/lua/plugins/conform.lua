return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    opts = {
      formatters_by_ft = {
        groovy = { "groovylint_format" },
      },
      formatters = {
        groovylint_format = {
          command = "npm-groovy-lint",
          args = { "--format", "$FILENAME", "--failon", "none", "--loglevel", "error", "--nolintafter" },
          exit_codes = { 0, 1 },
          stdin = false,
        },
      },
      format_on_save = {
        timeout_ms = 5000,
        lsp_format = "fallback",
      },
    },
  },
}
