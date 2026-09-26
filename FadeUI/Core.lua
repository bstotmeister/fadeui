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
--   Out of combat, a unit frame also pops up while its unit's health or power is
--   away from where it rests (full health; full mana or energy, empty rage) by
--   more than the pop-up threshold.
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
-- Chat has its own modes: it hides when idle rather than by combat state.
FadeUI.CHAT_MODES = {
	{ key = "always", code = "A", label = "Always",
	  tip = "Always shown, like the normal UI.",
	  color = { 0.24, 0.55, 0.30 }, driver = "show" },
	{ key = "active", code = "W", label = "When active",
	  tip = "Hides once the chat window you're looking at has had no new message, and you haven't typed, for the idle time. The next message brings it back.",
	  color = { 0.22, 0.44, 0.75 }, driver = "show" },
	{ key = "typing", code = "Y", label = "While typing",
	  tip = "Hidden except while you type a message.",
	  color = { 0.36, 0.36, 0.40 }, driver = "hide" },
}

-- Each list gets lookups by key and by settings-macro code.
for _, list in ipairs({ FadeUI.MODES, FadeUI.CHAT_MODES }) do
	list.byKey, list.byCode = {}, {}
	for i, m in ipairs(list) do
		m.index = i
		list.byKey[m.key] = m
		list.byCode[m.code] = m
	end
end
local MODE = FadeUI.MODES.byKey
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
	CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame" .. i .. "EditBox"
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
		{ id = 11, key = "player",  label = "Player Frame",      frames = { "PlayerFrame" },         default = "target", unit = "player" },
		{ id = 12, key = "pet",     label = "Pet Frame",         frames = { "PetFrame" },            default = "target", unit = "pet" },
		{ id = 13, key = "target",  label = "Target Frame",      frames = { "TargetFrame" },         default = "target", unit = "target" },
		{ id = 14, key = "tot",     label = "Target of Target",  frames = { "TargetFrameToT" },      default = "target",
		  note = "Sits inside the Target Frame, so it is also hidden whenever that is." },
		{ id = 15, key = "focus",   label = "Focus Frame",       frames = { "FocusFrame" },          default = "target", unit = "focus" },
		{ id = 16, key = "castbar", label = "Cast Bar",          frames = { "PlayerCastingBarFrame" }, default = "always", direct = true,
		  note = "Only appears while you cast anyway. If it is locked to the Player Frame in Edit Mode, it hides with that frame too." },
		{ id = 31, key = "swing",   label = "Swing Timers",      frames = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }, default = "combat" },
		{ id = 17, key = "boss",    label = "Boss Frames",       frames = { "BossTargetFrameContainer" }, default = "target" },
	}},
	{ title = "Group frames", items = {
		{ id = 18, key = "party",   label = "Party Frames",      frames = { "PartyFrame", "CompactPartyFrame" }, default = "combat" },
		{ id = 19, key = "raid",    label = "Raid Frames",       frames = { "CompactRaidFrameContainer" }, default = "combat" },
		{ id = 20, key = "raidmgr", label = "Raid Manager Tab",  frames = { "CompactRaidFrameManager" },   default = "never" },
	}},
	{ title = "Everything else", items = {
		{ id = 21, key = "minimap", label = "Minimap",           frames = { "MinimapCluster" },      default = "target" },
		{ id = 22, key = "buffs",   label = "Buffs",             frames = { "BuffFrame" },           default = "target" },
		{ id = 23, key = "debuffs", label = "Debuffs",           frames = { "DebuffFrame" },         default = "combat" },
		{ id = 24, key = "tracker", label = "Quest Tracker",     frames = { "ObjectiveTrackerFrame" }, default = "target", direct = true },
		{ id = 25, key = "chat",    label = "Chat",              frames = CHAT_FRAMES,               default = "active", modes = FadeUI.CHAT_MODES,
		  note = "Chat always comes back while you are typing a message." },
		{ id = 26, key = "micro",   label = "Menu Buttons",      frames = { "MicroMenuContainer" },  default = "never" },
		{ id = 27, key = "bags",    label = "Bag Buttons",       frames = { "BagsBar" },             default = "never" },
		{ id = 28, key = "xp",      label = "XP / Rep Bars",     frames = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }, default = "never" },
		{ id = 29, key = "cdm",     label = "Cooldown Manager",  frames = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }, default = "never", direct = true },
		{ id = 30, key = "meter",   label = "Damage Meter",      frames = { "DamageMeter" },         default = "never" },
	}},
}

