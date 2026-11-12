-- Other addons' UI. Each file in Addons/ describes one addon FadeUI supports
-- and registers it here, so nothing about a particular addon lives in the core.
-- To support a new one, add Addons/<Name>.lua and list it in Addons/Addons.xml.
--
--   FadeUI.RegisterAddon({
--     addon    = "Questie", -- its folder name; nothing below happens unless it's loaded
--     frames   = { tracker = { "Questie_BaseFrame" } }, -- frames added to an element, by key
--     replace  = { chat = { ... } }, -- frames used instead of an element's own
--     styles   = { Questie_BaseFrame = "secure" }, -- how a frame is hidden (FRAME_STYLE in Core.lua)
--     elements = { { key = "...", label = "...", frames = { ... }, default = "never" } },
--                -- rows of its own, under "Other addons" (shown only while it's loaded)
--     OnLogin    = function() end, -- once, at login (or when it loads, if that's later)
--     OnChatIdle = function() end, -- chat has just gone idle
--   })

local _, ns = ...
local FadeUI = ns.FadeUI

local GROUP = "Other addons"
FadeUI.GetGroup(GROUP) -- after the built-in groups, before Custom frames

local specs = {}

local function IsLoaded(name)
	local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
	return isLoaded and isLoaded(name) and true or false
end

-- Runs one of an addon's handlers. An error in it is reported as usual but
-- doesn't stop FadeUI (or the other addons' handlers).
local function Call(fn, ...)
	if fn then xpcall(fn, geterrorhandler(), ...) end
end

function FadeUI.RegisterAddon(spec)
	specs[#specs + 1] = spec
	for _, el in ipairs(spec.elements or {}) do
		el.available = false
		FadeUI.AddElement(el, GROUP)
	end
end

-- Turns on what each registered addon adds, once that addon has loaded. Core
-- calls this at login, before it first hides anything, and again whenever an
-- addon loads after that.
function FadeUI.ActivateAddons()
	for _, spec in ipairs(specs) do
		if not spec.active and IsLoaded(spec.addon) then
			spec.active = true
			for key, names in pairs(spec.frames or {}) do
				local frames = FadeUI.BY_KEY[key].frames
				for _, name in ipairs(names) do frames[#frames + 1] = name end
			end
			for key, names in pairs(spec.replace or {}) do FadeUI.BY_KEY[key].frames = names end
			for name, style in pairs(spec.styles or {}) do FadeUI.FRAME_STYLE[name] = style end
			for _, el in ipairs(spec.elements or {}) do el.available = true end
			Call(spec.OnLogin)
		end
	end
end

-- Runs a handler, e.g. "OnChatIdle", for each active addon that has it.
function FadeUI.FireAddons(handler, ...)
	for _, spec in ipairs(specs) do
		if spec.active then Call(spec[handler], ...) end
	end
end
