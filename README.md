# Neovim (Lua Powered) Network File Manager

## WIP

## Goals

While netman was originally targetted at replacing [Netrw](http://www.drchip.org/astronaut/vim/index.html#NETRW) with a lua drop in, it has grown to different aspirations. Below is the current list of goals for Netman

- [ ] Remote File Management
- [ ] [Extensible Framework to Integrate Remote Filesystems with Existing File Managers](https://github.com/miversen33/netman.nvim/blob/main/lua/netman/providers/explore_shim.lua)
- [ ] [Fully Functional with Neovim LSP](#lsp)

## Dependencies

Your client (and server) will need whatever software is necessary to use the remote protocol of your chosing. This means that if you wish to connect to a remote file system via sftp/scp, your client and server must both have installed (and running) ssh. 
The server must have [find](https://man7.org/linux/man-pages/man1/find.1.html) installed (this is usually preinstalled on most linux environments)

- find
- [Required Protocols for Remote Providers](#core-providers)

## Usage

Using Netman should be as simple as adding this line to your `init.lua`

```lua
require('netman')
```

## Network Protocols Targeted
- [x] [SSH](#ssh) **CURRENT TARGET FOR IMPLEMENTATION**
- [ ] Rsync
- [ ] Docker

## Core Providers

### SSH

Accessing files/directories over ssh can be done in below format
- $PROTOCOL://[$USERNAME@]$HOSTNAME[:$PORT]/[//][$PATH]
  
    A break down of what is happening here
    - `$PROTOCOL`: Must be either `sftp` or `scp`
    - `$USERNAME`: The username to authenticate with (Optional)
    - `$HOSTNAME`: The hostname to connect to. Supports using hostnames defined in an [SSH CONFIG](https://linux.die.net/man/5/ssh_config) file
    - `$PORT`    : The port to connect to (Optional)
    - `/[//]`    : Forward slash (one) is considered a relative path to the `$USER` home directory. Note, this will work regardless of if `$USER` is specified or not. Providing `///` will act as a "Full Path" override
    - `$PATH`    : The path to a file/directory to interact with. If not provided, defaults to `/[//]` as described above (Optional)

Current Limitations:
- Interactive authentication currently do not work
    If you need a password or keyphrase to enter a box, currently this will just fail (ish?).
    - This is being investigated in [issue 33](https://github.com/miversen33/netman.nvim/issues/33)

## Debugging

When debugging your netman session, ensure that you are running in `DEBUG` mode. This can be done by simply setting
```lua
vim.g.netman_log_level = 1
```
in your `init.lua` configuration file.
**NOTE: It is recommended that you place this line somewhere before you import plugins as `Netman` automatically sets itself up on import of itself or `api`. Any logging during initialization is lost if the appropriate level is not set before that**

Valid log levels are
- 4 (Error)
- 3 (Warn)
- 2 (Info)
- 1 (Debug)
- 0 (Trace)
These are in conjuntion with [vim.log.levels](https://neovim.io/doc/user/lua.html#vim.log.levels)


**NOTE: Debug mode a significantly volume of logs, ensure you only have it on when its needed**

When you encounter a bug that you wish to submit an issue for, 
please refer to [How to fill out issue](https://github.com/miversen33/netman.nvim/issues/3). Netman is designed to make
your life as the user easy. To help accomplish this, netman has a command built in
specifically to dump session logs for you.
```vim
:Nmlogs
```
-- More details coming on how its implemented and how to use it.

You can additionally provide an output path for the logs to be stored at
```vim
:Nmlogs /home/miversen33/WHY_YOU_BIG_DED.log
```
This will dump the session log out into the above listed `/home/miversen33/WHY_YOU_BIG_DED.log` file, which can then be retrieved and uploaded with your issue. Additionally, the generated log will be opened up in a new `NetmanLogs` filetype buffer, formatted and available for viewing. This should prove
helpful for developers as they work through integration with Netman.

NOTE: In order for the logs to be useful, it is required that `:Nmlogs` be ran from within
the problem session as only the logs associated with the current session will be aggregated.

The logfile for netman is stored in `$HOME/.local/nvim/netman/logs.txt` if you would prefer to 
look through this in an attempt to troubleshoot issues

**NOTE: This does _not_ scrub sensitive content, so it is wise to ensure there are no passwords or the like in this log before uploading it**