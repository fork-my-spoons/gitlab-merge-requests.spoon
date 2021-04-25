# GitLab Merge Requests

<p align="center">
  <a href="https://github.com/fork-my-spoons/gitlab-merge-requests.spoon/actions">
    <img alt="Build" src="https://github.com/fork-my-spoons/gitlab-merge-requests.spoon/workflows/build/badge.svg"/></a>
  <a href="https://github.com/fork-my-spoons/gitlab-merge-requests.spoon/issues">
    <img alt="GitHub issues" src="https://img.shields.io/github/issues/fork-my-spoons/gitlab-merge-requests.spoon"/></a>
  <a href="https://github.com/fork-my-spoons/gitlab-merge-requests.spoon/releases">
    <img alt="GitHub all releases" src="https://img.shields.io/github/downloads/fork-my-spoons/gitlab-merge-requests.spoon/total"/></a>
</p>

A menu bar app, showing a list of merge requests assigned to a user to review:

<p align="center">
  <img src="https://github.com/fork-my-spoons/gitlab-merge-requests.spoon/raw/master/screenshots/screenshot.png"/>
</p>

Each item in the list is showing following information:

<p align="center">
  <img src="https://github.com/fork-my-spoons/gitlab-merge-requests.spoon/raw/master/screenshots/details.png"/>
</p>

# Installation

 - install [Hammerspoon](http://www.hammerspoon.org/) - a powerfull automation tool for OS X
   - Manually:

      Download the [latest release](https://github.com/Hammerspoon/hammerspoon/releases/latest), and drag Hammerspoon.app from your Downloads folder to Applications.
   - Homebrew:

      ```brew install hammerspoon --cask```

 - download [gitlab-merge-requests.spoon](https://github.com/fork-my-spoons/gitlab-merge-requests.spoon/releases/latest/download/gitlab-merge-requests.spoon.zip), unzip and double click on a .spoon file. It will be installed under `~/.hammerspoon/Spoons` folder.
 
 - open ~/.hammerspoon/init.lua and add the following snippet, adding your parameters:

```lua
-- GitLab
hs.loadSpoon('gitlab-merge-requests')
spoon['gitlab-merge-requests']:setup({
    gitlab_host = 'https://gitlab.com',
    token = 'your_token',
    username = 'gitlab_username' 
})
```

To generate a token, go to: https://gitlab.com/-/profile/personal_access_tokens, select **api** scope and type a name.

This app uses icons, to properly display them, install a [feather-font](https://github.com/AT-UI/feather-font) by [downloading](https://github.com/AT-UI/feather-font/raw/master/src/fonts/feather.ttf) this .ttf font and installing it.