local ELEMENTS, BY_KEY, BY_ID, BY_UNIT, MAX_ID = {}, {}, {}, {}, 0
for _, group in ipairs(FadeUI.GROUPS) do
	for _, el in ipairs(group.items) do
		el.modes = el.modes or FadeUI.MODES
		ELEMENTS[#ELEMENTS + 1] = el
		BY_KEY[el.key] = el
		BY_ID[el.id] = el
		if el.unit then BY_UNIT[el.unit] = el end
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
	target.fadeIn = 5     -- fade-in time, tenths of a second (0 = instant)
	target.fadeOut = 5    -- fade-out time, tenths of a second (0 = instant)
	target.fadeDelay = 50 -- wait before fading out, tenths of a second
	target.chatIdle = 100 -- "When active" chat hides after this long without activity, tenths of a second
	target.threshold = 5  -- unit frames pop up when health/power is off its resting value by more than this, percent (0 = off)
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
		if not BY_KEY[key].modes.byKey[t.modes[key] or ""] then t.modes[key] = mode end
	end
end

function FadeUI.GetDB() return db end

FadeUI.MAX_TIME = 999 -- tenths of a second; three digits in the settings macro

-- Compact form used by the settings macro: version, on/off, fade-in, fade-out,
-- fade-out delay, chat idle, pop-up threshold (three digits each), then one mode
-- letter per element id ("_" = unknown).
function FadeUI.Encode()
	local codes = {}
	for id = 1, MAX_ID do
		local el = BY_ID[id]
		local m = el and el.modes.byKey[db.modes[el.key]]
		codes[id] = m and m.code or "_"
	end
	local function t(v) return math.min(FadeUI.MAX_TIME, math.max(0, v or 0)) end
	return ("5%d%03d%03d%03d%03d%03d%s"):format(db.enabled and 1 or 0,
		t(db.fadeIn), t(db.fadeOut), t(db.fadeDelay), t(db.chatIdle), t(db.threshold), table.concat(codes))
end

function FadeUI.Decode(s)
	if type(s) ~= "string" or not db then return false end
	local enabled, fadeIn, fadeOut, delay, chatIdle, threshold, codes = s:match("^5([01])(%d%d%d)(%d%d%d)(%d%d%d)(%d%d%d)(%d%d%d)([%u_]*)")
	if not enabled then
		-- version 4: no pop-up threshold
		enabled, fadeIn, fadeOut, delay, chatIdle, codes = s:match("^4([01])(%d%d%d)(%d%d%d)(%d%d%d)(%d%d%d)([%u_]*)")
	end
	if not enabled then
		-- version 3: no chat idle
		enabled, fadeIn, fadeOut, delay, codes = s:match("^3([01])(%d%d%d)(%d%d%d)(%d%d%d)([ACTON_]*)")
	end
	if not enabled then
		-- version 2: single-digit fade-in, no fade-out
		enabled, fadeIn, codes = s:match("^2([01])(%d)([ACTON_]*)")
	end
	if not enabled then return false end
	db.enabled = enabled == "1"
	db.fadeIn = tonumber(fadeIn)
	if fadeOut then
		db.fadeOut = tonumber(fadeOut)
		db.fadeDelay = tonumber(delay)
	end
	if chatIdle then db.chatIdle = tonumber(chatIdle) end
	if threshold then db.threshold = math.min(100, tonumber(threshold)) end
	for id = 1, #codes do
		local el = BY_ID[id]
		local m = el and el.modes.byCode[codes:sub(id, id)]
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
	if state == "hide" and h.fadeuiEl and h.fadeuiEl.alert and not InCombatLockdown() then state = "show" end
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

-- Runs an element's holders through Holder_State again, after something other
-- than its state driver (chat typing or idle, a unit frame alert) changed.
local function Reevaluate(el)
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

-- Chat comes back while you type, so you can see what you're writing, and
-- hides once it has been idle (see ChatState).
function FadeUI.UpdateChatPeek()
	Reevaluate(BY_KEY.chat)
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

-- A unit frame pops up while its unit's health or power is off its resting
-- value by more than db.threshold. Only checked out of combat: protected frames
-- can't be shown in combat anyway. Secret values (which addon code can't do
-- math on) are skipped.
local POWER_RESTS_EMPTY = { [1] = true, [6] = true } -- rage, runic power

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

