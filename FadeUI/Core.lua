-- FadeUI: hide the UI like Alt-Z, one element at a time.
--
-- How it works
--   Each Blizzard element (an action bar, the player frame, the minimap...) is
--   moved into an invisible "holder" frame that sits exactly where its old parent
--   was, so nothing moves or changes size. The holder is shown or hidden by a
--   secure state driver ("[combat] show; hide" and so on). A hidden holder hides
--   the element completely, like Alt-Z: it can't be seen or clicked, but keybinds
--   still fire. State drivers are run by Blizzard's secure code, so elements appear
--   and disappear in combat without "action blocked" errors. Out of combat, a hide
--   can wait (fade-out delay) and fade out before it happens.
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
	{ key = "always", label = "Always",
	  tip = "Always shown, like the normal UI.",
	  color = { 0.24, 0.55, 0.30 }, driver = "show" },
	{ key = "combat", label = "In combat",
	  tip = "Shown only while you are in combat.",
	  color = { 0.72, 0.24, 0.20 }, driver = "[combat] show; hide" },
	{ key = "target", label = "Combat/Target",
	  tip = "Shown in combat, and whenever you have something targeted.",
	  color = { 0.80, 0.48, 0.14 }, driver = "[combat] show; [@target,exists] show; hide" },
	{ key = "ooc", label = "Out of combat",
	  tip = "Shown only while you are NOT in combat.",
	  color = { 0.22, 0.44, 0.75 }, driver = "[combat] hide; show" },
	{ key = "never", label = "Never",
	  tip = "Always hidden while FadeUI is on. Keybinds still work.",
	  color = { 0.36, 0.36, 0.40 }, driver = "hide" },
}
-- Chat has its own modes: it hides when idle rather than by combat state.
FadeUI.CHAT_MODES = {
	{ key = "always", label = "Always",
	  tip = "Always shown, like the normal UI.",
	  color = { 0.24, 0.55, 0.30 }, driver = "show" },
	{ key = "active", label = "When active",
	  tip = "Hides once the chat window you're looking at has had no new message, and you haven't typed, for the idle time. The next message brings it back.",
	  color = { 0.22, 0.44, 0.75 }, driver = "show" },
	{ key = "typing", label = "While typing",
	  tip = "Hidden except while you type a message.",
	  color = { 0.36, 0.36, 0.40 }, driver = "hide" },
}

-- Each list gets a lookup by key.
for _, list in ipairs({ FadeUI.MODES, FadeUI.CHAT_MODES }) do
	list.byKey = {}
	for i, m in ipairs(list) do
		m.index = i
		list.byKey[m.key] = m
	end
end
local MODE = FadeUI.MODES.byKey
FadeUI.MODE = MODE

-------------------------------------------------------------------------------
-- Elements
-------------------------------------------------------------------------------

local CHAT_FRAMES = {
	"GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton",
	"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton",
	"TextToSpeechButton", "QuickJoinToastButton", "CombatLogQuickButtonFrame_Custom",
}
for i = 1, 10 do
	CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame" .. i
	CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame" .. i .. "Tab"
	CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame" .. i .. "EditBox"
end

