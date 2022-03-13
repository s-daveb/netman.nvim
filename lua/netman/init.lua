local remote_tools = require('netman.remote_tools')
local utils        = require('netman.utils')
local notify       = utils.notify

local default_options = {
    allow_netrw     = true,
    keymaps         = {}, -- TODO(Mike): Figure this out
    debug           = false,
    quiet           = false, -- TODO(Mike): Notate this
    compress        = false, -- TODO(Mike): Document this
    providers       = {
        "netman.providers.ssh"
    }
}

local buffer_details_table = {}

local override_netrw = function()
    if vim.g.loaded_netman then
        return
    end
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    -- vim.g.loaded_netman = 1 -- TODO(Mike) By disabling netrw, we prevent ANY netrw handling of files. This is probably bad, we may want to consider a way to allow some of NetRW to function.
    -- EG, this disables NetRW's local directory handling which is not amazing. 
    -- Alternatively, we build our own internal file handling...?
    vim.api.nvim_command('augroup Netman')
    vim.api.nvim_command('autocmd!')
    vim.api.nvim_command('autocmd VimEnter sil! au! FileExplorer *')
    vim.api.nvim_command('autocmd FileReadCmd sftp://*,scp://* lua Nmread(vim.fn.expand("<amatch>"), "file")')
    vim.api.nvim_command('autocmd BufReadCmd sftp://*,scp://* lua Nmread(vim.fn.expand("<amatch>"), "buf")')
    vim.api.nvim_command('autocmd FileWriteCmd sftp://*,scp://* lua Nmwrite(vim.fn.expand("<abuf>"), 1, "file")')
    vim.api.nvim_command('autocmd BufWriteCmd sftp://*,scp://* lua Nmwrite(vim.fn.expand("<abuf>"), 1, "buf")')
    vim.api.nvim_command('augroup END')
end

local browse = function(path, remote_info, display_results)
    display_results = display_results or false
    remote_info = remote_info or remote_tools.get_remote_details(path)
    local contents = remote_tools.get_remote_files(remote_info, path)
    if not display_results then
        return contents
    end
    -- TODO(Mike): Figure out how to display this?
    for type, subtable in pairs(contents) do
        for subtype, array in pairs(subtable) do
            for _, info in ipairs(array) do
                notify("Received: " .. type .. '|' .. subtype .. '|' .. info.full_path, vim.log.levels.INFO, true)
            end
        end
    end
end

