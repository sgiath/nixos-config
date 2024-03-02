---@type MappingsTable
local M = {}

M.general = {
  n = {
    [";"] = { ":", "enter command mode", opts = { nowait = true } },

    --  format with conform
    ["<leader>fm"] = {
      function()
        require("conform").format()
      end,
      "formatting",
    },

    ["<leader>fn"] = { ":ObsidianQuickSwitch<CR>", "Search Obsidian" },
  },
  v = {
    [";"] = { ":", "enter command mode", opts = { nowait = true } },
    [">"] = { ">gv", "indent" },
  },
}

-- more keybinds!

return M