FadeUI.GROUPS = {
	{ title = "Action bars", items = {
		{ key = "bar1",   label = "Action Bar 1",       frames = { "MainActionBar", "MainMenuBar" }, default = "never" },
		{ key = "bar2",   label = "Action Bar 2",       frames = { "MultiBarBottomLeft" },  default = "never" },
		{ key = "bar3",   label = "Action Bar 3",       frames = { "MultiBarBottomRight" }, default = "never" },
		{ key = "bar4",   label = "Action Bar 4",       frames = { "MultiBarRight" },       default = "never" },
		{ key = "bar5",   label = "Action Bar 5",       frames = { "MultiBarLeft" },        default = "never" },
		{ key = "bar6",   label = "Action Bar 6",       frames = { "MultiBar5" },           default = "never" },
		{ key = "bar7",   label = "Action Bar 7",       frames = { "MultiBar6" },           default = "never" },
		{ key = "bar8",   label = "Action Bar 8",       frames = { "MultiBar7" },           default = "never" },
		{ key = "stance", label = "Stance / Form Bar",  frames = { "StanceBar" },           default = "never" },
		{ key = "petbar", label = "Pet Bar",            frames = { "PetActionBar" },        default = "never" },
	}},
	{ title = "Unit frames", items = {
		{ key = "player",  label = "Player Frame",      frames = { "PlayerFrame" },         default = "target" },
		{ key = "pet",     label = "Pet Frame",         frames = { "PetFrame" },            default = "target" },
		{ key = "target",  label = "Target Frame",      frames = { "TargetFrame" },         default = "target" },
		{ key = "tot",     label = "Target of Target",  frames = { "TargetFrameToT" },      default = "target",
		  note = "Sits inside the Target Frame, so it is also hidden whenever that is." },
		{ key = "focus",   label = "Focus Frame",       frames = { "FocusFrame" },          default = "target" },
		{ key = "castbar", label = "Cast Bar",          frames = { "PlayerCastingBarFrame" }, default = "always", direct = true,
		  note = "Only appears while you cast anyway. If it is locked to the Player Frame in Edit Mode, it hides with that frame too." },
		{ key = "swing",   label = "Swing Timers",      frames = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }, default = "combat" },
		{ key = "boss",    label = "Boss Frames",       frames = { "BossTargetFrameContainer" }, default = "target" },
	}},
	{ title = "Group frames", items = {
		{ key = "party",   label = "Party Frames",      frames = { "PartyFrame", "CompactPartyFrame" }, default = "combat" },
		{ key = "raid",    label = "Raid Frames",       frames = { "CompactRaidFrameContainer" }, default = "combat" },
		{ key = "raidmgr", label = "Raid Manager Tab",  frames = { "CompactRaidFrameManager" },   default = "never" },
	}},
	{ title = "Everything else", items = {
		{ key = "minimap", label = "Minimap",           frames = { "MinimapCluster" },      default = "target" },
		{ key = "buffs",   label = "Buffs",             frames = { "BuffFrame" },           default = "target" },
		{ key = "debuffs", label = "Debuffs",           frames = { "DebuffFrame" },         default = "combat" },
		{ key = "tracker", label = "Quest Tracker",     frames = { "ObjectiveTrackerFrame" }, default = "target", direct = true },
		{ key = "chat",    label = "Chat",              frames = CHAT_FRAMES,               default = "active", modes = FadeUI.CHAT_MODES,
		  note = "Chat always comes back while you are typing a message." },
		{ key = "micro",   label = "Menu Buttons",      frames = { "MicroMenuContainer" },  default = "never" },
		{ key = "bags",    label = "Bag Buttons",       frames = { "BagsBar" },             default = "never" },
		{ key = "xp",      label = "XP / Rep Bars",     frames = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }, default = "never" },
		{ key = "cdm",     label = "Cooldown Manager",  frames = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }, default = "never", direct = true },
		{ key = "meter",   label = "Damage Meter",      frames = { "DamageMeter" },         default = "never" },
	}},
}

