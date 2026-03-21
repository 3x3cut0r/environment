return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Neotree",
    config = function()
      require("neo-tree").setup({
        filesystem = {
          follow_current_file = {
            enabled = true,
          },
        },
        window = {
          position = "left",
          width = 34,
        },
      })
    end,
  },
}
