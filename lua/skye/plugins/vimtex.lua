return {
  "lervag/vimtex",
  lazy = false, -- we don't want to lazy load VimTeX
  -- tag = "v2.15", -- uncomment to pin to a specific release
  init = function()
    -- VimTeX configuration goes here, e.g.
    vim.g.vimtex_view_method = "general"
    vim.g.vimtex_view_general_viewer = "okular"
    vim.g.vimtex_view_general_options = "--unique file:@pdf\\#src:@line@tex"

    -- Alternative viewers (uncomment one of these instead of okular if preferred):
    -- For Zathura:
    -- vim.g.vimtex_view_method = "zathura"

    -- For Evince:
    -- vim.g.vimtex_view_method = "general"
    -- vim.g.vimtex_view_general_viewer = "evince"

    -- For PDF.js in browser:
    -- vim.g.vimtex_view_method = "general"
    -- vim.g.vimtex_view_general_viewer = "firefox"
    -- vim.g.vimtex_view_general_options = "file://@pdf"

    -- Compiler settings
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_compiler_latexmk = {
      aux_dir = "",
      out_dir = "",
      callback = 1,
      continuous = 1,
      executable = "latexmk",
      hooks = {},
      options = {
        "-pdf",
        "-pdflatex=pdflatex",
        "-verbose",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
      },
    }

    -- Enable quickfix window for errors
    vim.g.vimtex_quickfix_mode = 0

    -- Disable overfull/underfull \hbox and all package warnings
    vim.g.vimtex_quickfix_ignore_filters = {
      "default",
      "general",
    }

    -- Auto enable concealing
    vim.g.vimtex_syntax_conceal = {
      accents = 1,
      ligatures = 1,
      cites = 1,
      fancy = 1,
      spacing = 1,
      greek = 1,
      math_bounds = 1,
      math_delimiters = 1,
      math_fracs = 1,
      math_super_sub = 1,
      math_symbols = 1,
      sections = 0,
      styles = 1,
    }

    -- Enable folding
    vim.g.vimtex_fold_enabled = 1

    -- Custom function to open PDF in tmux pane
    local function open_pdf_in_tmux_pane(pdf_path)
      print("=== DEBUG INFO ===")
      print("TMUX env var: " .. (vim.env.TMUX or "nil"))
      print("PDF path: " .. pdf_path)
      print("PDF exists: " .. (vim.fn.filereadable(pdf_path) == 1 and "yes" or "no"))

      if not vim.env.TMUX or vim.env.TMUX == "" then
        vim.notify("Not in tmux session.", vim.log.levels.WARN)
        return
      end

      if vim.fn.filereadable(pdf_path) == 0 then
        vim.notify("PDF not found: " .. pdf_path, vim.log.levels.WARN)
        return
      end

      -- Test which PDF viewers are available (prefer terminal-based for tmux)
      local viewers = {
        { cmd = "termpdf", args = "", type = "terminal" },
        { cmd = "pdftotext", args = "-layout - | less", type = "text" },
        { cmd = "zathura", args = "", type = "gui" },
        { cmd = "okular", args = "", type = "gui" },
        { cmd = "evince", args = "", type = "gui" },
      }
      local available_viewer = nil
      local viewer_args = ""
      local viewer_type = ""

      for _, viewer in ipairs(viewers) do
        local result = vim.fn.system("which " .. viewer.cmd)
        if vim.v.shell_error == 0 then
          available_viewer = viewer.cmd
          viewer_args = viewer.args
          viewer_type = viewer.type
          print("Found PDF viewer: " .. viewer.cmd .. " (" .. viewer.type .. ")")
          break
        end
      end

      if not available_viewer then
        vim.notify("No PDF viewer found", vim.log.levels.ERROR)
        return
      end

      -- Use simple split without sizing (50/50 split)
      local split_cmd = "tmux split-window -h"
      local viewer_cmd

      if viewer_type == "text" then
        -- Text-based viewing with poppler-utils
        viewer_cmd = string.format("pdftotext -layout '%s' - | less -R", pdf_path)
      elseif viewer_type == "terminal" then
        -- Terminal PDF viewer
        viewer_cmd = string.format("%s '%s'", available_viewer, pdf_path)
      else
        -- GUI viewer - show info in tmux pane and open GUI separately
        viewer_cmd = string.format(
          "echo 'Opening %s in %s...'; echo 'PDF: %s'; echo 'Use Ctrl+C to close this pane'; %s '%s' & sleep 1",
          available_viewer,
          available_viewer,
          pdf_path,
          available_viewer,
          pdf_path
        )
      end

      local full_cmd = split_cmd .. " '" .. viewer_cmd .. '; echo "Press Enter to close..."; read\''

      print("Running command: " .. full_cmd)

      local result = vim.fn.system(full_cmd)
      local exit_code = vim.v.shell_error

      print("Exit code: " .. exit_code)
      print("Output: " .. (result or "no output"))

      if exit_code == 0 then
        vim.notify("PDF opened in tmux pane", vim.log.levels.INFO)
      else
        vim.notify("Failed to open tmux pane. Exit code: " .. exit_code, vim.log.levels.ERROR)
      end
    end

    -- Custom function to get current PDF path
    local function get_pdf_path()
      return vim.fn.expand("%:r") .. ".pdf"
    end

    -- Simple citation picker function
    local function pick_citation()
      local bib_file = "/home/skye/Documents/bibliography.bib/library.bib"

      -- Check if file exists
      if vim.fn.filereadable(bib_file) == 0 then
        vim.notify("Bibliography file not found: " .. bib_file, vim.log.levels.ERROR)
        return
      end

      local citations = {}
      local file = io.open(bib_file, "r")

      if not file then
        vim.notify("Cannot open bibliography file", vim.log.levels.ERROR)
        return
      end

      -- Parse the bib file for citation keys and titles
      local current_key = nil
      local current_title = nil

      for line in file:lines() do
        -- Look for citation keys (@article{key,)
        local key = line:match("^@%w+{([^,]+),")
        if key then
          current_key = key
          current_title = nil
        end

        -- Look for titles
        local title = line:match("title%s*=%s*{(.-)}")
        if title and current_key then
          current_title = title:gsub("^{", ""):gsub("}$", "") -- Remove extra braces
          table.insert(citations, {
            key = current_key,
            title = current_title,
            display = current_key .. " - " .. current_title,
          })
          current_key = nil
          current_title = nil
        end
      end

      file:close()

      if #citations == 0 then
        vim.notify("No citations found in bibliography file", vim.log.levels.WARN)
        return
      end

      -- Use vim.ui.select for citation picking
      vim.ui.select(citations, {
        prompt = "Select citation (" .. #citations .. " available):",
        format_item = function(item)
          return item.display
        end,
      }, function(choice)
        if choice then
          -- Insert citation at cursor position
          local citation = "\\cite{" .. choice.key .. "}"
          vim.api.nvim_put({ citation }, "c", false, true)
          vim.notify("Inserted: " .. citation, vim.log.levels.INFO)
        end
      end)
    end

    -- Enhanced citation picker that handles multiple bib files (groups)
    local function pick_citation_with_groups()
      local bib_base_path = "/home/skye/Documents/mendeley_groups/"

      -- Find all .bib files in the directory
      local bib_files = {}
      local handle = io.popen("find " .. bib_base_path .. " -name '*.bib' 2>/dev/null")
      if handle then
        for file in handle:lines() do
          table.insert(bib_files, file)
        end
        handle:close()
      end

      -- Fallback to single file if no group files found
      if #bib_files == 0 then
        bib_files = { "/home/skye/Documents/bibliography.bib/library.bib" }
      end

      local all_citations = {}

      -- Parse each bib file
      for _, bib_file in ipairs(bib_files) do
        if vim.fn.filereadable(bib_file) == 1 then
          local file = io.open(bib_file, "r")
          if file then
            -- Extract group name from filename
            local group_name = bib_file:match("([^/]+)%.bib$") or "Default"
            group_name = group_name:gsub("_", " "):gsub("^%l", string.upper)

            local current_key = nil
            local current_title = nil

            for line in file:lines() do
              local key = line:match("^@%w+{([^,]+),")
              if key then
                current_key = key
                current_title = nil
              end

              local title = line:match("title%s*=%s*{(.-)}")
              if title and current_key then
                current_title = title:gsub("^{", ""):gsub("}$", "")
                table.insert(all_citations, {
                  key = current_key,
                  title = current_title,
                  group = group_name,
                  display = "[" .. group_name .. "] " .. current_key .. " - " .. current_title,
                  sort_key = group_name .. "|" .. current_key,
                })
                current_key = nil
                current_title = nil
              end
            end
            file:close()
          end
        end
      end

      if #all_citations == 0 then
        vim.notify("No citations found in any bibliography files", vim.log.levels.WARN)
        return
      end

      -- Sort by group, then by citation key
      table.sort(all_citations, function(a, b)
        return a.sort_key < b.sort_key
      end)

      -- Use vim.ui.select with group information
      vim.ui.select(all_citations, {
        prompt = "Select citation (" .. #all_citations .. " from " .. #bib_files .. " groups):",
        format_item = function(item)
          return item.display
        end,
      }, function(choice)
        if choice then
          local citation = "\\cite{" .. choice.key .. "}"
          vim.api.nvim_put({ citation }, "c", false, true)
          vim.notify("Inserted: " .. citation .. " from " .. choice.group, vim.log.levels.INFO)
        end
      end)
    end

    -- Group selection first, then citation
    local function pick_citation_by_group()
      local bib_base_path = "/home/skye/Documents/mendeley_groups/"

      -- Find all .bib files
      local bib_files = {}
      local handle = io.popen("find " .. bib_base_path .. " -name '*.bib' 2>/dev/null")
      if handle then
        for file in handle:lines() do
          local group_name = file:match("([^/]+)%.bib$")
          if group_name then
            table.insert(bib_files, {
              path = file,
              name = group_name:gsub("_", " "):gsub("^%l", string.upper),
              display = group_name:gsub("_", " "):gsub("^%l", string.upper),
            })
          end
        end
        handle:close()
      end

      -- Fallback option
      if #bib_files == 0 then
        table.insert(bib_files, {
          path = "/home/skye/Documents/bibliography.bib/library.bib",
          name = "All References",
          display = "All References",
        })
      end

      -- First, select the group
      vim.ui.select(bib_files, {
        prompt = "Select citation group:",
        format_item = function(item)
          return item.display
        end,
      }, function(selected_group)
        if not selected_group then
          return
        end

        -- Then show citations from that group
        local citations = {}
        local file = io.open(selected_group.path, "r")

        if not file then
          vim.notify("Cannot open " .. selected_group.name .. " bibliography", vim.log.levels.ERROR)
          return
        end

        local current_key = nil
        local current_title = nil

        for line in file:lines() do
          local key = line:match("^@%w+{([^,]+),")
          if key then
            current_key = key
            current_title = nil
          end

          local title = line:match("title%s*=%s*{(.-)}")
          if title and current_key then
            current_title = title:gsub("^{", ""):gsub("}$", "")
            table.insert(citations, {
              key = current_key,
              title = current_title,
              display = current_key .. " - " .. current_title,
            })
            current_key = nil
            current_title = nil
          end
        end
        file:close()

        if #citations == 0 then
          vim.notify("No citations found in " .. selected_group.name, vim.log.levels.WARN)
          return
        end

        -- Show citations from selected group
        vim.ui.select(citations, {
          prompt = "Select citation from " .. selected_group.name .. " (" .. #citations .. " available):",
          format_item = function(item)
            return item.display
          end,
        }, function(choice)
          if choice then
            local citation = "\\cite{" .. choice.key .. "}"
            vim.api.nvim_put({ citation }, "c", false, true)
            vim.notify("Inserted: " .. citation .. " from " .. selected_group.name, vim.log.levels.INFO)
          end
        end)
      end)
    end

    -- Make citation picker function globally accessible
    _G.vimtex_pick_citation = pick_citation

    -- Set custom keymaps for LaTeX files
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "tex",
      callback = function()
        local opts = { buffer = true, silent = true }

        -- VimTeX keymaps
        vim.keymap.set(
          "n",
          "<leader>ll",
          "<cmd>VimtexCompile<CR>",
          vim.tbl_extend("force", opts, { desc = "Toggle LaTeX compilation" })
        )
        vim.keymap.set(
          "n",
          "<leader>lv",
          "<cmd>VimtexView<CR>",
          vim.tbl_extend("force", opts, { desc = "View PDF in external window (Okular)" })
        )
        vim.keymap.set(
          "n",
          "<leader>ls",
          "<cmd>VimtexStop<CR>",
          vim.tbl_extend("force", opts, { desc = "Stop compilation" })
        )
        vim.keymap.set(
          "n",
          "<leader>lc",
          "<cmd>VimtexClean<CR>",
          vim.tbl_extend("force", opts, { desc = "Clean auxiliary files" })
        )
        vim.keymap.set(
          "n",
          "<leader>le",
          "<cmd>VimtexErrors<CR>",
          vim.tbl_extend("force", opts, { desc = "Show LaTeX errors" })
        )
        vim.keymap.set(
          "n",
          "<leader>lt",
          "<cmd>VimtexTocToggle<CR>",
          vim.tbl_extend("force", opts, { desc = "Toggle table of contents" })
        )
        vim.keymap.set(
          "n",
          "<leader>lm",
          "<cmd>VimtexImapsDisable<CR>",
          vim.tbl_extend("force", opts, { desc = "Disable insert mode mappings" })
        )

        -- Custom PDF viewing options and citation picker
        vim.keymap.set("n", "<leader>lp", function()
          open_pdf_in_tmux_pane(get_pdf_path())
        end, vim.tbl_extend("force", opts, { desc = "View PDF in tmux pane" }))

        vim.keymap.set(
          "n",
          "<leader>lw",
          "<cmd>VimtexView<CR>",
          vim.tbl_extend("force", opts, { desc = "View PDF in external window (same as <leader>lv)" })
        )

        -- Citation pickers with forced override for linter conflicts
        vim.schedule(function()
          -- Force clear any conflicting mappings that linters might set
          pcall(vim.keymap.del, "n", "<leader>lz", { buffer = true })
          pcall(vim.keymap.del, "n", "<leader>lg", { buffer = true })
          pcall(vim.keymap.del, "n", "<leader>lG", { buffer = true })

          -- Then immediately re-set our keymaps
          vim.keymap.set(
            "n",
            "<leader>lz",
            pick_citation,
            vim.tbl_extend("force", opts, { desc = "Search and insert citation (original single file)" })
          )
          vim.keymap.set(
            "n",
            "<leader>lg",
            pick_citation_with_groups,
            vim.tbl_extend("force", opts, { desc = "Citations with groups (all)" })
          )
          vim.keymap.set(
            "n",
            "<leader>lG",
            pick_citation_by_group,
            vim.tbl_extend("force", opts, { desc = "Citations by group (select group first)" })
          )
        end)

        -- Navigation
        vim.keymap.set(
          "n",
          "]]",
          "<cmd>VimtexSectionNext<CR>",
          vim.tbl_extend("force", opts, { desc = "Next section" })
        )

        vim.keymap.set(
          "n",
          "[[",
          "<cmd>VimtexSectionPrev<CR>",
          vim.tbl_extend("force", opts, { desc = "Previous section" })
        )

        -- Text objects (these work in visual and operator-pending modes)
        vim.keymap.set({ "x", "o" }, "ae", "<plug>(vimtex-ae)", opts)
        vim.keymap.set({ "x", "o" }, "ie", "<plug>(vimtex-ie)", opts)
        vim.keymap.set({ "x", "o" }, "a$", "<plug>(vimtex-a$)", opts)
        vim.keymap.set({ "x", "o" }, "i$", "<plug>(vimtex-i$)", opts)
        vim.keymap.set({ "x", "o" }, "ad", "<plug>(vimtex-ad)", opts)
        vim.keymap.set({ "x", "o" }, "id", "<plug>(vimtex-id)", opts)
      end,
    })
  end,
}
