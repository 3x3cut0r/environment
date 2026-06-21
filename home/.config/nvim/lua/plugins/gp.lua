return {
  {
    "Robitx/gp.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      local defaults = require("gp.defaults")
      local base_url = os.getenv("OPENCODE_GO_BASE_URL") .. "/chat/completions"
      local api_key = os.getenv("OPENCODE_GO_API_KEY")

      if not base_url or base_url == "" or not api_key or api_key == "" then
        vim.schedule(function()
          vim.notify("gp.nvim requires OPENCODE_GO_BASE_URL and OPENCODE_GO_API_KEY", vim.log.levels.WARN)
        end)
        return
      end

      local is_https = base_url:match("^https://")
      local is_local_http = base_url:match("^http://localhost[:/]") or base_url:match("^http://127%.0%.0%.1[:/]")

      if not is_https and not is_local_http then
        vim.schedule(function()
          vim.notify("gp.nvim requires an https base_url or localhost http base_url", vim.log.levels.WARN)
        end)
        return
      end

      require("gp").setup({
        providers = {
          openai = {},
          opencode = {
            endpoint = base_url,
            secret = api_key,
          },
        },
        default_chat_agent = "OpenCode DeepSeek V4 Flash Chat",
        default_command_agent = "OpenCode DeepSeek V4 Flash Code",
        agents = {
          {
            provider = "opencode",
            name = "DeepSeek V4 Flash Chat",
            chat = true,
            command = false,
            model = { model = "deepseek-v4-flash", temperature = 0.7, top_p = 1 },
            system_prompt = defaults.chat_system_prompt,
          },
          {
            provider = "opencode",
            name = "DeepSeek V4 Flash Code",
            chat = false,
            command = true,
            model = { model = "deepseek-v4-flash", temperature = 0.2, top_p = 1 },
            system_prompt = defaults.code_system_prompt,
          },
        },
      })
    end,
  },
}
