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
	Tooltip(name, el.label, function()
		local lines = {}
		if el.found == 0 then
			lines[#lines + 1] = "|cffff6060Not found in this game client, so this setting does nothing.|r"
		end
		if el.note then lines[#lines + 1] = el.note end
		lines[#lines + 1] = "|cff888888Frames: " .. table.concat(el.frames, ", ", 1, math.min(#el.frames, 6))
			.. (#el.frames > 6 and ", ..." or "") .. "|r"
		return table.concat(lines, "\n\n")
	end)

	row.segs = {}
	for i, mode in ipairs(el.modes) do
		local b = Button(row, mode.label, SEG_W, SEG_H, function()
			FadeUI.SetMode(el.key, mode.key)
		end, mode.color)
		b:SetPoint("LEFT", LABEL_W + (i - 1) * (SEG_W + SEG_GAP), 0)
		b.mode = mode
		Tooltip(b, el.label .. ": " .. mode.label, mode.tip)
		row.segs[i] = b
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

-- Stacks the groups and rows that match `query` (case-insensitive, on the
-- element or group name) and hides the rest. An empty query shows everything.
local function Layout(query)
	query = strtrim(query or ""):lower()
	-- Keys of the matching elements, for "set all"; nil when not searching.
	refs.matches = query ~= "" and {} or nil
	local cy = 0
	for _, g in ipairs(groups) do
		local groupHit = query == "" or g.title:lower():find(query, 1, true)
		local shown = {}
		for _, row in ipairs(g.rows) do
			local hit = groupHit or row.el.label:lower():find(query, 1, true)
			row:SetShown(hit and true or false)
			if hit then
				shown[#shown + 1] = row
				if refs.matches then refs.matches[row.el.key] = true end
			end
		end
		g.header:SetShown(#shown > 0)
		if #shown > 0 then
			g.header:SetPoint("TOPLEFT", 0, cy)
			cy = cy - GROUP_H
			for _, row in ipairs(shown) do
				row:SetPoint("TOPLEFT", 0, cy)
				cy = cy - ROW_H
			end
			cy = cy - 6
		end
	end
	refs.noMatch:SetShown(cy == 0)
	refs.content:SetHeight(math.max(GROUP_H, -cy))
	refs.scroll:SetVerticalScroll(0)
	refs.scroll.UpdateThumb()
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
	win:SetScript("OnShow", function() FadeUI.RefreshOptions() end)
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

	-- Account-wide or per-character settings
	y = y - 26
	refs.perChar = Checkbox(win, "Use settings for this character only", function(self)
		FadeUI.SetPerCharacter(self:GetChecked())
	end)
	refs.perChar:SetPoint("TOPLEFT", PAD, y)
	Tooltip(refs.perChar, "Settings for this character only",
		"Off: this character uses your account-wide settings, shared with every character that has this off.\n\nOn: this character keeps its own settings, starting as a copy of the account-wide ones. Changes then only affect this character.")

	-- Range and resource helpers: they share one icon, and each has its own time
	y = y - 26
	local SHARED = "\n\nIt stays up while you tab through targets, and hides when you cast the spell or after the seconds set next to this. With both helpers on and both problems at once: red border around a dull icon."
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
	refs.rangeMove = Button(win, "Move", 56, SEG_H, function()
		FadeUI.SetRangeIconUnlocked(not FadeUI.IsRangeIconUnlocked())
	end)
	refs.rangeMove:SetPoint("LEFT", unit, "RIGHT", 24, 0)
	Tooltip(refs.rangeMove, "Move the helper icon",
		"Shows the range/resource helper icon so you can drag it into place. Click Lock (or type /fui range) when you're done.")

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
		"Type to filter the list by element or group name. Escape clears it.")
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
		local g = { title = group.title, header = GroupHeader(content, group.title), rows = {} }
		for _, el in ipairs(group.items) do
			g.rows[#g.rows + 1] = ElementRow(content, el)
		end
		groups[#groups + 1] = g
	end
	refs.noMatch = Text(content, "GameFontDisable", "No matching elements.")
	refs.noMatch:SetPoint("TOPLEFT", 8, -10)
	Layout("")

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
	refs.keyHint = Text(foot, "GameFontHighlightSmall", "", MUTED)
	refs.keyHint:SetPoint("RIGHT", -PAD, 0)
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function FadeUI.RefreshOptions()
	if not (win and win:IsShown()) then return end
	local db = FadeUI.GetDB()
	if not db then return end

	refs.master:SetChecked(db.enabled)
	refs.perChar:SetChecked(FadeUI.IsPerCharacter())
	for _, e in ipairs(refs.fade) do
		if not e:HasFocus() then e:SetText(("%g"):format((db[e.field] or 0) / 10)) end
	end

	for _, row in ipairs(rows) do
		local current = db.modes[row.el.key]
		local missing = row.el.found == 0
		for _, b in ipairs(row.segs) do
			SetActive(b, b.mode.key == current)
			b:SetAlpha(missing and 0.45 or 1)
		end
		if row.idle then row.idle:SetAlpha(current == "active" and 1 or 0.45) end
		if missing then
			row.label:SetText(row.el.label .. " |cff777777(not found)|r")
			row.label:SetTextColor(0.5, 0.5, 0.5)
		else
			row.label:SetText(row.el.label)
			row.label:SetTextColor(0.92, 0.92, 0.92)
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
