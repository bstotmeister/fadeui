-- Chattynator replaces Blizzard's chat with its own windows, all inside
-- ChattynatorHyperlinkHandler, and borrows Blizzard's typing box. It hides the
-- Blizzard chat windows itself, but only if they're still directly on UIParent,
-- so with it loaded the Chat setting leaves them alone and fades Chattynator
-- instead. Chattynator goes by that frame's parent too (it opens its copy-chat
-- window there), so it stays where it is and is its own holder.

local _, ns = ...
local FadeUI = ns.FadeUI

-- Chattynator draws its own windows, so a filter on each of its tabs counts its
-- messages as chat activity. Chattynator runs it on each message the tab shows
-- as it arrives, even one whose text is secret (in boss fights, Mythic+ and
-- PvP), and again on older ones it redraws, so only recent messages count.
local function Activity(data)
	if type(data.timestamp) == "number" and time() - data.timestamp <= 2 then FadeUI.ChatActivity() end
	return true -- the tab still shows it
end

-- AddFilter keeps one filter per function, window and tab, and adding one
-- that's already there does nothing, so watching again only adds new tabs.
local function Watch()
	local api = Chattynator and Chattynator.API
	if not (api and api.AddFilter and api.GetWindowsAndTabs) then return end
	for window, tabs in ipairs(api.GetWindowsAndTabs()) do
		for tab in ipairs(tabs) do api.AddFilter(Activity, window, tab) end
	end
end

FadeUI.RegisterAddon({
	addon = "Chattynator",
	replace = { chat = { "ChattynatorHyperlinkHandler", "ChatFrame1EditBox" } },
	styles = { ChattynatorHyperlinkHandler = "inPlace" },
	OnLogin = Watch,
	-- Tabs added since login are watched once chat next goes idle.
	OnChatIdle = Watch,
})
