return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = function()
      local base_url = (os.getenv("NVIM_CC_BASE_URL") or "https://opencode.ai/zen/go/v1"):gsub("/$", "")
      local api_key = os.getenv("NVIM_CC_API_KEY") or "OPENAI_API_KEY"
      local model = os.getenv("NVIM_CC_MODEL") or "deepseek-v4-flash"

      if base_url == "" or model == "" then
        vim.schedule(function()
          vim.notify("codecompanion.nvim requires NVIM_CC_BASE_URL and NVIM_CC_MODEL", vim.log.levels.WARN)
        end)

        return {}
      end

      return {
        adapters = {
          http = {
            my_openai = function()
              return require("codecompanion.adapters").extend("openai_compatible", {
                env = {
                  url = base_url,
                  api_key = api_key,
                },
                schema = {
                  model = {
                    default = model,
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
      }
    end,
  },
}
