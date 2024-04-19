local M = {}

---
---@param value Message
local function generate_display(value)
  return string.format("%s [%s] #%d %s |%s |%s", value.type_icon, value.context.reason, value.number or 0, value.display,
    value.context.full_name, value.context.timestamp)
end

local function read_notification(value)
  require("gh-notify.utils").executeCommand("gh api --method PATCH /notifications/threads/" .. value.id)
end

---@param bufnr nil
---@param options table
---@param on_select_cb function
---@param title any
M.picker = function(bufnr, options, on_select_cb, title)
  if (#options == 0) then
    error("No options provided, minimum 1 is required")
    return
  end

  local picker = require('telescope.pickers').new(bufnr, {
    prompt_title = title,
    finder = require('telescope.finders').new_table {
      results = options,
      --TODO: make it pretty
      entry_maker = function(entry)
        return {
          display = generate_display(entry),
          value = entry,
          ordinal = entry.display
        }
      end,
    },
    sorter = require('telescope.config').values.generic_sorter({}),
    attach_mappings = function(_, map)
      map('i', '<CR>', function(prompt_bufnr)
        local selection = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)
        on_select_cb(selection.value)
        read_notification(selection.value)
      end)
      map("n", "d", function()
        local selection = require('telescope.actions.state').get_selected_entry()
        read_notification(selection.value)
      end)
      map('n', '<CR>', function(prompt_bufnr)
        local selection = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)
        on_select_cb(selection.value)
        read_notification(selection.value)
      end)
      map("n", "q", function(prompt_bufnr)
        require("telescope.actions").close(prompt_bufnr)
      end)
      return true
    end,
  })
  picker:find()
end

return M
