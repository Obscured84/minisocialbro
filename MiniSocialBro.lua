local ADDON = ...
MiniSocialBroDB = MiniSocialBroDB or {}
MiniSocialBroIconDB = MiniSocialBroIconDB or { hide = false }

-- ===================== Utils / Defaults =====================
local function CloneTable(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k,v in pairs(t) do r[k] = CloneTable(v) end
  return r
end

local defaults = {
  pos = nil,
  width = 300,
  height = 20,
  scale = 1.0,
  bgAlpha = 0.75,
  accent = true,
  labelColor = {0.75, 0.75, 0.85},
  valueColor = {0.40, 0.70, 1.00},
  locked = false,
  fontSize = 12,

  tooltip = { colName = 160, colZone = 150, colLvl = 34, colNote = 180, maxRows = 18 },
  zebra   = true,
  tipDown = true,    -- true = klappt nach unten auf
  tipTop  = true,    -- true = TOOLTIP-Strata (topmost)
  compact = true,    -- kompaktere Zeilen
  showNote = true,   -- Notizspalte anzeigen
  noteType = "public", -- "public" oder "officer"
}

local function ApplyDefaults()
  for k,v in pairs(defaults) do
    if MiniSocialBroDB[k] == nil then
      MiniSocialBroDB[k] = CloneTable(v)
    end
  end
end

-- MIGRATION: füllt fehlende Keys aus alten Versionen
local function MigrateDB()
  ApplyDefaults()
  MiniSocialBroDB.tooltip = MiniSocialBroDB.tooltip or {}
  local t, d = MiniSocialBroDB.tooltip, defaults.tooltip
  if type(t.colName) ~= "number" then t.colName = d.colName end
  if type(t.colZone) ~= "number" then t.colZone = d.colZone end
  if type(t.colLvl)  ~= "number" then t.colLvl  = d.colLvl  end
  if type(t.colNote) ~= "number" then t.colNote = d.colNote end
  if type(t.maxRows) ~= "number" then t.maxRows = d.maxRows end
  if MiniSocialBroDB.showNote == nil then MiniSocialBroDB.showNote = defaults.showNote end
  if MiniSocialBroDB.noteType ~= "public" and MiniSocialBroDB.noteType ~= "officer" then
    MiniSocialBroDB.noteType = defaults.noteType
  end
  if MiniSocialBroDB.compact == nil then MiniSocialBroDB.compact = defaults.compact end
end

local function safe(fn, ...) local ok,r=pcall(fn,...); return ok and r or nil end

-- Kürzt Text auf Breite mit …
local function FitText(fs, text, maxW)
  if not text or text == "" then fs:SetText(""); return end
  fs:SetText(text)
  if fs:GetStringWidth() <= maxW then return end
  local ell = "…"
  local lo, hi = 1, #text
  local best = ""
  while lo <= hi do
    local mid = math.floor((lo+hi)/2)
    local t = string.sub(text, 1, mid)..ell
    fs:SetText(t)
    if fs:GetStringWidth() <= maxW then
      best = t; lo = mid + 1
    else
      hi = mid - 1
    end
  end
  fs:SetText(best)
end

-- ===================== Data helpers =====================
local function NormalizeCharRealm(char, realm)
  if not char or char == "" then return nil end
  local c = char:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
  if realm and realm ~= "" then
    local low = c:lower()
    local rr = realm:lower():gsub("%s+","")
    if not low:match("%-"..rr.."$") then c = c.."-"..realm end
    local pat = "%-"..realm:gsub("(%W)","%%%1")
    while c:lower():find(("-"..rr.."-"..rr):gsub("%-","%%-")) do
      c = c:gsub(pat..pat, "-"..realm)
    end
  end
  return c
end

local function GetGuildRows()
  local rows, online = {}, 0
  if IsInGuild() then
    safe(C_GuildInfo.GuildRoster)
    local total = GetNumGuildMembers() or 0
    for i=1,total do
      local name, _, _, level, _, zone, publicNote, officerNote, isOnline = GetGuildRosterInfo(i)
      if isOnline and name then
        online = online + 1
        rows[#rows+1] = {
          name  = name,
          zone  = zone or "",
          level = level or 0,
          note  = (MiniSocialBroDB.noteType == "officer") and (officerNote or "") or (publicNote or "")
        }
      end
    end
  end
  table.sort(rows, function(a,b) return a.name < b.name end)
  return online, rows
end

local function GetFriendRows()
  local rows, online = {}, 0
  local seen = {}

  local num = C_FriendList.GetNumFriends() or 0
  for i=1,num do
    local info = C_FriendList.GetFriendInfoByIndex(i)
    if info and info.connected then
      local name = NormalizeCharRealm(info.name, nil)
      if name and not seen[name] then
        seen[name] = true
        online = online + 1
        rows[#rows+1] = { name = name, zone = info.area or "", level = info.level or 0, note = "" }
      end
    end
  end

  local bnum = BNGetNumFriends() or 0
  for i=1,bnum do
    local acct = C_BattleNet.GetFriendAccountInfo(i)
    if acct and acct.gameAccountInfo then
      local g = acct.gameAccountInfo
      if g.isOnline and g.clientProgram == "WoW" then
        local nm = NormalizeCharRealm(g.characterName or acct.accountName, g.realmName)
        if nm and not seen[nm] then
          seen[nm] = true
          online = online + 1
          rows[#rows+1] = { name = nm, zone = g.areaName or "", level = g.characterLevel or 0, note = "" }
        end
      end
    end
  end

  table.sort(rows, function(a,b) return a.name < b.name end)
  return online, rows
end

-- ===================== Bar UI =====================
local function SaveBarPosition()
  local p,rel,rp,x,y = MiniSocialBroBar:GetPoint(1)
  MiniSocialBroDB.pos = {p=p, rel=rel and rel:GetName() or "Minimap", rp=rp, x=x, y=y}
end

local parent = Minimap
local bar = CreateFrame("Button","MiniSocialBroBar", parent, "BackdropTemplate")
bar:SetClampedToScreen(true)
bar:SetFrameStrata("MEDIUM")
bar:SetFrameLevel(5)
bar:SetMovable(true)
bar:EnableMouse(true)

local function UpdateBackdrop()
  local a = MiniSocialBroDB.bgAlpha or 0.75
  if bar.SetBackdrop then
    bar:SetBackdrop({bgFile="Interface/Buttons/WHITE8x8"})
    bar:SetBackdropColor(0,0,0,a)
  end
end

local accent = CreateFrame("StatusBar", nil, bar)
accent:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
accent:SetMinMaxValues(0,1)
accent:SetValue(1)

local function MakeFont(parent, size)
  local fs = parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  fs:SetFont(STANDARD_TEXT_FONT, size or 12, "OUTLINE")
  fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE")
  return fs
end

local guildBtn = CreateFrame("Button","MiniSocialBroGuild", bar)
local friendBtn = CreateFrame("Button","MiniSocialBroFriends", bar)
guildBtn:EnableMouse(true); friendBtn:EnableMouse(true)

local guildText = MakeFont(guildBtn, defaults.fontSize)
local friendText = MakeFont(friendBtn, defaults.fontSize)
guildText:SetPoint("CENTER"); friendText:SetPoint("CENTER")
guildBtn:SetHitRectInsets(-6,-6,-4,-4); friendBtn:SetHitRectInsets(-6,-6,-4,-4)

-- Alt-Drag per Drag-Events
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", function(self, button)
  if button == "LeftButton" and IsAltKeyDown() then
    self:StartMoving()
    self.__msbMoving = true
  end
end)
bar:SetScript("OnDragStop", function(self)
  if self.__msbMoving then
    self.__msbMoving = false
    self:StopMovingOrSizing()
    SaveBarPosition()
  end
end)
bar:SetScript("OnHide", function(self)
  if self.__msbMoving then
    self.__msbMoving = false
    self:StopMovingOrSizing()
    SaveBarPosition()
  end
end)

local function ForwardAltDrag(btn)
  btn:RegisterForDrag("LeftButton")
  btn:HookScript("OnDragStart", function(_, button)
    if button=="LeftButton" and IsAltKeyDown() then
      bar:GetScript("OnDragStart")(bar, "LeftButton")
    end
  end)
  btn:HookScript("OnDragStop", function()
    bar:GetScript("OnDragStop")(bar)
  end)
end
ForwardAltDrag(guildBtn)
ForwardAltDrag(friendBtn)

local function RestorePosition()
  local pos = MiniSocialBroDB.pos
  bar:ClearAllPoints()
  if pos and pos.rel then
    bar:SetPoint(pos.p or "TOP", _G[pos.rel] or Minimap, pos.rp or "BOTTOM", pos.x or 0, pos.y or -6)
  else
    bar:SetPoint("TOP", parent, "BOTTOM", 0, -6)
  end
end

local function Colorize(label, value)
  local lc = MiniSocialBroDB.labelColor or defaults.labelColor
  local vc = MiniSocialBroDB.valueColor or defaults.valueColor
  return string.format("|cff%02x%02x%02x%s:|r |cff%02x%02x%02x%d|r",
    lc[1]*255, lc[2]*255, lc[3]*255, label,
    vc[1]*255, vc[2]*255, vc[3]*255, value)
end

local function Layout()
  bar:SetScale(MiniSocialBroDB.scale or 1.0)
  bar:SetSize(MiniSocialBroDB.width or 300, MiniSocialBroDB.height or 20)
  UpdateBackdrop()

  local pad = 6
  guildBtn:ClearAllPoints(); friendBtn:ClearAllPoints()
  guildBtn:SetPoint("LEFT", bar, "LEFT", pad, 0)
  friendBtn:SetPoint("RIGHT", bar, "RIGHT", -pad, 0)
  guildBtn:SetSize((bar:GetWidth()/2)-pad, bar:GetHeight()-4)
  friendBtn:SetSize((bar:GetWidth()/2)-pad, bar:GetHeight()-4)

  local fs = MiniSocialBroDB.fontSize or 12
  guildText:SetFont(STANDARD_TEXT_FONT, fs, "OUTLINE")
  friendText:SetFont(STANDARD_TEXT_FONT, fs, "OUTLINE")

  accent:ClearAllPoints()
  accent:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, 2)
  accent:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
  accent:SetHeight(3)
  accent:SetStatusBarColor(0.25, 0.55, 1.0, 0.9)
  accent:SetShown(MiniSocialBroDB.accent)
end

-- ===================== Grid Tooltip (klickbar) =====================
local grid = CreateFrame("Frame","MiniSocialBroTooltip", UIParent, "BackdropTemplate")
grid:SetClampedToScreen(true)
grid:SetBackdrop({
  bgFile  = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile= "Interface/Tooltips/UI-Tooltip-Border",
  tile=true, tileSize=16, edgeSize=12,
  insets={left=3,right=3,top=3,bottom=3}
})
grid:SetBackdropColor(0, 0, 0, 0.90)
grid:SetBackdropBorderColor(0.9, 0.9, 1, 0.12)
grid:Hide()

local function ApplyTooltipStrata()
  if MiniSocialBroDB.tipTop then
    grid:SetFrameStrata("TOOLTIP"); grid:SetFrameLevel(100)
  else
    grid:SetFrameStrata("HIGH"); grid:SetFrameLevel(10)
  end
end

local titleFS = grid:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
titleFS:SetPoint("TOPLEFT", 12, -10)

local header = CreateFrame("Frame", nil, grid)
header:SetPoint("TOPLEFT", grid, "TOPLEFT", 10, -32)
header:SetHeight(16)
local hName = header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
local hZone = header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
local hLvl  = header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
local hNote = header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
hName:SetText("Name"); hZone:SetText("Zone"); hLvl:SetText("Lv"); hNote:SetText("Note")

local hint = grid:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
hint:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 10, 8)
hint:SetText("|cffcfcfcfLeft: Whisper   Right: Invite   Alt+Drag: Move|r")

