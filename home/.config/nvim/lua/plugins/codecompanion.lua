return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      adapters = {
        http = {
          my_openai = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "http://localhost:11434/v1",
                api_key = "OPENAI_API_KEY",
              },
              schema = {
                model = {
                  default = "gpt-oss-20b",
                },
              },
            })
          end,
        },
      },
      interactions = {
        chat = { adapter = "my_openai" },
        inline = { adapter = "my_openai" },
        cmd = { adapter = "my_openai" },
      },
    },
  },
}
