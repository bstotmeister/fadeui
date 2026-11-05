-- FadeUI range icon: one spell you choose, shown after you try to cast while
-- out of range, so you can tell when you're close enough even with the action
-- bars and cast bar hidden.
--
--   /fui range unlocks it: drag it to move it, drop a spell on it from the
--   spellbook or an action bar, right-click to clear it. /fui range again locks it.
--   Locked, it stays hidden until you get an "Out of range" error with a target.
--   It's red until the spell is in range, then flashes and turns normal. It hides
--   when you cast that spell, or a few seconds after the last out-of-range error
--   or target change (so you can tab through targets to find one in range).
--
--   The corner number is how many casts of the spell your power covers.
--
--   This client can hide combat values from addons ("secret values"), which
--   can't be compared or used in maths. A secret range result still tints the
--   icon, but without the flash; a secret power value hides the number.

local _, ns = ...
local FadeUI = ns.FadeUI

local SIZE = 40
local TIMEOUT = 8   -- seconds the icon stays up after the last out-of-range error
local POLL = 0.1    -- seconds between range checks
local PLACEHOLDER = "Interface\\Icons\\INV_Misc_QuestionMark"

local WHITE = CreateColor(1, 1, 1)
local RED_TINT = CreateColor(1, 0.25, 0.25)
local RED = CreateColor(0.9, 0.1, 0.1)
local GREEN = CreateColor(0.2, 0.9, 0.3)
local BLACK = CreateColor(0, 0, 0)
local ACCENT = CreateColor(0.4, 0.8, 1)

local issecret = issecretvalue or function() return false end

local cfg              -- FadeUIDB.watch: { spell, point, relPoint, x, y }, per character
local unlocked = false
local active = false   -- up after an out-of-range error
local lastRange, timer, sinceCheck

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

local f = CreateFrame("Button", nil, UIParent)
f:SetSize(SIZE, SIZE)
f:SetFrameStrata("HIGH")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:RegisterForClicks("AnyUp")
f:EnableMouse(false)
f:Hide()

local border = f:CreateTexture(nil, "BACKGROUND")
border:SetAllPoints()
border:SetColorTexture(1, 1, 1, 1) -- tinted with SetVertexColor

local icon = f:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", 2, -2)
icon:SetPoint("BOTTOMRIGHT", -2, 2)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local flash = f:CreateTexture(nil, "OVERLAY")
flash:SetAllPoints(icon)
flash:SetColorTexture(1, 1, 1, 0.6)
flash:Hide()
local flashAnim = flash:CreateAnimationGroup()
local fade = flashAnim:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0)
fade:SetDuration(0.4)
flashAnim:SetScript("OnFinished", function() flash:Hide() end)

local count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
count:SetPoint("BOTTOMRIGHT", -3, 3)

local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
label:SetPoint("BOTTOM", f, "TOP", 0, 4)
label:SetText("Range icon")

local function Tint(iconColor, borderColor)
	icon:SetVertexColor(iconColor:GetRGB())
	border:SetVertexColor(borderColor:GetRGB())
end

-------------------------------------------------------------------------------
-- Count and range
-------------------------------------------------------------------------------

local function UpdateCount()
	local text = ""
	local costs = cfg and cfg.spell and C_Spell.GetSpellPowerCost(cfg.spell)
	for _, c in ipairs(costs or {}) do
		if not issecret(c.cost) and c.cost > 0 then
			local power = UnitPower("player", c.type)
			if not issecret(power) then text = tostring(math.floor(power / c.cost)) end
			break
		end
	end
	count:SetText(text)
end

local function UpdateRange()
	local r = C_Spell.IsSpellInRange(cfg.spell, "target")
	if issecret(r) then
		if icon.SetVertexColorFromBoolean then
			icon:SetVertexColorFromBoolean(r, WHITE, RED_TINT)
			border:SetVertexColorFromBoolean(r, GREEN, RED)
		end
		return
	end
	if r == false then
		Tint(RED_TINT, RED)
	elseif r == true then
		Tint(WHITE, GREEN)
		if lastRange == false then
			flash:Show()
			flashAnim:Restart()
		end
	else
		Tint(WHITE, BLACK) -- no range to check
	end
	lastRange = r
