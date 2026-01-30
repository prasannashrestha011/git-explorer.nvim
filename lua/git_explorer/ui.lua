
local M = {}
local devicons = require("nvim-web-devicons")
M.buf = nil
M.win = nil

-- Git status icons
local git_icons = {
    staged = "",
    unstaged = "",
    untracked = "",
}

local function setup_highlights()
    vim.cmd [[
    highlight GitExplorerTitle guifg=#61AFEF guibg=#282C34 gui=bold
    highlight GitExplorerBorder guifg=#61AFEF
    highlight GitExplorerBranch guifg=#98C379 gui=bold
    highlight GitExplorerBranchIcon guifg=#E06C75
    highlight GitExplorerStagedTitle guifg=#98C379 gui=bold
    highlight GitExplorerUnstagedTitle guifg=#E5C07B gui=bold
    highlight GitExplorerUntrackedTitle guifg=#61AFEF gui=bold
    highlight GitExplorerFileName guifg=#ABB2BF
    highlight GitExplorerSeparator guifg=#3E4451
    highlight GitExplorerCursorLine guibg=#2C323C
    highlight GitExplorerHeader guifg=#C678DD gui=bold
    ]]
end

-- Get current git branch
local function get_git_branch()
    local handle = io.popen("git branch --show-current 2>/dev/null")
    if not handle then return "unknown" end
    
    local branch = handle:read("*a")
    handle:close()
    
    branch = branch:gsub("%s+$", "")
    return branch ~= "" and branch or "unknown"
end

-- Create a separator line
local function create_separator(width)
    return string.rep("─", width - 4)
end

