return {
  {
    "ms-jpq/coq.artifacts",
    branch = "artifacts",
    lazy = false,
  },
  {
    "ms-jpq/coq_nvim",
    branch = "coq",
    lazy = false,
    init = function()
      vim.g.coq_settings = {
        auto_start = true,
        display = {
          statusline = {
            helo = false,
          },
          pum = {
            y_max_len = 8,
            y_ratio = 0.2,
          },
        },
      }
    end,
  },
}
