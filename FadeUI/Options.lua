-- FadeUI options window: one row per UI element, one button per mode.

local _, ns = ...
local FadeUI = ns.FadeUI

local BG      = { 0.055, 0.055, 0.065 }
local CARD    = { 0.095, 0.095, 0.110 }
local LINE    = { 0.200, 0.200, 0.230 }
local BTN     = { 0.130, 0.130, 0.150 }
local BTN_HI  = { 0.190, 0.190, 0.220 }
local ACCENT  = { 0.400, 0.800, 1.000 }
local MUTED   = { 0.560, 0.560, 0.600 }

local WIDTH, HEIGHT = 740, 640
local PAD = 16
local LABEL_W = 196
local SEG_W, SEG_H, SEG_GAP = 96, 20, 3
local ROW_H, GROUP_H = 26, 30

local win
local rows = {}
local groups = {} -- { title, header, rows } per group, for the search filter
local refs = {}

-------------------------------------------------------------------------------
-- Small widget kit (plain textures, no Blizzard templates)
-------------------------------------------------------------------------------

local function Fill(frame, layer, c, a)
	local t = frame:CreateTexture(nil, layer)
	t:SetAllPoints()
	t:SetColorTexture(c[1], c[2], c[3], a or 1)
	return t
end

local function Outline(frame, c)
	local function edge()
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetColorTexture(c[1], c[2], c[3], 1)
		return t
	end
	local top, bottom, left, right = edge(), edge(), edge(), edge()
	top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(1)
	bottom:SetPoint("BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT") bottom:SetHeight(1)
	left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(1)
	right:SetPoint("TOPRIGHT") right:SetPoint("BOTTOMRIGHT") right:SetWidth(1)
end

