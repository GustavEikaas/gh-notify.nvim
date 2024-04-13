local M = {}

---
---@param cmd string
---@return table
M.executeCommandJson = function(cmd)
  return vim.fn.json_decode(M.executeCommand(cmd))
end

---
---@param cmd string
---@return string
M.executeCommand = function(cmd)
  local handle = io.popen(cmd)
  if handle == nil then
    error("Failed to execute")
  end
  local value = handle:read("*a")
  handle:close()
  return value
end


return M