local ELEMENTS, BY_KEY = {}, {}
for _, group in ipairs(FadeUI.GROUPS) do
	for _, el in ipairs(group.items) do
		el.modes = el.modes or FadeUI.MODES
		ELEMENTS[#ELEMENTS + 1] = el
		BY_KEY[el.key] = el
	end
end
FadeUI.ELEMENTS, FadeUI.BY_KEY = ELEMENTS, BY_KEY

-------------------------------------------------------------------------------
-- Settings
--
-- Settings are account-wide (FadeUIAccountDB). A character can switch to its
-- own instead, kept in its per-character FadeUIDB with perCharacter = true.
-------------------------------------------------------------------------------

local db -- the settings in use: FadeUIAccountDB, or this character's FadeUIDB
FadeUI.editMode = false
FadeUI.pendingApply = false
local loggedIn = false

local function Defaults(target)
	target.enabled = true -- FadeUI on (the Alt-Z-like state)
	target.fadeIn = 5     -- fade-in time, tenths of a second (0 = instant)
	target.fadeOut = 5    -- fade-out time, tenths of a second (0 = instant)
	target.fadeDelay = 50 -- wait before fading out, tenths of a second
	target.chatIdle = 100 -- "When active" chat hides after this long without activity, tenths of a second
	target.rangeHelper = true -- show a spell's icon after it fails out of range (RangeHelper.lua)
	target.rangePoint, target.rangeRelPoint, target.rangeX, target.rangeY = "CENTER", "CENTER", 0, -120
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
		if not BY_KEY[key].modes.byKey[t.modes[key] or ""] then t.modes[key] = mode end
	end
end

-- Copies the settings (not the perCharacter switch) from one table to another.
local function CopySettings(from, to)
	local d = {}
	Defaults(d)
	for k in pairs(d) do to[k] = from[k] end
	to.modes = {}
	for key, mode in pairs(from.modes or {}) do to.modes[key] = mode end
end

-- Picks the account-wide or this character's settings. A character's own
-- settings start as a copy of the account-wide ones.
local function UseSettings()
	if FadeUIDB.perCharacter and type(FadeUIDB.modes) ~= "table" then
		CopySettings(FadeUIAccountDB, FadeUIDB)
	end
	db = FadeUIDB.perCharacter and FadeUIDB or FadeUIAccountDB
	FillMissing(db)
end

function FadeUI.GetDB() return db end

function FadeUI.IsPerCharacter()
	return type(FadeUIDB) == "table" and FadeUIDB.perCharacter or false
end

FadeUI.MAX_TIME = 999 -- tenths of a second

-------------------------------------------------------------------------------
-- Holders
-------------------------------------------------------------------------------

local holders = {}   -- frame -> holder
local attached = {}  -- frame -> true while it lives inside its holder
local guard = false  -- set while we call SetParent ourselves

local fading = {}  -- holder -> alpha it is fading to (1 = in, 0 = out)

local function FinishHide(h)
	if InCombatLockdown() and h:IsProtected() then
		h:SetAlpha(1) -- can't hide it now; don't leave it invisible but clickable
	else
		h:Hide()
	end
end

local animator = CreateFrame("Frame")
animator:Hide()
animator:SetScript("OnUpdate", function(self, elapsed)
	local busy = false
	for h, target in pairs(fading) do
		local duration = db and (target == 1 and db.fadeIn or db.fadeOut) or 0
		local step = duration > 0 and elapsed / (duration / 10) or 1
		local a = h:GetAlpha() + (target == 1 and step or -step)
		if not h:IsShown() or a >= 1 then
			h:SetAlpha(1)
			fading[h] = nil
		elseif a <= 0 then
			fading[h] = nil
			FinishHide(h)
		else
			h:SetAlpha(a)
			busy = true
		end
	end
	if not busy then self:Hide() end
end)

local function CancelFadeOut(h)
	if h.fadeuiTimer then
		h.fadeuiTimer:Cancel()
		h.fadeuiTimer = nil
	end
	if fading[h] == 0 then
		fading[h] = nil
		h:SetAlpha(1)
	end
end

local function StartFadeOut(h)
	h.fadeuiTimer = nil
	if not h:IsShown() then return end
	-- A direct element isn't inside its holder, so fading the holder does nothing.
	if (db.fadeOut or 0) > 0 and not h.fadeuiDirect then
		fading[h] = 0
		animator:Show()
	else
		FinishHide(h)
	end
end

-- Chat is shown while you type, and hidden once it has been idle (see ChatIdleCheck).
local chatIdle = false
local chatTyping -- the chat edit box being typed in, if any

local function ChatState(state)
	if chatTyping then return "show" end
	if chatIdle then return "hide" end
	return state
end

-- The holder's state driver changed to "show" or "hide". Secure holders run
-- STATE_SNIPPET first, which has already shown them (or hidden them in combat).
-- `now` skips the fade-out delay.
local function Holder_State(h, state, now)
	if h.fadeuiChat then state = ChatState(state) end
	if h.fadeuiTimer then
		h.fadeuiTimer:Cancel()
		h.fadeuiTimer = nil
	end
	if state == "show" then
		if not h:IsShown() then
			h:Show()
		elseif fading[h] == 0 then
			fading[h] = 1 -- fade back in from wherever the fade-out got to
			animator:Show()
		end
	elseif InCombatLockdown() or not loggedIn then
		fading[h] = nil
		FinishHide(h)
	elseif h:IsShown() and fading[h] ~= 0 then
		local delay = now and 0 or (db.fadeDelay or 0) / 10
		if delay > 0 then
			h.fadeuiTimer = C_Timer.NewTimer(delay, function() StartFadeOut(h) end)
		else
			StartFadeOut(h)
		end
	end
end

local function Holder_OnAttributeChanged(self, name, value)
	if name == "state-fadeui" then Holder_State(self, value) end
end

-- Runs in Blizzard's secure environment, so protected holders can be shown and
-- hidden in combat. Out of combat the hide is left to Holder_State.
local STATE_SNIPPET = [[
	if newstate == "show" then
		self:Show()
	elseif PlayerInCombat() then
		self:Hide()
		return
	end
	self:CallMethod("FadeUI_State", newstate)
]]

local wanted = {}  -- frame -> whether Blizzard wants it shown (direct elements only)

-- Show or hide a direct element (see AttachDirect). It is only brought back if
-- Blizzard wants it shown: a cast bar with no cast, or an empty quest tracker,
-- stays hidden.
local function SetFrameShown(frame, shown)
	if shown and not wanted[frame] then return end
	if frame:IsShown() == shown or (InCombatLockdown() and frame:IsProtected()) then return end
	guard = true
	frame:SetShown(shown)
	guard = false
end

local function Holder_OnShow(self)
	if self.fadeuiDirect then
		SetFrameShown(self.fadeuiFrame, true)
		return
	end
	if db and (db.fadeIn or 0) > 0 and loggedIn and attached[self.fadeuiFrame] then
		self:SetAlpha(0)
		fading[self] = 1
		animator:Show()
	end
end

local function Holder_OnHide(self)
	CancelFadeOut(self)
	fading[self] = nil
	self:SetAlpha(1)
	if self.fadeuiDirect and attached[self.fadeuiFrame] then
		SetFrameShown(self.fadeuiFrame, false)
	end
end

local function SetDriver(h, driver)
	if h.fadeuiDriver == driver then return end
	UnregisterStateDriver(h, "fadeui")
	CancelFadeOut(h)
	h.fadeuiDriver = driver
	if driver == "show" then
		h:Show()
	elseif driver == "hide" then
		h:Hide()
	elseif driver then
		RegisterStateDriver(h, "fadeui", driver)
	else
		h:Show()
	end
end

-- Some Blizzard frames are "managed": whenever they show, and whenever the screen
-- is rearranged, their container clears their position, moves them into itself
-- and lays out its direct children. Taking the frame into its holder before that
-- layout runs leaves it with no position at all, so it never draws. Instead the
-- holder waits until the container has finished, and the frame keeps the spot
-- the layout gave it. (Later layouts don't leave room for it, so a neighbouring
-- managed frame can occasionally overlap it.)
local hookedContainers = {}

local function IsManagedContainer(frame, parent)
	local c = frame.layoutParent
	return c ~= nil and parent ~= nil and (parent == c or parent == c.BottomManagedLayoutContainer)
end

local function HookManagedContainer(frame)
	local c = frame.layoutParent
	if type(c) ~= "table" or type(c.UpdateFrame) ~= "function" or hookedContainers[c] then return end
	hookedContainers[c] = true
	hooksecurefunc(c, "UpdateFrame", function(_, f)
		if holders[f] and not attached[f] and not holders[f].fadeuiDirect then FadeUI.Apply() end
	end)
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
		-- Holders of protected frames (action bars...) need a secure handler to
		-- be shown and hidden in combat. Others stay plain, so chat can still
		-- peek in combat.
		local secure = frame:IsProtected()
		h = CreateFrame("Frame", nil, parent, secure and "SecureHandlerStateTemplate" or nil)
		if secure then
			h:SetAttribute("_onstate-fadeui", STATE_SNIPPET)
		else
			h:SetScript("OnAttributeChanged", Holder_OnAttributeChanged)
		end
		h.FadeUI_State = Holder_State
		h.fadeuiFrame = frame
		h:SetScript("OnShow", Holder_OnShow)
		h:SetScript("OnHide", Holder_OnHide)
		holders[frame] = h
		-- If Blizzard moves the element to a new parent later, move the holder
		-- with it. A managed frame (see HookManagedContainer) is moved into its
		-- container and then laid out, so it's taken back once that's done.
		hooksecurefunc(frame, "SetParent", function(self, newParent)
			if guard or not attached[self] or newParent == holders[self] then return end
			attached[self] = nil
			if not IsManagedContainer(self, newParent) then FadeUI.Apply() end
		end)
		HookManagedContainer(frame)
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

-- Managed frames that aren't protected (the cast bar, quest tracker, cooldown
-- manager) stay out of holders completely, so Blizzard's layout keeps working
-- as normal. The holder just carries the state driver, and the frame itself is
-- hidden while the holder is hidden.
local function AttachDirect(frame)
	local h = holders[frame]
	if not h then
		h = CreateFrame("Frame", nil, UIParent)
		h.fadeuiFrame = frame
		h.fadeuiDirect = true
		h.FadeUI_State = Holder_State
		h:SetScript("OnAttributeChanged", Holder_OnAttributeChanged)
		h:SetScript("OnShow", Holder_OnShow)
		h:SetScript("OnHide", Holder_OnHide)
		holders[frame] = h
		wanted[frame] = frame:IsShown()
		local function Want(self, shown)
			if not guard then wanted[self] = shown and true or false end
		end
		hooksecurefunc(frame, "Show", function(self) Want(self, true) end)
		hooksecurefunc(frame, "Hide", function(self) Want(self, false) end)
		hooksecurefunc(frame, "SetShown", Want)
		frame:HookScript("OnShow", function(self)
			if attached[self] and not holders[self]:IsShown() then SetFrameShown(self, false) end
		end)
	end
	attached[frame] = true
	if not h:IsShown() then SetFrameShown(frame, false) end
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