local function Text(parent, font, str, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetText(str or "")
	if color then fs:SetTextColor(color[1], color[2], color[3]) end
	return fs
end

local function Tooltip(owner, title, body)
	owner:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(type(title) == "function" and title(self) or title, 1, 1, 1)
		local b = type(body) == "function" and body(self) or body
		if b and b ~= "" then GameTooltip:AddLine(b, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A flat button. `color` (optional) is used as the fill when it is active.
local function Paint(b)
	local c
	if b.active then
		c = b.color or ACCENT
		b.label:SetTextColor(1, 1, 1)
	else
		c = b.hover and BTN_HI or BTN
		b.label:SetTextColor(b.hover and 0.95 or 0.72, b.hover and 0.95 or 0.72, b.hover and 0.95 or 0.75)
	end
	b.bg:SetColorTexture(c[1], c[2], c[3], 1)
end

local function Button(parent, label, w, h, onClick, color)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = Fill(b, "BACKGROUND", BTN)
	Outline(b, LINE)
	b.label = Text(b, "GameFontHighlightSmall", label)
	b.label:SetPoint("CENTER")
	b.color = color
	b:SetScript("OnEnter", function(self) self.hover = true Paint(self) end)
	b:SetScript("OnLeave", function(self) self.hover = false Paint(self) end)
	if onClick then b:SetScript("OnClick", onClick) end
	Paint(b)
	return b
end

local function SetActive(b, on)
	b.active = on and true or false
	Paint(b)
end

local function Checkbox(parent, label, onClick)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(16, 16)
	Fill(c, "BACKGROUND", BTN)
	Outline(c, LINE)
	local mark = c:CreateTexture(nil, "ARTWORK")
	mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	mark:SetPoint("TOPLEFT", 3, -3)
	mark:SetPoint("BOTTOMRIGHT", -3, 3)
	c:SetCheckedTexture(mark)
	c.text = Text(c, "GameFontHighlight", label)
	c.text:SetPoint("LEFT", c, "RIGHT", 8, 0)
	c:SetHitRectInsets(0, -(c.text:GetStringWidth() + 12), 0, 0)
	c:SetScript("OnClick", onClick)
	return c
end

-- A small box for a number of seconds. `field` is the setting it edits.
local function SecondsBox(parent, field)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(40, SEG_H)
	e:SetAutoFocus(false)
	e:SetFontObject("GameFontHighlightSmall")
	e:SetJustifyH("CENTER")
	e:SetMaxLetters(4)
	Fill(e, "BACKGROUND", BTN)
	Outline(e, LINE)
	e.field = field
	e:SetScript("OnEnterPressed", e.ClearFocus)
	e:SetScript("OnEscapePressed", function(self)
		self.cancel = true
		self:ClearFocus()
	end)
	e:SetScript("OnEditFocusLost", function(self)
		if not self.cancel then FadeUI.SetTime(self.field, tonumber(self:GetText())) end
		self.cancel = nil
		FadeUI.RefreshOptions() -- shows the stored value (rounded, clamped, or unchanged)
	end)
	return e
end

-- A text box with a grey hint while it's empty. `onChange` gets the text.
local function SearchBox(parent, w, h, hint, onChange)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(w, h)
	e:SetAutoFocus(false)
	e:SetFontObject("GameFontHighlightSmall")
	e:SetTextInsets(6, 6, 0, 0)
	e:SetMaxLetters(40)
	Fill(e, "BACKGROUND", BTN)
	Outline(e, LINE)
	local placeholder = Text(e, "GameFontDisableSmall", hint)
	placeholder:SetPoint("LEFT", 6, 0)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	e:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	e:SetScript("OnTextChanged", function(self)
		local text = self:GetText()
		placeholder:SetShown(text == "")
		onChange(text)
	end)
	return e
end

-------------------------------------------------------------------------------
-- Rows
-------------------------------------------------------------------------------

-- Headers and rows are placed by Layout(), so the search can hide and restack them.
local function GroupHeader(parent, title)
	local h = CreateFrame("Frame", nil, parent)
	h:SetPoint("RIGHT")
	h:SetHeight(GROUP_H)
	local fs = Text(h, "GameFontNormal", title, ACCENT)
	fs:SetPoint("TOPLEFT", 4, -10)
	local rule = h:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(LINE[1], LINE[2], LINE[3], 1)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", fs, "RIGHT", 10, 0)
	rule:SetPoint("RIGHT", h, "RIGHT", -4, 0)
	return h
end

-- Everything the row does goes by row.el, so a custom frame's row can be
-- reused for another (see RefreshCustomRows).
local function ElementRow(parent, el)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("RIGHT")
	row:SetHeight(ROW_H)
	row.el = el

	local hl = Fill(row, "BACKGROUND", { 1, 1, 1 }, 0.035)
	hl:Hide()

	-- The label area carries the tooltip; it's a button so it can take the mouse.
	local name = CreateFrame("Button", nil, row)
	name:SetPoint("LEFT", 8, 0)
	name:SetSize(LABEL_W - 8, ROW_H)
	row.label = Text(name, "GameFontHighlight", el.label)
	row.label:SetPoint("LEFT")
	row.label:SetJustifyH("LEFT")
	Tooltip(name, function() return row.el.label end, function()
		local e = row.el
		local lines = {}
		if e.found == 0 then
			lines[#lines + 1] = e.custom and "|cffff6060There's no frame with this name right now.|r"
				or "|cffff6060Not found in this game client, so this setting does nothing.|r"
		end
		if e.note then lines[#lines + 1] = e.note end
		lines[#lines + 1] = "|cff888888Frames: " .. table.concat(e.frames, ", ", 1, math.min(#e.frames, 6))
			.. (#e.frames > 6 and ", ..." or "") .. "|r"
		return table.concat(lines, "\n\n")
	end)

	row.segs = {}
	for i, mode in ipairs(el.modes) do
		local b = Button(row, mode.label, SEG_W, SEG_H, function()
			FadeUI.SetMode(row.el.key, mode.key)
		end, mode.color)
		b:SetPoint("LEFT", LABEL_W + (i - 1) * (SEG_W + SEG_GAP), 0)
		b.mode = mode
		Tooltip(b, function() return row.el.label .. ": " .. mode.label end, mode.tip)
		row.segs[i] = b
	end

	-- A custom frame's row has a remove button at the end of its label.
	if el.custom then
		row.label:SetWidth(LABEL_W - 40)
		row.label:SetWordWrap(false)
		local remove = Button(row, "x", 18, 18, function() FadeUI.RemoveCustomFrame(row.el.frames[1]) end)
		remove:SetPoint("LEFT", LABEL_W - 28, 0)
		remove:SetFrameLevel(name:GetFrameLevel() + 1) -- above the label's button, which it sits on
		Tooltip(remove, function() return "Remove " .. row.el.label end,
			"FadeUI stops hiding this frame, and it goes back to normal.")
	end

	-- Chat's idle time sits in its row, after its buttons.
	if el.key == "chat" then
		local x = LABEL_W + #row.segs * (SEG_W + SEG_GAP) + 8
		local label = Text(row, "GameFontHighlightSmall", "Idle:")
		label:SetPoint("LEFT", x, 0)
		row.idle = SecondsBox(row, "chatIdle")
		row.idle:SetPoint("LEFT", label, "RIGHT", 6, 0)
		local unit = Text(row, "GameFontHighlightSmall", "s", MUTED)
		unit:SetPoint("LEFT", row.idle, "RIGHT", 3, 0)
		Tooltip(row.idle, "Chat idle",
			"With chat on \"When active\": seconds without a new message in the chat window you're looking at, or typing, before chat hides.")
		refs.fade[#refs.fade + 1] = row.idle
	end

	-- Bag buttons' "while open" switch sits on a line of its own, below the row
	-- (Layout leaves room for it).
	if el.key == "bags" then
		row.bagsOpen = Checkbox(row, "Also show while your bags are open", function(self)
			FadeUI.SetBagsOpen(self:GetChecked())
		end)
		row.bagsOpen:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 24, 0)
		Tooltip(row.bagsOpen, "Bag Buttons: while bags are open",
			"Shows the bag buttons whenever a bag is open, whatever their mode above.")
		row.extraH = 22
	end

	-- The "while dragging" switch covers every action bar, so it sits below the
	-- last row of the group.
	if el.key == "petbar" then
		row.barsDrag = Checkbox(row, "Also show all action bars while you drag a spell or item", function(self)
			FadeUI.SetBarsDrag(self:GetChecked())
		end)
		row.barsDrag:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 24, 0)
		Tooltip(row.barsDrag, "Action bars: while dragging",
			"Shows your action bars and pet bar whenever you pick up something you can put on them (a spell, item, macro...), whatever their mode above, so you can drop it into a slot. Not in combat.")
		row.extraH = 22
	end

	local function over() hl:Show() end
	local function out() hl:Hide() end
	name:HookScript("OnEnter", over) name:HookScript("OnLeave", out)
	for _, b in ipairs(row.segs) do b:HookScript("OnEnter", over) b:HookScript("OnLeave", out) end

	rows[#rows + 1] = row
	return row
end

-------------------------------------------------------------------------------
-- Scroll area with a slim thumb
-------------------------------------------------------------------------------

local function ScrollArea(parent)
	local sf = CreateFrame("ScrollFrame", nil, parent)
	local content = CreateFrame("Frame", nil, sf)
	content:SetSize(10, 1)
	sf:SetScrollChild(content)

	local track = sf:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(LINE[1], LINE[2], LINE[3], 0.5)
	track:SetWidth(3)
	track:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 8, 0)
	track:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 8, 0)
	local thumb = sf:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
	thumb:SetWidth(3)

	local function update()
		local view, total = sf:GetHeight(), content:GetHeight()
		local max = math.max(0, total - view)
		if max <= 0 then
			thumb:Hide() track:Hide()
			sf:SetVerticalScroll(0)
			return
		end
		thumb:Show() track:Show()
		local h = math.max(24, view * view / total)
		local pos = sf:GetVerticalScroll() / max
		thumb:SetHeight(h)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 8, -pos * (view - h))
	end

	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, content:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * ROW_H * 2)))
		update()
	end)
	sf:SetScript("OnSizeChanged", function(self, w)
		content:SetWidth(w)
		update()
	end)
	sf.UpdateThumb = update
	return sf, content
end

-- Whether an element's name, or the name of a loaded addon that's part of it
-- (see AddKeyword in Addons.lua), contains `query`.
local function Matches(el, query)
	if el.label:lower():find(query, 1, true) then return true end
	for _, word in ipairs(el.keywords or {}) do
		if word:find(query, 1, true) then return true end
	end
	return false
end

