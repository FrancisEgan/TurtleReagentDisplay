-- ReagentDisplay: Shows reagent counts on action bar spell buttons
-- Supports ALL vanilla WoW classes that use spell reagents.
-- Compatible with Turtle WoW (1.12 client)

ReagentDisplay = {}

---------------------------------------------------------------------------
-- REAGENT GROUPS
-- Consumable item reagents (bought, looted, or traded — NOT class-generated
-- resources like Soul Shards). Each group is a list of item names. We sum
-- them all when counting, which handles spells whose different ranks
-- consume different items (e.g. Rebirth R1-R5 use different seeds).
---------------------------------------------------------------------------
local REAGENT_GROUPS = {
    -- Mage
    teleport_rune = { "Rune of Teleportation" },
    portal_rune   = { "Rune of Portals" },
    arcane_powder = { "Arcane Powder" },
    -- Shared (Mage Slow Fall + Priest Levitate)
    light_feather = { "Light Feather" },
    -- Mage (Khadgar's Unlocking R1-R4)
    khadgar_unlocking_r1 = { "Tiny Bronze Key" },
    khadgar_unlocking_r2 = { "Tiny Iron Key" },
    khadgar_unlocking_r3 = { "Tiny Copper Key" },
    khadgar_unlocking_r4 = { "Tiny Silver Key" },
    -- Paladin
    symbol_divinity = { "Symbol of Divinity" },
    symbol_kings    = { "Symbol of Kings" },
    -- Priest
    sacred_candle = { "Sacred Candle", "Holy Candle" },
    -- Shaman
    ankh = { "Ankh" },
    -- Rogue
    blinding_powder = { "Blinding Powder" },
    flash_powder    = { "Flash Powder" },
    -- Warlock (vendor-purchaseable only, NOT Soul Shards)
    infernal_stone   = { "Infernal Stone" },
    demonic_figurine = { "Demonic Figurine" },
    -- Druid
    rebirth_seed = { "Maple Seed", "Stranglethorn Seed", "Ashwood Seed",
                     "Hornbeam Seed", "Ironwood Seed" },
    gift_wild    = { "Wild Thornroot", "Wild Quillvine" },
}

---------------------------------------------------------------------------
-- SPELL → REAGENT GROUP  (exact spell-name match)
-- The tooltip's first line is used for matching.
---------------------------------------------------------------------------
local SPELL_REAGENTS = {
    ----- MAGE ----- Teleports
    ["Teleport: Stormwind"]     = "teleport_rune",
    ["Teleport: Ironforge"]     = "teleport_rune",
    ["Teleport: Darnassus"]     = "teleport_rune",
    ["Teleport: Orgrimmar"]     = "teleport_rune",
    ["Teleport: Thunder Bluff"] = "teleport_rune",
    ["Teleport: Undercity"]     = "teleport_rune",
    -- Portals
    ["Portal: Stormwind"]       = "portal_rune",
    ["Portal: Ironforge"]       = "portal_rune",
    ["Portal: Darnassus"]       = "portal_rune",
    ["Portal: Orgrimmar"]       = "portal_rune",
    ["Portal: Thunder Bluff"]   = "portal_rune",
    ["Portal: Undercity"]       = "portal_rune",
    -- Other Mage
    ["Arcane Brilliance"]       = "arcane_powder",
    ["Slow Fall"]               = "light_feather",

    ----- PALADIN -----
    ["Divine Intervention"]           = "symbol_divinity",
    ["Greater Blessing of Kings"]     = "symbol_kings",
    ["Greater Blessing of Might"]     = "symbol_kings",
    ["Greater Blessing of Wisdom"]    = "symbol_kings",
    ["Greater Blessing of Salvation"] = "symbol_kings",
    ["Greater Blessing of Sanctuary"] = "symbol_kings",
    ["Greater Blessing of Light"]     = "symbol_kings",

    ----- PRIEST -----
    ["Prayer of Fortitude"]         = "sacred_candle",
    ["Prayer of Shadow Protection"] = "sacred_candle",
    ["Prayer of Spirit"]            = "sacred_candle",
    ["Levitate"]                    = "light_feather",

    ----- SHAMAN -----
    ["Reincarnation"]   = "ankh",

    ----- ROGUE -----
    ["Blind"]   = "blinding_powder",
    ["Vanish"]  = "flash_powder",

    ----- WARLOCK ----- (vendor-purchaseable reagents only)
    ["Inferno"]        = "infernal_stone",
    ["Ritual of Doom"] = "demonic_figurine",

    ----- DRUID -----
    ["Rebirth"]          = "rebirth_seed",
    ["Gift of the Wild"] = "gift_wild",
}

-- Spells that require per-rank reagent mapping.
local SPELL_RANK_REAGENTS = {
    ["Khadgar's Unlocking"] = {
        [1] = "khadgar_unlocking_r1",
        [2] = "khadgar_unlocking_r2",
        [3] = "khadgar_unlocking_r3",
        [4] = "khadgar_unlocking_r4",
    },
}

---------------------------------------------------------------------------
-- PREFIX matching for Turtle-WoW custom destinations
-- Any "Teleport: <anything>" or "Portal: <anything>" not already
-- in the exact table above will still show the correct reagent count.
---------------------------------------------------------------------------
local PREFIX_REAGENTS = {
    { prefix = "Teleport: ", group = "teleport_rune" },
    { prefix = "Portal: ",   group = "portal_rune"   },
}

---------------------------------------------------------------------------
-- Texture fallback table  (lowercase icon filename → group key)
-- Covers known Mage teleport/portal icons so detection still works
-- even if tooltip scanning fails for some reason.
---------------------------------------------------------------------------
local TEXTURE_REAGENTS = {}
local function addTex(list, group)
    for _, v in ipairs(list) do
        TEXTURE_REAGENTS[string.lower(v)] = group
    end
end
addTex({
    "Spell_Arcane_TeleportStormwind",
    "Spell_Arcane_TeleportIronForge",
    "Spell_Arcane_TeleportDarnassus",
    "Spell_Arcane_TeleportOrgrimmar",
    "Spell_Arcane_TeleportThunderBluff",
    "Spell_Arcane_TeleportUnderCity",
}, "teleport_rune")
addTex({
    "Spell_Arcane_PortalStormwind",
    "Spell_Arcane_PortalIronForge",
    "Spell_Arcane_PortalDarnassus",
    "Spell_Arcane_PortalOrgrimmar",
    "Spell_Arcane_PortalThunderBluff",
    "Spell_Arcane_PortalUnderCity",
}, "portal_rune")

---------------------------------------------------------------------------
-- Reagent count cache  (groupKey → integer)
---------------------------------------------------------------------------
local groupCounts = {}

local frame = CreateFrame("Frame", "ReagentDisplayFrame", UIParent)

-- Count a specific item across all bags (and keyring, if available)
local KEYRING_BAG_ID = KEYRING_CONTAINER or -2

local function GetContainerSlotCount(bag)
    -- Bagshui uses GetKeyRingSize for KEYRING_CONTAINER because keyring is special.
    if bag == KEYRING_BAG_ID and type(GetKeyRingSize) == "function" then
        local okKey, keySlots = pcall(GetKeyRingSize)
        if okKey and keySlots and keySlots > 0 then
            return keySlots
        end
    end

    local okBag, bagSlots = pcall(GetContainerNumSlots, bag)
    if okBag and bagSlots and bagSlots > 0 then
        return bagSlots
    end
    return 0
end

local function CountItemInContainer(bag, itemName)
    local count = 0
    local numSlots = GetContainerSlotCount(bag)
    if numSlots <= 0 then
        return 0
    end

    for slot = 1, numSlots do
        local link = GetContainerItemLink(bag, slot)
        if link then
            local _, _, name = string.find(link, "%[(.+)%]")
            if name and name == itemName then
                local _, itemCount = GetContainerItemInfo(bag, slot)
                count = count + (itemCount or 0)
            end
        end
    end
    return count
end

local function CountItem(itemName)
    local count = 0
    for bag = 0, 4 do
        count = count + CountItemInContainer(bag, itemName)
    end
    count = count + CountItemInContainer(KEYRING_BAG_ID, itemName)
    return count
end

-- Update all reagent group counts
local function UpdateAllReagentCounts()
    for key, items in pairs(REAGENT_GROUPS) do
        local total = 0
        for _, name in ipairs(items) do
            total = total + CountItem(name)
        end
        groupCounts[key] = total
    end
end

---------------------------------------------------------------------------
-- Hidden tooltip for spell-name scanning
-- SetOwner MUST be called before each SetAction for reliable results.
---------------------------------------------------------------------------
local scanTip = CreateFrame("GameTooltip", "RDScanTip", UIParent, "GameTooltipTemplate")

local function ParseRankNumber(rankText)
    if not rankText then return nil end
    local _, _, digits = string.find(rankText, "(%d+)")
    local n = tonumber(digits)
    return n
end

local function GetSpellNameAndRankForSlot(slot)
    if not HasAction(slot) then return nil end
    if GetActionText(slot) then return nil end          -- skip macros

    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:SetAction(slot)
    local line1 = getglobal("RDScanTipTextLeft1")
    local right1 = getglobal("RDScanTipTextRight1")
    local name = line1 and line1:GetText()
    -- Rank is usually on the right side ("Rank X"), not line 2.
    local rank = ParseRankNumber(right1 and right1:GetText())
    for i = 2, 8 do
        if rank then break end
        local left = getglobal("RDScanTipTextLeft" .. i)
        local right = getglobal("RDScanTipTextRight" .. i)
        local leftText = left and left:GetText()
        local rightText = right and right:GetText()
        rank = ParseRankNumber(leftText) or ParseRankNumber(rightText)
        if rank then break end
    end
    scanTip:Hide()
    return name, rank
end

local function GetRankMappedGroupFromTooltip(slot, rankMap)
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:SetAction(slot)

    for i = 2, 12 do
        local line = getglobal("RDScanTipTextLeft" .. i)
        local text = line and line:GetText()
        if text then
            for _, group in pairs(rankMap) do
                local items = REAGENT_GROUPS[group]
                if items then
                    for _, itemName in ipairs(items) do
                        if string.find(text, itemName, 1, true) then
                            scanTip:Hide()
                            return group
                        end
                    end
                end
            end
        end
    end

    scanTip:Hide()
    return nil
end

---------------------------------------------------------------------------
-- Resolve an action slot to a reagent-group key (or nil)
-- 1) tooltip spell-name + rank → per-rank match → exact match → prefix match
-- 2) fallback: icon texture match
---------------------------------------------------------------------------
local function GetGroupForSlot(slot)
    local spellName, spellRank = GetSpellNameAndRankForSlot(slot)
    if spellName then
        -- per-rank mapping
        local rankMap = SPELL_RANK_REAGENTS[spellName]
        if rankMap then
            if spellRank and rankMap[spellRank] then
                return rankMap[spellRank], spellName
            end
            -- Fallback: detect the reagent name directly from tooltip text.
            local tooltipGroup = GetRankMappedGroupFromTooltip(slot, rankMap)
            if tooltipGroup then
                return tooltipGroup, spellName
            end
        end
        -- exact match
        local g = SPELL_REAGENTS[spellName]
        if g then return g, spellName end
        -- prefix match (Turtle-WoW custom teleports/portals)
        for _, p in ipairs(PREFIX_REAGENTS) do
            if string.sub(spellName, 1, string.len(p.prefix)) == p.prefix then
                return p.group, spellName
            end
        end
    end
    -- texture fallback
    local texture = GetActionTexture(slot)
    if texture then
        local iconName = string.lower(texture)
        local _, _, short = string.find(iconName, "([^/\\]+)$")
        if short and TEXTURE_REAGENTS[short] then
            return TEXTURE_REAGENTS[short], (spellName or "?")
        end
    end
    return nil, spellName
