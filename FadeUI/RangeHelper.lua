-- FadeUI range helper: with the action bars and cast bar hidden there's no
-- out-of-range feedback, so when a spell fails with "Out of range" this shows
-- that spell's icon until you're close enough.
--
--   It's red until the spell is in range, then flashes and turns normal. It hides
--   when you cast that spell, or a few seconds after the last out-of-range error
--   or target change (so you can tab through targets to find one in range).
--   Auto attack's "You are too far away!" shows the Auto Attack icon.
--
--   The corner number is how many casts of the spell your power covers.
--
--   /fui range (or Move in the options) unlocks the icon to drag it into place.
--
--   This client can hide combat values from addons ("secret values"), which
--   can't be compared or used in maths. A secret range result still tints the
--   icon, but without the flash; a secret power value hides the number.

local _, ns = ...
local FadeUI = ns.FadeUI

local SIZE = 40
local TIMEOUT = 8      -- seconds the icon stays up after the last error or target change
local POLL = 0.1       -- seconds between range checks
local AUTO_ATTACK = 6603
local PLACEHOLDER = "Interface\\Icons\\INV_Misc_QuestionMark"

local WHITE = CreateColor(1, 1, 1)
local RED_TINT = CreateColor(1, 0.25, 0.25)
local RED = CreateColor(0.9, 0.1, 0.1)
local GREEN = CreateColor(0.2, 0.9, 0.3)
local BLACK = CreateColor(0, 0, 0)
local ACCENT = CreateColor(0.4, 0.8, 1)

local issecret = issecretvalue or function() return false end

local spell                  -- the spell shown: the last one that failed out of range
local failedSpell, failedAt  -- the player's last failed cast; its error follows right after
local unlocked = false
local active = false         -- up after an out-of-range error
local lastRange, timer, sinceCheck

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

local f = CreateFrame("Frame", nil, UIParent)
f:SetSize(SIZE, SIZE)
f:SetFrameStrata("HIGH")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
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
label:SetText("Range helper")

local function Tint(iconColor, borderColor)
	icon:SetVertexColor(iconColor:GetRGB())
	border:SetVertexColor(borderColor:GetRGB())
end

-------------------------------------------------------------------------------
-- Count and range
-------------------------------------------------------------------------------

local function UpdateCount()
	local text = ""
	local costs = spell and C_Spell.GetSpellPowerCost(spell)
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
	local r = C_Spell.IsSpellInRange(spell, "target")
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
	icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or PLACEHOLDER)
	f:EnableMouse(unlocked)
	label:SetShown(unlocked)
	if not active then Tint(WHITE, unlocked and ACCENT or BLACK) end
	f:SetShown(unlocked or active)
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

local function RestartTimer()
	if timer then timer:Cancel() end
	timer = C_Timer.NewTimer(TIMEOUT, Stop)
end

local function Start(id)
	local db = FadeUI.GetDB()
	if not (db and db.rangeHelper and id and UnitExists("target")) then return end
	spell = id
	active = true
	lastRange = false -- you were just out of range, so coming in flashes
	sinceCheck = 0
	RestartTimer()
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
-- Moving (while unlocked) and settings
-------------------------------------------------------------------------------

local function Place()
	local db = FadeUI.GetDB()
	f:ClearAllPoints()
	f:SetPoint(db.rangePoint, UIParent, db.rangeRelPoint, db.rangeX, db.rangeY)
end

f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local db = FadeUI.GetDB()
	local point, _, relPoint, x, y = self:GetPoint()
	db.rangePoint, db.rangeRelPoint, db.rangeX, db.rangeY = point, relPoint, x, y
end)
f:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText("FadeUI range helper", 1, 1, 1)
	GameTooltip:AddLine("Drag to move. Type /fui range, or click Lock in the options, when it's in place.", nil, nil, nil, true)
	GameTooltip:Show()
end)
f:SetScript("OnLeave", function() GameTooltip:Hide() end)

function FadeUI.IsRangeIconUnlocked() return unlocked end

function FadeUI.SetRangeIconUnlocked(on)
	unlocked = on and true or false
	Refresh()
	if FadeUI.RefreshOptions then FadeUI.RefreshOptions() end
end

-- Called by FadeUI.Changed: the settings in use, or one of them, changed.
function FadeUI.RefreshRangeHelper()
	local db = FadeUI.GetDB()
	if not db then return end
	Place()
	if active and not db.rangeHelper then Stop() else Refresh() end
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
f:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")

f:SetScript("OnEvent", function(_, event, _, b, c)
	if event == "PLAYER_LOGIN" then
		FadeUI.RefreshRangeHelper() -- Core has loaded the settings by now (ADDON_LOADED)
	elseif event == "UNIT_SPELLCAST_FAILED" then
		if not issecret(c) then failedSpell, failedAt = c, GetTime() end
	elseif event == "UI_ERROR_MESSAGE" then
		if issecret(b) then return end
		if b == ERR_BADATTACKPOS then
			Start(AUTO_ATTACK)
		elseif OUT_OF_RANGE[b] and failedAt and GetTime() - failedAt < 0.1 then
			Start(failedSpell)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		if active then RestartTimer() end -- stay up while tabbing through targets
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- A secret spell ID can't be compared, so any cast hides it then.
		if active and (issecret(c) or c == spell) then Stop() end
	elseif event == "UNIT_POWER_FREQUENT" then
		if f:IsShown() then UpdateCount() end
	end
end)
