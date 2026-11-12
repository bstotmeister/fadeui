-- Questie hides Blizzard's quest tracker and shows its own, Questie_BaseFrame,
-- so the Quest Tracker setting covers that one too. It isn't managed, so it goes
-- in a holder and fades. Its quest item buttons make it protected on and off,
-- so its holder is always secure.

local _, ns = ...
local FadeUI = ns.FadeUI

FadeUI.RegisterAddon({
	addon = "Questie",
	frames = { tracker = { "Questie_BaseFrame" } },
	styles = { Questie_BaseFrame = "secure" },
	-- Questie builds its tracker a few seconds after login.
	OnLogin = function()
		if Questie and Questie.API and Questie.API.RegisterOnReady then
			Questie.API.RegisterOnReady(FadeUI.Apply)
		end
	end,
})
