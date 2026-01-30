
local git = require("git_explorer.git")
local ui = require("git_explorer.ui")

vim.api.nvim_create_user_command("GitExplorer", function()
    local files = git.get_git_status()
    ui.open_git_explorer(files)
end, {})
vim.api.nvim_set_keymap("n", "<leader>ge", "", {
    noremap = true,
    silent = true,
    callback = function()
        local files = git.get_git_status()
        ui.open_git_explorer(files)
    end,
})
