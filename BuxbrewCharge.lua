-- BuxbrewCharge v1.0.0 (Vanilla/Turtle 1.12)
-- Account-wide SavedVariables. Lua 5.0-safe string handling.

-------------------------------------------------
-- Emote pool (built-in emotes you’d /type)
-- Tweak as you like; tokens are case-insensitive for DoEmote.
-------------------------------------------------
local EMOTE_TOKENS = {
  "CHARGE",        -- /charge (battle opener)
  "ATTACKTARGET",  -- /attacktarget
  "ROAR",          -- /roar
  "CHEER",         -- /cheer
  "FLEX",          -- /flex
  "TRAIN",         -- /train
  "LAUGH",         -- /lol
  "CHUCKLE",       -- /chuckle
  "BORED",          -- /bored
  "WHISTLE",         -- /whistle
}

-------------------------------------------------
-- State
-------------------------------------------------
local WATCH_SLOT = nil
local WATCH_MODE = false
local LAST_EMOTE_TIME = 0
local EMOTE_COOLDOWN = 21  -- seconds

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function chat(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffBBC:|r " .. text)
  end
end

local function ensureDB()
  if type(BuxbrewChargeDB) ~= "table" then
    BuxbrewChargeDB = {}
  end
  return BuxbrewChargeDB
end

-- one-time lazy load in case events fire oddly on this client
local _bbc_loaded_once = false
local function ensureLoaded()
  if not _bbc_loaded_once then
    local db = ensureDB()
    if WATCH_SLOT == nil then
      WATCH_SLOT = db.slot or nil
    end
    _bbc_loaded_once = true
  end
end

local function tlen(t)
  if t and table.getn then return table.getn(t) end
  return 0
end

local function pick(t)
  local n = tlen(t)
  if n < 1 then return nil end
  return t[math.random(1, n)]
end

local function performBuiltInEmote(token)
  -- Try to run a built-in emote. If your client lacks a token, just remove it from EMOTE_TOKENS.
  if DoEmote then
    DoEmote(token)
  else
    -- emergency fallback: a generic roar emote text
    SendChatMessage("roars a battlecry!", "EMOTE")
  end
end

local function doEmoteNow()
  local now = GetTime()
  if now - LAST_EMOTE_TIME < EMOTE_COOLDOWN then return end
  LAST_EMOTE_TIME = now
  local e = pick(EMOTE_TOKENS)
  if e then performBuiltInEmote(e) end
end

-------------------------------------------------
-- Hook UseAction (1.12)
-------------------------------------------------
local _Orig_UseAction = UseAction
function UseAction(slot, checkCursor, onSelf)
  ensureLoaded()
  if WATCH_MODE then
    chat("pressed slot " .. tostring(slot))
  end
  if WATCH_SLOT and slot == WATCH_SLOT then
    doEmoteNow()
  end
  return _Orig_UseAction(slot, checkCursor, onSelf)
end

-------------------------------------------------
-- Slash Commands
-------------------------------------------------
SLASH_BUXBREWCHARGE1 = "/bbc"
SlashCmdList["BUXBREWCHARGE"] = function(raw)
  ensureLoaded()
  local s = raw or ""
  s = string.gsub(s, "^%s+", "")
  local cmd, rest = string.match(s, "^(%S+)%s*(.-)$")

  if cmd == "slot" then
    local n = tonumber(rest)
    if n then
      WATCH_SLOT = n
      local db = ensureDB()
      db.slot = n
      chat("watching action slot " .. n .. " (saved).")
    else
      chat("usage: /bbc slot <number>")
    end

  elseif cmd == "watch" then
    WATCH_MODE = not WATCH_MODE
    chat("watch mode " .. (WATCH_MODE and "ON" or "OFF"))

  elseif cmd == "emote" then
    doEmoteNow()

  elseif cmd == "info" then
    chat("watching slot: " .. (WATCH_SLOT and tostring(WATCH_SLOT) or "none"))
    chat("cooldown: " .. EMOTE_COOLDOWN .. "s")
    chat("emote pool: " .. tlen(EMOTE_TOKENS) .. " tokens")

  elseif cmd == "timer" then
    local remain = EMOTE_COOLDOWN - (GetTime() - LAST_EMOTE_TIME)
    if remain < 0 then remain = 0 end
    chat("time left: " .. string.format("%.1f", remain) .. "s")

  elseif cmd == "reset" then
    WATCH_SLOT = nil
    local db = ensureDB()
    db.slot = nil
    chat("cleared saved slot.")

  elseif cmd == "save" then
    local db = ensureDB()
    db.slot = WATCH_SLOT
    chat("saved now.")

  elseif cmd == "debug" then
    local t = type(BuxbrewChargeDB)
    local v = (t == "table") and tostring(BuxbrewChargeDB.slot) or "n/a"
    chat("type(BuxbrewChargeDB)=" .. t .. " | SV slot=" .. v .. " | WATCH_SLOT=" .. tostring(WATCH_SLOT))

  else
    chat("/bbc slot <number> | /bbc watch | /bbc emote | /bbc info | /bbc timer | /bbc reset | /bbc save | /bbc debug")
  end
end

-------------------------------------------------
-- Init / Save / RNG
-------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(self, event)
  if event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD" then
    local db = ensureDB()
    WATCH_SLOT = db.slot or WATCH_SLOT
    chat("loaded slot " .. tostring(WATCH_SLOT or "none"))
  elseif event == "PLAYER_LOGIN" then
    math.randomseed(math.floor(GetTime() * 1000)); math.random()
  elseif event == "PLAYER_LOGOUT" then
    ensureDB().slot = WATCH_SLOT
  end
end)