local function OffBy(cur, max, restsEmpty)
	if IsSecret(cur) or IsSecret(max) or not max or max <= 0 then return 0 end
	return restsEmpty and cur / max or 1 - cur / max
end

local function UnitAlert(unit)
	local t = (db.threshold or 0) / 100
	if t <= 0 or not UnitExists(unit) or UnitIsDeadOrGhost(unit) then return false end
	if OffBy(UnitHealth(unit), UnitHealthMax(unit)) > t then return true end
	return OffBy(UnitPower(unit), UnitPowerMax(unit), POWER_RESTS_EMPTY[UnitPowerType(unit)]) > t
end

-- `force` re-runs the holders even if the alert didn't change.
function FadeUI.UpdateAlert(el, force)
	if not db or not loggedIn or InCombatLockdown() then return end
	local alert = UnitAlert(el.unit)
	if alert ~= el.alert or force then
		el.alert = alert
		Reevaluate(el)
	end
end

function FadeUI.UpdateAlerts(force)
	for _, el in pairs(BY_UNIT) do FadeUI.UpdateAlert(el, force) end
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
					h.fadeuiEl = el.unit and el or nil
					SetDriver(h, mode.driver)
				else
					Detach(f)
				end
			end
		end
	end

	ChatIdleCheck()
	FadeUI.UpdateChatPeek()
	FadeUI.UpdateAlerts(true)
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
	if not (db and BY_KEY[key] and BY_KEY[key].modes.byKey[mode]) then return end
	db.modes[key] = mode
	FadeUI.Changed()
end

function FadeUI.SetAll(mode)
	if not (db and MODE[mode]) then return end
	for _, el in ipairs(ELEMENTS) do
		if el.modes.byKey[mode] then db.modes[el.key] = mode end -- chat only takes the modes it has
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

-- Unit frame pop-up threshold, whole percent (0 = off).
function FadeUI.SetThreshold(percent)
	if not db or type(percent) ~= "number" then return end
	db.threshold = math.min(100, math.max(0, math.floor(percent + 0.5)))
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
for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
	"UNIT_DISPLAYPOWER", "UNIT_PET", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }) do
	events:RegisterEvent(e)
end

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
		chatLastActive = GetTime()
		if mirror.macrosSeen then MirrorReady() else TryRestore() end
		FadeUI.Apply()

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
		if not mirror.ready then
			-- Normally UPDATE_MACROS says the macro list is in; don't wait forever.
			C_Timer.After(10, MirrorReady)
		end

	elseif event == "UPDATE_MACROS" then
		mirror.macrosSeen = true
		if loggedIn then MirrorReady() end

	elseif event == "PLAYER_REGEN_DISABLED" then
		if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end

	elseif event == "PLAYER_TARGET_CHANGED" then
		FadeUI.UpdateAlert(BY_UNIT.target)

	elseif event == "PLAYER_FOCUS_CHANGED" then
		FadeUI.UpdateAlert(BY_UNIT.focus)

	elseif event == "UNIT_PET" then
		if arg1 == "player" then FadeUI.UpdateAlert(BY_UNIT.pet) end

	elseif event:sub(1, 5) == "UNIT_" then
		if BY_UNIT[arg1] then FadeUI.UpdateAlert(BY_UNIT[arg1]) end

	elseif event == "PLAYER_REGEN_ENABLED" then
		if FadeUI.pendingApply then FadeUI.Apply() end
		FadeUI.UpdateAlerts(true) -- alerts aren't checked in combat
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
