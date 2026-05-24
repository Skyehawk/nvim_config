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

    -- Enhanced citation picker that handles multiple bib files with better search prioritization
    local function pick_citation_with_groups()
      local bib_base_path = "/home/skye/Documents/mendeley_groups/"
      local fallback_file = "/home/skye/Documents/bibliography.bib/library.bib"

      -- Find all .bib files in the directory
      local bib_files = {}
      local handle = io.popen("find " .. bib_base_path .. " -name '*.bib' 2>/dev/null")
      if handle then
        for file in handle:lines() do
          if vim.fn.filereadable(file) == 1 then
            table.insert(bib_files, file)
          end
        end
        handle:close()
      end

      -- Add fallback file if it exists
      if vim.fn.filereadable(fallback_file) == 1 then
        table.insert(bib_files, fallback_file)
      end

      if #bib_files == 0 then
        vim.notify("No readable .bib files found in " .. bib_base_path .. " or " .. fallback_file, vim.log.levels.ERROR)
        return
      end

      local all_citations = {}

      -- Parse each bib file
      for _, bib_file in ipairs(bib_files) do
        local file = io.open(bib_file, "r")
        if file then
          -- Extract group name from filename
          local group_name = bib_file:match("([^/]+)%.bib$") or "Unknown"
          group_name = group_name:gsub("_", " "):gsub("^%l", string.upper)

          local current_key = nil
          local current_title = nil
          local current_author = nil
          local current_year = nil
          local current_keywords = nil

          for line in file:lines() do
            -- Look for citation keys
            local key = line:match("^@%w+{([^,]+),")
            if key then
              if current_key and (current_title or current_author) then
                -- Save previous entry with comprehensive search text
                local search_components = {
                  current_key,
                  current_title or "",
                  current_author or "",
                  current_year or "",
                  current_keywords or "",
                  group_name,
                }

                local display_info = current_title or current_author or "No title"
                if current_year then
                  display_info = display_info .. " (" .. current_year .. ")"
                end

                table.insert(all_citations, {
                  key = current_key,
                  title = current_title or "No title",
                  author = current_author or "No author",
                  year = current_year or "",
                  keywords = current_keywords or "",
                  group = group_name,
                  display = string.format("[%s] %s - %s", group_name, current_key, display_info),
                  search_text = string.lower(table.concat(search_components, " ")),
                  sort_key = group_name .. "|" .. current_key,
                })
              end
              current_key = key
              current_title = nil
              current_author = nil
              current_year = nil
              current_keywords = nil
            end

            -- Look for titles
            local title = line:match("title%s*=%s*{(.-)}")
            if title and current_key then
              current_title = title:gsub("^{+", ""):gsub("}+$", "")
            end

            -- Look for authors (as backup if no title)
            local author = line:match("author%s*=%s*{(.-)}")
            if author and current_key and not current_author then
              current_author = author:gsub("^{+", ""):gsub("}+$", ""):match("^([^,]+)") -- Just first author
            end

            -- Look for year
            local year = line:match("year%s*=%s*{?(%d%d%d%d)}?") or line:match("year%s*=%s*(%d%d%d%d)")
            if year and current_key then
              current_year = year
            end

            -- Look for keywords (can be on multiple lines, so we'll collect them)
            local keywords = line:match("keywords%s*=%s*{(.-)}")
            if keywords and current_key then
              -- Clean up keywords: remove extra braces, split on common separators
              keywords = keywords:gsub("^{+", ""):gsub("}+$", "")
              keywords = keywords:gsub("[,;]", " ") -- Replace separators with spaces
              current_keywords = keywords
            end
          end

          -- Don't forget the last entry
          if current_key and (current_title or current_author) then
            local search_components = {
              current_key,
              current_title or "",
              current_author or "",
              current_year or "",
              current_keywords or "",
              group_name,
            }

            local display_info = current_title or current_author or "No title"
            if current_year then
              display_info = display_info .. " (" .. current_year .. ")"
            end

            table.insert(all_citations, {
              key = current_key,
              title = current_title or "No title",
              author = current_author or "No author",
              year = current_year or "",
              keywords = current_keywords or "",
              group = group_name,
              display = string.format("[%s] %s - %s", group_name, current_key, display_info),
              search_text = string.lower(table.concat(search_components, " ")),
              sort_key = group_name .. "|" .. current_key,
            })
          end

          file:close()
        end
      end

      if #all_citations == 0 then
        vim.notify("No citations found in any bibliography files", vim.log.levels.WARN)
        return
      end

      -- Custom sorting function that prioritizes matches
      local function sort_citations_by_relevance(citations, search_term)
        if not search_term or search_term == "" then
          -- Default sort by group, then by citation key
          table.sort(citations, function(a, b)
            return a.sort_key < b.sort_key
          end)
          return citations
        end

        search_term = string.lower(search_term)

        -- Score each citation based on match quality
        for _, citation in ipairs(citations) do
          local score = 0
          local key_lower = string.lower(citation.key)
          local title_lower = string.lower(citation.title)

          -- Exact key match gets highest priority
          if key_lower == search_term then
            score = score + 1000
          -- Key starts with search term
          elseif key_lower:sub(1, #search_term) == search_term then
            score = score + 500
          -- Key contains search term
          elseif key_lower:find(search_term, 1, true) then
            score = score + 100
          end

          -- Title exact match
          if title_lower:find(search_term, 1, true) then
            score = score + 50
          end

          -- Penalize longer distances from start
          local key_pos = key_lower:find(search_term, 1, true)
          if key_pos then
            score = score + (20 - key_pos) -- Closer to start = higher score
          end

          citation.relevance_score = score
        end

        -- Sort by relevance score (descending), then by original sort key
        table.sort(citations, function(a, b)
          if a.relevance_score ~= b.relevance_score then
            return a.relevance_score > b.relevance_score
          end
          return a.sort_key < b.sort_key
        end)

        return citations
      end

      -- Sort initially by default order
      sort_citations_by_relevance(all_citations, nil)

      -- Use vim.ui.select with improved sorting
      vim.ui.select(all_citations, {
        prompt = string.format("Select citation (%d from %d groups):", #all_citations, #bib_files),
        format_item = function(item)
          return item.display
        end,
        -- Note: Some fuzzy finders might override this, but we've pre-sorted for better results
      }, function(choice)
        if choice then
          local citation = "\\cite{" .. choice.key .. "}"
          vim.api.nvim_put({ citation }, "c", false, true)
          vim.notify("Inserted: " .. citation .. " from " .. choice.group, vim.log.levels.INFO)
        end
      end)
    end

    -- Group selection first, then citation with navigation
    local function pick_citation_by_group()
      local bib_base_path = "/home/skye/Documents/mendeley_groups/"
      local fallback_file = "/home/skye/Documents/bibliography.bib/library.bib"

      -- Forward declare the functions so they can call each other
      local show_group_selection
      local show_citations_from_group

      show_group_selection = function()
        -- Find all .bib files
        local bib_files = {}
        local handle = io.popen("find " .. bib_base_path .. " -name '*.bib' 2>/dev/null")
        if handle then
          for file in handle:lines() do
            if vim.fn.filereadable(file) == 1 then
              local group_name = file:match("([^/]+)%.bib$")
              if group_name then
                table.insert(bib_files, {
                  path = file,
                  name = group_name:gsub("_", " "):gsub("^%l", string.upper),
                  display = group_name:gsub("_", " "):gsub("^%l", string.upper),
                })
              end
            end
          end
          handle:close()
        end

        -- Add fallback option if it exists
        if vim.fn.filereadable(fallback_file) == 1 then
          table.insert(bib_files, {
            path = fallback_file,
            name = "All References",
            display = "All References (Main Library)",
          })
        end

        if #bib_files == 0 then
          vim.notify("No readable .bib files found", vim.log.levels.ERROR)
          return
        end

        -- First, select the group
        vim.ui.select(bib_files, {
          prompt = "Select citation group (Esc to cancel):",
          format_item = function(item)
            return item.display
          end,
        }, function(selected_group)
          if not selected_group then
            return -- User cancelled or pressed Escape
          end
          show_citations_from_group(selected_group)
        end)
      end

      show_citations_from_group = function(selected_group)
        -- Parse citations from the selected group
        local citations = {}
        local file = io.open(selected_group.path, "r")

        if not file then
          vim.notify("Cannot open " .. selected_group.name .. " bibliography", vim.log.levels.ERROR)
          return
        end

        local current_key = nil
        local current_title = nil
        local current_author = nil
        local current_year = nil
        local current_keywords = nil

        for line in file:lines() do
          local key = line:match("^@%w+{([^,]+),")
          if key then
            if current_key and (current_title or current_author) then
              local display_info = current_title or current_author or "No title"
              if current_year then
                display_info = display_info .. " (" .. current_year .. ")"
              end

              table.insert(citations, {
                key = current_key,
                title = current_title or "No title",
                author = current_author or "No author",
                year = current_year or "",
                keywords = current_keywords or "",
                display = string.format("%s - %s", current_key, display_info),
                search_text = string.lower(table.concat({
                  current_key,
                  current_title or "",
                  current_author or "",
                  current_year or "",
                  current_keywords or "",
                }, " ")),
              })
            end
            current_key = key
            current_title = nil
            current_author = nil
            current_year = nil
            current_keywords = nil
          end

          local title = line:match("title%s*=%s*{(.-)}")
          if title and current_key then
            current_title = title:gsub("^{+", ""):gsub("}+$", "")
          end

          local author = line:match("author%s*=%s*{(.-)}")
          if author and current_key and not current_author then
            current_author = author:gsub("^{+", ""):gsub("}+$", ""):match("^([^,]+)")
          end

          -- Look for year
          local year = line:match("year%s*=%s*{?(%d%d%d%d)}?") or line:match("year%s*=%s*(%d%d%d%d)")
          if year and current_key then
            current_year = year
          end

          -- Look for keywords
          local keywords = line:match("keywords%s*=%s*{(.-)}")
          if keywords and current_key then
            keywords = keywords:gsub("^{+", ""):gsub("}+$", "")
            keywords = keywords:gsub("[,;]", " ") -- Replace separators with spaces
            current_keywords = keywords
          end
        end

        -- Last entry
        if current_key and (current_title or current_author) then
          local display_info = current_title or current_author or "No title"
          if current_year then
            display_info = display_info .. " (" .. current_year .. ")"
          end

          table.insert(citations, {
            key = current_key,
            title = current_title or "No title",
            author = current_author or "No author",
            year = current_year or "",
            keywords = current_keywords or "",
            display = string.format("%s - %s", current_key, display_info),
            search_text = string.lower(table.concat({
              current_key,
              current_title or "",
              current_author or "",
              current_year or "",
              current_keywords or "",
            }, " ")),
          })
        end

        file:close()

        if #citations == 0 then
          vim.notify("No citations found in " .. selected_group.name, vim.log.levels.WARN)
          return
        end

        -- Add navigation option at the top
        table.insert(citations, 1, {
          key = "..back",
          title = "",
          author = "",
          display = ".. (back to group selection)",
          is_navigation = true,
        })

        -- Show citations from selected group
        vim.ui.select(citations, {
          prompt = string.format(
            "Select citation from %s (%d available, Esc to go back):",
            selected_group.name,
            #citations - 1
          ),
          format_item = function(item)
            return item.display
          end,
        }, function(choice)
          if not choice then
            -- User pressed Escape - go back to group selection
            show_group_selection()
            return
          end

          if choice.is_navigation then
            -- User selected the ".." option - go back to group selection
            show_group_selection()
            return
          end

          -- User selected a citation - insert it
          local citation = "\\cite{" .. choice.key .. "}"
          vim.api.nvim_put({ citation }, "c", false, true)
          vim.notify("Inserted: " .. citation .. " from " .. selected_group.name, vim.log.levels.INFO)
        end)
      end

      -- Start the process
      show_group_selection()
    end

    -- Set custom keymaps for LaTeX files
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "tex",
      callback = function()
        local opts = { buffer = true, silent = true }

        -- VimTeX keymaps with auto-combine bibliography
        vim.keymap.set("n", "<leader>ll", function()
          -- First, combine all group files into single library.bib with smarter duplicate removal
          local group_dir = "/home/skye/Documents/mendeley_groups/"
          local output_file = "/home/skye/Documents/library.bib"
          local temp_file = "/tmp/combined_bibliography.bib"

          -- Combine all .bib files, then remove duplicate entries (not just lines)
          local combine_cmd = string.format(
            "find %s -name '*.bib' -exec cat {} \\; > %s 2>/dev/null && "
              .. 'awk \'BEGIN{RS="@"; ORS="@"} !seen[$0]++ && NF\' %s > %s && '
              .. "sed -i '1s/^@//' %s && " -- Remove leading @ from first line
              .. "mv %s %s && "
              .. "echo 'Combined and deduplicated bibliography entries' || echo 'No group files found'",
            vim.fn.shellescape(group_dir),
            vim.fn.shellescape(temp_file),
            vim.fn.shellescape(temp_file),
            vim.fn.shellescape(temp_file .. "_clean"),
            vim.fn.shellescape(temp_file .. "_clean"),
            vim.fn.shellescape(temp_file .. "_clean"),
            vim.fn.shellescape(output_file)
          )

          local result = vim.fn.system(combine_cmd)
          vim.notify("Bibliography: " .. vim.trim(result), vim.log.levels.INFO)

          -- Then proceed with normal compilation
          vim.cmd("VimtexCompile")
        end, vim.tbl_extend("force", opts, { desc = "Combine bibliography and compile LaTeX" }))

        vim.keymap.set(
          "n",
          "<leader>lv",
          "<cmd>VimtexView<CR>",
          vim.tbl_extend("force", opts, { desc = "View PDF in external window" })
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

        -- Custom PDF viewing options
        vim.keymap.set("n", "<leader>lp", function()
          open_pdf_in_tmux_pane(get_pdf_path())
        end, vim.tbl_extend("force", opts, { desc = "View PDF in tmux pane" }))

        -- Citation pickers - now without conflict workarounds
        vim.keymap.set(
          "n",
          "<leader>lz",
          pick_citation_with_groups,
          vim.tbl_extend("force", opts, { desc = "Citations with groups (all)" })
        )
        vim.keymap.set(
          "n",
          "<leader>lbg",
          pick_citation_by_group,
          vim.tbl_extend("force", opts, { desc = "Citations by group (select group first)" })
        )

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

        -- Add latex-count keymap directly for both normal and visual modes
        vim.keymap.set("n", "<leader>la", function()
          require("skye.utils.latex-count").comprehensive_count()
        end, vim.tbl_extend("force", opts, { desc = "LaTeX document analysis" }))

        vim.keymap.set("v", "<leader>la", function()
          -- Capture visual selection before exiting visual mode
          local start_pos = vim.fn.getpos("v")
          local end_pos = vim.fn.getpos(".")

          -- Ensure start comes before end
          if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
            start_pos, end_pos = end_pos, start_pos
          end

          local start_line = start_pos[2]
          local start_col = start_pos[3]
          local end_line = end_pos[2]
          local end_col = end_pos[3]

          -- Exit visual mode and call with selection bounds
          require("skye.utils.latex-count").comprehensive_count_selection(start_line, end_line, start_col, end_col)
        end, vim.tbl_extend("force", opts, { desc = "LaTeX selection analysis" }))
      end,
    })
  end,
}
