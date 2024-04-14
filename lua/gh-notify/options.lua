return {
  polling = true,
  polling_interval = 10000, --60000 * 5,
  ---@param notifications table Message
  on_messages = function(notifications, all_notifications)
    -- First batch of messages
    if #all_notifications == #notifications and #notifications > 3 then
      vim.notify(" " .. #notifications .. " unread notifications")
      return
    end

    for key, value in pairs(notifications) do
      vim.notify(" " .. value.message)
    end
  end,
}