local scroll = CreateFrame("ScrollFrame", nil, grid, "UIPanelScrollFrameTemplate")
local content = CreateFrame("Frame", nil, scroll)
scroll:SetScrollChild(content)
content:SetSize(10,10)

local rowsFS = {}
local function AcquireRow(i)
  if not rowsFS[i] then
    local name = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    local zone = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    local lvl  = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    local note = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    for _,fs in ipairs({name, zone, lvl, note}) do
      if fs.SetWordWrap then fs:SetWordWrap(false) end
      if fs.SetMaxLines then fs:SetMaxLines(1) end
    end
    local bg  = content:CreateTexture(nil, "BACKGROUND")
    local btn = CreateFrame("Button", nil, content)

    -- Basis-Handler, final per Zeile in ShowGrid gesetzt
    btn:SetScript("OnMouseDown", function(self, button)
      if button=="LeftButton" and IsAltKeyDown() then
        MiniSocialBroBar:StartMoving()
        MiniSocialBroBar.__msbMoving = true
      end
    end)
    btn:SetScript("OnMouseUp", function(self, button)
      if MiniSocialBroBar.__msbMoving then
        MiniSocialBroBar.__msbMoving = false
        MiniSocialBroBar:StopMovingOrSizing()
        SaveBarPosition()
        return
      end
      local target = self.charName
      if not target or target == "" then return end
      if button == "LeftButton" then
        ChatFrame_OpenChat("/w "..target.." ")
      elseif button == "RightButton" then
        if C_PartyInfo and C_PartyInfo.InviteUnit then
          C_PartyInfo.InviteUnit(target)
        else
          InviteUnit(target)
        end
      end
    end)

    rowsFS[i] = { name=name, zone=zone, lvl=lvl, note=note, bg=bg, btn=btn }
  end
  return rowsFS[i]
