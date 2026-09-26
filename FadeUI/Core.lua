-- FadeUI: hide the UI like Alt-Z, one element at a time.
--
-- How it works
--   Each Blizzard element (an action bar, the player frame, the minimap...) is
--   moved into an invisible "holder" frame that sits exactly where its old parent
--   was, so nothing moves or changes size. The holder is shown or hidden by a
--   secure state driver ("[combat] show; hide" and so on). A hidden holder hides
--   the element completely, like Alt-Z: it can't be seen or clicked, but keybinds
--   still fire. State drivers are run by Blizzard's secure code, so elements appear
--   and disappear in combat without "action blocked" errors.
--
--   Moving protected frames is only allowed out of combat, so setting changes made
--   during a fight are applied as soon as the fight ends.
--
--   While Edit Mode is open, or FadeUI is switched off, every element is put back
--   under its original parent: your normal UI, untouched.

local ADDON, ns = ...

local FadeUI = {}
ns.FadeUI = FadeUI
_G.FadeUI = FadeUI

local PREFIX = "|cff66ccffFadeUI|r: "
function FadeUI.Print(msg, ...)
	if select("#", ...) > 0 then msg = msg:format(...) end
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end
local Print = FadeUI.Print

-------------------------------------------------------------------------------
-- Modes
-------------------------------------------------------------------------------

FadeUI.MODES = {
	{ key = "always", code = "A", label = "Always",
	  tip = "Always shown, like the normal UI.",
	  color = { 0.24, 0.55, 0.30 }, driver = "show" },
	{ key = "combat", code = "C", label = "In combat",
	  tip = "Shown only while you are in combat.",
	  color = { 0.72, 0.24, 0.20 }, driver = "[combat] show; hide" },
	{ key = "target", code = "T", label = "Combat/Target",
	  tip = "Shown in combat, and whenever you have something targeted.",
	  color = { 0.80, 0.48, 0.14 }, driver = "[combat] show; [@target,exists] show; hide" },
	{ key = "ooc", code = "O", label = "Out of combat",
	  tip = "Shown only while you are NOT in combat.",
	  color = { 0.22, 0.44, 0.75 }, driver = "[combat] hide; show" },
	{ key = "never", code = "N", label = "Never",
	  tip = "Always hidden while FadeUI is on. Keybinds still work.",
	  color = { 0.36, 0.36, 0.40 }, driver = "hide" },
}
local MODE, MODE_BY_CODE = {}, {}
for i, m in ipairs(FadeUI.MODES) do
	m.index = i
	MODE[m.key] = m
	MODE_BY_CODE[m.code] = m
end
FadeUI.MODE = MODE

