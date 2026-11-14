-- Minimal fake of the WoW client API, enough to drive the addon from tests.
-- install() sets globals and returns an `env` used to fire events and inspect
-- side effects; uninstall() restores whatever globals existed before.
local Wow = {}

local STUBBED_GLOBALS = {
  "CreateFrame", "UIParent", "print", "geterrorhandler", "SlashCmdList",
  "SLASH_INTROVERT1", "SLASH_INTROVERT2", "IntroVertDB",
  "IsInInstance", "GetInstanceInfo", "IsPartyLFG", "UnitName",
  "UnitGroupRolesAssigned", "Ambiguate", "C_ChatInfo", "C_Timer",
  "C_PartyInfo", "GetTime", "PlaySound", "SOUNDKIT", "FlashClientIcon",
  "RaidNotice_AddMessage", "RaidWarningFrame", "ChatTypeInfo",
  "ChatFrame_AddMessageEventFilter", "issecretvalue", "date",
  "LE_PARTY_CATEGORY_INSTANCE",
  "Settings", "CreateSettingsListSectionHeaderInitializer",
  "CreateSettingsButtonInitializer", "MinimalSliderWithSteppersMixin",
  "StaticPopupDialogs", "StaticPopup_Show", "InCombatLockdown", "ACCEPT", "CANCEL",
  "GetNumSavedInstances", "GetSavedInstanceInfo", "RequestRaidInfo", "GetRealmName", "time",
  "C_MountJournal", "C_Item", "UISpecialFrames",
  "Enum", "C_WeeklyRewards", "C_Map", "C_AreaPoiInfo",
  "GetCategoryList", "GetCategoryInfo", "GetCategoryNumAchievements", "GetAchievementInfo",
  "GetAchievementNumCriteria", "GetAchievementCriteriaInfo",
  "C_Scenario", "C_UIWidgetManager",
  "DeclineGuild", "CancelDuel", "DeclineGroup", "C_PetBattles", "StaticPopup_Hide",
  "C_FriendList", "C_BattleNet",
  "GetAverageItemLevel", "UnitLevel", "GetMoney", "C_DateAndTime", "GameTooltip",
  "IntroVert_OnAddonCompartmentClick", "IntroVert_OnAddonCompartmentEnter",
  "IntroVert_OnAddonCompartmentLeave", "Minimap", "GetCursorPosition",
  "UnitRace", "UnitClass", "RAID_CLASS_COLORS", "LOCALIZED_CLASS_NAMES_MALE",
  "UnitIsAFK", "BNSendWhisper",
}

-- Unknown UI methods (SetBackdrop, SetMovable, ...) are accepted and ignored.
local function noop() end
local IGNORE_UNKNOWN = { __index = function() return noop end }

local function newFontString()
  local fontString = {}
  function fontString:SetText(text) self.text = text end
  function fontString:GetText() return self.text end
  function fontString:GetStringHeight() return 100 end
  return setmetatable(fontString, IGNORE_UNKNOWN)
end

local saved = {}

local function newEnv()
  return {
    eventFrames = {}, sent = {}, sounds = {}, notices = {}, prints = {},
    timers = {}, filters = {}, errors = {}, buttons = {}, flashes = 0, leaves = 0,
    instance = { inInstance = false, instanceType = "none", difficultyID = 0 },
    isLFG = false, playerName = "Nubbel", role = "DAMAGER", now = 100,
    secret = false, inCombat = false, afk = false, sendFails = false, bnSent = {},
    realm = "Silvermoon", time = 1000000, savedInstances = {}, raidInfoRequests = 0,
    mounts = {}, uncachedItems = {}, itemLoadRequests = {},
    vault = {}, zones = {}, delvePois = {},
    achievementCategories = {}, achievementScans = 0,
    scenarioWidgetSet = 0, widgets = {}, widgetTiers = {},
    declines = {}, hiddenPopups = {}, friends = {}, bnetFriends = {},
    itemLevel = 0, money = 0, level = 1, secondsUntilReset = 86400, vaultRewards = false,
    tooltip = { lines = {}, shown = false }, cursorX = 0, cursorY = 0,
    settings = { categories = {}, controls = {}, initializers = {}, byVariable = {} },
  }