-- Chat comes back while you type, so you can see what you're writing, and
-- hides once it has been idle (see ChatState).
function FadeUI.UpdateChatPeek()
	local el = BY_KEY.chat
	if not el or not db or not loggedIn then return end
	for _, name in ipairs(el.frames) do
		local f = GetFrame(name)
		local h = f and holders[f]
		if h and attached[f] and h.fadeuiDriver and not (InCombatLockdown() and h:IsProtected()) then
			local state = h.fadeuiDriver
			if state ~= "show" and state ~= "hide" then state = SecureCmdOptionParse(state) end
			Holder_State(h, state, true)
		end
	end
end

-- Chat is idle once the shown chat window has had no new message, and you
-- haven't typed, for db.chatIdle.
local chatLastActive, chatTimer = 0, nil

local function ChatIdleCheck()
	if chatTimer then
		chatTimer:Cancel()
		chatTimer = nil
	end
	local timeout = db and db.modes.chat == "active" and (db.chatIdle or 0) / 10 or 0
	local left = chatLastActive + timeout - GetTime()
	if timeout > 0 and left > 0 then chatTimer = C_Timer.NewTimer(left, ChatIdleCheck) end
	local idle = timeout > 0 and left <= 0
	if idle ~= chatIdle then
		chatIdle = idle
		FadeUI.UpdateChatPeek()
	end