end

---------------------------------------------------------------------------
-- Overlay creation – one per button, rendered above everything
---------------------------------------------------------------------------
local overlays = {}   -- button → { frame, text }

local function GetOrCreateOverlay(button)
    if overlays[button] then return overlays[button] end

    local of = CreateFrame("Frame", nil, button)
    of:SetAllPoints(button)
    of:SetFrameStrata("HIGH")
    of:SetFrameLevel(button:GetFrameLevel() + 10)

    local t = of:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    t:SetPoint("BOTTOMRIGHT", of, "BOTTOMRIGHT", -2, 2)
    t:SetJustifyH("RIGHT")

    overlays[button] = { frame = of, text = t }
    return overlays[button]
end

local function HideOverlay(button)
    local o = overlays[button]
    if o then o.text:Hide() end
end

---------------------------------------------------------------------------
-- Button configs – prefix, count, slot-getter
---------------------------------------------------------------------------
local BUTTON_CONFIGS = {
    { prefix = "ActionButton",              count = 12, getSlot = function(b) return ActionButton_GetPagedID(b) end },
    { prefix = "BonusActionButton",         count = 12, getSlot = function(b) return b:GetID()                  end },
    { prefix = "MultiBarBottomLeftButton",  count = 12, getSlot = function(b) return b:GetID() + 60             end },
    { prefix = "MultiBarBottomRightButton", count = 12, getSlot = function(b) return b:GetID() + 48             end },
    { prefix = "MultiBarRightButton",       count = 12, getSlot = function(b) return b:GetID() + 24             end },
    { prefix = "MultiBarLeftButton",        count = 12, getSlot = function(b) return b:GetID() + 36             end },
}

