-- [Outland] Issue #1: Set Global Spawn Point & Disable Cinematics

-- Set all player starting locations to a single point in Hellfire Peninsula
UPDATE `playercreateinfo`
SET
    `map` = 530,           -- Map: Outland
    `zone` = 3483,         -- Zone: Hellfire Peninsula
    `position_x` = -248.468,
    `position_y` = 939.677,
    `position_z` = 84.3798,
    `orientation` = 1.57862;