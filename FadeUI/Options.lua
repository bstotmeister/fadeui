-- FadeUI options window: one row per UI element, one button per mode.

local ADDON, ns = ...
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

-------------------------------------------------------------------------------
-- Rows
-------------------------------------------------------------------------------

local function GroupHeader(parent, title, y)
	local fs = Text(parent, "GameFontNormal", title, ACCENT)
	fs:SetPoint("TOPLEFT", 4, y - 10)
	local rule = parent:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(LINE[1], LINE[2], LINE[3], 1)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", fs, "RIGHT", 10, 0)
	rule:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
end

local function ElementRow(parent, el, y)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", 0, y)
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
	for i, mode in ipairs(FadeUI.MODES) do
		local b = Button(row, mode.label, SEG_W, SEG_H, function()
			FadeUI.SetMode(el.key, mode.key)
		end, mode.color)
		b:SetPoint("LEFT", LABEL_W + (i - 1) * (SEG_W + SEG_GAP), 0)
		b.mode = mode
		Tooltip(b, el.label .. ": " .. mode.label, mode.tip)
		row.segs[i] = b
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

	-- Settings macro
	y = y - 26
	refs.macro = Checkbox(win, "Keep settings in a macro", function(self)
		FadeUI.SetMacroMirror(self:GetChecked())
	end)
	refs.macro:SetPoint("TOPLEFT", PAD, y)
	Tooltip(refs.macro, "Keep settings in a macro",
		"The Forever beta client currently forgets addon settings when the game restarts. This keeps a copy in one general macro (named FadeUI...) and reads it back at login. You can turn it off once Blizzard fixes saved settings.")

	-- Chat idle, in seconds
	local idleUnit = Text(win, "GameFontHighlightSmall", "s", MUTED)
	idleUnit:SetPoint("TOPRIGHT", -PAD, y - 1)
	local idle = SecondsBox(win, "chatIdle")
	idle:SetPoint("RIGHT", idleUnit, "LEFT", -3, 0)
	local idleLabel = Text(win, "GameFontHighlight", "Chat idle:")
	idleLabel:SetPoint("RIGHT", idle, "LEFT", -6, 0)
	Tooltip(idle, "Chat idle",
		"Seconds without a new message in the chat window you're looking at, or typing, before chat hides. It comes back with the next message. 0 = never hide for being idle.")
	refs.fade[#refs.fade + 1] = idle

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
	local colLabel = Text(cols, "GameFontDisableSmall", "Element")
	colLabel:SetPoint("LEFT", 8, 0)
	for i, mode in ipairs(FadeUI.MODES) do
		local h = CreateFrame("Button", nil, cols)
		h:SetSize(SEG_W, 18)
		h:SetPoint("LEFT", LABEL_W + (i - 1) * (SEG_W + SEG_GAP), 0)
		local fs = Text(h, "GameFontDisableSmall", "set all")
		fs:SetPoint("CENTER")
		h:SetScript("OnEnter", function() fs:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
		h:SetScript("OnLeave", function() fs:SetTextColor(0.5, 0.5, 0.5) end)
		h:SetScript("OnClick", function() FadeUI.SetAll(mode.key) end)
		Tooltip(h, "Set all: " .. mode.label, "Set every element in the list to \"" .. mode.label .. "\".")
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

	local cy = 0
	for _, group in ipairs(FadeUI.GROUPS) do
		GroupHeader(content, group.title, cy)
		cy = cy - GROUP_H
		for _, el in ipairs(group.items) do
			ElementRow(content, el, cy)
			cy = cy - ROW_H
		end
		cy = cy - 6
	end
	content:SetHeight(-cy)

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
	refs.macro:SetChecked(db.macro)
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