end

local function newFrame(env, kind)
  local frame = { scripts = {}, shown = true, kind = kind }
  function frame:RegisterEvent(event) env.eventFrames[event] = self end
  function frame:SetScript(name, fn) self.scripts[name] = fn end
  function frame:SetSize() end
  function frame:SetPoint(...) self.point = { ... } end
  function frame:CreateTexture() return newFontString() end
  function frame:SetText(text) self.text = text end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:IsShown() return self.shown end
  function frame:Click() self.scripts.OnClick(self) end
  frame.enabled = true
  function frame:Enable() self.enabled = true end
  function frame:Disable() self.enabled = false end
  frame.highlightLocked = false
  function frame:LockHighlight() self.highlightLocked = true end
  function frame:UnlockHighlight() self.highlightLocked = false end
  function frame:CreateFontString() return newFontString() end
  if kind == "Button" then
    env.buttons[#env.buttons + 1] = frame
  end
  return setmetatable(frame, IGNORE_UNKNOWN)
end

local function installUi(env)
  _G.CreateFrame = function(kind, name, parent)
    local frame = newFrame(env, kind)
    frame.name, frame.parent = name, parent
    return frame
  end
  _G.UIParent = newFrame(env, "Frame")
  _G.Minimap = newFrame(env, "Frame")
  function Minimap:GetCenter() return 100, 100 end
  function Minimap:GetWidth() return 140 end
  function Minimap:GetEffectiveScale() return 1 end
  _G.GetCursorPosition = function() return env.cursorX, env.cursorY end
  _G.print = function(message) env.prints[#env.prints + 1] = message end
  _G.geterrorhandler = function()
    return function(err) env.errors[#env.errors + 1] = err end
  end
  _G.SlashCmdList = {}
  _G.PlaySound = function(id, channel) env.sounds[#env.sounds + 1] = { id = id, channel = channel } end
  _G.SOUNDKIT = { READY_CHECK = 8960 }
  _G.FlashClientIcon = function() env.flashes = env.flashes + 1 end
  _G.RaidWarningFrame = {}
  _G.ChatTypeInfo = { RAID_WARNING = {} }
  _G.RaidNotice_AddMessage = function(_, text) env.notices[#env.notices + 1] = text end
  _G.date = os.date
  _G.UISpecialFrames = {}
end

local function installGame(env)
  _G.IsInInstance = function() return env.instance.inInstance, env.instance.instanceType end
  _G.GetInstanceInfo = function()
    return env.instance.name or "Test", env.instance.instanceType, env.instance.difficultyID,
      env.instance.difficultyName or "Difficulty", 10, 0, false, env.instance.instanceID
  end
  _G.Enum = {
    WeeklyRewardChestThresholdType = { Activities = 1, Raid = 3, World = 6 },
    UIMapType = { Zone = 3 },
  }
  _G.GetAverageItemLevel = function() return env.itemLevel, env.itemLevel, env.itemLevel end
  _G.UnitLevel = function() return env.level end
  _G.UnitRace = function() return "Dwarf", "Dwarf", 3 end
  _G.UnitClass = function() return "Rogue", "ROGUE", 4 end
  _G.RAID_CLASS_COLORS = { ROGUE = { colorStr = "fffff468" }, WARLOCK = { colorStr = "ff8788ee" } }
  _G.LOCALIZED_CLASS_NAMES_MALE = { ROGUE = "Rogue", WARLOCK = "Warlock" }
  _G.GetMoney = function() return env.money end
  _G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return env.secondsUntilReset end }
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, text) env.tooltip.lines = { text } end,
    AddLine = function(_, text) table.insert(env.tooltip.lines, text) end,
    Show = function() env.tooltip.shown = true end,
    Hide = function() env.tooltip.shown = false end,
  }
  -- Widget set ID is the 12th return of GetStepInfo (verified in the 12.1 client).
  _G.C_Scenario = {
    GetStepInfo = function()
      return "Stage", "", 1, false, false, false, false, {}, 0, 0, 0, env.scenarioWidgetSet
    end,
  }
  -- env.widgets: setID -> { widgetID, ... }; env.widgetTiers: widgetID -> tierText
  _G.C_UIWidgetManager = {
    GetAllWidgetsBySetID = function(setID)
      local list = {}
      for index, widgetID in ipairs(env.widgets[setID] or {}) do
        list[index] = { widgetID = widgetID, widgetType = 0 }
      end
      return list
    end,
    GetScenarioHeaderDelvesWidgetVisualizationInfo = function(widgetID)
      local tierText = env.widgetTiers[widgetID]
      return tierText and { tierText = tierText } or nil
    end,
  }
  _G.C_WeeklyRewards = {
    GetActivities = function() return env.vault end,
    HasAvailableRewards = function() return env.vaultRewards end,
  }
  -- env.zones: { { mapID, name } }; env.delvePois: mapID -> { { poiID, name, atlasName } }
  _G.C_Map = { GetMapChildrenInfo = function() return env.zones end }
  _G.C_AreaPoiInfo = {
    GetDelvesForMap = function(mapID)
      local ids = {}
      for _, poi in ipairs(env.delvePois[mapID] or {}) do
        ids[#ids + 1] = poi.poiID
      end
      return ids
    end,
    GetAreaPOIInfo = function(mapID, poiID)
      for _, poi in ipairs(env.delvePois[mapID] or {}) do
        if poi.poiID == poiID then
          return { name = poi.name, atlasName = poi.atlasName }
        end
      end
    end,
  }
  _G.C_Item = {
    IsItemDataCachedByID = function(itemID) return not env.uncachedItems[itemID] end,
    RequestLoadItemDataByID = function(itemID) env.itemLoadRequests[itemID] = true end,
  }
  -- env.mounts: itemID -> { mountID, name, collected }
  _G.C_MountJournal = {
    GetMountFromItem = function(itemID)
      local mount = env.mounts[itemID]
      return mount and mount.mountID
    end,
    GetMountInfoByID = function(mountID)
      for _, mount in pairs(env.mounts) do
        if mount.mountID == mountID then
          return mount.name, 0, 0, false, true, 0, false, false, nil, false, mount.collected, mountID
        end
      end
    end,
  }
  _G.IsPartyLFG = function() return env.isLFG end
  _G.UnitName = function() return env.playerName end
  _G.UnitGroupRolesAssigned = function() return env.role end
  _G.Ambiguate = function(name) return (name:gsub("%-.*$", "")) end
  _G.GetTime = function() return env.now end
  _G.issecretvalue = function() return env.secret end
  _G.C_ChatInfo = {
    SendChatMessage = function(text, channel, _, target)
      assert(not env.sendFails, "sending blocked")
      env.sent[#env.sent + 1] = { text = text, channel = channel, target = target }
    end,
  }
  _G.UnitIsAFK = function() return env.afk end
  _G.BNSendWhisper = function(id, text) env.bnSent[#env.bnSent + 1] = { id = id, text = text } end
  local function countDecline(kind)
    return function() env.declines[kind] = (env.declines[kind] or 0) + 1 end
  end
  _G.DeclineGuild = countDecline("guild")
  _G.CancelDuel = countDecline("duel")
  _G.DeclineGroup = countDecline("group")
  _G.C_PetBattles = { CancelPVPDuel = countDecline("petDuel") }
  _G.StaticPopup_Hide = function(which) env.hiddenPopups[#env.hiddenPopups + 1] = which end
  _G.C_FriendList = { IsFriend = function(guid) return env.friends[guid] == true end }
  _G.C_BattleNet = {
    GetAccountInfoByGUID = function(guid) return env.bnetFriends[guid] and {} or nil end,
  }
  _G.C_Timer = { After = function(_, fn) env.timers[#env.timers + 1] = fn end }
  _G.LE_PARTY_CATEGORY_INSTANCE = 2
  _G.C_PartyInfo = {
    LeaveParty = function(category)
      env.leaves = env.leaves + 1
      env.leftCategory = category
    end,
  }
  _G.GetRealmName = function() return env.realm end
  _G.time = function() return env.time end
  _G.RequestRaidInfo = function() env.raidInfoRequests = env.raidInfoRequests + 1 end
  _G.GetNumSavedInstances = function() return #env.savedInstances end
  -- Same return order as the real API (14 values).
  _G.GetSavedInstanceInfo = function(index)
    local e = env.savedInstances[index]
    return e.name, index, e.reset, e.difficultyID, e.locked, e.extended, 0,
      e.isRaid, 10, e.difficultyName, e.numEncounters, e.encounterProgress, false, e.instanceID
  end
  _G.ChatFrame_AddMessageEventFilter = function(event, fn)
    env.filters[event] = env.filters[event] or {}
    table.insert(env.filters[event], fn)
  end
end

local function newCategory(env, name)
  local category = { name = name, id = "category-" .. name }
  function category:GetID() return self.id end
  return category
end

local function addControl(env, kind, setting, options, tooltip)
  local entry = { kind = kind, setting = setting, options = options, tooltip = tooltip }
  env.settings.controls[#env.settings.controls + 1] = entry
  return entry
end

local function newProxySetting(env, variable, varType, name, default, getValue, setValue)
  local setting = { variable = variable, varType = varType, name = name, default = default }
  function setting:GetValue() return getValue() end
  function setting:SetValue(value) setValue(value) end
  env.settings.byVariable[variable] = setting
  return setting
end

local function installSettings(env)
  local layout = {}
  function layout:AddInitializer(init) table.insert(env.settings.initializers, init) end

  _G.Settings = {
    VarType = { Boolean = "boolean", String = "string", Number = "number" },
    RegisterVerticalLayoutCategory = function(name) return newCategory(env, name), layout end,
    RegisterAddOnCategory = function(category) table.insert(env.settings.categories, category) end,
    RegisterProxySetting = function(_, variable, varType, name, default, getValue, setValue)
      return newProxySetting(env, variable, varType, name, default, getValue, setValue)
    end,
    CreateCheckbox = function(_, setting, tooltip) return addControl(env, "checkbox", setting, nil, tooltip) end,
    CreateDropdown = function(_, setting, options, tooltip) return addControl(env, "dropdown", setting, options, tooltip) end,
    CreateSlider = function(_, setting, options, tooltip) return addControl(env, "slider", setting, options, tooltip) end,
    CreateSliderOptions = function(min, max, step)
      return { min = min, max = max, step = step, SetLabelFormatter = function() end }
    end,
    CreateControlTextContainer = function()
      local data = {}
      return {
        Add = function(_, value, label) data[#data + 1] = { value = value, label = label } end,
        GetData = function() return data end,
      }
    end,
    OpenToCategory = function(id) env.settings.opened = id end,
  }
  _G.CreateSettingsListSectionHeaderInitializer = function(text) return { kind = "header", text = text } end
  _G.CreateSettingsButtonInitializer = function(name, buttonText, onClick, tooltip)
    return { kind = "button", name = name, buttonText = buttonText, onClick = onClick, tooltip = tooltip }
  end
  _G.MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
  _G.InCombatLockdown = function() return env.inCombat end
end

local function newPopup()
  local popup = { shown = true }
  local editBox = { text = "" }
  function editBox:SetText(text) self.text = text end
  function editBox:GetText() return self.text end
  function editBox:HighlightText() end
  function editBox:GetParent() return popup end
  function popup:Hide() self.shown = false end
  popup.EditBox = editBox
  popup.editBox = editBox
  return popup
end

local function installPopups(env)
  _G.ACCEPT, _G.CANCEL = "Accept", "Cancel"
  _G.StaticPopupDialogs = {}
  _G.StaticPopup_Show = function(which, textArg, _, data)
    local dialog = _G.StaticPopupDialogs[which]
    local popup = newPopup()
    popup.which, popup.textArg, popup.data, popup.dialog = which, textArg, data, dialog
    env.popup = popup
    dialog.OnShow(popup, data)
    return popup
  end

  function env.acceptPopup(text)
    env.popup.editBox:SetText(text)
    env.popup.dialog.OnAccept(env.popup, env.popup.data)
    env.popup:Hide()
  end

  function env.enterPopup(text)
    env.popup.editBox:SetText(text)
    env.popup.dialog.EditBoxOnEnterPressed(env.popup.editBox, env.popup.data)
  end

  function env.escapePopup()
    env.popup.dialog.EditBoxOnEscapePressed(env.popup.editBox, env.popup.data)
  end
end

-- env.achievementCategories: { { id, title, parent, achievements = {
--   { id, name, points, completed, reward, isGuild, criteria = { { completed, quantity, required } } } } } }
local function installAchievements(env)
  local function category(id)
    for _, entry in ipairs(env.achievementCategories) do
      if entry.id == id then
        return entry
      end
    end
  end
  local function achievementByID(id)
    for _, entry in ipairs(env.achievementCategories) do
      for _, achievement in ipairs(entry.achievements) do
        if achievement.id == id then
          return achievement
        end
      end
    end
  end

  _G.GetCategoryList = function()
    env.achievementScans = env.achievementScans + 1
    local ids = {}
    for index, entry in ipairs(env.achievementCategories) do
      ids[index] = entry.id
    end
    return ids
  end
  _G.GetCategoryInfo = function(id)
    local entry = category(id)
    return entry.title, entry.parent, 0
  end
  _G.GetCategoryNumAchievements = function(id) return #category(id).achievements end
  -- Same return order as the real API (15 values).
  -- Like the real API: (categoryID, index) or just (achievementID).
  _G.GetAchievementInfo = function(categoryID, index)
    local a = index and category(categoryID).achievements[index] or achievementByID(categoryID)
    return a.id, a.name, a.points, a.completed, 0, 0, 0, "", 0, 0, a.reward, a.isGuild, false, nil, false
  end
  _G.GetAchievementNumCriteria = function(id) return #achievementByID(id).criteria end
  _G.GetAchievementCriteriaInfo = function(id, index)
    local c = achievementByID(id).criteria[index]
    return "criterion", 0, c.completed, c.quantity, c.required
  end
end

local function addHelpers(env)
  function env.fire(event, ...)
    local frame = assert(env.eventFrames[event], "no handler registered for " .. event)
    frame.scripts.OnEvent(frame, event, ...)
  end

  function env.runTimers()
    local pending = env.timers
    env.timers = {}
    for _, fn in ipairs(pending) do fn() end
  end

  -- Simulates one chat line delivered to `frames` chat windows.
  -- Returns true when any filter hid it.
  function env.chat(event, text, author, lineID, frames)
    local hidden = false
    for _ = 1, frames or 1 do
      for _, fn in ipairs(env.filters[event] or {}) do
        hidden = fn({}, event, text, author, "", "", "", "", 0, 0, "", 0, lineID) or hidden
      end
    end
    return hidden
  end

  function env.slash(input)
    _G.SlashCmdList.INTROVERT(input)
  end

  function env.lastPrint()
    return env.prints[#env.prints]
  end

  -- The created Button frame with this global name, or nil.
  function env.buttonNamed(name)
    for _, button in ipairs(env.buttons) do
      if button.name == name then
        return button
      end
    end
    return nil
  end

  -- True when any printed line contains `text` (plain match, not a pattern).
  function env.printed(text)
    for _, line in ipairs(env.prints) do
      if line:find(text, 1, true) then
        return true
      end
    end
    return false
  end
end

function Wow.install()
  for _, name in ipairs(STUBBED_GLOBALS) do
    saved[name] = { value = _G[name] }
  end
  local env = newEnv()
  installUi(env)
  installGame(env)
  installSettings(env)
  installPopups(env)
  installAchievements(env)
  addHelpers(env)
  return env
end

function Wow.uninstall()
  for _, name in ipairs(STUBBED_GLOBALS) do
    _G[name] = saved[name] and saved[name].value
  end
  saved = {}
end

-- Loads every file listed in the .toc, in order, into a fresh namespace.
function Wow.loadAddon(helper)
  local ns = {}
  for line in io.lines("IntroVert.toc") do
    local path = line:match("^%s*([^#%s].-)%s*$")
    if path then
      helper.load(path, ns)
    end
  end
  return ns
end

return Wow
