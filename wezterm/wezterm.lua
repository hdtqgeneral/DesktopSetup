--- @type Wezterm
local wezterm = require("wezterm")

local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action

local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
local is_macos = (wezterm.target_triple == "aarch64-apple-darwin" or wezterm.target_triple == "x86_64-apple-darwin")
    or false

-- max fps
config.max_fps = 144
config.animation_fps = 144
local launch_menu = {}

config.color_scheme = 'Tokyo Night Moon'
config.window_decorations = "RESIZE"
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_and_split_indices_are_zero_based = false
config.set_environment_variables = {}
config.window_background_opacity = 0.85
config.front_end = "OpenGL"
config.notification_handling = "AlwaysShow"
config.tab_max_width = 300

local ShellTypes = {
    NONE = 0,
    CMD = 1,
    CMDER = 2,
    PowerShell = 3,
    WSL = 4,
    Nushell = 5,
}

local shellType = ShellTypes.Nushell
-- Detect PowerShell 7 path dynamically
local pwsh_paths = {
    "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
}
local pwsh = pwsh_paths[1] -- default
for _, path in ipairs(pwsh_paths) do
    local f = io.open(path, "r")
    if f then
        f:close()
        pwsh = path
        break
    end
end

-- Detect Nushell path dynamically
local nu_paths = {
    "C:\\Users\\%USERPROFILE%\\AppData\\Local\\Programs\\nu\\bin\\nu.exe",
}
local nu = nu_paths[1] -- default
for _, path in ipairs(nu_paths) do
    local f = io.open(path, "r")
    if f then
        f:close()
        nu = path
        break
    end
end
-- uncomment if I want to use clink only
if is_windows then
    local distro = "Ubuntu-24.04"
    local wsl_domain = "WSL:" .. distro

    -- PowerShell 7
    table.insert(launch_menu, {
        label = "PowerShell 7",
        args = { pwsh, "-NoLogo" },
        domain = { DomainName = "local" },
    })

    -- Windows PowerShell (5.1)
    table.insert(launch_menu, {
        label = "Windows PowerShell",
        args = { "powershell.exe", "-NoLogo" },
        domain = { DomainName = "local" },
    })

    -- WSL2 default distro
    table.insert(launch_menu, {
        label = "WSL2 (default)",
        domain = { DomainName = wsl_domain },
    })

    -- Cmder (use environment variable or fallback to default path)
    local cmder_root = os.getenv("cmder_root") or os.getenv("CMDER_ROOT") or "C:\\tools\\cmder"
    table.insert(launch_menu, {
        label = "Cmder",
        args = { "cmd.exe", "/s", "/k", cmder_root .. "\\vendor\\init.bat" },
        domain = { DomainName = "local" },
    })

    -- because my tmux on macos have bottom tab bar
    config.tab_bar_at_bottom = true
    if shellType == ShellTypes.CMD then
        -- Use OSC 7 as per the above example
        config.set_environment_variables["prompt"] =
            "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m "
        -- use a more ls-like output format for dir
        -- And inject clink into the command prompt
        config.set_environment_variables["DIRCMD"] = "/d"
    end

    if shellType == ShellTypes.CMDER then
        config.default_prog = { "cmd.exe", "/s", "/k", "c:/clink/clink_x64.exe", "inject", "-q" }

        -- bring color to default cmd
        config.set_environment_variables = {
            prompt = "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m ",
        }

        local initBat = os.getenv("cmder_root") .. "\\vendor\\init.bat"
        config.set_environment_variables["prompt"] =
            "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m "
        config.set_environment_variables["DIRCMD"] = "/d"
        config.default_prog = { "cmd.exe", "/s", "/k", initBat }
    end

    if shellType == ShellTypes.PowerShell then
        config.default_prog = { pwsh, "-NoLogo" }
    end

    if shellType == ShellTypes.Nushell then
        config.default_prog = { nu }
    end

    if shellType == ShellTypes.WSL then
        config.default_domain = wsl_domain
        config.default_prog = { "wsl.exe" }
        config.wsl_domains = {
            {
                name = wsl_domain,
                distribution = distro,
                default_cwd = "~",
            },
        }
    end
end

