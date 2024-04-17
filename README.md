# gh-notify.nvim

Receive and manage GitHub notifications directly within Neovim.

## Introduction

Welcome to gh-notify.nvim! This Neovim plugin allows you to receive and manage GitHub notifications without leaving your editor.

## Features

- **Mentioned**: Receive notifications when you're mentioned in GitHub issues or pull requests.
- **Assigned**: Get notified when someone assigns an issue or pull request to you.
- **State Change**: Receive notifications when the state of an issue or pull request changes.
- **Review Requested**: Get notified when someone requests your review on a pull request.
- **Team Mention**: Receive notifications when your GitHub team is mentioned.
- **Subscribed**: Get notified about activity on repositories you're subscribed to.

## Setup

Ensure you have the following dependencies installed:

- [octo.nvim](https://github.com/pwntester/octo.nvim): Provides GitHub integration for Neovim.
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim): Enables interactive searching and browsing in Neovim.

Add `gh-notify.nvim` to your Neovim configuration:

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

### Lua Functions

- `notify.list()`: Open a Telescope picker with all notifications from the current repository.
- `notify.mention()`: Open a Telescope picker with all mention notifications.
- `notify.reviews()`: Open a Telescope picker with all review notifications.
- `notify.refresh()`: Manually fetch new notifications.
- `notify.assigned()`: Open a Telescope picker with all assigned notifications.

### Vim Commands

- `:GhNotify list`: List all notifications.
- `:GhNotify refresh`: Manually refresh notifications.
- `:GhNotify assigned`: List assigned notifications.
- `:GhNotify mention`: List mention notifications.
- `:GhNotify reviews`: List review notifications.

## Example Usage

1. After installing the plugin and its dependencies, open a Neovim session.
2. Use the provided commands or functions to view and manage your GitHub notifications directly within Neovim.
3. Stay focused and productive without switching between your editor and the GitHub website.