-------------------------------------------------------------------------------
-- Elements
--
-- `id` is the element's slot in the settings macro. Never reuse or renumber an
-- id; give a new element the next free number (display order doesn't matter).
-------------------------------------------------------------------------------

local CHAT_FRAMES = {
	"GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton",
	"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton",
	"TextToSpeechButton", "QuickJoinToastButton", "CombatLogQuickButtonFrame_Custom",
}
for i = 1, 10 do
	CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame" .. i
	CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame" .. i .. "Tab"
end

FadeUI.GROUPS = {
	{ title = "Action bars", items = {
		{ id = 1,  key = "bar1",   label = "Action Bar 1",       frames = { "MainActionBar", "MainMenuBar" }, default = "never" },
		{ id = 2,  key = "bar2",   label = "Action Bar 2",       frames = { "MultiBarBottomLeft" },  default = "never" },
		{ id = 3,  key = "bar3",   label = "Action Bar 3",       frames = { "MultiBarBottomRight" }, default = "never" },
		{ id = 4,  key = "bar4",   label = "Action Bar 4",       frames = { "MultiBarRight" },       default = "never" },
		{ id = 5,  key = "bar5",   label = "Action Bar 5",       frames = { "MultiBarLeft" },        default = "never" },
		{ id = 6,  key = "bar6",   label = "Action Bar 6",       frames = { "MultiBar5" },           default = "never" },
		{ id = 7,  key = "bar7",   label = "Action Bar 7",       frames = { "MultiBar6" },           default = "never" },
		{ id = 8,  key = "bar8",   label = "Action Bar 8",       frames = { "MultiBar7" },           default = "never" },
		{ id = 9,  key = "stance", label = "Stance / Form Bar",  frames = { "StanceBar" },           default = "never" },
		{ id = 10, key = "petbar", label = "Pet Bar",            frames = { "PetActionBar" },        default = "never" },
	}},
	{ title = "Unit frames", items = {
		{ id = 11, key = "player",  label = "Player Frame",      frames = { "PlayerFrame" },         default = "combat" },
		{ id = 12, key = "pet",     label = "Pet Frame",         frames = { "PetFrame" },            default = "combat" },
		{ id = 13, key = "target",  label = "Target Frame",      frames = { "TargetFrame" },         default = "combat" },
		{ id = 14, key = "tot",     label = "Target of Target",  frames = { "TargetFrameToT" },      default = "combat",
		  note = "Sits inside the Target Frame, so it is also hidden whenever that is." },
		{ id = 15, key = "focus",   label = "Focus Frame",       frames = { "FocusFrame" },          default = "combat" },
		{ id = 16, key = "castbar", label = "Cast Bar",          frames = { "PlayerCastingBarFrame" }, default = "always",
		  note = "Only appears while you cast anyway. If it is locked to the Player Frame in Edit Mode, it hides with that frame too." },
		{ id = 17, key = "boss",    label = "Boss Frames",       frames = { "BossTargetFrameContainer" }, default = "always" },
	}},
	{ title = "Group frames", items = {
		{ id = 18, key = "party",   label = "Party Frames",      frames = { "PartyFrame", "CompactPartyFrame" }, default = "combat" },
		{ id = 19, key = "raid",    label = "Raid Frames",       frames = { "CompactRaidFrameContainer" }, default = "combat" },
		{ id = 20, key = "raidmgr", label = "Raid Manager Tab",  frames = { "CompactRaidFrameManager" },   default = "never" },
	}},
	{ title = "Everything else", items = {
		{ id = 21, key = "minimap", label = "Minimap",           frames = { "MinimapCluster" },      default = "never" },
		{ id = 22, key = "buffs",   label = "Buffs",             frames = { "BuffFrame" },           default = "never" },
		{ id = 23, key = "debuffs", label = "Debuffs",           frames = { "DebuffFrame" },         default = "combat" },
		{ id = 24, key = "tracker", label = "Quest Tracker",     frames = { "ObjectiveTrackerFrame" }, default = "never" },
		{ id = 25, key = "chat",    label = "Chat",              frames = CHAT_FRAMES,               default = "never",
		  note = "Chat always comes back while you are typing a message." },
		{ id = 26, key = "micro",   label = "Menu Buttons",      frames = { "MicroMenuContainer" },  default = "never" },
		{ id = 27, key = "bags",    label = "Bag Buttons",       frames = { "BagsBar" },             default = "never" },
		{ id = 28, key = "xp",      label = "XP / Rep Bars",     frames = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }, default = "never" },
		{ id = 29, key = "cdm",     label = "Cooldown Manager",  frames = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }, default = "combat" },
		{ id = 30, key = "meter",   label = "Damage Meter",      frames = { "DamageMeter" },         default = "never" },
	}},
}

