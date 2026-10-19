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
