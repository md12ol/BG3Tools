-- uiprobe.lua: client-side UI text probe for the generic autopilot (installed at run time through Probe.lua's command
-- channel, like camdirector.lua: autopilot.py ui_install(), or ./cq.sh "$(cat uiprobe.lua)"). Read-only: it never
-- changes the UI. Walks the Noesis tree the same way Build Advisor's Highlighter does (Ext.UI.GetRoot, Type, Text,
-- VisualChildrenCount, VisualChild(i) 1-based, DataContext) and returns visible texts.
-- NOT YET RUN IN GAME (2026-10-09). First test, during any dialogue:
--   ./cq.sh "$(cat uiprobe.lua)"; ./cq.sh "Mods.Autopilot.BA_CAM.ui.dump(6000)" > ui_dialog.txt
-- then note which element names / types hold the answer lines and tighten ui.dialog() (GENERAL_RULES learning log).
local B = Mods.Autopilot.BA_CAM
B.ui = B.ui or {}
local U = B.ui

local function try(f, ...)
  local ok, r = pcall(f, ...)
  if ok then return r end
  return nil
end
local DC_FIELDS = { "Text", "Name", "DisplayName", "Title", "Label", "Content" }

local function textOf(el)
  local t = try(function() return el.Text end)
  if type(t) == "string" and t ~= "" and t ~= "[ForceUpdate]" then return t end
  local dc = try(function() return el.DataContext end)
  if dc ~= nil and (type(dc) == "userdata" or type(dc) == "table") then
    for _, f in ipairs(DC_FIELDS) do
      local v = try(function() return dc[f] end)
      if type(v) == "string" and v ~= "" then
        if v:match("^h%x+g%x+g") then v = try(Ext.Loca.GetTranslatedString, v) or v end
        return v
      end
    end
  end
  return nil
end

local function hidden(el)
  local v = try(function() return el.Visibility end)
  return v ~= nil and tostring(v) ~= "Visible" and tostring(v) ~= "0"
end

-- walk(fn): fn(el, depth, path) for every visible element; path = "Type:Name/Type:Name/..."; budget = max nodes
local function walk(fn, budget)
  local root = try(Ext.UI.GetRoot)
  if not root then return 0 end
  local n = 0
  local function rec(el, depth, path)
    if n >= budget or depth > 40 or hidden(el) then return end
    n = n + 1
    local ty = tostring(try(function() return el.Type end) or "?")
    local nm = tostring(try(function() return el.Name end) or "")
    local p = path .. "/" .. ty .. (nm ~= "" and (":" .. nm) or "")
    fn(el, depth, p)
    for i = 1, (try(function() return el.VisualChildrenCount end) or 0) do
      local c = try(function() return el:VisualChild(i) end)
      if c then rec(c, depth + 1, p) end
    end
  end
  rec(root, 0, "")
  return n
end

-- dump(budget): every visible text with its element path (for learning the widget names)
function U.dump(budget)
  local out = {}
  local n = walk(function(el, depth, path)
    local t = textOf(el)
    if t then out[#out + 1] = string.format("%d|%s|%s", depth, path:sub(-160), t:gsub("\n", " ")) end
  end, budget or 6000)
  return "nodes " .. n .. "\n" .. table.concat(out, "\n")
end

-- find(word): how many visible elements have `word` in their type or name (e.g. "Book", "Dialog")
function U.find(word)
  local k, w = 0, word:lower()
  walk(function(el, depth, path)
    local tail = path:match("[^/]*$") or ""
    if tail:lower():find(w, 1, true) then k = k + 1 end
  end, 6000)
  return k
end

-- dialog(): the texts below the first element whose type or name mentions "Dialog" (heuristic until learned in game),
-- one per line, in tree order. Empty string when no such element is visible.
function U.dialog()
  local out, inside = {}, nil
  walk(function(el, depth, path)
    if inside and depth <= inside then inside = nil end
    local tail = (path:match("[^/]*$") or ""):lower()
    if not inside and tail:find("dialog", 1, true) then inside = depth end
    if inside then
      local t = textOf(el)
      if t and #t > 1 then out[#out + 1] = (t:gsub("\n", " ")) end
    end
  end, 8000)
  return table.concat(out, "\n")
end

return "uiprobe installed"