end

grid:SetScript("OnMouseWheel", function(self, delta)
  local step = MiniSocialBroDB.compact and 14 or 16
  scroll:SetVerticalScroll(math.max(0, scroll:GetVerticalScroll() - delta*step))
end)

local function ShowGrid(anchor, title, rows)
  local cfg = MiniSocialBroDB.tooltip
  local showNote = MiniSocialBroDB.showNote

  -- Fallbacks für alte/kaputte Werte
  local col1 = cfg.colName or 160
  local col2 = cfg.colZone or 150
  local col3 = cfg.colLvl  or 34
  local col4 = cfg.colNote or 180

  local pad  = 10
  local gap  = 8
  local rowH = MiniSocialBroDB.compact and 14 or 16
  local maxRows = cfg.maxRows or 18

  hName:ClearAllPoints(); hZone:ClearAllPoints(); hLvl:ClearAllPoints(); hNote:ClearAllPoints()
  hName:SetPoint("LEFT", header, "LEFT", 0, 0);        hName:SetWidth(col1)
  hZone:SetPoint("LEFT", hName, "RIGHT", gap, 0);      hZone:SetWidth(col2)
  hLvl:SetPoint("LEFT",  hZone, "RIGHT", gap, 0);      hLvl:SetWidth(col3)

  if showNote and col4 and col4 > 0 then
    hNote:SetPoint("LEFT", hLvl, "RIGHT", gap, 0)
    hNote:SetWidth(col4)
    hNote:Show()
  else
    showNote = false
    hNote:Hide()
  end

  titleFS:SetText(title)
  local totalW = col1 + gap + col2 + gap + col3 + (showNote and (gap + col4) or 0)
  header:SetWidth(totalW)

  for i=1,#rows do
    local r = AcquireRow(i)
    r.btn.index = i

    -- BG
    r.bg:ClearAllPoints()
    r.bg:SetPoint("TOPLEFT", content, "TOPLEFT", -2, -(i-1)*rowH)
    r.bg:SetSize(totalW + 4, rowH)
    if MiniSocialBroDB.zebra then
      r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.06 or 0.12)
    else
      r.bg:SetColorTexture(0, 0, 0, 0)
    end

    -- Spalten
    r.name:ClearAllPoints(); r.zone:ClearAllPoints(); r.lvl:ClearAllPoints(); r.note:ClearAllPoints()
    r.name:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1)*rowH)
    r.zone:SetPoint("LEFT", r.name, "RIGHT", gap, 0)
    r.lvl:SetPoint("LEFT", r.zone, "RIGHT", gap, 0)
    if showNote then r.note:SetPoint("LEFT", r.lvl, "RIGHT", gap, 0) end

    r.name:SetWidth(col1);  r.name:SetJustifyH("LEFT")
    r.zone:SetWidth(col2);  r.zone:SetJustifyH("LEFT")
    r.lvl:SetWidth(col3);   r.lvl:SetJustifyH("RIGHT")
    r.note:SetWidth(col4);  r.note:SetJustifyH("LEFT"); r.note:SetShown(showNote)

    -- Texte
    local row = rows[i]
    FitText(r.name, row.name or "", col1)
    FitText(r.zone, row.zone or "", col2)
    r.lvl:SetText(row.level and tostring(row.level) or "")
    if showNote then
      FitText(r.note, row.note or "", col4)
    end

    -- Klick-Overlay + Hover
    r.btn:ClearAllPoints()
    r.btn:SetPoint("TOPLEFT", content, "TOPLEFT", -2, -(i-1)*rowH)
    r.btn:SetSize(totalW + 4, rowH)
    r.btn.bg = r.bg
    r.btn.charName = row.name or ""

    r.btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
      GameTooltip:ClearLines()
      GameTooltip:AddLine(self.charName, 0.9, 0.9, 1)
      GameTooltip:AddLine("Left: Whisper", 1,1,1)
      GameTooltip:AddLine("Right: Invite", 1,1,1)
      GameTooltip:AddLine("Alt+Drag: Move bar", 1,1,1)
      GameTooltip:Show()
      if MiniSocialBroDB.zebra then
        self.bg:SetColorTexture(1, 1, 1, 0.18)
      else
        self.bg:SetColorTexture(1, 1, 1, 0.10)
      end
    end)
    r.btn:SetScript("OnLeave", function(self)
      local idx = self.index or 1
      if MiniSocialBroDB.zebra then
        self.bg:SetColorTexture(1, 1, 1, (idx % 2 == 0) and 0.06 or 0.12)
      else
        self.bg:SetColorTexture(0, 0, 0, 0)
      end
      GameTooltip:Hide()
    end)

    r.name:Show(); r.zone:Show(); r.lvl:Show()
  end

  -- ungenutzte Zeilen verstecken
  for i=#rows+1, #rowsFS do
    rowsFS[i].name:Hide(); rowsFS[i].zone:Hide(); rowsFS[i].lvl:Hide(); rowsFS[i].note:Hide()
    if rowsFS[i].bg then rowsFS[i].bg:SetColorTexture(0,0,0,0) end
    if rowsFS[i].btn then rowsFS[i].btn:ClearAllPoints(); rowsFS[i].btn:SetSize(1,1); rowsFS[i].btn.charName = nil end
  end

  content:SetSize(totalW, #rows * rowH)

  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
  scroll:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -10, -38)
  local visibleH = math.min(#rows, maxRows) * rowH + 2
  scroll:SetHeight(visibleH)

  local w = pad + totalW + pad
  local h = 40 + 6 + visibleH + 12
  grid:SetSize(w, h)

  grid:ClearAllPoints()
  if MiniSocialBroDB.tipDown then
    grid:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
  else
    grid:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
  end
  ApplyTooltipStrata()
  grid:Show()
end

local function HideGrid() grid:Hide(); scroll:SetVerticalScroll(0) end

-- ===================== Hover / Clicks =====================
local function UpdateTexts()
  local gCount = select(1, GetGuildRows()) or 0
  local fCount = select(1, GetFriendRows()) or 0
  guildText:SetText(Colorize("Guild", gCount))
  friendText:SetText(Colorize("Friends", fCount))
end

guildBtn:SetScript("OnEnter", function(self)
  local _, rows = GetGuildRows()
  ShowGrid(self, "Guild", rows)
end)
friendBtn:SetScript("OnEnter", function(self)
  local _, rows = GetFriendRows()
  ShowGrid(self, "Friends", rows)
end)
guildBtn:SetScript("OnLeave", HideGrid)
friendBtn:SetScript("OnLeave", HideGrid)

guildBtn:SetScript("OnMouseUp", function(_, btn)
  if bar.__msbMoving then return end
  if btn == "LeftButton" then
    if CommunitiesFrame then ToggleCommunitiesFrame()
    elseif GuildFrame_Toggle then GuildFrame_Toggle()
    else ToggleGuildFrame() end
  end
end)
friendBtn:SetScript("OnMouseUp", function(_, btn)
  if bar.__msbMoving then return end
  if btn == "LeftButton" then ToggleFriendsFrame() end
end)

-- ===================== Minimap Button (native) + LDB/LibDBIcon =====================
local function GetAddonIconTexture()
  return "Interface\\AddOns\\MiniSocialBro\\media\\msb_raven"
end

local LDB = _G.LibStub and _G.LibStub("LibDataBroker-1.1", true)
local LDI = _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)
local ldbObj

