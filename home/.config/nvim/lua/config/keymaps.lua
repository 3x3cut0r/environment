-- Keymaps are automatically loaded on the VeryLazy event.
-- This file is a repo-local keymap reference:
-- 1. Defaults are listed first as comments.
-- 2. Active manual mappings follow below them.

-- Bufferline
-- Defaults:
-- none

vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>bn", "<cmd>BufferLineCycleNext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous tab" })

-- Windows
-- Defaults:
-- <C-w>s -> split window below
-- <C-w>v -> split window right
-- <C-w>c -> close current window
-- <C-w>o -> close all other windows
-- <C-w>h/j/k/l -> move focus between windows

vim.keymap.set("n", "<leader>ws", "<C-w>s", { desc = "Split below" })
vim.keymap.set("n", "<leader>wv", "<C-w>v", { desc = "Split right" })
vim.keymap.set("n", "<leader>wc", "<C-w>c", { desc = "Close window" })
vim.keymap.set("n", "<leader>wo", "<C-w>o", { desc = "Only window" })
vim.keymap.set("n", "<leader>wh", "<C-w>h", { desc = "Focus left" })
vim.keymap.set("n", "<leader>wj", "<C-w>j", { desc = "Focus down" })
vim.keymap.set("n", "<leader>wk", "<C-w>k", { desc = "Focus up" })
vim.keymap.set("n", "<leader>wl", "<C-w>l", { desc = "Focus right" })

-- CodeCompanion
-- Defaults:
-- none

vim.keymap.set("v", "<leader>aa", "<cmd>CodeCompanionChat Add<cr>", { desc = "Add selection to chat" })
vim.keymap.set({ "n", "v" }, "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", { desc = "CodeCompanion chat" })
vim.keymap.set("n", "<leader>ai", "<cmd>CodeCompanion<cr>", { desc = "CodeCompanion inline" })

-- Comment.nvim
-- Defaults:
-- gcc -> toggle current line comment
-- gc{motion} -> toggle comment for motion
-- gc in visual mode -> toggle comment for selection
-- gbc -> toggle current line block comment
-- gb{motion} -> toggle block comment for motion
-- gb in visual mode -> toggle block comment for selection

-- Diagnostics
-- Defaults:
-- none

vim.keymap.set("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "<leader>xn", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>xp", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "<leader>xx", function()
  vim.diagnostic.setloclist()
  vim.cmd("lopen")
end, { desc = "Diagnostics list" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

-- LSP
-- Defaults:
-- none
-- Buffer-local mappings created on LspAttach:
-- K -> hover
-- gD -> go to declaration
-- gd -> go to definition
-- gi -> go to implementation
-- gr -> references
-- <leader>ca -> code action
-- <leader>cf -> format buffer
-- <leader>rn -> rename

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
    end

    map("K", vim.lsp.buf.hover, "LSP: Hover")
    map("gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
    map("gd", vim.lsp.buf.definition, "LSP: Go to definition")
    map("gi", vim.lsp.buf.implementation, "LSP: Go to implementation")
    map("gr", vim.lsp.buf.references, "LSP: References")
    map("<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")
    map("<leader>cf", function()
      vim.lsp.buf.format({ async = true })
    end, "LSP: Format buffer")
    map("<leader>rn", vim.lsp.buf.rename, "LSP: Rename")
  end,
})

-- Neo-tree
-- Defaults:
-- none

vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Explorer (Neo-tree)" })
vim.keymap.set("n", "<leader>o", "<cmd>Neotree reveal<cr>", { desc = "Reveal file (Neo-tree)" })

-- nvim-lint
-- Defaults:
-- none

vim.keymap.set("n", "<leader>xl", function()
  require("lint").try_lint()
end, { desc = "Lint current buffer" })

-- nvim-surround
-- Defaults:
-- ds{char} -> delete surrounding pair
-- cs{target}{replacement} -> change surrounding pair
-- ys{motion}{char} -> add surrounding pair around motion
-- yss{char} -> add surrounding pair around current line
-- S in visual mode -> add surrounding pair around selection

-- Remote SSH
-- Defaults:
-- none

vim.keymap.set("n", "<leader>fr", "<cmd>RemoteHistory<cr>", { desc = "Remote history" })
vim.keymap.set("n", "<leader>ro", ":RemoteOpen ", { desc = "Open remote file" })
vim.keymap.set("n", "<leader>rt", ":RemoteTreeBrowser ", { desc = "Browse remote tree" })

-- Telescope
-- Defaults:
-- none

vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
vim.keymap.set("n", "<leader>ff", function()
  require("telescope.builtin").find_files({
    hidden = true,
    no_ignore = true,
    find_command = { "fd", "--type", "f", "--hidden", "--no-ignore", "--exclude", ".git", "--exclude", ".svn" },
  })
end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help tags" })

-- Todo Comments
-- Defaults:
-- none

vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "Search todo comments" })
vim.keymap.set("n", "<leader>xT", "<cmd>TodoLocList keywords=TODO,FIX,FIXME<cr>", { desc = "Todo/Fix loclist" })
vim.keymap.set("n", "<leader>xt", "<cmd>TodoQuickFix<cr>", { desc = "Todo quickfix list" })
vim.keymap.set("n", "[t", function()
  require("todo-comments").jump_prev()
end, { desc = "Previous todo comment" })
vim.keymap.set("n", "]t", function()
  require("todo-comments").jump_next()
end, { desc = "Next todo comment" })

-- Which-key
-- Defaults:
-- <leader> -> popup after delay
-- Marks, registers, spelling suggestions, and built-in preset hints are enabled

vim.keymap.set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })

-- Core
-- Defaults:
-- none

vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
vim.keymap.set("n", "<leader>gg", function()
  if vim.fn.executable("lazygit") == 1 then
    Snacks.lazygit()
  else
    vim.notify("lazygit not found in PATH", vim.log.levels.WARN)
  end
end, { desc = "Lazygit" })
vim.keymap.set("n", "<leader>qq", "<cmd>q<cr>", { desc = "Quit window/tab" })
vim.keymap.set("n", "<leader>qQ", "<cmd>q!<cr>", { desc = "Quit window/tab (force)" })
vim.keymap.set("n", "<leader>qa", "<cmd>qa<cr>", { desc = "Quit all" })
vim.keymap.set("n", "<leader>qA", "<cmd>qa!<cr>", { desc = "Quit all (force)" })
