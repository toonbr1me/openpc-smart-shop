local sides = require("sides")

-- Addresses and block-facing sides. Replace placeholders with your world setup.
return {
  -- OC transposer that can see: buffer chest, processing ME Chest, output chest, trash chest.
  transposer = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",  -- component address

  -- Inventory sides on the transposer
  bufferSide = sides.north,      -- chest players access
  processChestSide = sides.east, -- ME Chest that holds the portable cell while processing
  dropSide = sides.west,         -- chest/dropper where finished cell is returned

  -- AE2 interfaces (component type: me_interface). These must be touchable by an OC adapter.
  processingInterface = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy", -- network that only sees the user cell (ME Chest/Drive)
  mainInterface = "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz",      -- main base network for paying out blocks/ingots

  -- Facing directions of each interface
  processingTrashSide = sides.top,   -- side of processingInterface pointing to a trash buffer (void/dust bin)
  mainOutputSide = sides.south,      -- side of mainInterface pointing to the fill chest

  -- Shared fill chest: main network exports here; processing network must have an Import Bus on it
  fillChestSideOnTransposer = sides.south,

  logPath = "/var/log/exchanger.log"
}
