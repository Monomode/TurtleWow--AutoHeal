-- Name: AutoHeal
-- License: LGPL v2.1

-- ========================================================================
-- If your health drops below the HEALTH THRESHOLD, a healing potion is used.
-- If your mana drops below the MANA THRESHOLD, a mana potion is used.
-- ========================================================================


-- User Options
local defaults =
{
	enabled = true,
	combat_only = false,
	min_group_size = 1,
  
	use_majorheal = true,   -- major healing potion
	use_greaterheal = true, -- greater healing potion
	use_heal = false,         -- healing potion 
	use_lesserheal = true,  -- lesser healing potion 
	use_minorheal = true,   -- minor healing potion 
	
	use_jade = true,        -- conjured mana jade
	use_agate = true,        -- conjured mana agate
	use_majormana = true,   -- major mana potion
	use_greatermana = true,	-- greater mana potion
	use_mana = true,         -- mana potion
	use_lessermana = true,  -- lesser mana potion
	use_minormana = true,   -- minor mana potion

	use_majorrejuv = true,  -- major rejuvenation potion 
	use_rejuv = true,        -- rejuvenation potion 
	use_lesserrejuv = true, -- lesser rejuvenation potion 
	use_minorrejuv = true,  -- minor rejuvenation potion 

	use_tea = true, 		  -- Tea with sugar
	use_healthstone = true,   -- Healthstone
	use_wisdom = true,       -- Flask of distilled wisdom
	
	health_percent = 20, -- default % HP
    mana_percent   = 20, -- default % Mana
}


local DEBUG_MODE = false

local success = true
local failure = nil

local msglog = CreateFrame("Frame")
msglog:RegisterEvent("PLAYER_ENTERING_WORLD")

local function OnPlayerEnteringWorld(self, event)
--   local seg1 = "|cffffffff ---- Refonte de l'addon ---- "
  local seg2 = "|cffffffff <"
  local seg3 = "|cffffffff Auto"
  local seg4 = "|cffff0000 Heal" -- cffffff00 yellow
  local seg5 = "|cffffffff and"
  local seg6 = "|cff0070DD Mana"
  local seg7 = "|cffffffff >"
  local seg8 = ""
  local seg9 = "|cff00FF00 Loaded successfully!"
  local seg10 = "|cffffff00 /autoheal for more info"


  -- Combine the segments and display the message
  -- DEFAULT_CHAT_FRAME:AddMessage(seg1)
  DEFAULT_CHAT_FRAME:AddMessage(seg8)
  DEFAULT_CHAT_FRAME:AddMessage(seg2 .. seg3 .. seg4 .. seg5 .. seg6 .. seg7 .. seg8 .. seg9..seg10)
  DEFAULT_CHAT_FRAME:AddMessage(seg8)
  
  InitMinimapButton()
  DisplayDungeonsByColor()
  ShowDungeonUI()
  msglog:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

msglog:SetScript("OnEvent", OnPlayerEnteringWorld)

---------------------------------------------------------------------------------
--                           Init                             --
---------------------------------------------------------------------------------

local amcolor = {
  blue = format("|c%02X%02X%02X%02X", 1, 41,146,255),
  red = format("|c%02X%02X%02X%02X",1, 255, 0, 0),
  green = format("|c%02X%02X%02X%02X",1, 22, 255, 22),
  yellow = format("|c%02X%02X%02X%02X",1, 255, 255, 0),
  orange = format("|c%02X%02X%02X%02X",1, 255, 146, 24),
  red = format("|c%02X%02X%02X%02X",1, 255, 0, 0),
  gray = format("|c%02X%02X%02X%02X",1, 187, 187, 187),
  gold = format("|c%02X%02X%02X%02X",1, 255, 255, 154),
  blizzard = format("|c%02X%02X%02X%02X",1, 180,244,1),
}

local function colorize(msg,color)
  local c = color or ""
  return c..msg..FONT_COLOR_CODE_CLOSE
end

local function showOnOff(setting)
  local b = "d"
  return setting and colorize("On",amcolor.blue) or colorize("Off",amcolor.red)
end