-- unbind alt enter
config.keys = {
    { key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
    { key = "u", mods = "CTRL|ALT", action = wezterm.action.DisableDefaultAssignment },
    { key = "d", mods = "CTRL|ALT", action = wezterm.action.DisableDefaultAssignment },
    -- emoji??
    { key = "u", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
}

if is_windows then
    -- Helper to check if current pane is in a WSL domain
    local function is_wsl_pane(pane)
        local domain_name = pane:get_domain_name()
        print("is_wsl_pane: " .. tostring(domain_name))
        return domain_name and domain_name:find("WSL") ~= nil
    end

    -- Debug overlay (non-leader key, add to config.keys)
    table.insert(config.keys, { key = "L", mods = "CTRL", action = wezterm.action.ShowDebugOverlay })

    -- Conditional Ctrl+Space: WSL pane passes to tmux, others activate leader key table
    table.insert(config.keys, {
        key = " ",
        mods = "CTRL",
        action = wezterm.action_callback(function(window, pane)
            if is_wsl_pane(pane) then
                -- WSL pane: pass Ctrl+Space through to tmux
                window:perform_action(act.SendKey({ key = " ", mods = "CTRL" }), pane)
            else
                -- Non-WSL pane: activate wezterm leader key table
                window:perform_action(
                    act.ActivateKeyTable({
                        name = "leader",
                        one_shot = true,
                        timeout_milliseconds = 1000,
                    }),
                    pane
                )
            end
        end),
    })

    local function split_current_pane(direction)
        return wezterm.action_callback(function(window, pane)
            local command = { domain = "CurrentPaneDomain" }

            if pane:get_domain_name() == "local" then
                command.args = { nu }
            end

            local cwd = pane:get_current_working_dir()
            if cwd then
                command.cwd = cwd
            end

            window:perform_action(act.SplitPane({ direction = direction, command = command }), pane)
        end)
    end

    -- Define leader key table with all leader bindings
    config.key_tables = {
        leader = {
            -- Escape to cancel leader mode
            { key = "Escape", action = act.PopKeyTable },
            -- Launcher
            { key = "T", mods = "SHIFT", action = act.ShowLauncher },
            -- Split panes
            { key = "+", action = split_current_pane("Right") },
            { key = "-", action = split_current_pane("Down") },
            { key = "*", action = act.CloseCurrentPane({ confirm = true }) },
            { key = "/", action = act.CloseCurrentTab({ confirm = true }) },
            -- Navigate panes
            { key = 'Delete', action = act.ActivatePaneDirection 'Left' },
            { key = 'End', action = act.ActivatePaneDirection 'Down' },
            { key = 'Home', action = act.ActivatePaneDirection 'Up' },
            { key = 'PageDown', action = act.ActivatePaneDirection 'Right' },
            { key = 'Insert', action = act.ActivateTabRelative(-1) },
            { key = 'PageUp', action = act.ActivateTabRelative(1) },
            { key = 'h', action = act.ActivatePaneDirection 'Left' },
            { key = 'j', action = act.ActivatePaneDirection 'Down' },
            { key = 'k', action = act.ActivatePaneDirection 'Up' },
            { key = 'l', action = act.ActivatePaneDirection 'Right' },
            -- Adjust pane size (do I even need this?)
            { key = 'LeftArrow', mods = "SHIFT", action = act.AdjustPaneSize { 'Left', 1 } },
            { key = 'DownArrow', mods = "SHIFT", action = act.AdjustPaneSize { 'Down', 1 } },
            { key = 'UpArrow', mods = "SHIFT", action = act.AdjustPaneSize { 'Up', 1 } },
            { key = 'RightArrow', mods = "SHIFT", action = act.AdjustPaneSize { 'Right', 1 } },
            { key = 'h', mods = "SHIFT", action = act.AdjustPaneSize { 'Left', 1 } },
            { key = 'j', mods = "SHIFT", action = act.AdjustPaneSize { 'Down', 1 } },
            { key = 'k', mods = "SHIFT", action = act.AdjustPaneSize { 'Up', 1 } },
            { key = 'l', mods = "SHIFT", action = act.AdjustPaneSize { 'Right', 1 } },
            -- Switch to new or existing workspace
            {
                key = "W",
                mods = "SHIFT",
                action = act.PromptInputLine({
                    description = wezterm.format({
                        { Attribute = { Underline = "Double" } },
                        { Foreground = { AnsiColor = "Fuchsia" } },
                        { Text = "Enter name for new workspace." },
                    }),
                    action = wezterm.action_callback(function(window, pane, line)
                        if line then
                            window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
                        end
                    end),
                }),
            },
            { key = "s", mods = "SHIFT", action = act.ShowLauncherArgs({ flags = "WORKSPACES" }) },
            -- Pane/Tab management
            {
                key = ",",
                action = act.PromptInputLine({
                    description = "Enter new name for tab",
                    action = wezterm.action_callback(function(window, pane, line)
                        if line then
                            window:active_tab():set_title(line)
                        end
                    end),
                }),
            },
            -- Tab navigation
            {
                key = "t",
                action = wezterm.action_callback(function(window, pane)
                    local command = { domain = "CurrentPaneDomain" }
                    if pane:get_domain_name() == "local" then
                        command.args = { nu }
                    end
                    window:perform_action(act.SpawnCommandInNewTab(command), pane)
                end),
            },
            
            -- Zoom pane toggle (mimics tmux prefix + z)
            { key = "z", action = act.TogglePaneZoomState },
            -- Fullscreen toggle
            { key = "f", action = act.ToggleFullScreen },
        },
    }

    -- Tab switching keys 1-9
    for i = 1, 9 do
        table.insert(config.key_tables.leader, {
            key = tostring(i),
            action = act.ActivateTab(i - 1),
        })
    end

    tabline.setup({
        options = {
            icons_enabled = true,
            theme = "Tokyo Night Storm",
            tabs_enabled = true,
            theme_overrides = {},
            section_separators = {
                left = '',
                right = '',
            },
            component_separators = {
                left = '',
                right = '',
            },
            tab_separators = {
                left = '',
                right = '',
            },
        },
        sections = {
            tabline_a = { "mode" },
            tabline_b = { "workspace" },
            tabline_c = { " " },
            tab_active = {
                "index",
                { "parent", padding = 0 },
                "/",
                { "cwd", padding = { left = 0, right = 1 } },
                { "zoomed", padding = 0 },
            },
            tab_inactive = {
                "index",
                -- { "output" },
                { "tab", padding = { left = 0, right = 1 } },
            },
            -- tabline_x = { "ram", "cpu" },
            tabline_x = {},
            tabline_y = { "datetime" },
            tabline_z = { "domain" },
        },
        extensions = {
            "resurrect",
            "smart_workspace_switcher",
            "quick_domains",
        },
    })
end

local font = wezterm.font_with_fallback({
    "Hack Nerd Font Mono",
    "JetBrains Mono",
    "JetBrainsMono Nerd Font",
    "Fira Code Nerd Font",
})
local macbookFontSize = 13
local windowsFontSize = 10
config.font = font
config.font_size = is_macos and macbookFontSize or windowsFontSize

--ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
config.freetype_load_target = "Normal" ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
config.freetype_render_target = "Normal" ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'

config.inactive_pane_hsb = {
    brightness = 0.6,
}

config.launch_menu = launch_menu
return config