-- Stacks the groups and rows that match `query` (case-insensitive, on the
-- element, group or addon name) and hides the rest. An empty query shows
-- everything, except rows for addons that aren't loaded. The Custom frames
-- group shows even with no rows, for its add line. `keepScroll` stays where
-- the list is scrolled to instead of going back to the top.
local function Layout(query, keepScroll)
	query = strtrim(query or ""):lower()
	-- Keys of the matching elements, for "set all"; nil when not searching.
	refs.matches = query ~= "" and {} or nil
	local cy = 0
	for _, g in ipairs(groups) do
		local groupHit = query == "" or g.title:lower():find(query, 1, true)
		local shown = {}
		for _, row in ipairs(g.rows) do
			local hit = row.el.available ~= false and (groupHit or Matches(row.el, query))
			row:SetShown(hit and true or false)
			if hit then
				shown[#shown + 1] = row
				if refs.matches then refs.matches[row.el.key] = true end
			end
		end
		local showGroup = #shown > 0 or (g.custom and groupHit)
		g.header:SetShown(showGroup and true or false)
		if showGroup then
			g.header:SetPoint("TOPLEFT", 0, cy)
			cy = cy - g.header:GetHeight()
			for _, row in ipairs(shown) do
				row:SetPoint("TOPLEFT", 0, cy)
				cy = cy - ROW_H - (row.extraH or 0)
			end
			cy = cy - 6
		end
	end
	refs.noMatch:SetShown(cy == 0)
	refs.content:SetHeight(math.max(GROUP_H, -cy))
	local max = math.max(0, refs.content:GetHeight() - refs.scroll:GetHeight())
	refs.scroll:SetVerticalScroll(keepScroll and math.min(refs.scroll:GetVerticalScroll(), max) or 0)
	refs.scroll.UpdateThumb()
end

-------------------------------------------------------------------------------
-- Custom frames
-------------------------------------------------------------------------------

-- Custom frames' rows come and go, and frames can't be deleted, so rows are
-- reused. Unused ones are hidden and marked spare.
local customRows = {}

function FadeUI.RefreshCustomRows()
	local g = refs.customGroup
	if not g then return end
	g.rows = {}
	for i, el in ipairs(g.group.items) do
		local row = customRows[i]
		if not row then
			row = ElementRow(refs.content, el)
			customRows[i] = row
		end
		row.el, row.spare = el, nil
		g.rows[i] = row
	end
	for i = #g.group.items + 1, #customRows do
		customRows[i].spare = true
		customRows[i]:Hide()
	end
	Layout(refs.search:GetText(), true)
	FadeUI.RefreshOptions()
end

-- Picking a frame with the mouse. The bar takes the keyboard but not the mouse,
-- so the mouse still finds the frame under it; a click would also click that
-- frame (and cast from an action button), so Enter picks it instead.
local picker

-- The frame to add for what's under the mouse: the outermost frame with a
-- name that it's in, below UIParent (an addon's window rather than one of its
-- buttons). It must be a global by that name, so it can be found again.
local function PickCandidate()
	local focus = GetMouseFoci and GetMouseFoci()[1] or GetMouseFocus and GetMouseFocus()
	local pick
	while type(focus) == "table" and focus ~= UIParent and focus ~= WorldFrame do
		if focus.IsForbidden and focus:IsForbidden() then return nil end
		local name = focus.GetName and focus:GetName()
		if name and _G[name] == focus then pick = focus end
		focus = focus.GetParent and focus:GetParent()
	end
	return pick
end

local function StopPicking(name)
	picker:Hide()
	local done = picker.done
	picker.done = nil
	if done then done(name) end
end

-- Calls `done` with the picked frame's name, or nil if it was cancelled.
local function PickFrame(done)
	if not picker then
		picker = CreateFrame("Frame", nil, UIParent)
		picker:SetFrameStrata("FULLSCREEN_DIALOG")
		picker:SetSize(520, 48)
		picker:SetPoint("TOP", 0, -80)
		Fill(picker, "BACKGROUND", BG, 0.95)
		Outline(picker, ACCENT)
		local hint = Text(picker, "GameFontHighlight", "Hover the frame to add and press |cffffffffEnter|r. |cffffffffEscape|r cancels.")
		hint:SetPoint("TOP", 0, -9)
		picker.text = Text(picker, "GameFontHighlightSmall", "", MUTED)
		picker.text:SetPoint("BOTTOM", 0, 9)
		-- An outline around the frame that would be picked, placed by position
		-- rather than anchored to it (anchoring to a protected frame would make
		-- this protected too).
		picker.box = CreateFrame("Frame", nil, picker)
		Outline(picker.box, ACCENT)
		picker:EnableKeyboard(true)
		picker:SetScript("OnKeyDown", function(self, key)
			if key == "ESCAPE" then
				StopPicking(nil)
			elseif key == "ENTER" and self.name then
				StopPicking(self.name)
			end
		end)
		picker:SetScript("OnUpdate", function(self)
			local f = PickCandidate()
			self.name = f and f:GetName()
			self.text:SetText(f and ("Under the mouse: |cffffffff" .. self.name .. "|r")
				or "Under the mouse: nothing with a name (type the name instead, see /fstack)")
			local l, b, w, h
			if f then l, b, w, h = f:GetRect() end
			if l then
				local s = f:GetEffectiveScale() / self.box:GetEffectiveScale()
				self.box:ClearAllPoints()
				self.box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * s, b * s)
				self.box:SetSize(w * s, h * s)
				self.box:Show()
			else
				self.box:Hide()
			end
		end)
		-- It takes every key, so it gives up as combat starts.
		picker:RegisterEvent("PLAYER_REGEN_DISABLED")
		picker:SetScript("OnEvent", function(self)
			if self:IsShown() then StopPicking(nil) end
		end)
		picker:Hide()
	end
	picker.done = done
	picker:Show()
end

