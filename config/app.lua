local sides = require("sides")

-- General runtime settings for the exchanger daemon.
return {
  pollSeconds = 2,           -- How often to check the buffer chest for a portable cell.
  waitAfterMoveSeconds = 1,  -- Delay after moving the cell so AE2 can notice it.
  requireFullPayout = true,  -- If true, skip the exchange when main ME lacks outputs.
  maxItemsPerCycle = 640,    -- Safety cap to avoid processing absurdly large batches.
  bufferSlot = 1             -- Slot in the buffer chest expected to hold the cell.
}
