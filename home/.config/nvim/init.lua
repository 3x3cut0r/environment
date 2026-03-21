local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.encoding = "utf-8"
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.scrolloff = 2
vim.opt.ruler = true
vim.opt.cursorline = true
vim.opt.visualbell = true
vim.opt.title = true
vim.opt.background = "dark"
vim.opt.history = 1000
vim.opt.mouse = "a"

vim.cmd("syntax enable")

if vim.fn.has("termguicolors") == 1 then
  vim.opt.termguicolors = true
end

local restore_cursor_position = vim.api.nvim_create_augroup("restore_cursor_position", { clear = true })

vim.api.nvim_create_autocmd("BufReadPost", {
  group = restore_cursor_position,
  pattern = "*",
  callback = function()
    local line = vim.fn.line([['"]])
    if line > 1 and line <= vim.fn.line("$") then
      vim.cmd([[normal! g`"]])
    end
  end,
})

require("lazy").setup({
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
    },
    config = function()
      require("telescope").setup({})
    end,
  },
})
