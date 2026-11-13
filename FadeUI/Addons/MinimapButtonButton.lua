-- MinimapButtonButton gathers the minimap's addon buttons into one button,
-- MinimapButtonButtonButton, that you can drag anywhere on screen, and opens
-- them in a panel inside it. As it isn't always by the minimap, it gets a row
-- of its own. It isn't protected (it never collects protected buttons) and
-- doesn't go by its parent, so it goes in a holder and fades, panel and all.

local _, ns = ...
local FadeUI = ns.FadeUI

FadeUI.RegisterAddon({
	addon = "MinimapButtonButton",
	elements = {
		{ key = "minimapbuttonbutton", label = "Minimap Buttons (MBB)",
		  frames = { "MinimapButtonButtonButton" }, default = "never" },
	},
})
