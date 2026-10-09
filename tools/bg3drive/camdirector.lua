-- camdirector.lua: client-side camera director (installed at run time through Probe.lua's command channel, cam.sh).
-- User 2026-10-06: cinematic (not tactical) view, zoomed out as far as the game allows, and the camera angled so the
-- companions' actions are in the shot (portrait clicks left much off screen).
-- B.uuids = characters to frame (the bot sets them per turn: the acting members + their targets). Every frame the
-- camera's target point eases toward the centroid of their CURRENT positions, and the yaw eases toward the angle that
-- looks across the group's long axis (so the spread runs left-right on screen). Distance = the game's own maximum.
-- Only the camera is touched (GameCameraBehavior), never a character.
local B = Mods.Autopilot.BA_CAM
B.uuids = B.uuids or {}
B.on = true
B.last = Ext.Utils.MonotonicTime()
B.ents = {}
local function cam() return Ext.Entity.GetAllEntitiesWithComponent('GameCameraBehavior')[1].GameCameraBehavior end
local function ent(u)
  local e = B.ents[u]
  if e == nil then e = Ext.Entity.Get(u) or false; B.ents[u] = e end
  return e or nil
end
local function wrap(a) while a > 180 do a = a - 360 end while a < -180 do a = a + 360 end return a end
B.tick = function()
  if not B.on then return end
  local now = Ext.Utils.MonotonicTime()
  local dt = math.min(0.1, math.max(0.001, (now - B.last) / 1000)); B.last = now
  -- B.uuids[1] = the anchor (the acting party member). 2026-10-06 user: "you are trying to move the camera somewhere you
  -- cant yet" - framing imps behind the closed helm door pulled the view into unexplored black space. Only points within
  -- B.leash m of the anchor count, and the aim point stays within B.maxOff m of the anchor.
  -- B.must = how many leading uuids are always framed (a cast: caster + target, user 2026-10-06 "when you launch a
  -- spell try to have the target in the camera"); the anchor is then the centroid of those must-points.
  local pts = {}
  local anchor
  local must = B.must or 1
  local mpts = {}
  for i, u in ipairs(B.uuids) do
    local e = ent(u)
    local t = e and e.Transform and e.Transform.Transform.Translate
    if t then
      if i <= must then
        mpts[#mpts + 1] = { t[1], t[2], t[3] }
        pts[#pts + 1] = { t[1], t[2], t[3] }
        if i == must or i == #B.uuids then
          local ax, ay, az = 0, 0, 0
          for _, p in ipairs(mpts) do ax, ay, az = ax + p[1], ay + p[2], az + p[3] end
          anchor = { ax / #mpts, ay / #mpts, az / #mpts }
        end
      elseif anchor and math.sqrt((t[1] - anchor[1]) ^ 2 + (t[3] - anchor[3]) ^ 2) <= (B.leash or 14)
          and math.abs(t[2] - anchor[2]) <= 4 then
        pts[#pts + 1] = { t[1], t[2], t[3] }
      end
    end
  end
  if not anchor and #mpts > 0 then
    local ax, ay, az = 0, 0, 0
    for _, p in ipairs(mpts) do ax, ay, az = ax + p[1], ay + p[2], az + p[3] end
    anchor = { ax / #mpts, ay / #mpts, az / #mpts }
  end
  if #pts == 0 or not anchor then return end
  local cx, cy, cz = 0, 0, 0
  for _, p in ipairs(pts) do cx, cy, cz = cx + p[1], cy + p[2], cz + p[3] end
  cx, cy, cz = cx / #pts, cy / #pts + 1.2, cz / #pts
  local off = math.sqrt((cx - anchor[1]) ^ 2 + (cz - anchor[3]) ^ 2)
  local maxOff = B.maxOff or 6
  if off > maxOff then
    cx, cz = anchor[1] + (cx - anchor[1]) * maxOff / off, anchor[3] + (cz - anchor[3]) * maxOff / off
  end
  local c = cam()
  -- 2026-10-07 (user): "The camera is shaky. Like you are fighting the engine cam movements. Each engine movement
  -- should cause you to rotate if necessary to satisfy the requirements." The director no longer writes the aim point
  -- (TargetCurrent) at all - the engine moves the camera. After every engine movement it checks the MUST points with
  -- the live projection; only when one is off screen does it plan the smallest yaw orbit around the engine's own
  -- target that frames them (rotating the camera by a = rotating the points by -a around the target, projected with
  -- the current matrices) and eases RotationY there once - no re-planning while it turns.
  if B.dist and c.DistanceDestination < B.dist then c.DistanceDestination = B.dist end
  local V, P = B.mats()
  local T = c.TargetCurrent
  local function fwd() local d = c.Direction return -d[1], -d[3] end
  local function proj(x, y, z, mx, my)
    local q = B.mul(P, B.mul(V, { x, y + 1.0, z, 1 }))
    if not q[4] or q[4] <= 0.0001 then return false end
    return math.abs(q[1] / q[4]) <= mx and math.abs(q[2] / q[4]) <= my
  end
  local function seen(list, a, mx, my)            -- how many of list are on screen after a camera orbit of a degrees
    local ca, sa = math.cos(math.rad(-a)), math.sin(math.rad(-a))
    local n = 0
    for _, p in ipairs(list) do
      local dx, dz = p[1] - T[1], p[3] - T[3]
      if proj(T[1] + dx * ca - dz * sa, p[2], T[3] + dx * sa + dz * ca, mx, my) then n = n + 1 end
    end
    return n
  end
  if B.shot ~= B.planShot then B.goal = nil; B.planShot = B.shot end   -- a new shot: plan afresh
  -- RotationY -> world orbit direction, measured once on the first real turn (B.rotSign)
  if B.cal then
    local fx, fz = fwd()
    local a = math.deg(math.atan(B.cal.fx * fz - B.cal.fz * fx, B.cal.fx * fx + B.cal.fz * fz))
    B.cal.n = B.cal.n + 1
    if math.abs(a) > 0.7 then
      local sg = ((a > 0) == (B.cal.dr > 0)) and B.cal.assumed or -B.cal.assumed
      if B.goal and sg ~= B.cal.assumed then B.goal = (B.goal0 + sg * B.planA) % 360 end
      B.rotSign = sg
      B.cal = nil
    elseif B.cal.n > 20 then B.cal = nil end
  end
  -- a118: the blast exploded at the right edge, under the quest panel / combat log - a "big moment" shot keeps its
  -- must points well inside the frame. B.tight is set by the driver per shot (generic; the director used to look for
  -- one helm item name in the shot label).
  local tight = B.tight == true
  local OX, OY, PX, PY = 0.95, 0.92, 0.85, 0.82
  if tight then OX, OY, PX, PY = 0.6, 0.6, 0.5, 0.5 end
  if V and P then
    local nm = #mpts
    local okNow = seen(mpts, 0, OX, OY) == nm
    if not B.goal and not okNow and now - (B.lastPlan or 0) > 300 then
      B.lastPlan = now
      local best, bestN = nil, seen(mpts, 0, PX, PY)
      for k = 1, 36 do
        for _, sgn in ipairs({ 1, -1 }) do
          local a = sgn * k * 5
          local n = seen(mpts, a, PX, PY)
          if n > bestN then best, bestN = a, n end
          if n == nm and not best then best = a end
        end
        if bestN == nm and best then break end
      end
      if best then
        -- among the turns up to 30 deg further that also frame everything, prefer one with the companions in view too
        if bestN == nm and #pts > nm then
          local allBest = seen(pts, best, PX, PY)
          for k = math.floor(math.abs(best) / 5) + 1, math.floor(math.abs(best) / 5) + 6 do
            for _, sgn in ipairs({ 1, -1 }) do
              local a = sgn * k * 5
              if seen(mpts, a, PX, PY) == nm then
                local na = seen(pts, a, PX, PY)
                if na > allBest then best, allBest = a, na end
              end
            end
          end
        end
        B.planA, B.goal0 = best, c.RotationY
        -- calibration 2026-10-06: theta = -40 - RotationY, i.e. +RotationY orbits the camera by -1 deg (sign -1);
        -- verified on the first turn of each install (B.cal) in case that ever differs
        B.goal = (c.RotationY + (B.rotSign or -1) * best) % 360
        if not B.rotSign and not B.cal then
          local fx, fz = fwd()
          B.cal = { fx = fx, fz = fz, dr = best, n = 0, assumed = -1 }
        end
      end
    end
  end
  if B.goal then
    local rc = c.RotationY
    local d = wrap(B.goal - rc)
    if math.abs(d) < 0.8 then
      B.goal = nil
    else
      local step = d * (1 - math.exp(-dt / 0.35))
      local maxs = (B.maxRate or 110) * dt
      if math.abs(step) < 0.4 * dt * 60 then step = (d > 0 and 1 or -1) * math.min(math.abs(d), 0.4 * dt * 60) end
      if step > maxs then step = maxs elseif step < -maxs then step = -maxs end
      c.RotationY = (rc + step) % 360
    end
  end
  B.turning = B.goal ~= nil
  local nx, nz = T[1], T[3]
  B.frames = (B.frames or 0) + 1
  -- audit (user 2026-10-06: "audit the director"): 4x per second, project the framed characters with the live camera
  -- matrices and count per shot how often all MUST points (actor/caster + target) and all points are on screen
  -- B.ready (every frame): all MUST points on screen and the camera not turning - the bot waits for it before a cast
  local function inside(p)
    local q = B.mul(P, B.mul(V, { p[1], p[2] + 1.0, p[3], 1 }))
    if not q[4] or q[4] <= 0.0001 then return false end
    return math.abs(q[1] / q[4]) <= 0.95 and math.abs(q[2] / q[4]) <= 0.92
  end
  local mOK = V ~= nil and P ~= nil
  if mOK then for _, p in ipairs(mpts) do if not inside(p) then mOK = false end end end
  B.ready = mOK
  if B.shot and now - (B.lastS or 0) >= 250 then
    B.lastS = now
    if V and P then
      local aOK = true
      for _, p in ipairs(pts) do if not inside(p) then aOK = false end end
      B.st = B.st or {}
      local s = B.st[B.shot] or { n = 0, must = 0, all = 0, label = B.label or "?", off = 0, npts = 0, nm = 0 }
      s.n = s.n + 1
      -- diagnostics (a70: shared turns 38 % with "camera on Tav" but the view on the empty centre): how far the aim
      -- point is from the must centroid, and how many points / must points were actually resolved and framed
      s.off = s.off + math.sqrt((nx - anchor[1]) ^ 2 + (nz - anchor[3]) ^ 2)
      s.npts = s.npts + #pts
      s.nm = s.nm + #mpts
      if mOK then s.must = s.must + 1 end
      if aOK then s.all = s.all + 1 end
      B.st[B.shot] = s
    end
  end
end
local function flat(m)
  if type(m) ~= 'table' and type(m) ~= 'userdata' then return nil end
  local out = {}
  local ok = pcall(function()
    if m[16] ~= nil then for i = 1, 16 do out[i] = m[i] end
    else for i = 1, 4 do for j = 1, 4 do out[#out + 1] = m[i][j] end end end
  end)
  return ok and #out == 16 and out or nil
end
B.mats = function()
  for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent('Camera')) do
    if e.Camera.Active then
      local cc = e.Camera.Controller.Camera
      return flat(cc.ViewMatrix), flat(cc.ProjectionMatrix)
    end
  end
end
B.mul = function(m, v)
  local r = {}
  for i = 1, 4 do r[i] = m[i] * v[1] + m[4 + i] * v[2] + m[8 + i] * v[3] + m[12 + i] * v[4] end
  return r
end
B.report = function()
  local out = {}
  for id, s in pairs(B.st or {}) do
    out[#out + 1] = string.format('%d|%d|%d|%d|%s~aim-off %.1f m, pts %.1f, must %.1f', id, s.n, s.must, s.all, s.label, (s.off or 0) / math.max(1, s.n), (s.npts or 0) / math.max(1, s.n), (s.nm or 0) / math.max(1, s.n))
  end
  table.sort(out, function(a, b) return tonumber(a:match('^%d+')) < tonumber(b:match('^%d+')) end)
  return table.concat(out, '\n')
end
B.yawOff = 320   -- calibrated 2026-10-06: theta = -40 - RotationY
return 'director installed'
