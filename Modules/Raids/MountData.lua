-- Curated raid mount drops. UNVERIFIED in the 12.1 client: run
-- `/iv mounts check` in game; any item it lists is wrong and is ignored.
--
-- instanceID: map ID (same as GetInstanceInfo / GetSavedInstanceInfo).
-- itemID: the mount item; the game resolves name and collected state.
-- boss: encounter name as sent by ENCOUNTER_END (English client).
-- difficulties: optional list of difficulty IDs that can drop it
--   (3 = 10N, 4 = 25N, 5 = 10H, 6 = 25H, 16 = Mythic).
local _, ns = ...

local LEGACY_10_NORMAL = 3
local LEGACY_25_NORMAL = 4
local LEGACY_25_HEROIC = 6
local MYTHIC = 16

ns.RaidMountData = {
  raids = {
    {
      instanceID = 532, name = "Karazhan",
      mounts = { { itemID = 30480, boss = "Attumen the Huntsman" } },
    },
    {
      instanceID = 550, name = "Tempest Keep",
      mounts = { { itemID = 32458, boss = "Kael'thas Sunstrider" } },
    },
    {
      instanceID = 249, name = "Onyxia's Lair",
      mounts = { { itemID = 49636, boss = "Onyxia" } },
    },
    {
      instanceID = 616, name = "The Eye of Eternity",
      mounts = {
        { itemID = 43952, boss = "Malygos" },
        { itemID = 43953, boss = "Malygos" },
      },
    },
    {
      instanceID = 615, name = "The Obsidian Sanctum",
      mounts = {
        { itemID = 43986, boss = "Sartharion", difficulties = { LEGACY_10_NORMAL }, note = "3 drakes up" },
        { itemID = 43954, boss = "Sartharion", difficulties = { LEGACY_25_NORMAL }, note = "3 drakes up" },
      },
    },
    {
      instanceID = 603, name = "Ulduar",
      mounts = { { itemID = 45693, boss = "Yogg-Saron", note = "no Keepers" } },
    },
    {
      instanceID = 631, name = "Icecrown Citadel",
      mounts = { { itemID = 50818, boss = "The Lich King", difficulties = { LEGACY_25_HEROIC }, note = "25 Heroic" } },
    },
    {
      instanceID = 720, name = "Firelands",
      mounts = {
        { itemID = 71665, boss = "Alysrazor" },
        { itemID = 69224, boss = "Ragnaros" },
      },
    },
    {
      instanceID = 967, name = "Dragon Soul",
      mounts = {
        { itemID = 78919, boss = "Ultraxion" },
        { itemID = 77067, boss = "Madness of Deathwing" },
      },
    },
    {
      instanceID = 1008, name = "Mogu'shan Vaults",
      mounts = { { itemID = 87777, boss = "Elegon" } },
    },
    {
      instanceID = 1098, name = "Throne of Thunder",
      mounts = {
        { itemID = 93666, boss = "Horridon" },
        { itemID = 95059, boss = "Ji-Kun" },
      },
    },
    {
      instanceID = 1136, name = "Siege of Orgrimmar",
      mounts = { { itemID = 104253, boss = "Garrosh Hellscream", difficulties = { MYTHIC }, note = "Mythic" } },
    },
    {
      instanceID = 1205, name = "Blackrock Foundry",
      mounts = { { itemID = 116660, boss = "Blackhand", difficulties = { MYTHIC }, note = "Mythic" } },
    },
    {
      instanceID = 1448, name = "Hellfire Citadel",
      mounts = { { itemID = 123890, boss = "Archimonde", difficulties = { MYTHIC }, note = "Mythic" } },
    },
    {
      instanceID = 1712, name = "Antorus, the Burning Throne",
      mounts = { { itemID = 152789, boss = "Argus the Unmaker", difficulties = { MYTHIC }, note = "Mythic" } },
    },
  },
}
