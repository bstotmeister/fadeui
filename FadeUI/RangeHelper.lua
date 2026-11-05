-- FadeUI range and resource helpers: with the action bars and cast bar hidden
-- there's no out-of-range or out-of-resource feedback, so when a spell fails
-- because of either, this shows that spell's icon. Each helper has its own
-- setting (rangeHelper, resourceHelper); they share the one icon.
--
--   Range is the border: red out of range, green in range. Resource is the icon:
--   dull (grayed and darker) while you're short on mana/rage/energy. Out of range
--   with enough resource also tints the icon red; with both, the icon stays dull
--   inside the red border, so both show. When it's ready it flashes and turns
--   normal. It hides when you cast that spell, or a few seconds after the last
--   failure or target change (so you can tab through targets to find one in range).
--
--   /fui range (or Move in the options) unlocks the icon to drag it into place.
--
--   This client can hide combat values from addons ("secret values"), which
--   can't be compared or used in maths. A secret range result still tints the
--   icon, but without the flash. (Your power is always secret here, which is why
--   there's no "casts left" number: the game's own usable check is used instead.)

local _, ns = ...
local FadeUI = ns.FadeUI

local SIZE = 40
local BORDER = 3       -- thick enough to read around a dull icon
local TIMEOUT = 8      -- seconds the icon stays up after the last error or target change
local POLL = 0.1       -- seconds between range checks
local PLACEHOLDER = "Interface\\Icons\\INV_Misc_QuestionMark"

local WHITE = CreateColor(1, 1, 1)
local RED_TINT = CreateColor(1, 0.25, 0.25)
local DULL = CreateColor(0.6, 0.6, 0.6)
local RED = CreateColor(0.9, 0.1, 0.1)
local GREEN = CreateColor(0.2, 0.9, 0.3)
local BLACK = CreateColor(0, 0, 0)
local ACCENT = CreateColor(0.4, 0.8, 1)

local issecret = issecretvalue or function() return false end

local spell                  -- the spell shown: the last one that failed out of range or resource
local failedSpell, failedAt  -- the player's last failed cast; its error follows right after
local unlocked = false
local active = false         -- up after a failed cast
local lastReady, timer, sinceCheck

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
icon:SetPoint("TOPLEFT", BORDER, -BORDER)
icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
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

local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
label:SetPoint("BOTTOM", f, "TOP", 0, 4)
label:SetText("Range / resource")

local function Tint(iconColor, borderColor)
	icon:SetVertexColor(iconColor:GetRGB())
	border:SetVertexColor(borderColor:GetRGB())
end

-------------------------------------------------------------------------------
-- Range and resource
-------------------------------------------------------------------------------

local function ShortOnResource(id)
	local _, noPower = C_Spell.IsSpellUsable(id)
	return not issecret(noPower) and noPower == true
end

-- Range is the border, resource is the icon; each only while its helper is on.
local function Update()
	local db = FadeUI.GetDB()
	local r -- nil: no range to show
	if db.rangeHelper then r = C_Spell.IsSpellInRange(spell, "target") end
	local dull = db.resourceHelper and ShortOnResource(spell)
	icon:SetDesaturated(dull)
	if issecret(r) then
		if icon.SetVertexColorFromBoolean then
			icon:SetVertexColorFromBoolean(r, dull and DULL or WHITE, dull and DULL or RED_TINT)
			border:SetVertexColorFromBoolean(r, GREEN, RED)
		end
		return
	end
	local iconColor = dull and DULL or r == false and RED_TINT or WHITE
	local borderColor = r == false and RED or r == true and GREEN or BLACK -- black: no range to check
	Tint(iconColor, borderColor)
	local ready = r ~= false and not dull
	if ready and not lastReady then
		flash:Show()
		flashAnim:Restart()
	end
	lastReady = ready
end

-------------------------------------------------------------------------------
-- Show and hide
-------------------------------------------------------------------------------

local function Refresh()
	icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or PLACEHOLDER)
	f:EnableMouse(unlocked)
	label:SetShown(unlocked)
	if not active then
		icon:SetDesaturated(false)
		Tint(WHITE, unlocked and ACCENT or BLACK)
	end
	f:SetShown(unlocked or active)
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

-- `field` is the helper's setting: "rangeHelper" or "resourceHelper".
local function Start(id, field)
	local db = FadeUI.GetDB()
	if not (db and db[field] and id) then return end
	spell = id
	active = true
	lastReady = false -- it just failed, so becoming ready flashes
	sinceCheck = 0
	RestartTimer()
	Refresh()
	Update()
end

f:SetScript("OnUpdate", function(_, elapsed)
	if not active then return end
	sinceCheck = sinceCheck + elapsed
	if sinceCheck < POLL then return end
	sinceCheck = 0
	Update()
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
	GameTooltip:SetText("FadeUI range / resource helper", 1, 1, 1)
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
	if active and not (db.rangeHelper or db.resourceHelper) then Stop() else Refresh() end
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

f:SetScript("OnEvent", function(_, event, _, b, c)
	if event == "PLAYER_LOGIN" then
		FadeUI.RefreshRangeHelper() -- Core has loaded the settings by now (ADDON_LOADED)
	elseif event == "UNIT_SPELLCAST_FAILED" then
		if issecret(c) then return end
		failedSpell, failedAt = c, GetTime()
		-- Short on resource: the game says so directly, whichever resource it is.
		if ShortOnResource(c) then Start(c, "resourceHelper") end
	elseif event == "UI_ERROR_MESSAGE" then
		if not issecret(b) and OUT_OF_RANGE[b] and failedAt and GetTime() - failedAt < 0.1 then
			Start(failedSpell, "rangeHelper")
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		if active then RestartTimer() end -- stay up while tabbing through targets
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- A secret spell ID can't be compared, so any cast hides it then.
		if active and (issecret(c) or c == spell) then Stop() end
	end
end)