end

function FadeUI.ChatActivity()
	chatLastActive = GetTime()
	-- A pending timer re-checks the time itself when it fires.
	if chatIdle or not chatTimer then ChatIdleCheck() end
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
		local mode = el.modes.byKey[db.modes[el.key]] or el.modes.byKey.always
		for _, name in ipairs(el.frames) do
			local f = GetFrame(name)
			if f then
				el.found = el.found + 1
				if active then
					local h = (el.direct and AttachDirect or Attach)(f)
					h.fadeuiChat = el.key == "chat"
					SetDriver(h, mode.driver)
				else
					Detach(f)
				end
			end
		end
	end

	ChatIdleCheck()
	FadeUI.UpdateChatPeek()
	if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end
end

-------------------------------------------------------------------------------
-- Old settings macros
--
-- Version 1.0.0 kept a copy of its settings in a general macro per character
-- (named FadeUI + 8 hex digits, body "/fui load ..."), because the Forever beta
-- didn't load SavedVariables. The live game does, so those macros are removed.
-------------------------------------------------------------------------------

local pendingMacroCleanup = false
local cleaningMacros = false -- DeleteMacro can fire UPDATE_MACROS mid-loop

local function RemoveOldMacros()
	if cleaningMacros then return end
	if InCombatLockdown() then
		pendingMacroCleanup = true
		return
	end
	pendingMacroCleanup = false
	cleaningMacros = true
	local removed = false
	for i = GetNumMacros(), 1, -1 do -- general (account-wide) macros only
		local name, _, body = GetMacroInfo(i)
		if name and name:match("^FadeUI%x%x%x%x%x%x%x%x$") and body and body:find("/fui load", 1, true) then
			DeleteMacro(i)
			removed = true
		end
	end
	cleaningMacros = false
	if removed then
		Print("removed its old settings macro. The game saves addon settings properly now, so it isn't needed.")
	end