local function amprint(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function debug_print(text)
    if DEBUG_MODE == true then DEFAULT_CHAT_FRAME:AddMessage(text) end
end

-- Did an oom event fire
local oom = false


local consumables = {}

-- taken from supermacros
local function ItemLinkToName(link)
  if ( link ) then
    return gsub(link,"^.*%[(.*)%].*$","%1");
  end
end

local function hasAlchStone()
  return ItemLinkToName(GetInventoryItemLink("player",13)) == "Alchemists' Stone"
      or ItemLinkToName(GetInventoryItemLink("player",14)) == "Alchemists' Stone" or false
end

-- adapted from supermacros
local function RunLine(...)
  for k=1,arg.n do
    local text=arg[k];
      ChatFrameEditBox:SetText(text);
      ChatEdit_SendText(ChatFrameEditBox);
  end
end

-- adapted from supermacros
local function RunBody(text)
  local body = text;
  local length = strlen(body);
  for w in string.gfind(body, "[^\n]+") do
    RunLine(w);
  end
end

-- Finds an item by either its numeric ID or its name, using string.find
-- @param consume     Optional table: { bag = b, slot = s } to check first
-- @param identifier  Number or string: item ID (e.g. 51916) or item name (e.g. "Healthstone")
-- @param bag         Optional bag index to search first (0‑4)
-- @return table { bag = b, slot = s } or nil
function AMFindItem(consume, identifier, bag)
  if not identifier then return end

  local searchID   = tonumber(identifier)
  local searchName = nil
  if not searchID then
    searchName = identifier
  end

  -- Helper: does this item link match our ID or name?
  local function linkMatches(link)
    -- extract item ID via string.find captures
    local _, _, idStr = string.find(link, "item:(%d+)")
    local id = idStr and tonumber(idStr)

    if searchID then
      return id == searchID
    else
      -- extract item name in brackets via string.find captures
      local _, _, name = string.find(link, "%[(.-)%]")
      -- exact match? partial?
      return name == searchName or (name and string.find(name, identifier))
    end
  end

  -- 1) check the consume slot if provided
  if consume and consume.bag and consume.slot then
    local link = GetContainerItemLink(consume.bag, consume.slot)
    if link and linkMatches(link) then
      return consume
    end
  end

  -- 2) scan a single bag
  local function SearchBag(b)
    for slot = 1, GetContainerNumSlots(b) do
      local link = GetContainerItemLink(b, slot)
      if link and linkMatches(link) then
        return { bag = b, slot = slot }
      end
    end
  end

  -- 3) search the specified bag first
  if bag then
    local result = SearchBag(bag)
    if result then return result end
  end

  -- 4) search all other bags
  for b = 0, 4 do
    if b ~= bag then
      local result = SearchBag(b)
      if result then return result end
    end
  end
end

function FindItemById(consume, item_id, bag)
  if not item_id then return end

  if consume then
    local link = GetContainerItemLink(consume.bag, consume.slot)
    if link then
      local _, _, id = string.find(link, "item:(%d+)")
      if id == item_id then
        return consume
      end
    end
  end

  -- Function to search a single bag for the item
  local function SearchBag(b)
    for slot = 1, GetContainerNumSlots(b) do
      local link = GetContainerItemLink(b, slot)
      if link then
        local _, _, id = string.find(link, "item:(%d+)")
        if id == item_id then
          return { bag = b, slot = slot }
        end
      end
    end
  end

  -- Search the specified bag first
  local result = bag and SearchBag(bag)
  if result then return result end

  -- Search other bags if not found
  for b = 0, 4 do
    if b ~= bag then
      result = SearchBag(b)
      if result then return result end
    end
  end
end

function consumeReady(which)
  if not which then return false end
  local start,dur = GetContainerItemCooldown(which.bag,which.slot)
  return GetTime() > start + dur
end

local function stopAndUse(bag, slot)
  if CastingInfo() or ChannelInfo() or SpellIsTargeting() then
    SpellStopCasting()
  end
  UseContainerItem(bag, slot)
end