local function LDB_OnClick(frame, button)
  if button == "LeftButton" then
    MiniSocialBroDB.locked = not MiniSocialBroDB.locked
    print(("|cff66aaffMiniSocialBro|r %s"):format(MiniSocialBroDB.locked and "locked" or "unlocked"))
  elseif button == "RightButton" then
    ToggleFriendsFrame()
  elseif button == "MiddleButton" then
    if CommunitiesFrame then ToggleCommunitiesFrame() end
  end
end

local function LDB_OnTooltip(tt)
  tt:AddLine("MiniSocialBro", 0.4, 0.7, 1)
  tt:AddLine("Left: Lock/Unlock Bar", 1,1,1)
  tt:AddLine("Right: Friends", 1,1,1)
  tt:AddLine("Middle: Communities/Guild", 1,1,1)
end

local function RegisterLDB()
  if LDB and not ldbObj then
    ldbObj = LDB:NewDataObject("MiniSocialBro", {
      type = "launcher",
      icon = GetAddonIconTexture(),
      label = "MiniSocialBro",
      OnClick = LDB_OnClick,
      OnTooltipShow = LDB_OnTooltip,
    })
  end
  if LDI and ldbObj and not LDI:IsRegistered("MiniSocialBro") then
    LDI:Register("MiniSocialBro", ldbObj, MiniSocialBroIconDB)
  end
