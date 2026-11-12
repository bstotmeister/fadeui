-- FadeUI minimap styles: what the minimap looks like while it's shown, and
-- what's left of it while it's hidden.
--
--   Shown:  Normal (Blizzard's minimap), or Map (just the map, cropped to a
--           circle around you at your usual zoom; no border or buttons).
--   Hidden: None, Nodes (only what the minimap marks: herb and ore nodes, quest
--           areas, party members, your arrow), or Map.
--   Shown and hidden each have their own Map size, 30% to 100% of the minimap.
--
--   Nodes and Map take just the Minimap frame out of the minimap cluster
--   (border, zone text, buttons) while the cluster is hidden. Nodes makes it
--   fully transparent: that hides the map, but the minimap still draws its
--   blips. Map crops it with a smaller round mask (Media/MinimapMask*.tga).
--   Either way it takes mouse-over (for the blips' tooltips), and clicks only
--   with Ping on (minimapPing): off, clicks go through to the world.
--
--   With Map chosen for shown, the cluster stays hidden (Core's Apply), and a
--   state driver here follows the minimap's mode to switch between the shown
--   and hidden styles.

local ADDON, ns = ...
local FadeUI = ns.FadeUI

-- Map sizes, % of the minimap. Each below 100 has a mask (scripts/make-minimap-masks.py).
local SIZES = {}
for s = 30, 100, 5 do SIZES[#SIZES + 1] = s end
local MASK = "Interface\\AddOns\\" .. ADDON .. "\\Media\\MinimapMask%d.tga"
local DEFAULT_MASK = 186178 -- textures\minimapmask, the minimap's own round mask
local HYBRID_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask" -- HybridMinimap's (indoor maps)

-- A size setting ("minimapShownSize" or "minimapHiddenSize"), snapped to the
-- closest step. Returns the size and its index.
local function Size(db, field)
	local want, best = db[field] or 100, 1
	for i, s in ipairs(SIZES) do
		if math.abs(s - want) < math.abs(SIZES[best] - want) then best = i end
	end
	return SIZES[best], best
end

-------------------------------------------------------------------------------
-- Moving the minimap out of the cluster and back
-------------------------------------------------------------------------------

-- Holds the minimap while the cluster is hidden.
local overlay = CreateFrame("Frame", nil, UIParent)
overlay:SetAllPoints()

local style    -- where the minimap is: nil (in the cluster), "nodes" or "map"
local saved    -- the minimap's parent, alpha and mouse state while it's out
local children -- child frame -> { alpha, mouse } for the ones hidden while it's out
local maskSize -- the smaller mask in use, if any

local function MoveOut()
	local parent = Minimap:GetParent() or UIParent
	saved = {
		parent = parent,
		alpha = Minimap:GetAlpha(),
		click = Minimap:IsMouseClickEnabled(),
		motion = Minimap:IsMouseMotionEnabled(),
		wheel = Minimap:IsMouseWheelEnabled(),
		insets = { Minimap:GetHitRectInsets() },
	}
	-- Same effective scale as before, so it keeps its size (its anchors don't change).
	overlay:SetScale(parent:GetEffectiveScale() / UIParent:GetEffectiveScale())
	local strata, level = Minimap:GetFrameStrata(), Minimap:GetFrameLevel()
	Minimap:SetParent(overlay)
	Minimap:SetFrameStrata(strata)
	Minimap:SetFrameLevel(level)
	-- Mouse-over shows the blips' tooltips; clicks are set in Place.
	Minimap:SetMouseMotionEnabled(true)
	Minimap:EnableMouseWheel(false)
	-- Hide what's attached to the minimap (compass ring, zoom and addon buttons),
	-- and keep it from catching the mouse. HybridMinimap is the map itself indoors.
	children = {}
	for _, c in ipairs({ Minimap:GetChildren() }) do
		if c ~= HybridMinimap and not c:IsProtected() then
			children[c] = { c:GetAlpha(), c:IsMouseEnabled() }
			c:SetAlpha(0)
			c:EnableMouse(false)
		end
	end
end

local function MoveBack()
	for c, s in pairs(children) do
		c:SetAlpha(s[1])
		c:EnableMouse(s[2])
	end
	children = nil
	local strata, level = Minimap:GetFrameStrata(), Minimap:GetFrameLevel()
	Minimap:SetParent(saved.parent)
	Minimap:SetFrameStrata(strata)
	Minimap:SetFrameLevel(level)
	Minimap:SetAlpha(saved.alpha)
	Minimap:SetMouseClickEnabled(saved.click)
	Minimap:SetMouseMotionEnabled(saved.motion)
	Minimap:EnableMouseWheel(saved.wheel)
	Minimap:SetHitRectInsets(unpack(saved.insets))
	saved = nil
end

-- `size` is a step below 100, or nil for the normal round mask.
local function SetMask(size)
	if size == maskSize then return end
	maskSize = size
	Minimap:SetMaskTexture(size and MASK:format(size) or DEFAULT_MASK)
	if HybridMinimap and HybridMinimap.CircleMask then
		HybridMinimap.CircleMask:SetTexture(size and MASK:format(size) or HYBRID_MASK)
	end
end

-- `want` is nil (normal), "nodes" or "map"; `size` is the map's size; `ping`
-- lets clicks ping (otherwise they go through to the world).
local function Place(want, size, ping)
	if want and not style then
		MoveOut()
	elseif not want and style then
		MoveBack()
	end
	style = want
	local crop = want == "map" and size < 100 and size or nil
	if want then
		Minimap:SetAlpha(want == "map" and 1 or 0)
		Minimap:SetMouseClickEnabled(ping)
		-- A cropped map only takes the mouse within the square around its circle.
		if crop then
			local inset = Minimap:GetWidth() * (1 - crop / 100) / 2
			Minimap:SetHitRectInsets(inset, inset, inset, inset)
		else
			Minimap:SetHitRectInsets(unpack(saved.insets))
		end
	end
	SetMask(crop)
end

-------------------------------------------------------------------------------
-- Shown or hidden, when the map replaces the normal minimap
-------------------------------------------------------------------------------

local stateFrame = CreateFrame("Frame")
local driver      -- the minimap mode's driver, registered while Shown is Map
local shown       -- whether that driver says show (hides wait for the fade-out delay)
local hideTimer

local function OnState(state)
	if FadeUI.HoverHolds("minimap", shown) then state = "show" end
	if hideTimer then
		hideTimer:Cancel()
		hideTimer = nil
	end
	local delay = FadeUI.GetTime("minimap", "fadeDelay") / 10
	if state == "show" or not shown or delay <= 0 then
		shown = state == "show"
		FadeUI.RefreshMinimap()
	else
		hideTimer = C_Timer.NewTimer(delay, function()
			hideTimer = nil
			shown = false
			FadeUI.RefreshMinimap()
		end)
	end
end

stateFrame:SetScript("OnAttributeChanged", function(_, name, value)
	if name == "state-fadeui" then OnState(value) end
end)

-- The mouse moved onto or off the minimap (Core's HoverCheck): re-checks the
-- driver's state, with hover taken into account.
function FadeUI.RecheckMinimapHover()
	if not driver then return end
	OnState((driver == "show" or driver == "hide") and driver or SecureCmdOptionParse(driver))
end

-- State drivers can only be changed out of combat (Apply runs then).
local function SetStateDriver(d)
	if d == driver or InCombatLockdown() then return end
	UnregisterStateDriver(stateFrame, "fadeui")
	driver = d
	if d == "show" or d == "hide" then
		OnState(d)
	elseif d then
		RegisterStateDriver(stateFrame, "fadeui", d)
		-- Registering doesn't call back when the state is unchanged (e.g. FadeUI
		-- turned off and on with a target), so apply it here.
		OnState(SecureCmdOptionParse(d))
	else
		shown = false
	end
end

-------------------------------------------------------------------------------
-- Refresh and settings
-------------------------------------------------------------------------------

-- Called whenever a holder shows or hides, and after Apply.
function FadeUI.RefreshMinimap()
	local db = FadeUI.GetDB()
	local cluster = MinimapCluster
	if not (db and Minimap and cluster) then return end
	if InCombatLockdown() and Minimap:IsProtected() then return end
	local active = FadeUI.IsActive()
	local shownMap = db.minimapShown == "map"

	local mode = FadeUI.BY_KEY.minimap.modes.byKey[db.modes.minimap]
	SetStateDriver(active and shownMap and mode and FadeUI.Driver(mode) or nil)

	-- Only while FadeUI has the cluster hidden (Alt-Z hides UIParent, which leaves IsShown() true).
	local h = FadeUI.GetHolder(cluster)
	local want, size
	if active and h and cluster:GetParent() == h and not h:IsShown() then
		if shownMap and shown then
			want, size = "map", Size(db, "minimapShownSize")
		elseif db.minimapHidden == "nodes" or db.minimapHidden == "map" then
			want, size = db.minimapHidden, Size(db, "minimapHiddenSize")
		end
	end
	Place(want, size, db.minimapPing and true or false)
end

-- `field` is "minimapShown" ("normal", "map"), "minimapHidden" ("none", "nodes", "map")
-- or "minimapPing" (true, false).
function FadeUI.SetMinimapStyle(field, value)
	local db = FadeUI.GetDB()
	if not db then return end
	db[field] = value
	FadeUI.Changed()
end

-- Makes a map size ("minimapShownSize" or "minimapHiddenSize") one step bigger (1) or smaller (-1).
function FadeUI.StepMinimapSize(field, dir)
	local db = FadeUI.GetDB()
	if not db then return end
	local _, i = Size(db, field)
	db[field] = SIZES[math.max(1, math.min(#SIZES, i + dir))]
	FadeUI.Changed()
end

function FadeUI.GetMinimapSize(field)
	local db = FadeUI.GetDB()
	return db and (Size(db, field))
end
