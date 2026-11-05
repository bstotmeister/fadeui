-- Lint config for the WoW client's Lua 5.1 environment. Run: luacheck FadeUI
std = "lua51"
max_line_length = false
unused_args = false -- WoW callbacks get arguments they don't always need

-- Globals FadeUI defines.
globals = {
	"FadeUI",
	"FadeUIAccountDB",
	"FadeUIDB",
	"FadeUI_Toggle",
	"FadeUI_OpenOptions",
	"FadeUI_OnAddonCompartmentClick",
	"BINDING_HEADER_FADEUI",
	"BINDING_NAME_FADEUI_TOGGLE",
	"BINDING_NAME_FADEUI_OPTIONS",
	"SLASH_FADEUI1",
	"SLASH_FADEUI2",
	"SlashCmdList",
}

-- WoW API it reads. Add new ones here as the addon starts using them.
read_globals = {
	"C_Timer",
	"CreateFrame",
	"DEFAULT_CHAT_FRAME",
	"DeleteMacro",
	"EventRegistry",
	"GameTooltip",
	"GetBindingKey",
	"GetMacroInfo",
	"GetNumMacros",
	"GetTime",
	"InCombatLockdown",
	"NUM_CONTAINER_FRAMES",
	"RegisterStateDriver",
	"SecureCmdOptionParse",
	"UIParent",
	"UISpecialFrames",
	"UnregisterStateDriver",
	"hooksecurefunc",
	"strtrim",
	"tinsert",
}
