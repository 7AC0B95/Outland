-- [Outland] Issue #3: Clean World Spawns
-- Description: Removes all default creature and gameobject spawns from the world,
-- and severs all links between entities and quests to create a blank slate.

-- Empty all creature spawn data. This will remove every NPC from the world.
TRUNCATE TABLE `creature`;

-- Empty all gameobject spawn data. This removes all chests, doors, chairs, etc.
TRUNCATE TABLE `gameobject`;

-- Remove all links that make a creature start a quest.
TRUNCATE TABLE `creature_queststarter`;

-- Remove all links that make a creature end a quest.
TRUNCATE TABLE `creature_questender`;

-- Remove all links that make an object start a quest.
TRUNCATE TABLE `gameobject_queststarter`;

-- Remove all links that make an object end a quest.
TRUNCATE TABLE `gameobject_questender`;

-- This table holds waypoints for creatures. Since there are no creatures, we clear this.
TRUNCATE TABLE `waypoint_data`;