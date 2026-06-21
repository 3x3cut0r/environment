return {
  {
    "Robitx/gp.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      local defaults = require("gp.defaults")
      local provider_name = os.getenv("NVIM_GP_PROVIDER") or "opencode"
      local raw_base_url = os.getenv("NVIM_GP_BASE_URL") or "https://opencode.ai/zen/go/v1"
      local api_key = os.getenv("NVIM_GP_API_KEY") or ""
      local chat_model = os.getenv("NVIM_GP_CHAT_MODEL") or ""
      local command_model = os.getenv("NVIM_GP_COMMAND_MODEL") or ""
      local base_url = raw_base_url:gsub("/$", "") .. "/chat/completions"
      local provider_label = provider_name:gsub("^%l", string.upper)
      local chat_agent_name = string.format("%s %s Chat", provider_label, chat_model)
      local command_agent_name = string.format("%s %s Code", provider_label, command_model)

      if raw_base_url == "" or api_key == "" or chat_model == "" or command_model == "" then
        vim.schedule(function()
          vim.notify(
            "gp.nvim requires NVIM_GP_BASE_URL, NVIM_GP_API_KEY, NVIM_GP_CHAT_MODEL, and NVIM_GP_COMMAND_MODEL",
            vim.log.levels.WARN
          )
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
          [provider_name] = {
            endpoint = base_url,
            secret = api_key,
          },
        },
        default_chat_agent = chat_agent_name,
        default_command_agent = command_agent_name,
        agents = {
          {
            provider = provider_name,
            name = chat_agent_name,
            chat = true,
            command = false,
            model = { model = chat_model, temperature = 0.7, top_p = 1 },
            system_prompt = defaults.chat_system_prompt,
          },
          {
            provider = provider_name,
            name = command_agent_name,
            chat = false,
            command = true,
            model = { model = command_model, temperature = 0.2, top_p = 1 },
            system_prompt = defaults.code_system_prompt,
          },
        },
      })
    end,
  },
}