local last_fired = 0
function AutoHeal(macro_body,fn)
  local fn = fn or RunBody
  local p = "player"
  local now = GetTime()
  local gcd_done = now > last_fired + 1.5 -- delay after item use before using another one or client gets unhappy, even if items have no gcd
  -- local gcd_done = true

  if AutoHealSettings.enabled and gcd_done
	and not UnitIsDeadOrGhost(p)   
    and (UnitAffectingCombat(p) or not AutoHealSettings.combat_only)
    and (max(1,max(GetNumRaidMembers(),GetNumPartyMembers())) >= AutoHealSettings.min_group_size) then

    local hp = UnitHealth(p)
    local hp_max = UnitHealthMax(p)
	local mana = UnitMana(p)
    local mana_max = UnitManaMax(p)
    local missing_mana = abs (mana - mana_max)
    local missing_health = abs (hp - hp_max)
    local health_perc = hp / hp_max
	local mana_perc = mana / mana_max
	-- local healing_threshold = (hp <= HEALTH_THRESHOLD)
	-- local mana_threshold    = (mana <= MANA_THRESHOLD)
	--local healing_threshold = (health_perc < AutoHealSettings.health_percent)
	--local mana_threshold    = (mana_perc < AutoHealSettings.mana_percent)
	--local healthstone_threshold = (health_perc < AutoHealSettings.health_percent)

	local healing_threshold = (health_perc < AutoHealSettings.health_percent / 100)
	local mana_threshold    = (mana_perc < AutoHealSettings.mana_percent / 100)
	local healthstone_threshold = (health_perc < AutoHealSettings.health_percent / 100)


	
    if AutoHealSettings.use_majorheal and healing_threshold and consumeReady(consumables.majorheal) and UnitAffectingCombat("player") then
      debug_print("Trying Major Healing Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.majorheal.bag,consumables.majorheal.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Major Healing Potion <<")
		last_fired = now

	elseif AutoHealSettings.use_greaterheal and healing_threshold and consumeReady(consumables.greaterheal) and UnitAffectingCombat("player") then
      debug_print("Trying Greater Healing Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.greaterheal.bag,consumables.greaterheal.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Greater Healing Potion <<")
		last_fired = now
		
    elseif AutoHealSettings.use_heal and healing_threshold and consumeReady(consumables.heal) and UnitAffectingCombat("player") then
      debug_print("Trying Healing Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.heal.bag,consumables.heal.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Healing Potion <<")
		last_fired = now
		
    elseif AutoHealSettings.use_lesserheal and healing_threshold and consumeReady(consumables.lesserheal) and UnitAffectingCombat("player") then
      debug_print("Trying Lesser Healing Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.lesserheal.bag,consumables.lesserheal.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Lesser Healing Potion <<")
		last_fired = now
		
    elseif AutoHealSettings.use_minorheal and healing_threshold and consumeReady(consumables.minorheal) and UnitAffectingCombat("player") then
      debug_print("Trying Minor Healing Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.minorheal.bag,consumables.minorheal.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Minor Healing Potion <<")
		last_fired = now
		
	elseif AutoHealSettings.use_jade and mana_threshold and consumeReady(consumables.jade) and UnitAffectingCombat("player") then
      debug_print("Trying Mana Jade")
	  SpellStopCasting()
      UseContainerItem(consumables.jade.bag,consumables.jade.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Mana Jade <<")
		oom = false
		last_fired = now
			
    elseif AutoHealSettings.use_agate and mana_threshold and consumeReady(consumables.agate) and UnitAffectingCombat("player") then
      debug_print("Trying Mana Agate")
	  SpellStopCasting()
      UseContainerItem(consumables.agate.bag,consumables.agate.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Mana Agate <<")
		oom = false
		last_fired = now
			
	elseif AutoHealSettings.use_majormana and mana_threshold and consumeReady(consumables.majormana) and UnitAffectingCombat("player") then
      debug_print("Trying Major Mana Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.majormana.bag,consumables.majormana.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Major Mana Potion <<")
		oom = false
		last_fired = now

	elseif AutoHealSettings.use_greatermana and mana_threshold and consumeReady(consumables.greatermana) and UnitAffectingCombat("player") then
      debug_print("Trying Greater Mana Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.greatermana.bag,consumables.greatermana.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Greater Mana Potion <<")
		oom = false
		last_fired = now
		
    elseif AutoHealSettings.use_mana and mana_threshold and consumeReady(consumables.mana) and UnitAffectingCombat("player") then
      debug_print("Trying Mana Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.mana.bag,consumables.mana.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Mana Potion <<")
		oom = false
		last_fired = now
		
    elseif AutoHealSettings.use_lessermana and mana_threshold and consumeReady(consumables.lessermana) and UnitAffectingCombat("player") then
      debug_print("Trying Lesser Mana Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.lessermana.bag,consumables.lessermana.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Lesser Mana Potion <<")
		oom = false
		last_fired = now
		
    elseif AutoHealSettings.use_minormana and mana_threshold and consumeReady(consumables.minormana) and UnitAffectingCombat("player") then
      debug_print("Trying Minor Mana Potion")
	  SpellStopCasting()
      UseContainerItem(consumables.minormana.bag,consumables.minormana.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Minor Mana Potion <<")
		oom = false
		last_fired = now	
		
    elseif AutoHealSettings.use_majorrejuv and healing_threshold and mana_threshold and consumeReady(consumables.majorrejuv) and UnitAffectingCombat("player") then
      debug_print("Trying Major Rejuvenation")
	  SpellStopCasting()
      UseContainerItem(consumables.majorrejuv.bag,consumables.majorrejuv.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Major Rejuvenation Potion <<")
		oom = false
		last_fired = now
		
    elseif AutoHealSettings.use_rejuv and healing_threshold and mana_threshold and consumeReady(consumables.rejuv) and UnitAffectingCombat("player") then
      debug_print("Trying Rejuvenation")
	  SpellStopCasting()
      UseContainerItem(consumables.rejuv.bag,consumables.rejuv.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Rejuvenation Potion <<")
		oom = false
		last_fired = now
		
    elseif AutoHealSettings.use_lesserrejuv and healing_threshold and mana_threshold and consumeReady(consumables.lesserrejuv) and UnitAffectingCombat("player") then
      debug_print("Trying Lesser Rejuvenation")
	  SpellStopCasting()
      UseContainerItem(consumables.lesserrejuv.bag,consumables.lesserrejuv.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Lesser Rejuvenation Potion <<")
		oom = false
		last_fired = now
		
    elseif AutoHealSettings.use_minorrejuv and healing_threshold and mana_threshold and consumeReady(consumables.minorrejuv) and UnitAffectingCombat("player") then
      debug_print("Trying Minor Rejuvenation")
	  SpellStopCasting()
      UseContainerItem(consumables.minorrejuv.bag,consumables.minorrejuv.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Minor Rejuvenation Potion <<")
		oom = false
		last_fired = now
		
    elseif AutoHealSettings.use_tea and mana_threshold and consumeReady(consumables.tea) and UnitAffectingCombat("player") then
      debug_print("Trying Tea with sugar")
	  SpellStopCasting()
      UseContainerItem(consumables.tea.bag,consumables.tea.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Tea with sugar <<")
		oom = false
		last_fired = now
		
    elseif AutoHealSettings.use_healthstone and healthstone_threshold and consumeReady(consumables.healthstone) and UnitAffectingCombat("player") then
      debug_print("Trying Healthstone")
	  SpellStopCasting()
      UseContainerItem(consumables.healthstone.bag,consumables.healthstone.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Healthstone <<")
		last_fired = now
		
    elseif AutoHealSettings.use_wisdom and mana_threshold and consumeReady(consumables.flask) and UnitAffectingCombat("player") then
      debug_print("Trying Flask")
	  SpellStopCasting()
      UseContainerItem(consumables.flask.bag,consumables.flask.slot)
		DEFAULT_CHAT_FRAME:AddMessage(">> Using Flask of Distilled Wisdom <<")
		oom = false
		last_fired = now
		
    else
      debug_print("Running body")
      fn(macro_body)
    end
  else
    fn(macro_body)
  end
end

-------------------------------------------------

local AutoHealFrame = CreateFrame("FRAME")

function AM_CastSpellByName(spell,a2,a3,a4,a5,a6,a7,a8,a9,a10)
  AutoHeal(spell,function () AutoHealFrame.orig_CastSpellByName(spell,a2,a3,a4,a5,a6,a7,a8,a9,a10) end)
end

function AM_CastSpell(spell,a2,a3,a4,a5,a6,a7,a8,a9,a10)
  AutoHeal(spell,function () AutoHealFrame.orig_CastSpell(spell,a2,a3,a4,a5,a6,a7,a8,a9,a10) end)
end

-- action bar buttons are spells too
function AM_UseAction(slot,a2,a3,a4,a5,a6,a7,a8,a9,a10)
  if AutoHealFrame.cachedSpells[GetActionTexture(slot)] then
    AutoHeal(slot,function () AutoHealFrame.orig_UseAction(slot,a2,a3,a4,a5,a6,a7,a8,a9,a10) end)
  else
    AutoHealFrame.orig_UseAction(slot,a2,a3,a4,a5,a6,a7,a8,a9,a10)
  end
end

local orig_CastSpell = CastSpell
local orig_CastSpellByName = CastSpellByName
local orig_UseAction = UseAction

local function HookCasts(unhook)
  if unhook then -- not neccesary really
    CastSpell = orig_CastSpell
    CastSpellByName = orig_CastSpellByName
    UseAction = orig_UseAction
  else
    AutoHealFrame.orig_CastSpell = orig_CastSpell
    AutoHealFrame.orig_CastSpellByName = orig_CastSpellByName
    AutoHealFrame.orig_UseAction = orig_UseAction
    CastSpell = AM_CastSpell
    CastSpellByName = AM_CastSpellByName
    UseAction = AM_UseAction
  end
end
HookCasts() -- hook right now in case another addon does further hooks

local function OnEvent()
  if event == "UI_ERROR_MESSAGE" and arg1 == "Not enough mana" then
    if AutoHealSettings.use_wisdom then oom = true end
  elseif event == "ADDON_LOADED" then
    if not AutoHealSettings
      then AutoHealSettings = defaults -- initialize default settings
      else -- or check that we only have the current settings format
        local s = {}
        for k,v in pairs(defaults) do
          s[k] = (AutoHealSettings[k] == nil) and defaults[k] or AutoHealSettings[k]
        end
        AutoHealSettings = s
    end
  elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then -- alch stone
    consumables.has_alchstone = hasAlchStone()
  elseif event == "BAG_UPDATE" then -- consume slot update
    -- this should only actually search for the missing item
    consumables.tea = AMFindItem(consumables.tea, "61675", arg1)
    if not consumables.tea then
	-- tea with sugar
      consumables.tea = AMFindItem(consumables.tea, "Tea with sugar", arg1)
    end
	-- major heal
	consumables.majorheal = AMFindItem(consumables.majorheal, "Major Healing Potion", arg1)
	-- greater heal
	consumables.greaterheal = AMFindItem(consumables.greaterheal, "7181", arg1)
	-- heal
	consumables.heal = AMFindItem(consumables.heal, "929", arg1)
	-- lesser heal
	consumables.lesserheal = AMFindItem(consumables.lesserheal, "Lesser Healing Potion", arg1)
	-- minor heal
	consumables.minorheal = AMFindItem(consumables.minorheal, "Minor Healing Potion", arg1)
	
	-- mana jade
	consumables.jade = AMFindItem(consumables.jade, "Mana Jade", arg1) -- conjured mana jade
	-- mana agate
	consumables.agate = AMFindItem(consumables.agate, "Mana Agate", arg1) -- conjured mana agate
	-- major mana
	consumables.majormana = AMFindItem(consumables.majormana, "Major Mana Potion", arg1)
	-- greater mana
	consumables.greatermana = AMFindItem(consumables.greatermana, "Greater Mana Potion", arg1)
	-- mana
	consumables.mana = AMFindItem(consumables.mana, "Mana Potion", arg1)
	-- lesser mana
	consumables.lessermana = AMFindItem(consumables.lessermana, "Lesser Mana Potion", arg1)
	-- minor mana
	consumables.minormana = AMFindItem(consumables.minormana, "Minor Mana Potion", arg1)
	
	-- major rejuv
	consumables.majorrejuv = AMFindItem(consumables.majorrejuv, "Major Rejuvenation Potion", arg1)
	-- rejuv
	consumables.rejuv = AMFindItem(consumables.rejuv, "Rejuvenation Potion", arg1)
	-- lesser rejuv
	consumables.lesserrejuv = AMFindItem(consumables.lesserrejuv, "Lesser Rejuvenation Potion", arg1)
	-- minor rejuv
	consumables.minorrejuv = AMFindItem(consumables.minorrejuv, "Minor Rejuvenation Potion", arg1)
	
	-- healthstone
	consumables.healthstone = AMFindItem(consumables.healthstone, "Healthstone", arg1)
	-- flask
	consumables.flask = AMFindItem(consumables.flask, "Flask of Distilled Wisdom", arg1)
  elseif event == "PLAYER_ENTERING_WORLD" then -- spell cache
    AutoHealFrame.cachedSpells = {}
    -- Loop through the spellbook and cache player spells
    local function CacheSpellTextures(bookType)
      local i = 1
      while true do
        local spellTexture = GetSpellTexture(i, bookType)
        if not spellTexture then break end
        AutoHealFrame.cachedSpells[spellTexture] = true
        i = i + 1
      end
  end

  CacheSpellTextures(BOOKTYPE_SPELL)
  CacheSpellTextures(BOOKTYPE_PET)
  end
end

local function handleCommands(msg,editbox)
  local args = {};
  for word in string.gfind(msg,'%S+') do table.insert(args,word) end
if args[1] == "majorheal" then
    AutoHealSettings.use_majorheal = not AutoHealSettings.use_majorheal
    amprint("Use Healing Potion: " .. showOnOff(AutoHealSettings.use_majorheal))
elseif args[1] == "greaterheal" then
    AutoHealSettings.use_greaterheal = not AutoHealSettings.use_greaterheal
    amprint("Use Greater Healing Potion: " .. showOnOff(AutoHealSettings.use_greaterheal))
elseif args[1] == "heal" then
    AutoHealSettings.use_heal = not AutoHealSettings.use_heal
    amprint("Use Healing Potion: " .. showOnOff(AutoHealSettings.use_heal))
elseif args[1] == "lesserheal" then
    AutoHealSettings.use_lesserheal = not AutoHealSettings.use_lesserheal
    amprint("Use Lesser Healing Potion: " .. showOnOff(AutoHealSettings.use_lesserheal))
elseif args[1] == "minorhealing" then
    AutoHealSettings.use_minorheal = not AutoHealSettings.use_minorheal
    amprint("Use Minor Healing Potion: " .. showOnOff(AutoHealSettings.use_minorheal))

elseif args[1] == "linenbandage" then
    AutoHealSettings.use_linenbandage = not AutoHealSettings.use_linenbandage
    amprint("Use Linen Bandage: " .. showOnOff(AutoHealSettings.use_linenbandage))
		
elseif args[1] == "majormana" then
    AutoHealSettings.use_majormana = not AutoHealSettings.use_majormana
    amprint("Use Major Mana Potion: " .. showOnOff(AutoHealSettings.use_majormana))
elseif args[1] == "greatermana" then
    AutoHealSettings.use_greatermana = not AutoHealSettings.use_greatermana
    amprint("Use Greater Mana Potion: " .. showOnOff(AutoHealSettings.use_greatermana))
elseif args[1] == "mana" then
    AutoHealSettings.use_mana = not AutoHealSettings.use_mana
    amprint("Use Mana Potion: " .. showOnOff(AutoHealSettings.use_mana))
elseif args[1] == "lessermana" then
    AutoHealSettings.use_lessermana = not AutoHealSettings.use_lessermana
    amprint("Use Lesser Mana Potion: " .. showOnOff(AutoHealSettings.use_lessermana))
elseif args[1] == "minormana" then
    AutoHealSettings.use_minormana = not AutoHealSettings.use_minormana
    amprint("Use Minor Mana Potion: " .. showOnOff(AutoHealSettings.use_minormana))
elseif args[1] == "majorrejuv" then
    AutoHealSettings.use_rejuv = not AutoHealSettings.use_rejuv
    amprint("Use Major Rejuvenation Potion: " .. showOnOff(AutoHealSettings.use_majorrejuv))
elseif args[1] == "rejuv" then
    AutoHealSettings.use_rejuv = not AutoHealSettings.use_rejuv
    amprint("Use Rejuvenation Potion: " .. showOnOff(AutoHealSettings.use_rejuv))
elseif args[1] == "lesserrejuv" then
    AutoHealSettings.use_lesserrejuv = not AutoHealSettings.use_lesserrejuv
    amprint("Use Lesser Rejuvenation Potion: " .. showOnOff(AutoHealSettings.use_lesserrejuv))
elseif args[1] == "minorrejuv" then
    AutoHealSettings.use_minorrejuv = not AutoHealSettings.use_minorrejuv
    amprint("Use Minor Rejuvenation Potion: " .. showOnOff(AutoHealSettings.use_minorrejuv))
elseif args[1] == "tea" then
    AutoHealSettings.use_tea = not AutoHealSettings.use_tea
    amprint("Use Tea: " .. showOnOff(AutoHealSettings.use_tea))
elseif args[1] == "stone" or args[1] == "healthstone" then
    AutoHealSettings.use_healthstone = not AutoHealSettings.use_healthstone
    amprint("Use Healthstone: " .. showOnOff(AutoHealSettings.use_healthstone))
elseif args[1] == "flask" then
    AutoHealSettings.use_wisdom = not AutoHealSettings.use_wisdom
    amprint("Use Flask of Distilled Wisdom: " .. showOnOff(AutoHealSettings.use_wisdom))
elseif args[1] == "agate" then
    AutoHealSettings.use_agate = not AutoHealSettings.use_agate
    amprint("Use Conjured Mana Agate: " .. showOnOff(AutoHealSettings.use_agate))
elseif args[1] == "jade" then
    AutoHealSettings.use_jade = not AutoHealSettings.use_jade
    amprint("Use Conjured Mana Jade: " .. showOnOff(AutoHealSettings.use_jade))
	
elseif args[1] == "hp" and args[2] then
    local val = tonumber(args[2])
    if val and val > 0 and val <= 100 then
        AutoHealSettings.health_percent = val
        amprint("Health threshold set to " .. val .. "%")
    else
        amprint("Usage: /autoheal heal <percent 1-100>")
    end

elseif args[1] == "mp" and args[2] then
    local val = tonumber(args[2])
    if val and val > 0 and val <= 100 then
        AutoHealSettings.mana_percent = val
        amprint("Mana threshold set to " .. val .. "%")
    else
        amprint("Usage: /autoheal mana <percent 1-100>")
    end


  elseif args[1] == "size" or args[1] == "group" then
    local n = tonumber(args[2])
    if n and n >= 0 then
      AutoHealSettings.min_group_size = n
      amprint("Active at minimum group size: "..n)
    else
      amprint("Usage: /AutoHeal size <non-negative number>")
    end
	
  elseif args[1] == "combat" then
    AutoHealSettings.combat_only = not AutoHealSettings.combat_only
    amprint("Use only in combat: "..showOnOff(AutoHealSettings.combat_only))
  elseif args[1] == "enabled" or args[1] == "enable" or args[1] == "toggle" then
    AutoHealSettings.enabled = not AutoHealSettings.enabled
    amprint("Addon enabled: "..showOnOff(AutoHealSettings.enabled))
  else -- todo make group size color by if you're in a big enough group currently
    amprint('AutoHeal: Automatically use consumes.')
    amprint('- Addon '..colorize("enable",amcolor.green)..'d [' .. showOnOff(AutoHealSettings.enabled) .. ']')
    amprint('- Active in ' .. colorize("combat",amcolor.green)..' only [' .. showOnOff(AutoHealSettings.combat_only) .. ']')
    amprint('- Active at minimum group ' .. colorize("size",amcolor.green) .. ' [' .. AutoHealSettings.min_group_size .. ']')

-- Bandages
	amprint('- Use ' .. colorize("LinenBandage", amcolor.green) .. ' [' .. showOnOff(AutoHealSettings.use_linenbandage) .. ']')

-- Healing Potions
	amprint('- Use ' .. colorize("MinorHeal", amcolor.green) .. 'ing Potion [' .. showOnOff(AutoHealSettings.use_minorheal) .. ']')
	amprint('- Use ' .. colorize("LesserHeal", amcolor.green) .. 'ing Potion [' .. showOnOff(AutoHealSettings.use_lesserheal) .. ']')
	amprint('- Use ' .. colorize("Heal", amcolor.green) .. 'ing Potion [' .. showOnOff(AutoHealSettings.use_heal) .. ']')
	amprint('- Use ' .. colorize("GreaterHeal",amcolor.green) .. 'ing Potion [' .. showOnOff(AutoHealSettings.use_greaterheal) .. ']')
	amprint('- Use ' .. colorize("MajorHeal",amcolor.green) .. 'ing Potion [' .. showOnOff(AutoHealSettings.use_majorheal) .. ']')

-- Mana Potions
	amprint('- Use ' .. colorize("MinorMana", amcolor.green) .. ' Potion [' .. showOnOff(AutoHealSettings.use_minormana) .. ']')
	amprint('- Use ' .. colorize("LesserMana", amcolor.green) .. ' Potion [' .. showOnOff(AutoHealSettings.use_lessermana) .. ']')
	amprint('- Use Conjured Mana ' .. colorize("Agate", amcolor.green) .. ' [' .. showOnOff(AutoHealSettings.use_agate) .. ']')
	amprint('- Use ' .. colorize("Mana", amcolor.green) .. ' Potion [' .. showOnOff(AutoHealSettings.use_mana) .. ']')
	amprint('- Use Conjured Mana ' .. colorize("Jade", amcolor.green) .. ' [' .. showOnOff(AutoHealSettings.use_jade) .. ']')
	amprint('- Use ' .. colorize("GreaterMana", amcolor.green) .. ' Potion [' .. showOnOff(AutoHealSettings.use_greatermana) .. ']')
	amprint('- Use ' .. colorize("MajorMana",amcolor.green) .. ' Potion [' .. showOnOff(AutoHealSettings.use_majormana) .. ']')
		
-- Rejuvenation Potions
	amprint('- Use ' .. colorize("MinorRejuv", amcolor.green) .. 'enation Potion [' .. showOnOff(AutoHealSettings.use_minorrejuv) .. ']')
	amprint('- Use ' .. colorize("LesserRejuv", amcolor.green) .. 'enation Potion [' .. showOnOff(AutoHealSettings.use_lesserrejuv) .. ']')
	amprint('- Use ' .. colorize("Rejuv", amcolor.green) .. 'enation Potion [' .. showOnOff(AutoHealSettings.use_rejuv) .. ']')
	amprint('- Use ' .. colorize("MajorRejuv",amcolor.green) .. 'enation Potion [' .. showOnOff(AutoHealSettings.use_majorrejuv) .. ']')

-- Specials
	amprint('- Use ' .. colorize("Tea", amcolor.green) .. ' with sugar [' .. showOnOff(AutoHealSettings.use_tea) .. ']')
	amprint('- Use Health' .. colorize("Stone", amcolor.green) .. ' [' .. showOnOff(AutoHealSettings.use_healthstone) .. ']')
	amprint('- Use ' .. colorize("Flask", amcolor.green) .. ' of Distilled Wisdom [' .. showOnOff(AutoHealSettings.use_wisdom) .. ']')

-- Health & Mana thresholds
    amprint('- Health threshold: ' .. colorize("HP", amcolor.green) .. ' [' .. AutoHealSettings.health_percent .. '%]')
    amprint('- Mana threshold: ' .. colorize("MP", amcolor.green) .. ' [' .. AutoHealSettings.mana_percent .. '%]')

  end
end

AutoHealFrame:RegisterEvent("UI_ERROR_MESSAGE")
AutoHealFrame:RegisterEvent("BAG_UPDATE")
AutoHealFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
AutoHealFrame:RegisterEvent("ADDON_LOADED")
AutoHealFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
AutoHealFrame:SetScript("OnEvent", OnEvent)
  
SLASH_AUTOHEAL1 = "/autoheal";
SlashCmdList["AUTOHEAL"] = handleCommands