end

-------------------------------------------------------------------------------
-- Public actions
-------------------------------------------------------------------------------

-- Call after changing any setting.
function FadeUI.Changed()
	FadeUI.Apply()
	if FadeUI.RefreshRangeHelper then FadeUI.RefreshRangeHelper() end
	if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end
end

function FadeUI.SetRangeHelper(on)
	if not db then return end
	db.rangeHelper = on and true or false
	FadeUI.Changed()
end

-- Switches this character between the account-wide settings and its own.
function FadeUI.SetPerCharacter(on)
	if not db then return end
	FadeUIDB.perCharacter = on and true or false
	UseSettings()
	FadeUI.Changed()
end

function FadeUI.SetMode(key, mode)
	if not (db and BY_KEY[key] and BY_KEY[key].modes.byKey[mode]) then return end
	db.modes[key] = mode
	FadeUI.Changed()
end

-- `only` (optional) is a set of element keys to limit it to, e.g. search matches.
function FadeUI.SetAll(mode, only)
	if not (db and MODE[mode]) then return end
	for _, el in ipairs(ELEMENTS) do
		-- chat only takes the modes it has
		if el.modes.byKey[mode] and (not only or only[el.key]) then db.modes[el.key] = mode end
	end
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

-- `field` is "fadeIn", "fadeOut", "fadeDelay" or "chatIdle"; `seconds` may be fractional.
function FadeUI.SetTime(field, seconds)
	if not db or type(seconds) ~= "number" then return end
	db[field] = math.min(FadeUI.MAX_TIME, math.max(0, math.floor(seconds * 10 + 0.5)))
	FadeUI.Changed()
end

function FadeUI.ResetDefaults()
	Defaults(db)
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

