local messages = require("gh-notify.messages")

--- @class Context
--- @field repoName string
--- @field type "PullRequest"|"Issue"
--- @field reason string
--- @field is_from_this_repo boolean

--- @class Message
--- @field context Context
--- @field id string
--- @field message string
--- @field url string
--- @field number number | nil
--- @field display string Used for telescope
--- @field type_icon string
--- @field reason_icon string

local M = {
  opts = require("gh-notify.options"),
  state = {
    messages = {}
  }
}

function M:start()
  local timer = vim.loop.new_timer()
  timer:start(1000, M.opts.polling_interval, vim.schedule_wrap(self.refresh))
end

---@param on_settled function|nil callback to be invoked when refresh is finished
function M.refresh(on_settled)
  local cmd = "gh api /notifications"
  vim.fn.jobstart(cmd, {
    on_stdout = M.on_event,
    stdout_buffered = true,
    on_exit = function()
      if on_settled then
        on_settled()
      end
    end
  })
end

local function is_id_present(object, table)
  for _, value in ipairs(table) do
    if object.id == value.id then
      return true
    end
  end
  return false
end

local function extract_pr_number_from_url(url)
  local number = string.match(url, "/(%d+)$")
  return tonumber(number)
end

---@param title string
---@param context Context
---@return Message
local function state_change(value, title, context)
  if context.type == "PullRequest" then
    local prNumber = extract_pr_number_from_url(value.subject.url)
    return {
      number = prNumber,
      url = value.subject.url,
      message = messages.pr_state_change(prNumber, title, context),
      display = title
    }
  else
    return {
      number = nil,
      url = value.subject.url,
      messages = messages.issue_state_change(title, context),
      display = title
    }
  end
end

local function getIconByReason(type)
  if type == "review_requested" then
    return ""
  end
  return ""
end


---
---@param context Context
---@param id string
---@return Message
local function getDefaultMessage(context, id)
  return {
    context = context,
    id = id,
    message = "",
    display = "",
    reason_icon = getIconByReason(context.reason),
    type_icon = context.type == "PullRequest" and "" or context.type == "Issue" and "" or ""
  }
end


---@param msg Message
---@param mention Message
---@return Message
local function update_message(msg, mention)
  msg.number = mention.number
  msg.message = mention.message
  msg.url = mention.url
  msg.display = mention.display
  return msg
end



---
---@param value any
---@param context Context
---@return Message
local function message_router(value, context)
  local msg = getDefaultMessage(context, value.id)

  local reason = context.reason
  if reason == "mention" then
    -- You were mentioned
    local mention = messages.mention(value, context)
    return update_message(msg, mention)
  elseif reason == "state_change" then
    -- PR or Issue state changed
    local change = state_change(value, value.subject.title, context)
    return update_message(msg, change)
  elseif reason == "approval_requested" then
    --You were requested to review and approve a deployment.
    local approval = messages.approval_requested(value, value.subject.title, context)
    return update_message(msg, approval)
  elseif reason == "assign" then
    -- You were assigned to something
    local assigned = messages.assigned(value, value.subject.title, context)
    return update_message(msg, assigned)
  elseif reason == "author" then
    -- You created the thread
    --TODO:
  elseif reason == "comment" then
    -- You commented on the thread
    -- TODO:
  elseif reason == "ci_activity" then
    -- A github actions workflow run that you triggered completed
    -- TODO:
  elseif reason == "manual" then
    -- You subscribed to the thread (via issue or pr)
    -- TODO:
  elseif reason == "review_requested" then
    -- You, or a team you're a member of, were requested to review a pull request.
    local review = messages.review_requested(value, value.subject.title, context)
    return update_message(msg, review)
  elseif reason == "security_alert" then
    -- GitHub discovered a security vulnerability in your repository.
    local security = messages.security_alert(value.subject.title, context)
    return update_message(msg, security)
  elseif reason == "team_mention" then
    -- You were on a team that was mentioned.
    local team_mention = messages.team_mention(value.subject.title, context)
    return update_message(msg, team_mention)
  elseif reason == "subscribed" then
    -- You're watching the repository.
  end

  return update_message(msg,
    {
      display = "unknown",
      number = nil,
      message = "unhandled notification",
      url = "",
      context = context,
      id = value.id,
      type_icon =
      "",
      reason_icon = ""
    })
end


local function filterNotifications(notifications)
  local newNotifications = {}
  for _, value in pairs(notifications) do
    if is_id_present(value, M.state.messages) == false then
      table.insert(newNotifications, value)
    end
  end
  return newNotifications
end


local function extract_repository_name(url)
  local lastSlashIndex = url:find("/[^/]*$")
  if lastSlashIndex then
    return url:sub(lastSlashIndex + 1):gsub(".git", "")
  else
    return nil
  end
end

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function M:on_event(data)
  if data[1] == "" or data[1] == nil then
    return
  end
  local notifications = vim.fn.json_decode(data[1])
  local repo_url = require("gh-notify.utils").executeCommand("git config --get remote.origin.url")
  local repo_name = extract_repository_name(repo_url)
  local newNotifications = filterNotifications(notifications)

  for _, value in pairs(newNotifications) do
    local context = {
      reason = value.reason,
      type = value.subject.type,
      repoName = value.repository.name,
      is_from_this_repo = trim(repo_name) == trim(value.repository.name)
    }
    local msg = message_router(value, context)
    table.insert(M.state.messages, msg)
    M.opts.on_message(msg)
  end
end

---
---@param filter function|nil function to filter out messages. return true to keep message
M.list_messages = function(filter)
  local filtered_messages = {}
  for key, value in pairs(M.state.messages) do
    if value.context.is_from_this_repo == true and (filter == nil or filter(value)) then
      table.insert(filtered_messages, value)
    end
  end
  if #filtered_messages == 0 then
    vim.notify("No notifications from this repo")
    return
  end
  require("gh-notify.telescope").picker(nil, filtered_messages, function(selected_entry)
    if selected_entry.context.type == "PullRequest" and selected_entry.number ~= nil then
      vim.cmd("Octo pr edit " .. selected_entry.number)
    elseif selected_entry.context.type == "Issue" and selected_entry.number ~= nil then
      vim.cmd("Octo issue edit " .. selected_entry.number)
    else
      os.execute("start " .. selected_entry.url)
    end
  end, "Notifications")
end

local function merge_tables(table1, table2)
  local merged = {}
  for k, v in pairs(table1) do
    merged[k] = v
  end
  for k, v in pairs(table2) do
    merged[k] = v
  end
  return merged
end

M.setup = function(opts)
  M.opts = merge_tables(require("gh-notify.options"), opts or {})
  if M.opts.polling then
    M:start()
  end

  local commands = {
    list = function()
      M.list_messages()
    end,
    reviews = function()
      M.list_messages(function(i)
        local reason = i.context.reason
        return reason == "review_requested"
      end)
    end,
    refresh = function()
      M.refresh()
    end
  }

  vim.api.nvim_create_user_command('GhNotify',
    function(commandOpts)
      local subcommand = commandOpts.fargs[1]
      local func = commands[subcommand]
      if func then
        func()
      else
        print("Invalid subcommand:", subcommand)
      end
    end,
    {
      nargs = 1,
      complete = function()
        local completion = {}
        for key, _ in pairs(commands) do
          table.insert(completion, key)
        end
        return completion
      end,
    }
  )
end

return M
