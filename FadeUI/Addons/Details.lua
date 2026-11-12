-- Details! draws each of its windows as four frames side by side on UIParent:
-- DetailsBaseFrame<id> and three laid over it (its bars, the right-click
-- switch button and a mouse blocker for its menus). They follow the Damage
-- Meter setting along with Blizzard's meter, which Details can also show in
-- its windows. They aren't protected and Details doesn't go by their parent,
-- so each goes in a holder and fades.

local _, ns = ...
local FadeUI = ns.FadeUI

-- Your windows have ids 1 to 30, the most Details allows. Ids from 90 up are
-- previews another addon builds inside its own panel, so they're left alone.
local frames = {}
for id = 1, 30 do
	frames[#frames + 1] = "DetailsBaseFrame" .. id
	frames[#frames + 1] = "DetailsRowFrame" .. id
	frames[#frames + 1] = "Details_SwitchButtonFrame" .. id
	frames[#frames + 1] = "Details_WindowFrameAntiMenuOverlap" .. id
end

FadeUI.RegisterAddon({
	addon = "Details",
	frames = { meter = frames },
	-- Details builds a window's frames the first time it opens, which can be
	-- after login: a new window, or one that was closed.
	OnLogin = function()
		if Details and Details.CreateEventListener then
			Details:CreateEventListener():RegisterEvent("DETAILS_INSTANCE_OPEN", FadeUI.Apply)
		end
	end,
})
