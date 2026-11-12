-- Custom frames: any frame, by name, with a mode of its own, for UI that FadeUI
-- doesn't support itself. The names are kept in the settings (db.custom) and
-- each becomes an element in the "Custom frames" group, keyed "custom:<name>",
-- whose mode is stored with the others. A custom frame always gets a secure
-- holder, since FadeUI can't know whether it's protected (or will be).

local _, ns = ...
local FadeUI = ns.FadeUI

local GROUP = "Custom frames"
local PREFIX = "custom:"
FadeUI.GetGroup(GROUP).custom = true -- last in the list; Options adds the add line

-- Frames that can't be custom: the screen itself, FadeUI's window, and the
-- minimap (Minimap.lua takes it out of the minimap cluster).
local REFUSED = { UIParent = true, WorldFrame = true, FadeUIOptions = true, Minimap = true }

local current = {} -- the names that are elements now

-- Makes the custom elements match the settings' list. Callers apply the change.
function FadeUI.RebuildCustom()
	local db = FadeUI.GetDB()
	for _, name in ipairs(current) do
		FadeUI.RemoveElement(PREFIX .. name)
		FadeUI.FRAME_STYLE[name] = nil
	end
	current = {}
	for _, name in ipairs(db.custom) do
		local key = PREFIX .. name
		if not FadeUI.MODE[db.modes[key] or ""] then db.modes[key] = "always" end
		FadeUI.AddElement({ key = key, label = name, frames = { name }, default = "always", custom = true }, GROUP)
		FadeUI.FRAME_STYLE[name] = "secure"
		current[#current + 1] = name
	end
	if FadeUI.RefreshCustomRows then FadeUI.RefreshCustomRows() end
end

-- The element (other than a custom one) that already has this frame, if any.
local function Owner(name)
	for _, el in ipairs(FadeUI.ELEMENTS) do
		if not el.custom then
			for _, n in ipairs(el.frames) do
				if n == name then return el end
			end
		end
	end
end

-- Whether a name can be a custom frame, for a profile being imported: not one
-- FadeUI refuses, or one an element already has.
function FadeUI.CanBeCustom(name)
	return name ~= "" and not REFUSED[name] and not Owner(name)
end

-- Returns whether it was added, and a message saying what happened.
function FadeUI.AddCustomFrame(name)
	local db = FadeUI.GetDB()
	if not db then return false, "" end
	name = strtrim(name or "")
	if name == "" then return false, "Type a frame's name, or click Pick." end
	for _, n in ipairs(db.custom) do
		if n == name then return false, name .. " is already in the list." end
	end
	if REFUSED[name] then return false, "FadeUI can't hide " .. name .. "." end
	local owner = Owner(name)
	if owner then return false, name .. " is already part of " .. owner.label .. "." end
	local f = _G[name]
	if f ~= nil and not (type(f) == "table" and f.GetParent and f.SetParent) then
		return false, name .. " isn't a frame."
	end
	if f and f.IsForbidden and f:IsForbidden() then return false, "FadeUI can't hide " .. name .. "." end

	db.custom[#db.custom + 1] = name
	FadeUI.RebuildCustom()
	FadeUI.Changed()
	if f then return true, "Added " .. name .. ". Choose when it's shown below." end
	return true, "Added " .. name .. ". There's no frame with that name yet, so it's picked up once one appears."
end

-- The frame goes back to normal (Core's Apply releases it).
function FadeUI.RemoveCustomFrame(name)
	local db = FadeUI.GetDB()
	if not db then return end
	for i = #db.custom, 1, -1 do
		if db.custom[i] == name then table.remove(db.custom, i) end
	end
	db.modes[PREFIX .. name] = nil
	FadeUI.RebuildCustom()
	FadeUI.Changed()
end

-- Whether a custom frame wasn't there when FadeUI last applied its settings.
function FadeUI.CustomMissing()
	for _, name in ipairs(current) do
		local el = FadeUI.BY_KEY[PREFIX .. name]
		if el and el.found == 0 then return true end
	end
	return false
end

-- Some addons make their frames a few seconds after you log in, so a custom
-- frame that's missing then is looked for again a little later.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	for _, delay in ipairs({ 5, 15 }) do
		C_Timer.After(delay, function()
			if FadeUI.CustomMissing() then FadeUI.Apply() end
		end)
	end
end)
