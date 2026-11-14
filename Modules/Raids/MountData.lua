-- Curated raid and dungeon mount drops. Raids are verified in the 12.1
-- client; dungeons are UNVERIFIED: run `/iv mounts check` in game, any item
-- it lists is wrong and is ignored.
--
-- Dungeons: legacy normal/heroic only. They have no lockout, so they are
-- shown without a per-character status. Mythic-only dungeon mounts (weekly
-- lockout) are not tracked yet.
--
-- instanceID: map ID (same as GetInstanceInfo / GetSavedInstanceInfo).
-- minutes: rough solo clear time to the mount boss (guess; used by Finder).
-- itemID: the mount item; the game resolves name and collected state.
-- boss: encounter name as sent by ENCOUNTER_END (English client).
-- dropChance: optional drop chance 0..1 (default 1%, Mounts.DEFAULT_DROP_CHANCE);
--   rough community figures, only used for the "drop luck" line.
-- difficulties: optional list of difficulty IDs that can drop it
--   (raids: 3 = 10N, 4 = 25N, 5 = 10H, 6 = 25H, 16 = Mythic;
--    dungeons: 1 = Normal, 2 = Heroic).
local _, ns = ...

local DUNGEON_HEROIC = 2
local LEGACY_10_NORMAL = 3
local LEGACY_25_NORMAL = 4
local LEGACY_25_HEROIC = 6
local MYTHIC = 16

ns.RaidMountData = {
  raids = {
    {
      instanceID = 532, name = "Karazhan", minutes = 15,
      mounts = { { itemID = 30480, boss = "Attumen the Huntsman" } },
    },
    {
      instanceID = 550, name = "Tempest Keep", minutes = 10,
      mounts = { { itemID = 32458, boss = "Kael'thas Sunstrider" } },
    },
    {
      instanceID = 249, name = "Onyxia's Lair", minutes = 3,
      mounts = { { itemID = 49636, boss = "Onyxia" } },
    },
    {
      instanceID = 616, name = "The Eye of Eternity", minutes = 3,
      mounts = {
        { itemID = 43952, boss = "Malygos" },
        { itemID = 43953, boss = "Malygos" },
      },
    },
    {
      instanceID = 615, name = "The Obsidian Sanctum", minutes = 3,
      mounts = {
        { itemID = 43986, boss = "Sartharion", difficulties = { LEGACY_10_NORMAL }, note = "3 drakes up", dropChance = 1 },
        { itemID = 43954, boss = "Sartharion", difficulties = { LEGACY_25_NORMAL }, note = "3 drakes up", dropChance = 1 },
      },
    },
    {
      instanceID = 603, name = "Ulduar", minutes = 25,
      mounts = { { itemID = 45693, boss = "Yogg-Saron", note = "no Keepers" } },
    },
    {
      instanceID = 631, name = "Icecrown Citadel", minutes = 20,
      mounts = { { itemID = 50818, boss = "The Lich King", difficulties = { LEGACY_25_HEROIC }, note = "25 Heroic" } },
    },
    {
      instanceID = 720, name = "Firelands", minutes = 10,
      mounts = {
        { itemID = 71665, boss = "Alysrazor" },
        { itemID = 69224, boss = "Ragnaros" },
      },
    },
    {
      instanceID = 967, name = "Dragon Soul", minutes = 15,
      mounts = {
        { itemID = 78919, boss = "Ultraxion" },
        { itemID = 77067, boss = "Madness of Deathwing" },
      },
    },
    {
      instanceID = 1008, name = "Mogu'shan Vaults", minutes = 10,
      mounts = { { itemID = 87777, boss = "Elegon" } },
    },
    {
      instanceID = 1098, name = "Throne of Thunder", minutes = 20,
      mounts = {
        { itemID = 93666, boss = "Horridon" },
        { itemID = 95059, boss = "Ji-Kun" },
      },
    },
    {
      instanceID = 1136, name = "Siege of Orgrimmar", minutes = 25,
      mounts = { { itemID = 104253, boss = "Garrosh Hellscream", difficulties = { MYTHIC }, note = "Mythic" } },
    },
    {
      instanceID = 1205, name = "Blackrock Foundry", minutes = 15,
      mounts = { { itemID = 116660, boss = "Blackhand", difficulties = { MYTHIC }, note = "Mythic" } },
    },
    {
      instanceID = 1448, name = "Hellfire Citadel", minutes = 20,
      mounts = { { itemID = 123890, boss = "Archimonde", difficulties = { MYTHIC }, note = "Mythic" } },
    },
    {
      instanceID = 1712, name = "Antorus, the Burning Throne", minutes = 20,
      mounts = { { itemID = 152789, boss = "Argus the Unmaker", difficulties = { MYTHIC }, note = "Mythic" } },
    },
  },
  dungeons = {
    {
      instanceID = 329, name = "Stratholme", minutes = 15,
      mounts = { { itemID = 13335, boss = "Lord Aurius Rivendare" } },
    },
    {
      instanceID = 556, name = "Sethekk Halls", minutes = 10,
      mounts = { { itemID = 32768, boss = "Anzu", difficulties = { DUNGEON_HEROIC }, note = "Heroic" } },
    },
    {
      instanceID = 575, name = "Utgarde Pinnacle", minutes = 10,
      mounts = { { itemID = 44151, boss = "Skadi the Ruthless", difficulties = { DUNGEON_HEROIC }, note = "Heroic" } },
    },
    {
      instanceID = 657, name = "The Vortex Pinnacle", minutes = 10,
      mounts = { { itemID = 63040, boss = "Altairus" } },
    },
    {
      instanceID = 725, name = "The Stonecore", minutes = 10,
      mounts = { { itemID = 63043, boss = "Slabhide" } },
    },
    {
      instanceID = 859, name = "Zul'Gurub", minutes = 15,
      mounts = {
        { itemID = 68823, boss = "Bloodlord Mandokir" },
        { itemID = 68824, boss = "High Priestess Kilnara" },
      },
    },
  },
}
