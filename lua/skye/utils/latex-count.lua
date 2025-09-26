-- latex-count.lua
-- LaTeX counting utilities for content analysis
-- Requires vimtex to be loaded

local M = {}

-- Helper function to check if vimtex is available
local function check_vimtex()
  if not vim.b.vimtex then
    vim.notify("VimTeX not available in current buffer", vim.log.levels.ERROR)
    return false
  end
  return true
end

-- Helper function to get buffer content as string
local function get_buffer_content(start_line, end_line, start_col, end_col)
  local lines

  if start_line and end_line then
    -- Visual selection mode - get only selected lines
    lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    -- Handle partial line selections
    if start_col and end_col and #lines > 0 then
      if #lines == 1 then
        -- Single line selection
        lines[1] = lines[1]:sub(start_col, end_col)
      else
        -- Multi-line selection
        lines[1] = lines[1]:sub(start_col) -- First line from start_col to end
        lines[#lines] = lines[#lines]:sub(1, end_col) -- Last line from start to end_col
      end
    end
  else
    -- Normal mode - get entire buffer
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  return table.concat(lines, "\n")
end

-- Helper function to get visual selection bounds
local function get_visual_selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then -- \22 is Ctrl-V
    return nil -- Not in visual mode
  end

  -- Get visual selection marks
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

  -- For line-wise visual mode, select entire lines
  if mode == "V" then
    start_col = 1
    end_col = nil -- Will be handled by getting full last line
  end

  return start_line, end_line, start_col, end_col
end

-- Remove LaTeX comments
local function remove_comments(text)
  local lines = {}
  for line in text:gmatch("[^\n]*") do
    -- Find the first unescaped % character
    local comment_start = nil
    local i = 1
    while i <= #line do
      if line:sub(i, i) == "%" then
        -- Check if it's escaped by counting preceding backslashes
        local backslash_count = 0
        local j = i - 1
        while j > 0 and line:sub(j, j) == "\\" do
          backslash_count = backslash_count + 1
          j = j - 1
        end
        -- If even number of backslashes (including 0), the % is not escaped
        if backslash_count % 2 == 0 then
          comment_start = i
          break
        end
      end
      i = i + 1
    end

    -- Remove everything from the first unescaped % to end of line
    if comment_start then
      line = line:sub(1, comment_start - 1)
    end

    table.insert(lines, line)
  end

  return table.concat(lines, "\n")
end

-- Remove LaTeX commands and environments to exclude from word count
local function clean_latex_for_word_count(text)
  local cleaned = text

  -- Remove comments first
  cleaned = remove_comments(cleaned)

  -- Remove bibliography sections entirely
  cleaned = cleaned:gsub("\\begin{thebibliography}.-\\end{thebibliography}", "")
  cleaned = cleaned:gsub("\\bibliography{.-}", "")
  cleaned = cleaned:gsub("\\printbibliography.-\n", "")

  -- Remove citations but keep the text flow
  cleaned = cleaned:gsub("\\cite[tp]?%*?%b[]?%b{}", "")
  cleaned = cleaned:gsub("\\[Cc]ite[tp]?%*?%b[]?%b{}", "")

  -- Remove common LaTeX commands that don't contribute to content
  cleaned = cleaned:gsub("\\label%b{}", "")
  cleaned = cleaned:gsub("\\ref%b{}", "")
  cleaned = cleaned:gsub("\\pageref%b{}", "")
  cleaned = cleaned:gsub("\\index%b{}", "")

  -- Remove document structure commands but keep their content
  cleaned = cleaned:gsub("\\documentclass%b[]?%b{}", "")
  cleaned = cleaned:gsub("\\usepackage%b[]?%b{}", "")
  cleaned = cleaned:gsub("\\author%b{}", "")
  cleaned = cleaned:gsub("\\title%b{}", "")
  cleaned = cleaned:gsub("\\date%b{}", "")

  -- Remove begin/end document but keep content
  cleaned = cleaned:gsub("\\begin{document}", "")
  cleaned = cleaned:gsub("\\end{document}", "")

  -- Remove math environments (equations don't count as words)
  cleaned = cleaned:gsub("\\begin{equation%*?}.-\\end{equation%*?}", "")
  cleaned = cleaned:gsub("\\begin{align%*?}.-\\end{align%*?}", "")
  cleaned = cleaned:gsub("\\begin{gather%*?}.-\\end{gather%*?}", "")
  cleaned = cleaned:gsub("$$.-$$", "") -- display math
  cleaned = cleaned:gsub("$.-%$", "") -- inline math

  -- Remove table and tabular environments (structure, not content)
  cleaned = cleaned:gsub("\\begin{table%*?}.-\\end{table%*?}", function(match)
    -- Extract only caption from table
    local caption = match:match("\\caption%b{}")
    return caption or ""
  end)

  -- Remove figure environments but keep captions
  cleaned = cleaned:gsub("\\begin{figure%*?}.-\\end{figure%*?}", function(match)
    -- Extract caption from figure
    local caption = match:match("\\caption%b{}")
    if caption then
      -- Remove the \caption{} wrapper
      return caption:gsub("\\caption%b{}", function(cap)
        return cap:sub(10, -2) -- Remove \caption{ and }
      end)
    end
    return ""
  end)

  -- Keep caption content but remove command
  cleaned = cleaned:gsub("\\caption%b{}", function(cap)
    return cap:sub(10, -2) -- Remove \caption{ and }
  end)

  -- Remove remaining common formatting commands but keep content
  cleaned = cleaned:gsub("\\textbf%b{}", function(match)
    return match:sub(8, -2)
  end)
  cleaned = cleaned:gsub("\\textit%b{}", function(match)
    return match:sub(8, -2)
  end)
  cleaned = cleaned:gsub("\\emph%b{}", function(match)
    return match:sub(7, -2)
  end)

  -- Remove section commands but keep titles
  cleaned = cleaned:gsub("\\[sub]*section%*?%b{}", function(match)
    return match:match("%b{}"):sub(2, -2)
  end)

  -- Remove remaining simple commands
  cleaned = cleaned:gsub("\\[a-zA-Z]+%*?%b{}", "")
  cleaned = cleaned:gsub("\\[a-zA-Z]+%*?", "")

  -- Clean up extra whitespace
  cleaned = cleaned:gsub("\n+", "\n")
  cleaned = cleaned:gsub(" +", " ")

  return cleaned
end

-- Count words in cleaned text
local function count_words(text)
  if not text or text == "" then
    return 0
  end

  -- Split by whitespace and count non-empty strings
  local words = {}
  for word in text:gmatch("%S+") do
    table.insert(words, word)
  end

  return #words
end

-- Count characters
local function count_characters(text, include_spaces)
  if not text then
    return 0
  end

  if include_spaces then
    return #text
  else
    return #(text:gsub("%s", ""))
  end
end

-- Count citations and references
local function count_citations(text)
  if not text then
    return { commands = 0, total = 0, unique = 0 }
  end

  -- Remove comments first to avoid counting citations in comments
  local cleaned_text = remove_comments(text)

  local citation_commands = {}
  local all_citation_instances = {}
  local unique_refs = {}

  -- Simple pattern to match \cite{...}
  for cite in cleaned_text:gmatch("\\cite[^{]*%b{}") do
    table.insert(citation_commands, cite)

    -- Extract the content between braces
    local keys_part = cite:match("{([^}]*)}")
    if keys_part then
      -- Split by comma and clean each key
      for key in keys_part:gmatch("[^,]+") do
        -- Trim whitespace from each key
        key = key:match("^%s*(.-)%s*$")
        if key and key ~= "" then
          table.insert(all_citation_instances, key) -- Each individual citation
          unique_refs[key] = true -- Track unique refs
        end
      end
    end
  end

  local unique_count = 0
  for _ in pairs(unique_refs) do
    unique_count = unique_count + 1
  end

  return {
    commands = #citation_commands, -- Number of \cite{} commands
    total = #all_citation_instances, -- Total individual citations
    unique = unique_count, -- Unique reference keys
  }
end

-- Main word count function
function M.word_count()
  if not check_vimtex() then
    return
  end

  local content = get_buffer_content()
  local cleaned = clean_latex_for_word_count(content)
  local word_count = count_words(cleaned)

  vim.notify(string.format("Content word count: %d words", word_count), vim.log.levels.INFO)
end

-- Character count function
function M.character_count()
  if not check_vimtex() then
    return
  end

  local content = get_buffer_content()
  local cleaned = clean_latex_for_word_count(content)
  local char_count_with_spaces = count_characters(cleaned, true)
  local char_count_without_spaces = count_characters(cleaned, false)

  vim.notify(
    string.format(
      "Content characters: %d (with spaces), %d (without spaces)",
      char_count_with_spaces,
      char_count_without_spaces
    ),
    vim.log.levels.INFO
  )
end

-- Citation count function
function M.citation_count()
  if not check_vimtex() then
    return
  end

  local content = get_buffer_content()
  local citation_stats = count_citations(content)

  vim.notify(
    string.format(
      "Citations: %d total instances, %d unique references (%d commands)",
      citation_stats.total,
      citation_stats.unique,
      citation_stats.commands
    ),
    vim.log.levels.INFO
  )
end

-- Comprehensive count function for selections
function M.comprehensive_count_selection(start_line, end_line, start_col, end_col)
  if not check_vimtex() then
    return
  end

  local content = get_buffer_content(start_line, end_line, start_col, end_col)
  local cleaned = clean_latex_for_word_count(content)
  local word_count = count_words(cleaned)
  local char_count_with_spaces = count_characters(cleaned, true)
  local char_count_without_spaces = count_characters(cleaned, false)
  local citation_stats = count_citations(content)

  local message = string.format(
    "LaTeX Selection Statistics:\n"
      .. "• Words: %d (content text + figure captions)\n"
      .. "• Characters: %d (with spaces), %d (without)\n"
      .. "• Citations: %d total instances, %d unique references (%d commands)",
    word_count,
    char_count_with_spaces,
    char_count_without_spaces,
    citation_stats.total,
    citation_stats.unique,
    citation_stats.commands
  )

  vim.notify(message, vim.log.levels.INFO)
end

-- Comprehensive count function (now simplified for document-wide counting)
function M.comprehensive_count()
  if not check_vimtex() then
    return
  end

  local content = get_buffer_content()
  local cleaned = clean_latex_for_word_count(content)
  local word_count = count_words(cleaned)
  local char_count_with_spaces = count_characters(cleaned, true)
  local char_count_without_spaces = count_characters(cleaned, false)
  local citation_stats = count_citations(content)

  local message = string.format(
    "LaTeX Document Statistics:\n"
      .. "• Words: %d (content text + figure captions)\n"
      .. "• Characters: %d (with spaces), %d (without)\n"
      .. "• Citations: %d total instances, %d unique references (%d commands)",
    word_count,
    char_count_with_spaces,
    char_count_without_spaces,
    citation_stats.total,
    citation_stats.unique,
    citation_stats.commands
  )

  vim.notify(message, vim.log.levels.INFO)
end

-- Setup function to create keymaps
function M.setup(opts)
  opts = opts or {}

  -- Single keymap for comprehensive count
  local keymap = opts.keymap or "<leader>la"

  -- Set up keymap for LaTeX files using FileType autocmd (more reliable)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "tex",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()

      -- Add a small delay to ensure vimtex is loaded
      vim.defer_fn(function()
        -- Normal mode keymap
        vim.keymap.set("n", keymap, M.comprehensive_count, {
          buffer = buf,
          desc = "LaTeX document analysis (words, chars, citations)",
        })

        -- Visual mode keymap
        vim.keymap.set("v", keymap, M.comprehensive_count, {
          buffer = buf,
          desc = "LaTeX selection analysis (words, chars, citations)",
        })
      end, 100)
    end,
  })
end

return M
