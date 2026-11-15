-- Details! draws each of its windows as four frames side by side on UIParent:
-- DetailsBaseFrame<id> and three laid over it (its bars, the right-click
-- switch button and a mouse blocker for its menus). They follow the Damage
-- Meter setting along with Blizzard's meter, which Details can also show in
-- its windows. They aren't protected, so each goes in a holder and fades.
--
-- Details can embed window 1, and window 2 unless it uses one window, in a
-- chat tab. It moves their frames into the chat frame and back, and its embed
-- code goes by their parent. So while a window is embedded FadeUI leaves the
-- frames Details moves alone: they're inside the chat frame and fade with chat.
-- This is checked before every Apply, because the first frame Details moves
-- makes FadeUI apply again in the middle of the embed; holding the others then
-- would make Details size them to fit FadeUI's holder.

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

local MOVED = { "DetailsBaseFrame", "DetailsRowFrame", "Details_SwitchButtonFrame" }

local function Embedded(id)
	local embed = Details.chat_tab_embed
	return embed and embed.enabled and Details.chat_tab_embed_onframe
		and (id == 1 or id == 2 and not embed.single_window)
end

-- Takes embedded windows' frames out of the Damage Meter element, and puts the
-- others back.
local function UpdateEmbedded()
	local list = FadeUI.BY_KEY.meter.frames
	for id = 1, 2 do
		local embedded = Embedded(id)
		for _, prefix in ipairs(MOVED) do
			local name, at = prefix .. id, nil
			for i, n in ipairs(list) do
				if n == name then at = i end
			end
			if embedded and at then
				table.remove(list, at)
			elseif not embedded and not at then
				list[#list + 1] = name
			end
		end
	end
end

FadeUI.RegisterAddon({
	addon = "Details",
	frames = { meter = frames },
	OnLogin = function()
		if not (Details and Details.CreateEventListener) then return end
		-- Details builds a window's frames the first time it opens, which can be
		-- after login: a new window, or one that was closed.
		Details:CreateEventListener():RegisterEvent("DETAILS_INSTANCE_OPEN", FadeUI.Apply)
		-- Releasing doesn't make FadeUI apply by itself, so the frames are held
		-- again once Details has put them back.
		local embed = Details.chat_embed
		if embed and embed.DoEmbed and embed.ReleaseEmbed then
			hooksecurefunc(embed, "DoEmbed", FadeUI.Apply)
			hooksecurefunc(embed, "ReleaseEmbed", FadeUI.Apply)
		end
	end,
	BeforeApply = function()
		if Details and Details.chat_tab_embed then UpdateEmbedded() end
	end,
})
