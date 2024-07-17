return {
  "williamboman/mason.nvim",
  dependencies = {
    "williamboman/mason-lspconfig.nvim",  -- for installing language servers
    "WhoIsSethDaniel/mason-tool-installer.nvim",  -- helpful for installing stuff that isn't language servers - such as formatters
  },
  config = function()
    -- import mason
    local mason = require("mason")

    -- import mason-lspconfig
    local mason_lspconfig = require("mason-lspconfig")

    local mason_tool_installer = require("mason-tool-installer")

    -- enable mason and configure icons
    mason.setup({
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    })

    mason_lspconfig.setup({
      -- list of servers for mason to install
      ensure_installed = {
        "tsserver",
        "html",
        "cssls",
        "tailwindcss",
        "svelte",
        "lua_ls",
        "graphql",
        "emmet_ls",
        "prismals",
        "pyright",
        "julials",
        "rust_analyzer",
        "bashls",
      },
    })

    mason_tool_installer.setup({
      ensure_installed = {
        "prettier", -- prettier formatter
        "stylua", -- lua formatter
        "isort", -- python formatter
        "black", -- python formatter
        "pylint", -- pthon linter
        "eslint_d", -- js linter
        "beautysh", -- bash formatter
        "shellcheck", -- bash linter
        "rustfmt", -- rust formatter
        -- no formatter for  Julia, also need to edit formatting.lua
      },
    })
  end,
}