local read = function(path, execute_post_read_cmd)
    -- Read (called via auto command or :Nmread(path)) is used to open a remote file/directory
    -- :param path (String):
    --     A string representation of a remote location to open. This should include the full remote URI ($PROTOCOL://[[$USERNAME@]$HOSTNAME[:$PORT]/[//][$PATH]).
    --     EG: sftp://user@my-remote-host/file_located_in_user_home_directory.txt
    --     OR: sftp://user@my-remote-host///tmp/file_located_not_in_user_home_directory.txt
    --     For more details, `:help Nmread`
    -- :param execute_post_read_cmd (String, optional):
    --     This should not be used by an end user, this is passed to the `read` command
    --     via the Auto command set in the `Netman` AuGroup. Note: this is _not_ detailed in `:help Nmread` as it should not be used by end users.
    --     Available options:
    --         - "file"
    --         - "buf"
    -- :return:
    --     On successful read, this will return 1 of 2 things
    --     - Nothing
    --     - Table object of directory contents
    --     
    --     In the event that we are reading a file, this will return nothing and instead
    --     create a new buffer for which the end user can view/modify the contents of a remote file
    --     If the path is a rmeote directory _AND_ you have not configured a browse_handler, this will return an non-modifiable buffer with the contents of the directory to browse. It is highly recommended that you use Netman as the backend to a file browser (such as [telescope-file-browser.nvim](https://github.com/nvim-telescope/telescope-file-browser.nvim))
    --     If the path is a remote directory _AND_ you have configured a browse_handler (TODO(Mike): Create browse handlers), this will return a table of the contents of the directory. For more details. This table will be formatted as follows
    --     {
    --          dirs = {
    --              hidden = {},
    --              visible = {}
    --          },
    --          files = {
    --              hidden = {},
    --              visible = {}
    --          },
    --          links = {
    --              hidden = {},
    --              visible = {}
    --          }
    --     }
    local remote_info = remote_tools.get_remote_details(path)
    if not remote_info.protocol then
        notify("Unable to match any providers to " .. path, vim.log.levels.WARN, true)
        return
    end
    if remote_info.is_dir then
        return browse(path, remote_info)
    end
    local local_file = remote_tools.get_remote_file(path, remote_info)
    if not local_file then
        notify("Failed to get remote file", vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_command('keepjumps sil! 0')
    vim.api.nvim_command('keepjumps execute "sil! read ++edit ' .. local_file .. '"')
    vim.api.nvim_command('keepjumps sil! 0d')
    vim.api.nvim_command('keepjumps sil! 0')
    if execute_post_read_cmd == "buf" then
        vim.api.nvim_command('execute "sil doautocmd BufReadPost ' .. path .. '"')
    elseif execute_post_read_cmd == "file" then
        vim.api.nvim_command('execute "sil doautocmd FileReadPost ' .. path .. '"')
    end

    buffer_details_table["" .. remote_info.buffer] = remote_info
end

local _write_buffer = function(buffer_id)
    local file_info = buffer_details_table["" .. buffer_id]
    local local_file = file_info.local_file
    local buffer = vim.fn.bufname(buffer_id)
    notify("Saving buffer: " .. buffer .. " to " .. local_file, vim.log.levels.DEBUG, true)
    vim.fn.writefile(vim.fn.getbufline(buffer, 1, '$'), local_file)
    remote_tools.save_remote_file(file_info)
    -- TODO(Mike): Handle save errors
    return true
end

local write = function(path, is_buffer, execute_post_write_cmd)
    -- TODO(Mike): Determine if the provided path is a remote file or not?
    local continue = false
    if is_buffer then
        continue = _write_buffer(path)
    else
        continue = _write_file(path)
    end
    if not continue then
        return
    end
    vim.api.nvim_command('execute "sil set nomodified"')
    if execute_post_write_cmd == 'file' then
        vim.api.nvim_command('execute "sil doautocmd FileWritePost ' .. path .. '"')
    end
    if execute_post_write_cmd == 'buf' then
        vim.api.nvim_command('execute "sil doautocmd BufWritePost ' .. path .. '"')
    end
end

local unload = function(path)
    notify("Unloading file: " .. path, vim.log.levels.DEBUG, true)
    local buffer_details = buffer_details_table["" .. vim.fn.bufnr(path)]
    if not buffer_details then
        notify("Unable to find details related to buffer: " .. path, vim.log.levels.WARN, true)
        return
    end
    remote_tools.cleanup(buffer_details)
end

local delete = function(path)
    print("Deleting Path: " .. path)
end

local create = function(path)
    print("Creating Path: " .. path)
end

local export_functions = function()
    _G.Nmread   = read
    _G.Nmwrite  = write
    _G.Nmdelete = delete
    _G.Nmcreate = create
    _G.Nmunload   = unload
end

local setup = function(options)
    -- TODO(Mike): Input ability to handle ssh weirdness (like needing a password/passphrase) via neovim ui?
    if vim.g.loaded_netman then
        return
    end

    local opts = {}
    for key, value in pairs(default_options) do
        opts[key] = value
    end

    if default_options.debug or options.debug then
        utils.setup(0)
    else
        utils.setup()
    end

    if options then
        for key, value in pairs(options) do
            if(key ~= 'providers') then
                opts[key] = value
            else
                for _, provider in pairs(value) do
                    if opts.providers[provider] == nil then
                        notify("Received External Provider: " .. provider, vim.log.levels.DEBUG, true)
                        table.insert(opts.providers, provider)
                    end
                end
            end
        end
    end

    export_functions()
    if not opts.allow_netrw then
        override_netrw()
    end
end

return {
    setup  = setup,
    read   = read,
    write  = write,
    delete = delete,
    create = create,
}
