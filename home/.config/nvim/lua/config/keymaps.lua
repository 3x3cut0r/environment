-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })

vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help tags" })
vim.keymap.set("n", "<leader>bn", "<cmd>BufferLineCycleNext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<leader>w", "<cmd>bdelete<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit window/tab" })
vim.keymap.set("n", "<leader>gg", function()
  if vim.fn.executable("lazygit") == 1 then
    Snacks.lazygit()
  else
    vim.notify("lazygit not found in PATH", vim.log.levels.WARN)
  end
end, { desc = "Lazygit" })
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Explorer (Neo-tree)" })
vim.keymap.set("n", "<leader>o", "<cmd>Neotree reveal<cr>", { desc = "Reveal file (Neo-tree)" })
vim.keymap.set({ "n", "v" }, "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", { desc = "CodeCompanion chat" })
vim.keymap.set("v", "<leader>aa", "<cmd>CodeCompanionChat Add<cr>", { desc = "Add selection to chat" })
vim.keymap.set("n", "<leader>ai", "<cmd>CodeCompanion<cr>", { desc = "CodeCompanion inline" })

-- which-key keymaps
vim.keymap.set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "LSP: Go to definition")
    map("gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
    map("gi", vim.lsp.buf.implementation, "LSP: Go to implementation")
    map("gr", vim.lsp.buf.references, "LSP: References")
    map("K", vim.lsp.buf.hover, "LSP: Hover")
    map("<leader>rn", vim.lsp.buf.rename, "LSP: Rename")
    map("<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")
    map("<leader>cf", function()
      vim.lsp.buf.format({ async = true })
    end, "LSP: Format buffer")
  end,
})

vim.keymap.set("n", "<leader>xl", function()
  require("lint").try_lint()
end, { desc = "Lint current buffer" })
vim.keymap.set("n", "]t", function()
  require("todo-comments").jump_next()
end, { desc = "Next todo comment" })
vim.keymap.set("n", "[t", function()
  require("todo-comments").jump_prev()
end, { desc = "Previous todo comment" })
vim.keymap.set("n", "<leader>xt", "<cmd>TodoQuickFix<cr>", { desc = "Todo quickfix list" })
vim.keymap.set("n", "<leader>xT", "<cmd>TodoLocList keywords=TODO,FIX,FIXME<cr>", { desc = "Todo/Fix loclist" })
vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "Search todo comments" })

vim.keymap.set("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "<leader>xx", function()
  vim.diagnostic.setloclist()
  vim.cmd("lopen")
end, { desc = "Diagnostics list" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "<leader>xn", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>xp", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