end

-------------------------------------------------------------------------------
-- Show and hide
-------------------------------------------------------------------------------

local function Refresh()
	if not cfg then return end
	local spell = cfg.spell
	icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or PLACEHOLDER)
	f:EnableMouse(unlocked)
	label:SetShown(unlocked)
	if not active then Tint(WHITE, unlocked and ACCENT or BLACK) end
	f:SetShown(unlocked or (active and spell ~= nil))
	if f:IsShown() then UpdateCount() end
end

local function Stop()
	active = false
	if timer then
		timer:Cancel()
		timer = nil
	end
	Refresh()
end

local function Start()
	if not (cfg and cfg.spell and UnitExists("target")) then return end
	active = true
	lastRange = false -- you were just out of range, so coming in flashes
	sinceCheck = 0
	if timer then timer:Cancel() end
	timer = C_Timer.NewTimer(TIMEOUT, Stop)
	Refresh()
	UpdateRange()
end

f:SetScript("OnUpdate", function(_, elapsed)
	if not active then return end
	sinceCheck = sinceCheck + elapsed
	if sinceCheck < POLL then return end
	sinceCheck = 0
	UpdateRange()
end)

-------------------------------------------------------------------------------
-- Unlocked: drop a spell, drag to move, right-click to clear
-------------------------------------------------------------------------------

local function TakeCursorSpell()
	local kind, _, _, spellID = GetCursorInfo()
	if kind ~= "spell" or not spellID then return end
	cfg.spell = spellID
	ClearCursor()
	Refresh()
end

f:SetScript("OnReceiveDrag", TakeCursorSpell)
f:SetScript("OnClick", function(_, button)
	if button == "RightButton" then
		cfg.spell = nil
		Stop()
	else
		TakeCursorSpell()
	end
end)
f:SetScript("OnDragStart", function(self)
	if not GetCursorInfo() then self:StartMoving() end
end)
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	cfg.point, cfg.relPoint, cfg.x, cfg.y = point, relPoint, x, y
end)
f:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText("FadeUI range icon", 1, 1, 1)
	GameTooltip:AddLine("Drop a spell here from your spellbook or an action bar. Drag to move. Right-click to clear.", nil, nil, nil, true)
	GameTooltip:AddLine("Type /fui range to lock it. Then it only appears after you get an \"Out of range\" error.", nil, nil, nil, true)
	GameTooltip:Show()
end)
f:SetScript("OnLeave", function() GameTooltip:Hide() end)

function FadeUI.IsRangeIconUnlocked() return unlocked end

function FadeUI.SetRangeIconUnlocked(on)
	unlocked = on and true or false
	Refresh()
	if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local OUT_OF_RANGE = {}
for _, s in pairs({ ERR_OUT_OF_RANGE, ERR_SPELL_OUT_OF_RANGE, SPELL_FAILED_OUT_OF_RANGE }) do -- pairs: skips any this client lacks
	OUT_OF_RANGE[s] = true
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")

f:SetScript("OnEvent", function(_, event, _, b, c)
	if event == "PLAYER_LOGIN" then
		-- Core has made FadeUIDB a table by now (ADDON_LOADED).
		if type(FadeUIDB.watch) ~= "table" then FadeUIDB.watch = {} end
		cfg = FadeUIDB.watch
		if cfg.point then
			f:SetPoint(cfg.point, UIParent, cfg.relPoint or cfg.point, cfg.x or 0, cfg.y or 0)
		else
			f:SetPoint("CENTER", 0, -120)
		end
		Refresh()
	elseif event == "UI_ERROR_MESSAGE" then
		if not issecret(b) and OUT_OF_RANGE[b] then Start() end
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- Stay up while tabbing through targets, so you can find one in range.
		if active then
			if timer then timer:Cancel() end
			timer = C_Timer.NewTimer(TIMEOUT, Stop)
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- A secret spell ID can't be compared, so any cast hides it then.
		if active and (issecret(c) or c == cfg.spell) then Stop() end
	elseif event == "UNIT_POWER_FREQUENT" then
		if f:IsShown() then UpdateCount() end
	end
end)
