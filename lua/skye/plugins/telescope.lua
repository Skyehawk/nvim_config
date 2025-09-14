return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-tree/nvim-web-devicons",
    {
      "nvim-telescope/telescope-bibtex.nvim",
      ft = { "tex", "markdown", "pandoc" },
    },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        path_display = { "smart" },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
          },
        },
      },
      extensions = {
        bibtex = {
          -- Multiple bib files for different groups
          global_files = {
            "/home/skye/Documents/mendeley_groups/*.bib", -- Wildcard to include all group files
          },
          -- Alternative: specify individual group files if wildcard doesn't work
          -- global_files = {
          --   "/home/skye/Documents/mendeley_groups/atmospheric_modeling.bib",
          --   "/home/skye/Documents/mendeley_groups/climate_data.bib",
          --   "/home/skye/Documents/mendeley_groups/field_observations.bib",
          -- },
          search_keys = { "author", "year", "title" },
          citation_format = "\\cite{%s}",
          citation_trim_firstname = true,
          citation_max_auth = 2,
          context = true,
          context_fallback = true,
          wrap = false,
          custom_formats = {
            { id = "tex", cite_marker = "\\cite{%s}" },
            { id = "markdown", cite_marker = "[@%s]" },
          },
          format = "tex",
        },
      },
    })

    -- Load extensions AFTER setup
    telescope.load_extension("fzf")

    -- Try to load bibtex extension with error handling
    local status_ok, _ = pcall(telescope.load_extension, "bibtex")
    if not status_ok then
      vim.notify("Failed to load telescope-bibtex extension", vim.log.levels.WARN)
    else
      vim.notify("telescope-bibtex extension loaded successfully", vim.log.levels.INFO)
    end

    -- Set keymaps
    local keymap = vim.keymap

    keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
    keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
    keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
    keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
    keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })

    -- Only telescope-specific citation keymap (let vimtex.lua handle the rest)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "tex",
      callback = function()
        keymap.set("n", "<leader>lb", function()
          if status_ok then
            vim.cmd("Telescope bibtex")
          else
            vim.notify("telescope-bibtex not available", vim.log.levels.WARN)
          end
        end, { buffer = true, desc = "Search citations with Telescope" })
      end,
    })
  end,
}
