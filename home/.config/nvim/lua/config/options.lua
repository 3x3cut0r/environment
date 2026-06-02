-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.encoding = "utf-8"
vim.opt.number = true
vim.opt.relativenumber = true
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
vim.opt.completeopt = { "menuone", "noinsert", "noselect" }
vim.opt.pumheight = 8
vim.opt.pumblend = 30

-- disable intro messages
vim.opt.shortmess:append("I")

vim.cmd("syntax enable")

if vim.fn.has("termguicolors") == 1 then
  vim.opt.termguicolors = true
end
