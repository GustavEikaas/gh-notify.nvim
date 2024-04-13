local M = {}

local function extract_pr_number_from_url(url)
  local number = string.match(url, "/(%d+)$")
  return tonumber(number)
end

---@param context Context
---@return string
local function generate_footer(context)
  return context.repoName
end

local function format_message(header, content, context)
  return header .. "\n\n" .. content .. "\n\n" .. generate_footer(context)
end

---@param number number
---@param title string
---@param context Context
---@return string
M.pr_state_change = function(number, title, context)
  local header = "Update on pull request"
  return format_message(header, "#" .. number .. " " .. title, context)
end

---@param title string
---@param context Context
---@return string
M.issue_state_change = function(title, context)
  return format_message("Update on issue", title, context)
end

---@param title string
---@param context Context
---@return Message
M.approval_requested = function(value, title, context)
  local display = "You're approval was requested for a workflow run"
  return {
    message = format_message(display, title, context),
    number = nil,
    url = "",
    display = display
  }
end

---@param title string
---@param context Context
---@return Message
M.security_alert = function(title, context)
  --TODO: url
  local display = "Security alert"
  return { message = format_message(display, title, context), url = "", number = nil, display = display }
end


---@param title string
---@param context Context
---@return Message
M.team_mention = function(title, context)
  --TODO: url number
  local display = "Your team was mentioned"
  return { format_message(display, title, context), number = nil, url = "", display = display }
end

---@param title string
---@param context Context
---@return Message
M.review_requested = function(value, title, context)
  local url = value.subject.url
  local number = extract_pr_number_from_url(url)
  local display = "You were assigned as reviewer"
  return { message = format_message(display, title, context), number = number, url = url, display = title }
end

---@param value any
---@param title string
---@param context Context
---@return Message
M.assigned = function(value, title, context)
  if context.type == "PullRequest" then
    local display = "You were assigned to pull request"
    local url = value.subject.url
    local number = extract_pr_number_from_url(url)
    return {
      message = format_message(display, title, context),
      number = number,
      url = url,
      display = display
    }
  else
    local url = value.subject.latest_comment_url
    local issueNumber = extract_pr_number_from_url(url)
    local display = "You were assigned to issue"
    return {
      message = format_message(display, "#" .. issueNumber .. " " .. title, context),
      url = url,
      number = issueNumber,
      display = display
    }
  end
end

---
---@param value any
---@param context Context
---@return Message
M.mention = function(value, context)
  local comment_url = value.subject.latest_comment_url
  local comment = require("gh-notify.utils").executeCommandJson("gh api " .. comment_url)
  local number = extract_pr_number_from_url(value.subject.url)
  local header = comment.user.login ..
      " mentioned you in " .. "#" .. extract_pr_number_from_url(value.subject.url) .. " " ..
      value.subject.title
  return {
    number = number,
    message = format_message(header, comment.body, context),
    url = value.subject.url,
    display = header
  }
end

return M
