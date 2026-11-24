return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      heading = {
        position = "inline",
        sign = false,
      },
      code = {
        sign = false,
      },
    },
  },
}
