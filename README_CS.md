# mod-guild-village 

### 🇬🇧 [English version](README_EN.md)

## Popis (CZ)  
Tento modul umožňuje:  
- Vytvořit guildovní vesnici  
- Přidávat creature a gameobjecty  
- Vlastní měnu pro nákup rozšíření vesnice 
- Jednoduchá správa všech nastavení
- Nastavitelný limit pro vesnice, možnost nastavit automatické čištění při neaktivitě Guild Mastera
- Denní a týdenní úkoly pro guildu

### Instalace / Požadavky  
Pro správnou funkčnost autoupdateru je nutné zajistit, aby uživatel databáze z `(WorldDatabaseInfo) – "127.0.0.1;3306;acore;acore;acore_world"`  
měl práva i na novou databázi customs:
 
```
GRANT CREATE ON *.* TO 'acore'@'127.0.0.1';
GRANT ALL PRIVILEGES ON customs.* TO 'acore'@'127.0.0.1';
FLUSH PRIVILEGES;
```

# ⚠️ POZOR: DŮLEŽITÁ ZMĚNA VE STRUKTUŘE DB ⚠️
> **Platí pouze pro ty, kteří si stáhli modul před datem 27. 11. 2025**

- Poslední update se nachází v customs/archive/updates/014_important_update.sql  
Nezapomeňte aplikovat také všechny předchozí updaty, pokud jste je vynechali.  
- Po aplikaci updatu 014_important_update.sql se bude modul bude aktualizovat automaticky při spuštění serveru.

**Volitelné:**
- Přidejte do worldserver.conf tento řádek:  
  Logger.gv.customs=3,Console Server

##

### ⚠️ Upozornění
Modul používá vlastní **entry** v tabulkách `gameobject_template`, `creature_template`, `creature_template_model`, `game_graveyard`, `graveyard_zone`, `fishing_loot_template`, `points_of_interest`.  
Je nutné zajistit, že tato ID nejsou v `acore_world` již obsazená jiným obsahem:

- **Vlastní gameobject (`gameobject_template.entry`):**
  - `990203`,`990204`

- **Vlastní creatures (`creature_template.entry`):**
  - `987400`-`987430`, `987440`-`987454`

- **Vlastní PoI (`points_of_interest.Entry`):**
  - `1200`-`1250`
 
- **Vlastní Graveyard (`game_graveyard.Entry`):**
  - `2000`
  
Pokud máš v databázi již jiné záznamy s těmito ID, je potřeba čísla v modulu i v SQL posunout na jiný volný rozsah.

Odebrán SmartAI pro cooking trenéra a riding trenéra (pouze pohyb).

**Poznámky:**
- Modul používá vlastní DB `customs` v tabulkách je dodatečná správa vesnice
- gv_gameobject_template - Pokud chcete aby bylo něco vygenerováno ještě před vytvořením vesnice tak stačí přidat záznam zde. Pozor tato tabulka se aplikuje pouze jednou při zakoupení vesnice.
- gv_creature_template - Pokud chcete aby bylo něco vygenerováno ještě před vytvořením vesnice tak stačí přidat záznam zde. Pozor tato tabulka se aplikuje pouze jednou při zakoupení vesnice.

## Databázové tabulky a jejich popis
[Wikipedia](https://github.com/BeardBear33/mod-guild-village/wiki/%5BCZ%5D-Dokumentace)


