return {
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    config = function()
      require("gitsigns").setup({
        on_attach = function(bufnr)
          local gitsigns = require("gitsigns")

          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          map("n", "]c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "]c", bang = true })
            else
              gitsigns.nav_hunk("next")
            end
          end, "Next hunk")

          map("n", "[c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              gitsigns.nav_hunk("prev")
            end
          end, "Previous hunk")

          map("n", "<leader>gs", gitsigns.stage_hunk, "Stage hunk")
          map("n", "<leader>gr", gitsigns.reset_hunk, "Reset hunk")
          map("v", "<leader>gs", function()
            gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Stage hunk")
          map("v", "<leader>gr", function()
            gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Reset hunk")
          map("n", "<leader>gS", gitsigns.stage_buffer, "Stage buffer")
          map("n", "<leader>gR", gitsigns.reset_buffer, "Reset buffer")
          map("n", "<leader>gp", gitsigns.preview_hunk, "Preview hunk")
          map("n", "<leader>gi", gitsigns.preview_hunk_inline, "Preview hunk inline")
          map("n", "<leader>gb", function()
            gitsigns.blame_line({ full = true })
          end, "Blame line")
          map("n", "<leader>gd", gitsigns.diffthis, "Diff this")
          map("n", "<leader>gD", function()
            gitsigns.diffthis("~")
          end, "Diff this ~")
          map("n", "<leader>tb", gitsigns.toggle_current_line_blame, "Toggle line blame")
          map("n", "<leader>td", gitsigns.toggle_deleted, "Toggle deleted")
        end,
      })
    end,
  },
}