-- The Custom frames header holds the add line: a name box, Add, Pick, and what
-- happened last.
local function CustomAddLine(header)
	header:SetHeight(GROUP_H + 26)
	local msg = Text(header, "GameFontHighlightSmall", "", MUTED)
	local function Say(text, bad)
		msg:SetText(text or "")
		if bad then msg:SetTextColor(1, 0.45, 0.45) else msg:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end
	end

	local box = SearchBox(header, LABEL_W - 14, SEG_H, "Frame name (see /fstack)", function() Say("") end)
	box:SetMaxLetters(80)
	box:SetPoint("TOPLEFT", 8, -GROUP_H - 2)
	local function Add()
		local ok, text = FadeUI.AddCustomFrame(box:GetText())
		if ok then box:SetText("") end
		box:ClearFocus()
		Say(text, not ok)
	end
	box:SetScript("OnEnterPressed", Add)
	Tooltip(box, "Add a custom frame",
		"The name of a frame FadeUI doesn't have a setting for, such as another addon's window. Type /fstack and hover it to see its name, or click Pick.")

	local add = Button(header, "Add", 52, SEG_H, Add)
	add:SetPoint("LEFT", box, "RIGHT", 8, 0)
	Tooltip(add, "Add", "Adds the frame named in the box. It gets a row below, with the same modes as everything else.")

	local pick = Button(header, "Pick", 52, SEG_H, function()
		if InCombatLockdown() then return Say("You can't pick a frame in combat.", true) end
		win:Hide()
		PickFrame(function(name)
			win:Show()
			if name then
				box:SetText(name)
				box:SetFocus()
				Say("Press Enter to add " .. name .. ", or change the name first.")
			end
		end)
	end)
	pick:SetPoint("LEFT", add, "RIGHT", SEG_GAP, 0)
	Tooltip(pick, "Pick",
		"Hides this window so you can hover the frame you want, then press Enter to put its name in the box. Escape cancels. Frames that don't take the mouse can't be picked: type their name instead.")

	msg:SetPoint("LEFT", pick, "RIGHT", 12, 0)
	msg:SetPoint("RIGHT", header, "RIGHT", -4, 0)
	msg:SetJustifyH("LEFT")
	msg:SetWordWrap(false)
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------

local PROFILE_W, DIALOG_W = 180, 460
local menu, dialog

-- The list of profiles under the profile button. Clicking one switches to it.
local function ToggleProfileMenu()
	if not menu then
		menu = CreateFrame("Frame", nil, win)
		menu:SetFrameStrata("FULLSCREEN_DIALOG")
		menu:SetPoint("TOPLEFT", refs.profile, "BOTTOMLEFT", 0, -2)
		Fill(menu, "BACKGROUND", CARD)
		Outline(menu, LINE)
		menu.items = {}
		menu:Hide()
	end
	if menu:IsShown() then
		menu:Hide()
		return
	end
	local names, current = FadeUI.GetProfiles(), FadeUI.GetProfile()
	for i, name in ipairs(names) do
		local b = menu.items[i]
		if not b then
			b = Button(menu, "", PROFILE_W - 2, SEG_H, function(self)
				menu:Hide()
				FadeUI.SetProfile(self.profile)
			end)
			b:SetPoint("TOPLEFT", 1, -1 - (i - 1) * SEG_H)
			b.label:SetWidth(PROFILE_W - 14)
			b.label:SetWordWrap(false)
			menu.items[i] = b
		end
		b.profile = name
		b.label:SetText(name)
		SetActive(b, name == current)
		b:Show()
	end
	for i = #names + 1, #menu.items do menu.items[i]:Hide() end
	menu:SetSize(PROFILE_W, #names * SEG_H + 2)
	menu:Show()
end

local function BuildDialog()
	dialog = CreateFrame("Frame", nil, win)
	dialog:SetWidth(DIALOG_W)
	dialog:SetPoint("TOP", 0, -120)
	dialog:SetFrameStrata("FULLSCREEN_DIALOG")
	dialog:EnableMouse(true) -- clicks don't go through to the window
	Fill(dialog, "BACKGROUND", BG, 0.98)
	Outline(dialog, ACCENT)

	dialog.title = Text(dialog, "GameFontNormal", "", ACCENT)
	dialog.title:SetPoint("TOPLEFT", PAD, -14)
	dialog.text = Text(dialog, "GameFontHighlightSmall", "")
	dialog.text:SetPoint("TOPLEFT", dialog.title, "BOTTOMLEFT", 0, -8)
	dialog.text:SetWidth(DIALOG_W - 2 * PAD)
	dialog.text:SetJustifyH("LEFT")
	dialog.error = Text(dialog, "GameFontHighlightSmall", "")
	dialog.error:SetTextColor(1, 0.45, 0.45)
	dialog.error:SetPoint("LEFT", dialog, "BOTTOMLEFT", PAD, 23)
	dialog.error:SetWidth(DIALOG_W - 2 * PAD - 180)
	dialog.error:SetJustifyH("LEFT")
	local function Clear() dialog.error:SetText("") end

	local function OK()
		local err = dialog.onOK(dialog.name:GetText(), dialog.body:GetText())
		if err then dialog.error:SetText(err) else dialog:Hide() end
	end
	dialog.cancel = Button(dialog, "Cancel", 80, 22, function() dialog:Hide() end)
	dialog.cancel:SetPoint("BOTTOMRIGHT", -PAD, 12)
	dialog.ok = Button(dialog, "", 80, 22, OK)
	dialog.ok:SetPoint("RIGHT", dialog.cancel, "LEFT", -6, 0)

	dialog.name = SearchBox(dialog, 220, SEG_H, "Profile name", Clear)
	dialog.name:SetMaxLetters(32)
	dialog.name:SetScript("OnEnterPressed", OK)
	dialog.name:SetScript("OnEscapePressed", function() dialog:Hide() end)

	-- The big box, for a profile string. It scrolls, since the string is long.
	local scroll = CreateFrame("ScrollFrame", nil, dialog)
	scroll:SetSize(DIALOG_W - 2 * PAD, 120)
	Fill(scroll, "BACKGROUND", BTN)
	Outline(scroll, LINE)
	local body = CreateFrame("EditBox", nil, scroll)
	body:SetMultiLine(true)
	body:SetAutoFocus(false)
	body:SetFontObject("GameFontHighlightSmall")
	body:SetMaxLetters(0)
	body:SetTextInsets(6, 6, 6, 6)
	body:SetSize(DIALOG_W - 2 * PAD, 120)
	scroll:SetScrollChild(body)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function() body:SetFocus() end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 20)))
	end)
	body:SetScript("OnEscapePressed", function() dialog:Hide() end)
	-- An export can't be changed: typing puts it back, selected for copying.
	body:SetScript("OnTextChanged", function(self, userInput)
		if not userInput then return end
		if dialog.fixed then
			self:SetText(dialog.fixed)
			self:HighlightText()
		end
		Clear()
	end)
	body:SetScript("OnEditFocusGained", function(self)
		if dialog.fixed then self:HighlightText() end
	end)
	dialog.scroll, dialog.body = scroll, body
