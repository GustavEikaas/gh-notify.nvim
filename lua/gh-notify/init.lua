local M = {
  opts = {
    status = {
      update_interval = 60000,
    }
  },
  state = {
    messages = {}
  }
}
function M:start()
  local function force_update()
    local cmd = "gh api /notifications"
    vim.fn.jobstart(cmd, {
      on_stdout = self.on_event,
      stdout_buffered = true,
    })
  end

  local timer = vim.loop.new_timer()
  timer:start(1000, M.opts.status.update_interval, vim.schedule_wrap(force_update))
end

local function is_id_present(object, table)
  for _, value in ipairs(table) do
    if object.id == value then
      return true
    end
  end
  return false
end
local function getPrStateChangeNotification(title, repo)
  return "Update on pull request" .. "\n\n" .. title .. "\n" .. repo
end
local function getIssueStateChangeNotification(title, repo)
  return "Update on issue" .. "\n\n" .. title .. "\n" .. repo
end

local function notify_on_state_change(type, title, repoName)
  -- TODO: Extract pr number from url
  -- url = https://api.github.com/repos/GustavEikaas/nvim-config/pulls/16
  -- local prUrl = value.subject.url
  if type == "PullRequest" then
    vim.notify(getPrStateChangeNotification(title, repoName))
    return
  else
    vim.notify(getIssueStateChangeNotification(title, repoName))
    return
  end
end
local function notify_on_mention(value, repoName, type)
  local comment_url = value.subject.latest_comment_url
  local handle = io.popen("gh api " .. comment_url)
  if handle == nil then
    error("Failed to execute")
  end
  local comment = vim.fn.json_decode(handle:read("*a"))
  handle:close()
  local notification = comment.user.login ..
      " mentioned you" .. "\n\n" .. comment.body .. "\n" .. repoName .. "@" .. type
  vim.notify(notification, "info", { timeout = false })
end

function M:on_event(data)
  if data[1] == "" or data[1] == nil then
    return
  end
  local notifications = vim.fn.json_decode(data[1])
  for _, value in pairs(notifications) do
    if is_id_present(value, M.state.messages) then
      return
    end
    table.insert(M.state.messages, value.id)
    local reason = value.reason
    -- PullRequest|Issue
    local type = value.subject.type
    local repoName = value.repository.name
    if reason == "mention" then
      return notify_on_mention(value, repoName, type)
    elseif reason == "state_change" then
      return notify_on_state_change(type, value.subject.title, repoName)
    else
      local notification = " " .. reason .. "\n\n" .. "\n" .. repoName .. "@" .. type
      vim.notify(notification)
    end
  end
end

return M
