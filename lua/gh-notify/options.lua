return {
  polling = true,
  polling_interval = 60000,
  ---@param value Message
  on_message = function(value)
    vim.notify(value.message)
  end,
}