end

-- Saving, deleting, exporting and importing profiles all use one dialog. `opts`:
--   title, text   what it's for
--   name          true for a box to name the profile
--   body          text for the big box (nil: no box); `fixed` (the same text) can't be changed
--   ok            the OK button's label (nil: just a Close button)
--   onOK(name, body)  returns an error message to keep the dialog open
local function ShowDialog(opts)
	if not dialog then BuildDialog() end
	if menu then menu:Hide() end
	dialog.onOK, dialog.fixed = opts.onOK, opts.fixed
	dialog.title:SetText(opts.title)
	dialog.text:SetText(opts.text)
	dialog.error:SetText("")
	local below, h = dialog.text, 0
	dialog.name:SetText("")
	dialog.name:SetShown(opts.name and true or false)
	if opts.name then
		dialog.name:ClearAllPoints()
		dialog.name:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -10)
		below, h = dialog.name, h + SEG_H + 10
	end
	dialog.body:SetText(opts.body or "")
	dialog.scroll:SetShown(opts.body ~= nil)
	if opts.body then
		dialog.scroll:ClearAllPoints()
		dialog.scroll:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -10)
		dialog.scroll:SetVerticalScroll(0)
		h = h + 130
	end
	dialog.ok:SetShown(opts.ok ~= nil)
	dialog.ok.label:SetText(opts.ok or "")
	dialog.cancel.label:SetText(opts.ok and "Cancel" or "Close")
	dialog:SetHeight(36 + dialog.text:GetStringHeight() + h + 56)
	dialog:Show()
	if opts.body then
		dialog.body:SetFocus()
	elseif opts.name then
		dialog.name:SetFocus()
	end
end

local function SaveAsDialog()
	ShowDialog({ title = "Save as a new profile",
		text = "Saves a copy of " .. FadeUI.GetProfile() .. " under a new name, and switches this character to it.",
		name = true, ok = "Save", onOK = FadeUI.NewProfile })
end

local function DeleteDialog()
	local name = FadeUI.GetProfile()
	if name == FadeUI.DEFAULT_PROFILE then return end
	ShowDialog({ title = "Delete " .. name .. "?",
		text = "This character switches to " .. FadeUI.DEFAULT_PROFILE .. ". So does any other character using "
			.. name .. ", the next time it logs in.",
		ok = "Delete", onOK = FadeUI.DeleteProfile })
end

local function ExportDialog()
	local s = FadeUI.ExportProfile()
	ShowDialog({ title = "Export " .. FadeUI.GetProfile(),
		text = "Press Ctrl+C to copy this, then share it. Anyone with FadeUI can paste it into Import to get the same settings (all but the on/off switch).",
		body = s, fixed = s })
end

local function ImportDialog()
	ShowDialog({ title = "Import a profile",
		text = "Paste a profile string below (Ctrl+V) and give the new profile a name. This character switches to it.",
		name = true, body = "", ok = "Import", onOK = FadeUI.ImportProfile })
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local FADE_BOXES = {
	{ field = "fadeIn",    label = "Fade in",
	  tip = "Seconds an element takes to fade in when it appears. 0 = instant." },
	{ field = "fadeOut",   label = "Fade out",
	  tip = "Seconds an element takes to fade out before it hides. 0 = instant. In combat, elements always hide instantly." },
	{ field = "fadeDelay", label = "Delay",
	  tip = "Seconds to wait before an element starts fading out, e.g. after combat ends. If it's needed again during the wait, it stays." },
}

