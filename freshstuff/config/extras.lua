--[[
FreshStuff3 v5 'extras' module configuration file
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]
-- This is the maximum age of the item (in days).
-- After this, release pruning will delete it.
-- Pruning is always manual and releases get backed up when run.
MaxItemAge = 30

-- The number of top-adders to show wehen the command is issued.
TopAddersCount = 5

--[[
Enter the specific commands, DO NOT INCLUDE THE PREFIX!
For levels you give a number: 0-5. The numbers mean:

0: command is disabled
1: command is available to everyone
2: command is available to regs & above
3: command is available to vips & above
4: command is available to operators & above
5: command is available to masters only
]]


-- Pruning releases (removing old entries)
Commands.Prune="prunerel"
Levels.Prune=5

 -- Showing top adders
Commands.TopAdders="topadders"
Levels.TopAdders=1