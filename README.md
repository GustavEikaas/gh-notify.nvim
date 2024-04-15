# gh-notify.nvim


## WIP 🚧🏗
Not much too see here right now, but come back later and have a look

Get github notifications directly in neovim. Show, list, act on notifications directly from within neovim.


## Features

Supports the following events

- [x] Mentioned
- [x] Assigned
- [x] state_change
- [ ] approval_requested
- [ ] assign
- [ ] author
- [ ] comment
- [ ] ci_activity
- [ ] manual
- [x] review_requested
- [ ] security_alert
- [x] team_mention
- [x] subscribed

## Setup

```lua

return {
  "GustavEikaas/gh-notify.nvim",
  dependencies = {'pwntester/octo.nvim', 'nvim-telescope/telescope.nvim', },
  config = function()
    require("gh-notify").setup({
      -- Automatically fetches new notifications every 5 minutes
      polling = true
    })
  end
}
```


## Commands


### Lua functions

```lua
local notify = require("gh-notify")
notify.list() -- Telescope picker with all notifications from current repo
notify.mention() -- Telescope picker with all notifications of type mention
notify.reviews() -- Telescope picker with all notifications of type review
notify.refresh() -- Fetches new notifications
notify.assigned() -- Telescope picker with all notifications of type assigned

```


### Vim commands
```
GhNotify list 
GhNotify refresh
GhNotify assigned
GhNotify mention
GhNotify reviews
```