local function Build()
	win = CreateFrame("Frame", "FadeUIOptions", UIParent)
	win:SetSize(WIDTH, HEIGHT)
	win:SetPoint("CENTER")
	win:SetFrameStrata("DIALOG")
	win:SetToplevel(true)
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	win:SetScript("OnShow", function()
		-- A custom frame that wasn't there may be now.
		if FadeUI.CustomMissing() then FadeUI.Apply() end
		FadeUI.RefreshOptions()
	end)
	win:SetScript("OnHide", function()
		if menu then menu:Hide() end
		if dialog then dialog:Hide() end
	end)
	Fill(win, "BACKGROUND", BG, 0.97)
	Outline(win, LINE)
	tinsert(UISpecialFrames, "FadeUIOptions") -- Escape closes it

	-- Header
	local head = CreateFrame("Frame", nil, win)
	head:SetPoint("TOPLEFT", 1, -1)
	head:SetPoint("TOPRIGHT", -1, -1)
	head:SetHeight(44)
	Fill(head, "BACKGROUND", CARD)
	local rule = head:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	rule:SetHeight(2)
	rule:SetPoint("BOTTOMLEFT") rule:SetPoint("BOTTOMRIGHT")
	local icon = head:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Eye_01")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetSize(24, 24)
	icon:SetPoint("LEFT", PAD - 2, 0)
	local title = Text(head, "GameFontNormalLarge", "FadeUI", { 1, 1, 1 })
	title:SetPoint("LEFT", icon, "RIGHT", 10, 1)
	local sub = Text(head, "GameFontHighlightSmall", "Choose when each part of the UI is shown", MUTED)
	sub:SetPoint("LEFT", title, "RIGHT", 12, -1)
	local close = Button(head, "X", 24, 24, function() win:Hide() end)
	close:SetPoint("RIGHT", -10, 0)

	-- Master switch
	local y = -60
	refs.master = Checkbox(win, "Hide the UI (like Alt-Z)", function(self)
		FadeUI.SetEnabled(self:GetChecked())
	end)
	refs.master:SetPoint("TOPLEFT", PAD, y)
	Tooltip(refs.master, "Hide the UI",
		"When this is off, FadeUI puts everything back exactly as Blizzard had it. Bind a key to switch it under Key Bindings > AddOns > FadeUI.")

	-- Fade times, in seconds
	refs.fade = {}
	local anchor
	for i = #FADE_BOXES, 1, -1 do
		local info = FADE_BOXES[i]
		local unit = Text(win, "GameFontHighlightSmall", "s", MUTED)
		if anchor then
			unit:SetPoint("RIGHT", anchor, "LEFT", -14, 0)
		else
			unit:SetPoint("TOPRIGHT", -PAD, y - 1)
		end
		local e = SecondsBox(win, info.field)
		e:SetPoint("RIGHT", unit, "LEFT", -3, 0)
		local label = Text(win, "GameFontHighlight", info.label .. ":")
		label:SetPoint("RIGHT", e, "LEFT", -6, 0)
		Tooltip(e, info.label, info.tip)
		refs.fade[#refs.fade + 1] = e
		anchor = label
	end

	-- Profile: the settings this character uses, and saving, deleting and sharing them
	y = y - 26
	local profileLabel = Text(win, "GameFontHighlight", "Profile:")
	profileLabel:SetPoint("TOPLEFT", PAD, y - 3)
	refs.profile = Button(win, "", PROFILE_W, SEG_H, ToggleProfileMenu)
	refs.profile:SetPoint("LEFT", profileLabel, "RIGHT", 8, 0)
	refs.profile.label:ClearAllPoints()
	refs.profile.label:SetPoint("LEFT", 8, 0)
	refs.profile.label:SetPoint("RIGHT", -22, 0)
	refs.profile.label:SetJustifyH("LEFT")
	refs.profile.label:SetWordWrap(false)
	local arrow = refs.profile:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	arrow:SetSize(14, 14)
	arrow:SetPoint("RIGHT", -4, -3)
	Tooltip(refs.profile, "Profile",
		"The settings this character uses. Click to switch to another.\n\nProfiles are shared by all your characters, and each character remembers which one it's on. Changes go straight into the profile in use, so they affect every character on it.")
	local prev = refs.profile
	for _, info in ipairs({
		{ "profileSave", "Save as", SaveAsDialog, "Save as a new profile",
		  "Saves a copy of this profile under a new name and switches to it, so you can change it without touching this one." },
		{ "profileDelete", "Delete", DeleteDialog, "Delete this profile",
		  "Deletes the profile this character uses, and switches to " .. FadeUI.DEFAULT_PROFILE .. ". " .. FadeUI.DEFAULT_PROFILE .. " itself can't be deleted." },
		{ "profileExport", "Export", ExportDialog, "Export",
		  "Shows this profile as a line of text you can copy and share." },
		{ "profileImport", "Import", ImportDialog, "Import",
		  "Makes a new profile from a line of text someone exported." },
	}) do
		local b = Button(win, info[2], 64, SEG_H, info[3])
		b:SetPoint("LEFT", prev, "RIGHT", prev == refs.profile and 8 or SEG_GAP, 0)
		Tooltip(b, info[4], info[5])
		refs[info[1]] = b
		prev = b
	end

	-- Range, resource and cooldown helpers: they share one icon, and each has its own time
	y = y - 26
	local SHARED = "\n\nIt stays up while you tab through targets, and hides when you cast the spell or after the seconds set next to this. With both helpers on and both problems at once: red border around a dull icon. The icon is also dull while the spell can't be cast for another reason, like Charge in combat."
	local function Helper(field, timeField, label, tip, timeTip, after)
		local c = Checkbox(win, label, function(self) FadeUI.SetHelper(field, self:GetChecked()) end)
		if after then
			c:SetPoint("LEFT", after, "RIGHT", 24, 0)
		else
			c:SetPoint("TOPLEFT", PAD, y)
		end
		Tooltip(c, label, tip .. SHARED)
		local e = SecondsBox(win, timeField)
		e:SetPoint("LEFT", c.text, "RIGHT", 10, 0)
		Tooltip(e, label .. " time", timeTip .. " 0 = until you cast the spell.")
		refs.fade[#refs.fade + 1] = e
		local unit = Text(win, "GameFontHighlightSmall", "s", MUTED)
		unit:SetPoint("LEFT", e, "RIGHT", 3, 0)
		return c, e, unit
	end
	local unit
	refs.rangeHelper, refs.rangeTime, unit = Helper("rangeHelper", "rangeTime", "Range helper",
		"When a spell fails because you're out of range, shows that spell's icon with a red border and red tint until you're close enough (green border), then it flashes.",
		"Seconds the icon stays up after a spell fails out of range, or after you change target.")
	refs.resourceHelper, refs.resourceTime, unit = Helper("resourceHelper", "resourceTime", "Resource helper",
		"When a spell fails because you're short on mana, rage, energy or another resource, shows that spell's icon dulled until you have enough, then it flashes.",
		"Seconds the icon stays up after a spell fails for lack of resource, or after you change target.", unit)
	refs.cooldownHelper, refs.cooldownTime, unit = Helper("cooldownHelper", "cooldownTime", "Cooldown helper",
		"When a spell fails because it's on cooldown, shows that spell's icon with its cooldown, as on the action bars. While this is on, the icon also shows the cooldown for the other helpers.",
		"Seconds the icon stays up after a spell fails on cooldown, or after you change target.", unit)
	refs.rangeMove = Button(win, "Move", 56, SEG_H, function()
		FadeUI.SetRangeIconUnlocked(not FadeUI.IsRangeIconUnlocked())
	end)
	refs.rangeMove:SetPoint("LEFT", unit, "RIGHT", 24, 0)
	Tooltip(refs.rangeMove, "Move the helper icon",
		"Shows the helper icon so you can drag it into place. Click Lock (or type /fui range) when you're done.")

	-- Cooldown buffer: under the Cooldown helper's seconds
	y = y - 26
	refs.cooldownBuffer = SecondsBox(win, "cooldownBuffer")
	refs.cooldownBuffer:SetPoint("TOPLEFT", refs.cooldownTime, "BOTTOMLEFT", 0, -6)
	Tooltip(refs.cooldownBuffer, "Cooldown buffer",
		"Seconds after you cast a spell that it failing on cooldown is ignored, so pressing it again straight after casting it doesn't bring up the icon. 0 = off.")
	refs.fade[#refs.fade + 1] = refs.cooldownBuffer
	local bufferLabel = Text(win, "GameFontHighlight", "Buffer:")
	bufferLabel:SetPoint("RIGHT", refs.cooldownBuffer, "LEFT", -6, 0)
	Text(win, "GameFontHighlightSmall", "s", MUTED):SetPoint("LEFT", refs.cooldownBuffer, "RIGHT", 3, 0)

	-- Minimap styles: one row for while it's shown, one for while it's hidden,
	-- each with its own map size. The buttons and sizes line up in columns.
	local MAP_TIP = "Just the map, cropped to a circle around you at your usual zoom (Map size, on the right; 100% is the whole map). No border or buttons."
	refs.minimapRows = {}
	local function MinimapRow(label, field, sizeField, when, options)
		y = y - 26
		local row = { field = field, sizeField = sizeField, buttons = {} }
		local fs = Text(win, "GameFontHighlight", label)
		fs:SetPoint("TOPLEFT", PAD, y - 3)
		for i, o in ipairs(options) do
			local b = Button(win, o[2], 52, SEG_H, function() FadeUI.SetMinimapStyle(field, o[1]) end)
			b:SetPoint("LEFT", fs, "LEFT", 150 + (i - 1) * (52 + SEG_GAP), 0)
			b.value = o[1]
			Tooltip(b, label:gsub(":$", "") .. ": " .. o[2], o[3])
			row.buttons[i] = b
		end
		local sizeLabel = Text(win, "GameFontHighlight", "Map size:")
		sizeLabel:SetPoint("LEFT", fs, "LEFT", 150 + 3 * (52 + SEG_GAP) + 16, 0)
		local smaller = Button(win, "-", 20, SEG_H, function() FadeUI.StepMinimapSize(sizeField, -1) end)
		smaller:SetPoint("LEFT", sizeLabel, "RIGHT", 8, 0)
		row.sizeText = Text(win, "GameFontHighlightSmall", "")
		row.sizeText:SetWidth(36)
		row.sizeText:SetPoint("LEFT", smaller, "RIGHT", 2, 0)
		local bigger = Button(win, "+", 20, SEG_H, function() FadeUI.StepMinimapSize(sizeField, 1) end)
		bigger:SetPoint("LEFT", row.sizeText, "RIGHT", 2, 0)
		for _, b in ipairs({ smaller, bigger }) do
			Tooltip(b, "Map size " .. when, "How much of the minimap the Map style keeps " .. when
				.. ", as a share of its normal size. 100% is the whole map.")
		end
		row.size = { sizeLabel, smaller, row.sizeText, bigger }
		row.bigger = bigger
		refs.minimapRows[#refs.minimapRows + 1] = row
	end
	MinimapRow("Minimap when shown:", "minimapShown", "minimapShownSize", "while shown", {
		{ "normal", "Normal", "Blizzard's minimap, with its border, buttons and zone text." },
		{ "map", "Map", MAP_TIP },
	})
	MinimapRow("Minimap when hidden:", "minimapHidden", "minimapHiddenSize", "while hidden", {
		{ "none", "None", "Nothing: the minimap is fully hidden." },
		{ "nodes", "Nodes", "Only what the minimap marks: herb and ore nodes, quest areas, party members and your arrow. No map behind them." },
		{ "map", "Map", MAP_TIP },
	})
	refs.minimapPing = Checkbox(win, "Click the map to ping", function(self)
		FadeUI.SetMinimapStyle("minimapPing", self:GetChecked())
	end)
	refs.minimapPing:SetPoint("LEFT", refs.minimapRows[1].bigger, "RIGHT", 24, 0)
	Tooltip(refs.minimapPing, "Click the map to ping",
		"On: clicking the minimap in the Map or Nodes style pings that spot for your group, like the normal minimap.\n\nOff: clicks go through to the world instead.\n\nEither way, hovering a node or marker shows what it is.")

	-- Status line
	y = y - 26
	refs.status = Text(win, "GameFontHighlightSmall", "", MUTED)
	refs.status:SetPoint("TOPLEFT", PAD, y)
	refs.status:SetPoint("RIGHT", -PAD, 0)
	refs.status:SetJustifyH("LEFT")

	-- Column headers: click one to set every element to that mode
	y = y - 26
	local cols = CreateFrame("Frame", nil, win)
	cols:SetPoint("TOPLEFT", PAD, y)
	cols:SetPoint("RIGHT", -PAD - 8, 0)
	cols:SetHeight(18)
	refs.search = SearchBox(cols, LABEL_W - 14, 18, "Search, e.g. map", Layout)
	refs.search:SetPoint("LEFT", 2, 0)
	Tooltip(refs.search, "Search",
		"Type to filter the list by element, group or addon name. Escape clears it.")
	for i, mode in ipairs(FadeUI.MODES) do
		local h = CreateFrame("Button", nil, cols)
		h:SetSize(SEG_W, 18)
		h:SetPoint("LEFT", LABEL_W + (i - 1) * (SEG_W + SEG_GAP), 0)
		local fs = Text(h, "GameFontDisableSmall", "set all")
		fs:SetPoint("CENTER")
		h:SetScript("OnEnter", function() fs:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
		h:SetScript("OnLeave", function() fs:SetTextColor(0.5, 0.5, 0.5) end)
		h:SetScript("OnClick", function() FadeUI.SetAll(mode.key, refs.matches) end)
		Tooltip(h, "Set all: " .. mode.label, "Set every element in the list to \"" .. mode.label
			.. "\". While searching, only the elements that match.")
	end
	local colRule = cols:CreateTexture(nil, "ARTWORK")
	colRule:SetColorTexture(LINE[1], LINE[2], LINE[3], 1)
	colRule:SetHeight(1)
	colRule:SetPoint("TOPLEFT", cols, "BOTTOMLEFT", 0, -2)
	colRule:SetPoint("TOPRIGHT", cols, "BOTTOMRIGHT", 0, -2)

	-- Element list
	y = y - 24
	local sf, content = ScrollArea(win)
	sf:SetPoint("TOPLEFT", PAD, y)
	sf:SetPoint("BOTTOMRIGHT", -PAD - 8, 48)
	refs.scroll = sf
	refs.content = content

	for _, group in ipairs(FadeUI.GROUPS) do
		local g = { title = group.title, header = GroupHeader(content, group.title), rows = {}, group = group }
		if group.custom then
			-- Its rows are made by RefreshCustomRows.
			g.custom = true
			CustomAddLine(g.header)
			refs.customGroup = g
		else
			for _, el in ipairs(group.items) do
				g.rows[#g.rows + 1] = ElementRow(content, el)
			end
		end
		groups[#groups + 1] = g
	end
	refs.noMatch = Text(content, "GameFontDisable", "No matching elements.")
	refs.noMatch:SetPoint("TOPLEFT", 8, -10)

	-- Footer
	local foot = CreateFrame("Frame", nil, win)
	foot:SetPoint("BOTTOMLEFT", 1, 1)
	foot:SetPoint("BOTTOMRIGHT", -1, 1)
	foot:SetHeight(40)
	Fill(foot, "BACKGROUND", CARD)
	local reset = Button(foot, "Reset to defaults", 130, 22, function()
		FadeUI.ResetDefaults()
	end)
	reset:SetPoint("LEFT", PAD - 1, 0)
	Tooltip(reset, "Reset to defaults", function()
		return "Puts every setting in the profile " .. FadeUI.GetProfile() .. " back to its default. Your other profiles aren't changed."
	end)
	-- Undo and redo: back and forth through this session's changes to the profile
	refs.undo = Button(foot, "Undo", 60, 22, function() FadeUI.Undo() end)
	refs.undo:SetPoint("LEFT", reset, "RIGHT", 6, 0)
	refs.redo = Button(foot, "Redo", 60, 22, function() FadeUI.Redo() end)
	refs.redo:SetPoint("LEFT", refs.undo, "RIGHT", SEG_GAP, 0)
	Tooltip(refs.undo, "Undo",
		"Puts this profile back the way it was before your last change, one change at a time, as far back as when you logged in or reloaded. The on/off switch isn't included.")
	Tooltip(refs.redo, "Redo",
		"Makes the change you last undid again. Making a new change instead clears what you can redo.")
	refs.keyHint = Text(foot, "GameFontHighlightSmall", "", MUTED)
	refs.keyHint:SetPoint("RIGHT", -PAD, 0)

	-- Last, since it refreshes the whole window: makes the custom frame rows and
	-- lays out the list.
	FadeUI.RefreshCustomRows()
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function FadeUI.RefreshOptions()
	if not (win and win:IsShown()) then return end
	local db = FadeUI.GetDB()
	if not db then return end

	refs.master:SetChecked(db.enabled)
	local profile = FadeUI.GetProfile()
	local isDefault = profile == FadeUI.DEFAULT_PROFILE
	refs.profile.label:SetText(profile)
	refs.profileDelete:SetEnabled(not isDefault)
	refs.profileDelete:SetAlpha(isDefault and 0.45 or 1)
	local undo, redo = FadeUI.HistorySize()
	refs.undo:SetEnabled(undo > 0)
	refs.undo:SetAlpha(undo > 0 and 1 or 0.45)
	refs.redo:SetEnabled(redo > 0)
	refs.redo:SetAlpha(redo > 0 and 1 or 0.45)
	for _, e in ipairs(refs.fade) do
		if not e:HasFocus() then e:SetText(("%g"):format((db[e.field] or 0) / 10)) end
	end

	for _, row in ipairs(rows) do
		if not row.spare then -- spare: an unused custom frame row
			local current = db.modes[row.el.key]
			local missing = row.el.found == 0
			for _, b in ipairs(row.segs) do
				SetActive(b, b.mode.key == current)
				b:SetAlpha(missing and 0.45 or 1)
			end
			if row.idle then row.idle:SetAlpha(current == "active" and 1 or 0.45) end
			if row.bagsOpen then
				row.bagsOpen:SetChecked(db.bagsOpen)
				row.bagsOpen:SetAlpha((missing or current == "always") and 0.45 or 1)
			end
			if row.barsDrag then row.barsDrag:SetChecked(db.barsDrag) end
			if missing then
				row.label:SetText(row.el.label .. " |cff777777(not found)|r")
				row.label:SetTextColor(0.5, 0.5, 0.5)
			else
				row.label:SetText(row.el.label)
				row.label:SetTextColor(0.92, 0.92, 0.92)
			end
		end
	end

	local status
	if InCombatLockdown() then
		status = "|cffff9933In combat.|r Changes are saved now and applied as soon as combat ends."
	elseif FadeUI.editMode then
		status = "|cffffd200Edit Mode is open,|r so everything is shown until you close it."
	elseif not db.enabled then
		status = "FadeUI is |cffff6060off|r: your normal UI is showing. Tick the box above, or use your keybind, to turn it on."
	else
		status = "FadeUI is |cff60ff60on|r. Hidden elements can't be seen or clicked, but their keybinds still work."
	end
	refs.status:SetText(status)

	local key = GetBindingKey and GetBindingKey("FADEUI_TOGGLE")
	refs.keyHint:SetText(key and ("Toggle key: |cffffffff" .. key .. "|r")
		or "No toggle key yet: Key Bindings > AddOns > FadeUI")

	refs.rangeHelper:SetChecked(db.rangeHelper)
	refs.resourceHelper:SetChecked(db.resourceHelper)
	refs.rangeTime:SetAlpha(db.rangeHelper and 1 or 0.45)
	refs.resourceTime:SetAlpha(db.resourceHelper and 1 or 0.45)
	refs.cooldownHelper:SetChecked(db.cooldownHelper)
	refs.cooldownTime:SetAlpha(db.cooldownHelper and 1 or 0.45)
	refs.cooldownBuffer:SetAlpha(db.cooldownHelper and 1 or 0.45)
	for _, row in ipairs(refs.minimapRows) do
		for _, b in ipairs(row.buttons) do SetActive(b, db[row.field] == b.value) end
		row.sizeText:SetText(FadeUI.GetMinimapSize(row.sizeField) .. "%")
		for _, f in ipairs(row.size) do f:SetAlpha(db[row.field] == "map" and 1 or 0.45) end
	end
	refs.minimapPing:SetChecked(db.minimapPing)
	local outStyle = db.minimapShown == "map" or db.minimapHidden == "nodes" or db.minimapHidden == "map"
	refs.minimapPing:SetAlpha(outStyle and 1 or 0.45)
	local unlocked = FadeUI.IsRangeIconUnlocked()
	refs.rangeMove.label:SetText(unlocked and "Lock" or "Move")
	SetActive(refs.rangeMove, unlocked)

	if refs.scroll.UpdateThumb then refs.scroll.UpdateThumb() end
end

function FadeUI_OpenOptions()
	if not win then
		Build()
		win:Hide() -- new frames start shown; start closed so the toggle below opens it
	end
	if win:IsShown() then
		win:Hide()
	else
		win:Show()
	end
end