M.open_git_explorer = function(files)
    -- toggle
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_close(M.win, true)
        M.win = nil
        M.buf = nil
        return
    end

    -- create buffer
    M.buf = vim.api.nvim_create_buf(false, true)

    -- setup highlights
    setup_highlights()

    -- floating modal size
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.7)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- open window with custom border
    M.win = vim.api.nvim_open_win(M.buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = {
            { "╭", "GitExplorerBorder" },
            { "─", "GitExplorerBorder" },
            { "╮", "GitExplorerBorder" },
            { "│", "GitExplorerBorder" },
            { "╯", "GitExplorerBorder" },
            { "─", "GitExplorerBorder" },
            { "╰", "GitExplorerBorder" },
            { "│", "GitExplorerBorder" },
        },
        title = { { " 󰊢 Git Explorer ", "GitExplorerTitle" } },
        title_pos = "center",
    })

    -- Enable cursor line
    vim.api.nvim_win_set_option(M.win, 'cursorline', true)
    vim.api.nvim_win_set_option(M.win, 'winhl', 'CursorLine:GitExplorerCursorLine')

    -- buffer options
    vim.api.nvim_buf_set_option(M.buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(M.buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(M.buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(M.buf, 'modifiable', true)

    -- render lines
    local lines = {}
    local highlights = {}
    local file_lines = {}

    -- Header section
    local branch = get_git_branch()
    local separator = create_separator(width)
    
    -- Branch info with box drawing
    table.insert(lines, "")
    table.insert(lines, string.format("  %s  %s", "", branch))
    table.insert(highlights, { 1, 2, 4, "GitExplorerBranchIcon" })
    table.insert(highlights, { 1, 5, -1, "GitExplorerBranch" })
    
    table.insert(lines, string.format("  %s", separator))
    table.insert(highlights, { 2, 0, -1, "GitExplorerSeparator" })
    table.insert(lines, "")

    local function add_section(title, icon, file_list, title_hl)
        if #file_list == 0 then return end
        
        -- Section header with icon
        local header = string.format("  %s  %s (%d)", icon, title, #file_list)
        table.insert(lines, header)
        table.insert(highlights, { #lines-1, 0, -1, title_hl })
        
        -- Add a subtle line under header
        table.insert(lines, "")
        
        -- Files
        for _, f in ipairs(file_list) do
            local icon_text, _ = devicons.get_icon(f, nil, { default = true })
            local line = string.format("    %s  %s", icon_text or "", f)
            table.insert(lines, line)
            
            -- Track file lines for navigation
            table.insert(file_lines, { line_num = #lines - 1, filename = f })
            
            -- Highlight file icon
            local icon_start = 4
            local icon_end = icon_start + vim.fn.strwidth(icon_text or "")
            local _, hl_group = devicons.get_icon(f, nil, { default = true })
            if hl_group then
                table.insert(highlights, { #lines-1, icon_start, icon_end, hl_group })
            end
            
            -- Highlight filename
            local filename_start = icon_end + 2
            table.insert(highlights, { #lines-1, filename_start, -1, "GitExplorerFileName" })
        end
        
        -- Spacing between sections
        table.insert(lines, "")
    end

    add_section("Staged", git_icons.staged, files.staged, "GitExplorerStagedTitle")
    add_section("Unstaged", git_icons.unstaged, files.unstaged, "GitExplorerUnstagedTitle")
    add_section("Untracked", git_icons.untracked, files.untracked, "GitExplorerUntrackedTitle")

-- Footer with keybindings help (always at bottom)
-- Calculate how many empty lines we need to push footer to bottom
local content_lines = #lines
local footer_height = 2  -- separator + help text
local available_height = height - 2  -- subtract top/bottom borders
local empty_lines_needed = available_height - content_lines - footer_height

-- Add empty lines to push footer to bottom
for i = 1, math.max(0, empty_lines_needed) do
    table.insert(lines, "")
end

local footer_sep = create_separator(width)
table.insert(lines, string.format("  %s", footer_sep))
table.insert(highlights, { #lines-1, 0, -1, "GitExplorerSeparator" })

local help_text = "  <CR> open │ j/k navigate │ q/Esc close"
table.insert(lines, help_text)
table.insert(highlights, { #lines-1, 0, -1, "GitExplorerHeader" })
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)

    -- apply highlights
    for _, hl in ipairs(highlights) do
        local line, col_start, col_end, group = unpack(hl)
        vim.api.nvim_buf_add_highlight(M.buf, -1, group, line, col_start, col_end)
    end

    vim.api.nvim_buf_set_option(M.buf, 'modifiable', false)

    -- Helper to find file at cursor
    local function get_file_at_cursor()
        local cursor = vim.api.nvim_win_get_cursor(M.win)
        local current_line = cursor[1] - 1
        
        for _, entry in ipairs(file_lines) do
            if entry.line_num == current_line then
                return entry.filename
            end
        end
        return nil
    end

    -- Navigation functions
    local function jump_to_next_file()
        local cursor = vim.api.nvim_win_get_cursor(M.win)
        local current_line = cursor[1] - 1
        
        for _, entry in ipairs(file_lines) do
            if entry.line_num > current_line then
                vim.api.nvim_win_set_cursor(M.win, { entry.line_num + 1, 0 })
                return
            end
        end
        
        if #file_lines > 0 then
            vim.api.nvim_win_set_cursor(M.win, { file_lines[1].line_num + 1, 0 })
        end
    end

    local function jump_to_prev_file()
        local cursor = vim.api.nvim_win_get_cursor(M.win)
        local current_line = cursor[1] - 1
        
        for i = #file_lines, 1, -1 do
            if file_lines[i].line_num < current_line then
                vim.api.nvim_win_set_cursor(M.win, { file_lines[i].line_num + 1, 0 })
                return
            end
        end
        
        if #file_lines > 0 then
            vim.api.nvim_win_set_cursor(M.win, { file_lines[#file_lines].line_num + 1, 0 })
        end
    end

    -- Key mappings
    local opts = { noremap = true, silent = true, buffer = M.buf }
    
    vim.keymap.set("n", "<CR>", function()
        local filename = get_file_at_cursor()
        if filename and vim.fn.filereadable(filename) == 1 then
            vim.api.nvim_win_close(M.win, true)
            M.win = nil
            M.buf = nil
            vim.cmd("edit " .. vim.fn.fnameescape(filename))
        end
    end, opts)

    vim.keymap.set("n", "j", jump_to_next_file, opts)
    vim.keymap.set("n", "k", jump_to_prev_file, opts)
    vim.keymap.set("n", "<Down>", jump_to_next_file, opts)
    vim.keymap.set("n", "<Up>", jump_to_prev_file, opts)

    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(M.win, true)
        M.win = nil
        M.buf = nil
    end, opts)
    
    vim.keymap.set("n", "<Esc>", function()
        vim.api.nvim_win_close(M.win, true)
        M.win = nil
        M.buf = nil
    end, opts)

    -- Position cursor on first file
    if #file_lines > 0 then
        vim.api.nvim_win_set_cursor(M.win, { file_lines[1].line_num + 1, 0 })
    end
end

return M
