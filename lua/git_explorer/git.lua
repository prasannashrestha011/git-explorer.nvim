

local M = {}

-- Returns a table with staged, unstaged, and untracked files
M.get_git_status = function()
    local handle = io.popen("git status --porcelain")
    local result = handle:read("*a")
    handle:close()

    local files = {
        staged = {},
        unstaged = {},
        untracked = {},
    }

    for line in result:gmatch("[^\r\n]+") do
        local x, y = line:sub(1,1), line:sub(2,2)
        local file = line:sub(4)

        if x ~= " " then
            table.insert(files.staged, file)
        elseif y ~= " " then
            table.insert(files.unstaged, file)
        else
            table.insert(files.untracked, file)
        end
    end

    return files
end

return M