end

-- Fallback: eigener Minimap-Button (falls keine Libs)
local mmb = CreateFrame("Button","MiniSocialBroMMB", Minimap)
mmb:SetSize(26,26)
mmb:SetParent(Minimap)
mmb:SetFrameStrata(Minimap:GetFrameStrata() or "MEDIUM")
mmb:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
mmb:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 6, -6)
mmb:RegisterForClicks("LeftButtonUp","RightButtonUp","MiddleButtonUp")
mmb:RegisterForDrag("LeftButton")

local normal = mmb:CreateTexture(nil, "ARTWORK"); normal:SetAllPoints(); normal:SetTexture(GetAddonIconTexture()); mmb:SetNormalTexture(normal)
local pushed = mmb:CreateTexture(nil, "ARTWORK"); pushed:SetAllPoints(); pushed:SetTexture(GetAddonIconTexture()); pushed:SetVertexColor(0.9,0.9,0.9,1); mmb:SetPushedTexture(pushed)
local hl = mmb:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"); hl:SetBlendMode("ADD"); mmb:SetHighlightTexture(hl)

mmb:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("MiniSocialBro", 0.4, 0.7, 1)
  GameTooltip:AddLine("Left: Lock/Unlock Bar", 1,1,1)
  GameTooltip:AddLine("Right: Friends", 1,1,1)
  GameTooltip:AddLine("Middle: Communities/Guild", 1,1,1)
  GameTooltip:AddLine("Drag: Bar verschieben (Shift = Override Lock)", 1,1,1)
  GameTooltip:Show()
