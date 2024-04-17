local messages = require("gh-notify.messages")

--- @class Repo
--- @field id number The ID of the repository
--- @field node_id string
--- @field name string The name of the repository
--- @field full_name string The full name of the repository
-- --- @field 'private' boolean Indicates if the repository is private or not
--- @field owner User The owner of the repository
--- @field html_url string The URL of the repository's HTML page
--- @field description string The description of the repository
--- @field fork boolean Indicates if the repository is a fork or not
--- @field forks_url string The URL of the repository's forks
--- @field keys_url string The URL of the repository's keys
--- @field teams_url string The URL of the repository's teams
--- @field hooks_url string The URL of the repository's hooks
--- @field events_url string The URL of the repository's events
--- @field assignees_url string The URL of the repository's assignees
--- @field branches_url string The URL of the repository's branches
--- @field tags_url string The URL of the repository's tags
--- @field blobs_url string The URL of the repository's blobs
--- @field git_tags_url string The URL of the repository's git tags
--- @field git_refs_url string The URL of the repository's git refs
--- @field trees_url string The URL of the repository's trees
--- @field statuses_url string The URL of the repository's statuses
--- @field languages_url string The URL of the repository's languages
--- @field stargazers_url string The URL of the repository's stargazers
--- @field contributors_url string The URL of the repository's contributors
--- @field subscribers_url string The URL of the repository's subscribers
--- @field subscription_url string The URL of the repository's subscription
--- @field commits_url string The URL of the repository's commits
--- @field git_commits_url string The URL of the repository's git commits
--- @field comments_url string The URL of the repository's comments
--- @field releases_url string The URL of the repository's releases
--- @field deployments_url string The URL of the repository's deployments

--- @class User
--- @field login string The username of the user e.g., "bigdaddy69"
--- @field id number The ID of the user
--- @field node_id string
--- @field avatar_url string The URL of the user's avatar image
--- @field gravatar_id string
--- @field type string The type of the user
--- @field site_admin boolean Indicates if the user is a site administrator or not

--- @class Context
--- @field repoName string -- e.g gh-notify.nvim
--- @field owner string -- e.g GustavEikaas
--- @field full_name string -- e.g GustavEikaas/gh-notify.nvim
--- @field type "PullRequest"|"Issue"|"CheckSuite"
--- @field reason string
--- @field is_from_this_repo boolean
--- @field repo Repo
--- @field timestamp string

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
    local ci = messages.ci_activity(value, context)
    return update_message(msg, ci)
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
    -- e.g someone created an issue
    local subscribed = messages.subscribed(value, context)
    return update_message(msg, subscribed)
  end

  require("gh-notify.debugger").write_to_log("Unhandled -----------------")
  require("gh-notify.debugger").write_to_log(value)
  require("gh-notify.debugger").write_to_log("---------------------------")

  return update_message(msg,
    {
      display = "unknown",
      number = nil,
      message = "unhandled notification",
      url = "",
      context = context,
      id = value.id,
      type_icon = "",
      reason_icon = "",
      timestamp = "??"
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
  if s == nil then
    return nil
  end
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function convertToRelativeTimestamp(dateTimeString)
  -- Parse the date and time components from the input string
  local year, month, day, hour, min, sec = dateTimeString:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")

  -- Convert the components to numbers
  year, month, day, hour, min, sec = tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(min),
      tonumber(sec)

  -- Convert the input time to UTC
  local utcTime = os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })

  -- Calculate the current time in UTC
  local currentTime = os.time()

  -- Calculate the time difference in seconds
  local timeDifference = currentTime - utcTime

  -- Convert the time difference to a relative timestamp
  if timeDifference < 60 then
    return "just now"
  elseif timeDifference < 3600 then
    local minutes = math.floor(timeDifference / 60)
    return minutes .. " mins ago"
  elseif timeDifference < 86400 then
    local hours = math.floor(timeDifference / 3600)
    return hours .. " hours ago"
  else
    local days = math.floor(timeDifference / 86400)
    return days .. " days ago"
  end
end

function M:on_event(data)
  if data[1] == "" or data[1] == nil then
    return
  end
  local notifications = vim.fn.json_decode(data[1])
  local repo_url = require("gh-notify.utils").executeCommand("git config --get remote.origin.url")
  local repo_name = extract_repository_name(repo_url)
  local newNotifications = filterNotifications(notifications)


  local processed_messages = {}
  for _, value in pairs(newNotifications) do
    local context = {
      repo = value.repo,
      timestamp = convertToRelativeTimestamp(value.updated_at),
      owner = value.repository.owner.login,
      full_name = value.repository.full_name,
      reason = value.reason,
      type = value.subject.type,
      repoName = value.repository.name,
      is_from_this_repo = trim(repo_name) == trim(value.repository.name)
    }
    local msg = message_router(value, context)
    table.insert(M.state.messages, msg)
    table.insert(processed_messages, msg)
  end
  M.opts.on_messages(processed_messages, M.state.messages)
end

---
---@param filter function|nil function to filter out messages. return true to keep message
M.list_messages = function(filter)
  local filtered_messages = {}
  for key, value in pairs(M.state.messages) do
    if (filter == nil or filter(value)) then
      table.insert(filtered_messages, value)
    end
  end
  if #filtered_messages == 0 then
    vim.notify("No unread notifications to show")
    return
  end
  require("gh-notify.telescope").picker(nil, filtered_messages, function(selected_entry)
    if selected_entry.context.type == "PullRequest" and selected_entry.number ~= nil then
      if selected_entry.context.is_from_this_repo == false then
        local url = string.format("https://github.com/%s/pull/%d", selected_entry.context.full_name,
          selected_entry.number)
        vim.cmd("Octo " .. url)
      else
        vim.cmd("Octo pr edit " .. selected_entry.number)
      end
    elseif selected_entry.context.type == "Issue" and selected_entry.number ~= nil then
      if selected_entry.context.is_from_this_repo == false then
        local url = string.format("https://github.com/%s/issues/%d", selected_entry.context.full_name,
          selected_entry.number)
        vim.cmd("Octo " .. url)
      else
        vim.cmd("Octo issue edit " .. selected_entry.number)
      end
    else
      vim.cmd("Octo " .. selected_entry.url)
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
  if M.opts.polling == true then
    M:start()
  end

  local commands = {
    list = function()
      M.list_messages()
    end,
    mention = function()
      M.list_messages(function(i) return i.context.reason == "mention" end)
    end,
    assigned = function()
      M.list_messages(function(i) return i.context.reason == "assign" end)
    end,
    reviews = function()
      M.list_messages(function(i) return i.context.reason == "review_requested" end)
    end,
  }

  M.list = commands.list
  M.assigned = commands.assigned
  M.mention = commands.mention
  M.reviews = commands.reviews

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