local firstRun = false

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then
			if type(FadeUIDB) ~= "table" then FadeUIDB = {} end
			if type(FadeUIAccountDB) ~= "table" then
				-- First load with account-wide settings: start them from this
				-- character's settings (from when they were per character), if any.
				FadeUIAccountDB = {}
				if type(FadeUIDB.modes) == "table" then
					CopySettings(FadeUIDB, FadeUIAccountDB)
				else
					firstRun = true
				end
			end
			FadeUIDB.macro, FadeUIAccountDB.macro = nil, nil -- the old settings-macro switch
			FadeUIDB.watch = nil -- the range helper's old spell slot (never released)
			UseSettings()
		elseif loggedIn then
			-- A Blizzard module loaded late may have created one of our frames.
			FadeUI.Apply()
		end

	elseif event == "PLAYER_LOGIN" then
		loggedIn = true
		chatLastActive = GetTime()
		FadeUI.Apply()
		if firstRun then
			Print("is %s. Type |cffffff00/fui|r to choose what shows and when. Bind a toggle key under Key Bindings > AddOns.",
				db.enabled and "ON" or "off")
		end

		-- Typing: a chat edit box asked to take focus (Enter, /, reply...) brings
		-- chat back. It may have been hidden with chat, so it's focused again once shown.
		local function StartTyping(box)
			if chatTyping == box then return end
			chatTyping = box
			FadeUI.UpdateChatPeek()
			if not box:HasFocus() then box:SetFocus() end
		end
		local function StopTyping(box)
			C_Timer.After(0, function()
				if chatTyping ~= box or box:HasFocus() then return end
				chatTyping = nil
				FadeUI.ChatActivity()
				FadeUI.UpdateChatPeek()
			end)
		end
		for i = 1, 10 do
			local box = GetFrame("ChatFrame" .. i .. "EditBox")
			if box and box.SetFocus then
				hooksecurefunc(box, "SetFocus", StartTyping)
				box:HookScript("OnEditFocusGained", StartTyping)
				box:HookScript("OnEditFocusLost", StopTyping)
			end
			-- New lines in a chat window you can see (the selected tab, or an
			-- undocked window) count as chat activity.
			local f = GetFrame("ChatFrame" .. i)
			if f and f.AddMessage then
				hooksecurefunc(f, "AddMessage", function(self)
					if self:IsShown() then FadeUI.ChatActivity() end
				end)
			end
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
		RemoveOldMacros()

	elseif event == "UPDATE_MACROS" then
		-- The macro list may only arrive after login.
		if loggedIn then RemoveOldMacros() end

	elseif event == "PLAYER_REGEN_DISABLED" then
		if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end

	elseif event == "PLAYER_REGEN_ENABLED" then
		if FadeUI.pendingApply then FadeUI.Apply() end
		if pendingMacroCleanup then RemoveOldMacros() end
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
	local cmd = (msg:match("^(%S*)") or ""):lower()

	if cmd == "" or cmd == "options" or cmd == "config" then
		FadeUI_OpenOptions()
	elseif cmd == "toggle" then
		FadeUI_Toggle()
		Print(db.enabled and "on." or "off. Your normal UI is back.")
	elseif cmd == "on" or cmd == "off" then
		FadeUI.SetEnabled(cmd == "on")
		Print(cmd == "on" and "on." or "off. Your normal UI is back.")
	elseif cmd == "reset" then
		FadeUI.ResetDefaults()
		Print("settings reset to defaults.")
	elseif cmd == "range" then
		FadeUI.SetRangeIconUnlocked(not FadeUI.IsRangeIconUnlocked())
		Print(FadeUI.IsRangeIconUnlocked()
			and "range helper unlocked: drag it into place. Type |cffffff00/fui range|r again to lock it."
			or "range helper locked. It appears when a spell fails with \"Out of range\".")
	else
		Print("commands:")
		Print("  /fui - open the options window")
		Print("  /fui toggle | on | off - switch FadeUI (like Alt-Z)")
		Print("  /fui range - unlock (to move) or lock the range helper")
		Print("  /fui reset - back to default settings")
	end
end