end)
mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)
mmb:SetScript("OnClick", LDB_OnClick)
mmb:SetScript("OnDragStart", function()
  if not MiniSocialBroDB.locked or IsShiftKeyDown() then bar:StartMoving(); bar.__msbMoving = true end
end)
mmb:SetScript("OnDragStop", function()
  if bar.__msbMoving then
    bar.__msbMoving = false
    bar:StopMovingOrSizing()
    SaveBarPosition()
  end
end)

local function UpdateIconVisibility()
  if LDI and LDI:IsRegistered("MiniSocialBro") then
    if MiniSocialBroIconDB.hide then LDI:Hide("MiniSocialBro") else LDI:Show("MiniSocialBro") end
    mmb:Hide()
  else
    if MiniSocialBroIconDB.hide then mmb:Hide() else mmb:Show() end
  end
end

-- ===================== Events & Layout =====================
local function DoLayoutAndRefresh()
  RestorePosition(); Layout(); UpdateTexts(); ApplyTooltipStrata()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:RegisterEvent("FRIENDLIST_UPDATE")
ev:RegisterEvent("BN_FRIEND_INFO_CHANGED")
ev:RegisterEvent("BN_CONNECTED")
ev:RegisterEvent("BN_DISCONNECTED")
ev:RegisterEvent("SOCIAL_QUEUE_UPDATE")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    ApplyDefaults()
    MigrateDB()
    DoLayoutAndRefresh()
    safe(C_GuildInfo.GuildRoster)
    RegisterLDB()
    UpdateIconVisibility()
    if not MiniSocialBroTicker then
      MiniSocialBroTicker = C_Timer.NewTicker(30, function() UpdateTexts() end)
    end
  else
    UpdateTexts()
  end