---------------------------------------------------------------------------
-- Main update – scan every visible action button
---------------------------------------------------------------------------
local function UpdateAllButtons()
    UpdateAllReagentCounts()

    for _, cfg in ipairs(BUTTON_CONFIGS) do
        for i = 1, cfg.count do
            local button = getglobal(cfg.prefix .. i)
            if button then
                if button:IsVisible() then
                    local slot = cfg.getSlot(button)
                    local group = slot and GetGroupForSlot(slot)
                    if group and groupCounts[group] then
                        local count = groupCounts[group]
                        local o = GetOrCreateOverlay(button)
                        o.text:SetText(tostring(count))
                        if count == 0 then
                            o.text:SetTextColor(1, 0.1, 0.1, 1)
                        else
                            o.text:SetTextColor(1, 1, 1, 1)
                        end
                        o.text:Show()
                        o.frame:Show()
                    else
                        HideOverlay(button)
                    end
                else
                    HideOverlay(button)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Throttled update via OnUpdate
---------------------------------------------------------------------------
local updateTimer    = 0
local UPDATE_INTERVAL = 0.5
local needsUpdate    = true

frame:SetScript("OnUpdate", function()
    updateTimer = updateTimer + arg1
    if updateTimer >= UPDATE_INTERVAL then
        updateTimer = 0
        if needsUpdate then
            needsUpdate = false
            UpdateAllButtons()
        end
    end
end)

local function RequestUpdate()
    needsUpdate = true
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
frame:RegisterEvent("ACTIONBAR_UPDATE_STATE")

frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        updateTimer = -2       -- delay first scan so all bars are loaded
    end
    RequestUpdate()
end)