local ELEMENTS, BY_KEY, BY_ID, MAX_ID = {}, {}, {}, 0
for _, group in ipairs(FadeUI.GROUPS) do
	for _, el in ipairs(group.items) do
		ELEMENTS[#ELEMENTS + 1] = el
		BY_KEY[el.key] = el
		BY_ID[el.id] = el
		if el.id > MAX_ID then MAX_ID = el.id end
	end
end
FadeUI.ELEMENTS, FadeUI.BY_KEY = ELEMENTS, BY_KEY

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

local db
FadeUI.editMode = false
FadeUI.pendingApply = false
local loggedIn = false

local function Defaults(target)
	target.enabled = true -- FadeUI on (the Alt-Z-like state)
	target.fadeIn = 2     -- fade-in time, tenths of a second (0 = instant)
	target.macro = true   -- keep a copy of the settings in a macro (beta workaround)
	target.modes = {}
	for _, el in ipairs(ELEMENTS) do target.modes[el.key] = el.default end
end

local function FillMissing(t)
	local d = {}
	Defaults(d)
	for k, v in pairs(d) do
		if t[k] == nil then t[k] = v end
	end
	for key, mode in pairs(d.modes) do
		if not MODE[t.modes[key] or ""] then t.modes[key] = mode end
	end
end

function FadeUI.GetDB() return db end

-- Compact form used by the settings macro: version, on/off, fade-in, then one
-- mode letter per element id ("_" = unknown).
function FadeUI.Encode()
	local codes = {}
	for id = 1, MAX_ID do
		local el = BY_ID[id]
		local m = el and MODE[db.modes[el.key]]
		codes[id] = m and m.code or "_"
	end
	return ("2%d%d%s"):format(db.enabled and 1 or 0, math.min(9, math.max(0, db.fadeIn or 0)), table.concat(codes))
end

function FadeUI.Decode(s)
	if type(s) ~= "string" or not db then return false end
	local enabled, fade, codes = s:match("^2([01])(%d)([ACTON_]*)")
	if not enabled then return false end
	db.enabled = enabled == "1"
	db.fadeIn = tonumber(fade)
	for id = 1, #codes do
		local el, m = BY_ID[id], MODE_BY_CODE[codes:sub(id, id)]
		if el and m then db.modes[el.key] = m.key end
	end
	return true
end

-------------------------------------------------------------------------------
-- Holders
-------------------------------------------------------------------------------

local holders = {}   -- frame -> holder
local attached = {}  -- frame -> true while it lives inside its holder
local guard = false  -- set while we call SetParent ourselves

local fading = {}
local animator = CreateFrame("Frame")
animator:Hide()
animator:SetScript("OnUpdate", function(self, elapsed)
	local duration = db and (db.fadeIn or 0) / 10 or 0
	local step = duration > 0 and elapsed / duration or 1
	local busy = false
	for h in pairs(fading) do
		local a = h:GetAlpha() + step
		if a >= 1 or not h:IsShown() then
			h:SetAlpha(1)
			fading[h] = nil
		else
			h:SetAlpha(a)
			busy = true
		end
	end
	if not busy then self:Hide() end
end)

local function Holder_OnShow(self)
	if db and (db.fadeIn or 0) > 0 and loggedIn and attached[self.fadeuiFrame] then
		self:SetAlpha(0)
		fading[self] = true
		animator:Show()
	end
end

local function Holder_OnHide(self)
	fading[self] = nil
	self:SetAlpha(1)
end

local function SetDriver(h, driver)
	if h.fadeuiDriver == driver then return end
	UnregisterStateDriver(h, "visibility")
	h.fadeuiDriver = driver
	if driver == "show" then
		h:Show()
	elseif driver == "hide" then
		h:Hide()
	elseif driver then
		RegisterStateDriver(h, "visibility", driver)
	else
		h:Show()
	end
end

local function Attach(frame)
	local h = holders[frame]
	local parent = frame:GetParent() or UIParent
	if h and parent == h then
		attached[frame] = true
		return h
	end

	local strata, level = frame:GetFrameStrata(), frame:GetFrameLevel()

	if not h then
		h = CreateFrame("Frame", nil, parent)
		h.fadeuiFrame = frame
		h:SetScript("OnShow", Holder_OnShow)
		h:SetScript("OnHide", Holder_OnHide)
		holders[frame] = h
		-- If Blizzard moves the element to a new parent later (the cast bar does
		-- this when it's locked to the player frame), move the holder with it.
		hooksecurefunc(frame, "SetParent", function(self, newParent)
			if guard or not attached[self] or newParent == holders[self] then return end
			attached[self] = nil
			FadeUI.Apply()
		end)
	end

	h:ClearAllPoints()
	h:SetParent(parent)
	h:SetAllPoints(parent)
	h:SetFrameStrata(strata)
	h:SetFrameLevel(math.max(0, level - 1))

	guard = true
	frame:SetParent(h)
	guard = false
	frame:SetFrameStrata(strata)
	frame:SetFrameLevel(level)

	attached[frame] = true
	return h
end

local function Detach(frame)
	local h = holders[frame]
	attached[frame] = nil
	if not h then return end
	SetDriver(h, nil)
	if frame:GetParent() == h then
		local strata, level = frame:GetFrameStrata(), frame:GetFrameLevel()
		guard = true
		frame:SetParent(h:GetParent() or UIParent)
		guard = false
		frame:SetFrameStrata(strata)
		frame:SetFrameLevel(level)
	end
end

local function GetFrame(name)
	local f = _G[name]
	if type(f) == "table" and f.GetParent and f.SetParent and not (f.IsForbidden and f:IsForbidden()) then
		return f
	end
end

-- Chat comes back while you type, so you can see what you're writing.
function FadeUI.UpdateChatPeek()
	local el = BY_KEY.chat
	if not el or not db or not loggedIn then return end
	local typing = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and true or false
	for _, name in ipairs(el.frames) do
		local f = GetFrame(name)
		local h = f and holders[f]
		if h and attached[f] and h.fadeuiDriver then
			local want
			if typing or h.fadeuiDriver == "show" then
				want = true
			elseif h.fadeuiDriver == "hide" then
				want = false
			else
				want = SecureCmdOptionParse(h.fadeuiDriver) == "show"
			end
			if want ~= h:IsShown() and not (InCombatLockdown() and h:IsProtected()) then
				h:SetShown(want)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Apply
-------------------------------------------------------------------------------

function FadeUI.IsActive()
	return db and db.enabled and not FadeUI.editMode
end

function FadeUI.Apply()
	if not db or not loggedIn then return end
	if InCombatLockdown() then
		FadeUI.pendingApply = true
		if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end
		return
	end
	FadeUI.pendingApply = false

	local active = FadeUI.IsActive()
	for _, el in ipairs(ELEMENTS) do
		el.found = 0
		local mode = MODE[db.modes[el.key]] or MODE.always
		for _, name in ipairs(el.frames) do
			local f = GetFrame(name)
			if f then
				el.found = el.found + 1
				if active then
					SetDriver(Attach(f), mode.driver)
				else
					Detach(f)
				end
			end
		end
	end

	FadeUI.UpdateChatPeek()
	if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end
end

-------------------------------------------------------------------------------
-- Settings macro
--
-- The Forever beta client currently writes SavedVariables but never reads them
-- back, so every addon starts from defaults after a restart. Macros made with
-- CreateMacro do survive, so a copy of the settings is kept in one general macro
-- per character: "/fui load <data>". Clicking it just re-applies the settings.
-------------------------------------------------------------------------------

local mirror = { svLoaded = false, ready = false, restored = false, pendingWrite = false, token = 0 }

local function MacroName()
	local who = tostring(UnitName("player") or "") .. "-" .. tostring(GetRealmName and GetRealmName() or "")
	local h = 5381
	for i = 1, #who do h = (h * 33 + who:byte(i)) % 2147483647 end
	return ("FadeUI%08x"):format(h) -- 14 characters, under the 16 limit
end

local function MacroAPI()
	return CreateMacro and EditMacro and DeleteMacro and GetMacroBody and GetMacroIndexByName and true or false
end

local function MacroIndex()
	local ok, index = pcall(GetMacroIndexByName, MacroName())
	if ok and index and index > 0 then return index end
end

local function ReadMacro()
	if not MacroAPI() then return end
	local index = MacroIndex()
	if not index then return end
	local ok, body = pcall(GetMacroBody, index)
	if ok and type(body) == "string" then
		return body:match("/fui load ([%w_]+)") -- not anchored: bodies can come back with trailing spaces
	end
end

local function WriteMacro()
	if not (db and db.macro and mirror.ready and MacroAPI()) then return end
	if InCombatLockdown() then mirror.pendingWrite = true return end
	mirror.pendingWrite = false

	local data = FadeUI.Encode()
	if ReadMacro() == data then return end
	local body = "/fui load " .. data
	local index = MacroIndex()
	if index then
		pcall(EditMacro, index, nil, nil, body)
	else
		local ok, made = pcall(CreateMacro, MacroName(), "INV_Misc_Eye_01", body, nil)
		if ok and made and made ~= 0 then
			Print("saved your settings in a general macro named %s, because the Forever beta forgets addon settings on restart. Leave it alone; you can turn this off in /fui.", MacroName())
		elseif not mirror.warned then
			mirror.warned = true
			Print("couldn't create the settings macro (are your general macro slots full?). Settings will reset when the game restarts.")
		end
	end
end

local function DeleteSettingsMacro()
	if not MacroAPI() then return end
	if InCombatLockdown() then mirror.pendingDelete = true return end
	mirror.pendingDelete = false
	local index = MacroIndex()
	if index then pcall(DeleteMacro, index) end
end

-- Save soon, but not on every click.
local function ScheduleWrite()
	mirror.token = mirror.token + 1
	local token = mirror.token
	C_Timer.After(1, function()
		if token == mirror.token then WriteMacro() end
	end)
end

local function TryRestore()
	if mirror.svLoaded or mirror.restored or not db then return end
	local data = ReadMacro()
	if data and FadeUI.Decode(data) then
		mirror.restored = true
		db.macro = true
		Print("restored your settings from the settings macro.")
		FadeUI.Apply()
	end
end

local function MirrorReady()
	if mirror.ready then return end
	TryRestore()
	mirror.ready = true
	if not mirror.svLoaded and not mirror.restored then
		Print("is %s. Type |cffffff00/fui|r to choose what shows and when. Bind a toggle key under Key Bindings > AddOns.",
			db.enabled and "ON" or "off")
	end
	WriteMacro()
end

function FadeUI.SetMacroMirror(on)
	db.macro = on and true or false
	if db.macro then WriteMacro() else DeleteSettingsMacro() end
end

-------------------------------------------------------------------------------
-- Public actions
-------------------------------------------------------------------------------

-- Call after changing any setting.
function FadeUI.Changed()
	FadeUI.Apply()
	ScheduleWrite()
	if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end
end

function FadeUI.SetMode(key, mode)
	if not (db and BY_KEY[key] and MODE[mode]) then return end
	db.modes[key] = mode
	FadeUI.Changed()
end

function FadeUI.SetAll(mode)
	if not (db and MODE[mode]) then return end
	for _, el in ipairs(ELEMENTS) do db.modes[el.key] = mode end
	FadeUI.Changed()
end

function FadeUI.SetEnabled(on)
	if not db then return end
	db.enabled = on and true or false
	if InCombatLockdown() then
		Print("will turn %s when combat ends.", db.enabled and "on" or "off")
	end
	FadeUI.Changed()
end

function FadeUI.ResetDefaults()
	local keepMacro = db.macro
	Defaults(db)
	db.macro = keepMacro
	FadeUI.Changed()
end

function FadeUI_Toggle()
	if db then FadeUI.SetEnabled(not db.enabled) end
end

function FadeUI_OnAddonCompartmentClick(_, button)
	if button == "RightButton" then
		FadeUI_Toggle()
	else
		FadeUI_OpenOptions()
	end
end

BINDING_HEADER_FADEUI = "FadeUI"
BINDING_NAME_FADEUI_TOGGLE = "Toggle FadeUI (like Alt-Z)"
BINDING_NAME_FADEUI_OPTIONS = "Open FadeUI options"

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UPDATE_MACROS")

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then
			mirror.svLoaded = type(FadeUIDB) == "table" and type(FadeUIDB.modes) == "table"
			if not mirror.svLoaded then
				FadeUIDB = {}
				Defaults(FadeUIDB)
			end
			db = FadeUIDB
			FillMissing(db)
		elseif loggedIn then
			-- A Blizzard module loaded late may have created one of our frames.
			FadeUI.Apply()
		end

	elseif event == "PLAYER_LOGIN" then
		loggedIn = true
		if mirror.macrosSeen then MirrorReady() else TryRestore() end
		FadeUI.Apply()

		if ChatEdit_ActivateChat then
			hooksecurefunc("ChatEdit_ActivateChat", function() FadeUI.UpdateChatPeek() end)
		end
		if ChatEdit_DeactivateChat then
			hooksecurefunc("ChatEdit_DeactivateChat", function()
				C_Timer.After(0, FadeUI.UpdateChatPeek)
			end)
		end

		if EventRegistry and EventRegistry.RegisterCallback then
			EventRegistry:RegisterCallback("EditMode.Enter", function()
				FadeUI.editMode = true
				FadeUI.Apply()
			end, FadeUI)
			EventRegistry:RegisterCallback("EditMode.Exit", function()
				FadeUI.editMode = false
				FadeUI.Apply()
			end, FadeUI)
		end

	elseif event == "PLAYER_ENTERING_WORLD" then
		FadeUI.Apply()
		if not mirror.ready then
			-- Normally UPDATE_MACROS says the macro list is in; don't wait forever.
			C_Timer.After(10, MirrorReady)
		end

	elseif event == "UPDATE_MACROS" then
		mirror.macrosSeen = true
		if loggedIn then MirrorReady() end

	elseif event == "PLAYER_REGEN_DISABLED" then
		if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end

	elseif event == "PLAYER_REGEN_ENABLED" then
		if FadeUI.pendingApply then FadeUI.Apply() end
		if mirror.pendingWrite then WriteMacro() end
		if mirror.pendingDelete then DeleteSettingsMacro() end
		if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end
	end
end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

SLASH_FADEUI1 = "/fadeui"
SLASH_FADEUI2 = "/fui"
SlashCmdList.FADEUI = function(msg)
	msg = strtrim(msg or "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "" or cmd == "options" or cmd == "config" then
		FadeUI_OpenOptions()
	elseif cmd == "toggle" then
		FadeUI_Toggle()
		Print(db.enabled and "on." or "off. Your normal UI is back.")
	elseif cmd == "on" or cmd == "off" then
		FadeUI.SetEnabled(cmd == "on")
		Print(cmd == "on" and "on." or "off. Your normal UI is back.")
	elseif cmd == "load" then
		if FadeUI.Decode(rest) then
			FadeUI.Changed()
		else
			Print("that isn't a FadeUI settings string.")
		end
	elseif cmd == "reset" then
		FadeUI.ResetDefaults()
		Print("settings reset to defaults.")
	else
		Print("commands:")
		Print("  /fui - open the options window")
		Print("  /fui toggle | on | off - switch FadeUI (like Alt-Z)")
		Print("  /fui reset - back to default settings")
	end
end