end)

-- ===================== Slash Commands =====================
SLASH_MINISOCIALBRO1 = "/msb"
SlashCmdList.MINISOCIALBRO = function(msg)
  local cmd, a,b,c,d = msg:match("^(%S+)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
  cmd = cmd and cmd:lower() or ""
  local function num(x) return tonumber(x) end

  if cmd == "width" and num(a) then MiniSocialBroDB.width = math.max(160, num(a)); Layout()
  elseif cmd == "height" and num(a) then MiniSocialBroDB.height = math.max(14, num(a)); Layout()
  elseif cmd == "scale" and num(a) then MiniSocialBroDB.scale = math.max(0.5, math.min(2.0, num(a))); Layout()
  elseif cmd == "bg" and num(a) then MiniSocialBroDB.bgAlpha = math.max(0, math.min(1, num(a))); bar:SetBackdropColor(0,0,0,MiniSocialBroDB.bgAlpha)
  elseif cmd == "accent" and a ~= "" then MiniSocialBroDB.accent = (a=="on" or a=="1" or a=="true"); Layout()
  elseif cmd == "font" and num(a) then MiniSocialBroDB.fontSize = math.max(10, math.min(18, num(a))); Layout()
  elseif cmd == "color" and a and b and c and d then
    local t = a:lower(); local r,g,bl = tonumber(b), tonumber(c), tonumber(d)
    if r and g and bl then
      r,g,bl = math.max(0,math.min(1,r)), math.max(0,math.min(1,g)), math.max(0,math.min(1,bl))
      if t=="label" then MiniSocialBroDB.labelColor = {r,g,bl}
      elseif t=="value" then MiniSocialBroDB.valueColor = {r,g,bl} end
      UpdateTexts()
    end
  elseif cmd == "cols" then
    if num(a) and num(b) and num(c) then
      MiniSocialBroDB.tooltip.colName = num(a)
      MiniSocialBroDB.tooltip.colZone = num(b)
      MiniSocialBroDB.tooltip.colLvl  = num(c)
      if num(d) then MiniSocialBroDB.tooltip.colNote = num(d) end
      print("|cff66aaffMiniSocialBro|r columns set:", a, b, c, d ~= "" and d or "(note unchanged)")
    end
  elseif cmd == "rows" and num(a) then
    MiniSocialBroDB.tooltip.maxRows = math.max(8, math.min(30, num(a)))
    print("|cff66aaffMiniSocialBro|r max rows:", MiniSocialBroDB.tooltip.maxRows)
  elseif cmd == "zebra" and a ~= "" then
    MiniSocialBroDB.zebra = (a=="on" or a=="1" or a=="true")
    print("|cff66aaffMiniSocialBro|r zebra:", MiniSocialBroDB.zebra and "on" or "off")
  elseif cmd == "tipdir" and a ~= "" then
    local v = a:lower()
    if v=="down" or v=="up" then
      MiniSocialBroDB.tipDown = (v=="down")
      print("|cff66aaffMiniSocialBro|r tooltip direction:", MiniSocialBroDB.tipDown and "down" or "up")
    end
  elseif cmd == "tiptop" and a ~= "" then
    local on = (a=="on" or a=="1" or a=="true")
    MiniSocialBroDB.tipTop = on; ApplyTooltipStrata()
    print("|cff66aaffMiniSocialBro|r tooltip topmost:", on and "on" or "off")
  elseif cmd == "compact" and a ~= "" then
    MiniSocialBroDB.compact = (a=="on" or a=="1" or a=="true")
    print("|cff66aaffMiniSocialBro|r compact:", MiniSocialBroDB.compact and "on" or "off")
  elseif cmd == "note" and a ~= "" then
    MiniSocialBroDB.showNote = (a=="on" or a=="1" or a=="true")
    print("|cff66aaffMiniSocialBro|r note column:", MiniSocialBroDB.showNote and "on" or "off")
  elseif cmd == "notetype" and a ~= "" then
    local v = a:lower()
    if v=="public" or v=="officer" then
      MiniSocialBroDB.noteType = v
      print("|cff66aaffMiniSocialBro|r note type:", v)
    end
  elseif cmd == "icon" and a ~= "" then
    if a=="hide" then MiniSocialBroIconDB.hide = true; UpdateIconVisibility()
    elseif a=="show" then MiniSocialBroIconDB.hide = false; UpdateIconVisibility() end
    print("|cff66aaffMiniSocialBro|r icon:", MiniSocialBroIconDB.hide and "hidden" or "shown")
  elseif cmd == "lock" then MiniSocialBroDB.locked = true; print("|cff66aaffMiniSocialBro|r locked")
  elseif cmd == "unlock" then MiniSocialBroDB.locked = false; print("|cff66aaffMiniSocialBro|r unlocked (Alt-Drag am Balken oder Drag am Minimap-Icon)")
  elseif cmd == "reset" then
    MiniSocialBroDB = {}; ApplyDefaults(); MigrateDB(); RestorePosition(); Layout(); UpdateTexts(); ApplyTooltipStrata()
  else
    print("|cff66aaffMiniSocialBro|r Befehle:")
    print("/msb width <px> | /msb height <px> | /msb scale <0.5-2> | /msb font <10-18> | /msb bg <0-1>")
    print("/msb accent on|off | /msb color label r g b | /msb color value r g b")
    print("/msb cols <name> <zone> <lvl> [note] | /msb rows <8-30> | /msb zebra on|off | /msb compact on|off")
    print("/msb note on|off | /msb notetype public|officer")
    print("/msb tipdir up|down | /msb tiptop on|off | /msb icon show|hide")
    print("/msb lock | /msb unlock | /msb reset")
  end
end
