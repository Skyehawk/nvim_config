return {
  "kevinhwang91/nvim-ufo",
  dependencies = {
    "kevinhwang91/promise-async",
  },
  config = function()
    local ufo = require("ufo")

    -- Set options
    vim.o.foldcolumn = "2"
    vim.o.foldlevel = 99
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true

    -- Set keymaps
    vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "Open All Folds" })
    vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "Close All Folds" })
    vim.keymap.set("n", "zl", function()
      local winid = ufo.peekFoldedLinesUnderCursor()
      if not winid then
        vim.lsp.buf.hover()
      end
    end, { desc = "Peek Fold" })

    -- Setup ufo
    ufo.setup({
      provider_selector = function(bufnr, filetype, buftype)
        return { "lsp", "indent" }
      end,
    })
  end,
}
