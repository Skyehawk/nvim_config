return {
  "rmagatti/auto-session",
  config = function()
    local auto_session = require("auto-session")

    auto_session.setup({
      auto_restore_enabled = false,
      auto_session_suppress_dirs = { "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/" },
      pre_save_cmds = { "NvimTreeClose" },  --nvmimtree compatability issues  https://github.com/rmagatti/auto-session/issues/259#issuecomment-1812288591
      save_extra_cmds = {"NvimTreeOpen"},  --nvimtree compatability issues
      post_restore_cmds = {"NvimTreeOpen"}, --nvimtree compatability https://github.com/rmagatti/auto-session/issues/259#issuecomment-1812949343
    })

    local keymap = vim.keymap

    keymap.set("n", "<leader>wr", "<cmd>SessionRestore<CR>", { desc = "Restore session for cwd" }) -- restore last workspace session for current directory
    keymap.set("n", "<leader>ws", "<cmd>SessionSave<CR>", { desc = "Save session for auto session root dir" }) -- save workspace session for current working directory
  end,
}
