UPDATE `customs`.`gv_upgrade_catalog`
SET `label_en` = 'Profession: Cooking'
WHERE `expansion_key` = 'prof_cooking';

UPDATE `customs`.`gv_upgrade_catalog`
SET `info_en` = 'Adds a teleport pad and unlocks the expedition base.'
WHERE `expansion_key` = 'teleporter';

UPDATE `customs`.`gv_upgrade_catalog`
SET `label_en` = 'Indoor Lamps'
WHERE `expansion_key` = 'indoor_lamp';

UPDATE `customs`.`gv_upgrade_catalog`
SET `info_cs` = 'Spawnuje NPC, které vyrábí materiál pro vaši vesnici.'
WHERE `expansion_key` = 'material_production';

UPDATE `customs`.`gv_upgrade_catalog`
SET `info_cs` = 'Přidává teleport do tábora s expedicí. Umožní posílat hrdiny na výpravy.'
WHERE `expansion_key` = 'expedition';

UPDATE `customs`.`gv_upgrade_poi`
SET `name_en` = 'Profession: Inscription'
WHERE `expansion_key` = 'prof_inscription';