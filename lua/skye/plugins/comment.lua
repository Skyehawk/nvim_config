return {
  "numToStr/Comment.nvim",
  event = { "BufReadPre", "BufNewFile" }, -- Open plugin whenever we open a new buffer/ buffer for an existing file
  dependencies = {
    "JoosepAlviste/nvim-ts-context-commentstring",  -- used for properly commenting out tsx and jsx code
  },
  config = function()
    -- import comment plugin safely
    local comment = require("Comment")

    -- module that integrates nvmim ts context comment string with comment.nvim 
    local ts_context_commentstring = require("ts_context_commentstring.integrations.comment_nvim")

    -- enable comment
    comment.setup({
      -- for commenting tsx, jsx, svelte, html files
      pre_hook = ts_context_commentstring.create_pre_hook(),
    })
  end,
}
