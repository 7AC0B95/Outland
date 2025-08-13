-- [Outland] Hunger System: Famished debuff spell (ID 90001)
-- Effect: -25% Health Regen, -25% Mana Regen

SET @SPELL_ID := 90001;

DELETE FROM `spell_dbc` WHERE `ID` = @SPELL_ID;

INSERT INTO `spell_dbc` (
  `ID`,
  `Attributes`,
  `CastingTimeIndex`,
  `RangeIndex`,
  `DurationIndex`,
  `SpellIconID`,
  `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `EffectMiscValue_1`, `EffectMiscValueB_1`,
  `Effect_2`, `EffectBasePoints_2`, `EffectAura_2`, `EffectMiscValue_2`, `EffectMiscValueB_2`,
  `Name_Lang_enUS`,
  `Description_Lang_enUS`,
  `AuraDescription_Lang_enUS`
) VALUES (
  @SPELL_ID,
  0,
  1,   -- instant
  1,   -- self
  0,   -- no duration (persistent while aura is present)
  1,
  6,  -26, 88, 0, 0,   -- Effect 1: Apply Aura, BasePoints -26 -> amount -25, Aura = SPELL_AURA_MOD_HEALTH_REGEN_PERCENT
  6,  -26, 110, 0, 0,  -- Effect 2: Apply Aura, BasePoints -26 -> amount -25, Aura = SPELL_AURA_MOD_POWER_REGEN_PERCENT (MiscValue POWER_MANA=0)
  'Famished',
  'Your body is conserving energy due to lack of food. Health and mana regenerate 25% slower.',
  'Health and mana regenerate 25% slower.'
);



