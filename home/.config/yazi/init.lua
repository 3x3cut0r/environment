-- yazi plugin setup.
--
-- Skip the Git linemode gracefully when the plugin is not installed yet,
-- for example when setup could not download it.
local ok, git = pcall(require, "git")
if ok then
  git:setup {
    order = 1500,
  }
end

-- Feed the zoxide database on every directory change, so the jump list
-- is populated even before the shell has built up a cd history.
local zoxide_ok, zoxide = pcall(require, "zoxide")
if zoxide_ok then
  zoxide:setup {
    update_db = true,
  }
end
