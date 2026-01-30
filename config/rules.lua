-- Ore → payout rules. Tune names/metas to your modpack items.
-- Each rule key is a human-readable label; matching is done by `nameContains` or exact `id`.
-- blockCost: how many ores to make one block. Remainder turns into ingots unless bonus triggers.
-- bonus.whenRemainder: if remainder equals this number, give bonus item once.
return {
  copper = {
    nameContains = "copper_ore",       -- substring match in item id
    block = { name = "modid:copper_block", damage = 0 },
    ingot = { name = "modid:copper_ingot", damage = 0 },
    blockCost = 2
  },
  lead = {
    nameContains = "lead_ore",
    block = { name = "modid:lead_block", damage = 0 },
    ingot = { name = "modid:lead_ingot", damage = 0 },
    blockCost = 2,
    bonus = { whenRemainder = 1, item = { name = "modid:platinum_ingot", damage = 0 } }
  },
  nickel = {
    nameContains = "nickel_ore",
    block = { name = "modid:nickel_block", damage = 0 },
    ingot = { name = "modid:nickel_ingot", damage = 0 },
    blockCost = 2,
    bonus = { whenRemainder = 1, item = { name = "modid:silver_ingot", damage = 0 } }
  }
}
