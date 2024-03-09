return {
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = false,
    -- ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "hrsh7th/nvim-cmp",
    },
    opts = {
      workspaces = {
        {
          name = "personal",
          path = "~/notes/sgiath",
        },
        {
          name = "the expanse",
          path = "~/notes/expanse",
        },
        {
          name = "DnD",
          path = "~/notes/dnd",
        },
      },
      notes_subdir = "notes",
      daily_notes = {
        folder = "periodic",
        date_format = "%Y-%m-%d",
        template = "daily.md",
      },
      templates = {
        subdir = "_templates",
        date_format = "%Y-%m-%d",
        time_format = "%H%M Zulu",
      },
      open_app_foreground = true,
      open_notes_in = "vsplit",
      attachments = {
        img_folder = "files/imgs",
      },
      mappings = {
        -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
        ["gf"] = {
          action = function()
            return require("obsidian").util.gf_passthrough()
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
      },

      -- do not prepend notes with timestamp
      note_id_func = function(title)
        -- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
        -- In this case a note with the title 'My new note' will be given an ID that looks
        -- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'
        local suffix = ""
        if title ~= nil then
          -- If title is given, transform it into valid file name.
          suffix = title:gsub(" ", "_"):gsub("[^A-Za-z0-9_]", ""):lower()
        else
          -- If title is nil, just add 4 random uppercase letters to the suffix.
          for _ = 1, 4 do
            suffix = suffix .. string.char(math.random(65, 90))
          end
        end
        return suffix
      end,

      -- correctly open HTTP links
      follow_url_func = function(url)
        -- Open the URL in the default web browser.
        vim.fn.jobstart { "xdg-open", url }
      end,
    },
  },
}
