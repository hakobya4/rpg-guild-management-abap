CLASS zcl_rpg_cleanup DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_rpg_cleanup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    TYPES: BEGIN OF ty_seed,
             item_name      TYPE zrpg_loot_items-item_name,
             item_type      TYPE zrpg_loot_items-item_type,
             item_subtype   TYPE zrpg_loot_items-item_subtype,
             item_rarity         TYPE zrpg_loot_items-item_rarity,
             description    TYPE zrpg_loot_items-description,
             required_level TYPE zrpg_loot_items-required_level,
             str_bonus      TYPE zrpg_loot_items-str_bonus,
             dex_bonus      TYPE zrpg_loot_items-dex_bonus,
             con_bonus      TYPE zrpg_loot_items-con_bonus,
             int_bonus      TYPE zrpg_loot_items-int_bonus,
             wis_bonus      TYPE zrpg_loot_items-wis_bonus,
             cha_bonus      TYPE zrpg_loot_items-cha_bonus,
             price          TYPE zrpg_loot_items-price,
           END OF ty_seed.
    TYPES tt_seed TYPE STANDARD TABLE OF ty_seed WITH EMPTY KEY.

    DATA(lt_seed) = VALUE tt_seed(

      " ── WEAPON / LONGSWORD ──
      ( item_name = 'Rusty Longsword'        item_type = 'WEAPON' item_subtype = 'LONGSWORD'
        item_rarity = 'COMMON'    description = 'A worn blade, better than nothing.'
        required_level = 1  str_bonus = 1                price = 15 )
      ( item_name = 'Steel Longsword'        item_type = 'WEAPON' item_subtype = 'LONGSWORD'
        item_rarity = 'UNCOMMON'  description = 'Well-balanced and freshly sharpened.'
        required_level = 4  str_bonus = 2                price = 60 )
      ( item_name = 'Flametongue Longsword'  item_type = 'WEAPON' item_subtype = 'LONGSWORD'
        item_rarity = 'RARE'      description = 'The blade smolders faintly, never cooling.'
        required_level = 8  str_bonus = 3 int_bonus = 1  price = 200 )
      ( item_name = |Excalibur's Shard|      item_type = 'WEAPON' item_subtype = 'LONGSWORD'
        item_rarity = 'LEGENDARY' description = 'A fragment of a legend, still humming with power.'
        required_level = 14 str_bonus = 5 cha_bonus = 2  price = 750 )

      " ── WEAPON / DAGGER ──
      ( item_name = 'Chipped Dagger'         item_type = 'WEAPON' item_subtype = 'DAGGER'
        item_rarity = 'COMMON'    description = 'Small, dull, and easy to conceal.'
        required_level = 1  dex_bonus = 1                price = 12 )
      ( item_name = |Assassin's Dagger|      item_type = 'WEAPON' item_subtype = 'DAGGER'
        item_rarity = 'UNCOMMON'  description = 'Balanced for a silent strike.'
        required_level = 3  dex_bonus = 2                price = 55 )
      ( item_name = 'Shadowfang Dagger'      item_type = 'WEAPON' item_subtype = 'DAGGER'
        item_rarity = 'RARE'      description = 'Seems to drink the light around it.'
        required_level = 7  dex_bonus = 3 cha_bonus = 1  price = 180 )
      ( item_name = 'Nightbringer'           item_type = 'WEAPON' item_subtype = 'DAGGER'
        item_rarity = 'LEGENDARY' description = 'Whispers grow louder the longer you hold it.'
        required_level = 13 dex_bonus = 5 int_bonus = 2  price = 700 )

      " ── WEAPON / GREATAXE ──
      ( item_name = 'Worn Greataxe'          item_type = 'WEAPON' item_subtype = 'GREATAXE'
        item_rarity = 'COMMON'    description = 'Heavy, chipped, and still swings true.'
        required_level = 2  str_bonus = 1                price = 18 )
      ( item_name = 'Orcish Greataxe'        item_type = 'WEAPON' item_subtype = 'GREATAXE'
        item_rarity = 'UNCOMMON'  description = 'Crude craftsmanship, brutal effectiveness.'
        required_level = 5  str_bonus = 2 con_bonus = 1  price = 70 )
      ( item_name = |Berserker's Greataxe|   item_type = 'WEAPON' item_subtype = 'GREATAXE'
        item_rarity = 'RARE'      description = 'The haft is stained dark with old battles.'
        required_level = 9  str_bonus = 4                price = 220 )
      ( item_name = 'Ragnarok'               item_type = 'WEAPON' item_subtype = 'GREATAXE'
        item_rarity = 'LEGENDARY' description = 'Said to have ended a war in a single swing.'
        required_level = 15 str_bonus = 5 con_bonus = 3  price = 800 )

      " ── WEAPON / BOW ──
      ( item_name = |Hunter's Shortbow|      item_type = 'WEAPON' item_subtype = 'BOW'
        item_rarity = 'COMMON'    description = 'Simple, reliable, and light.'
        required_level = 1  dex_bonus = 1                price = 14 )
      ( item_name = 'Elven Longbow'          item_type = 'WEAPON' item_subtype = 'BOW'
        item_rarity = 'UNCOMMON'  description = 'Carved with quiet, careful precision.'
        required_level = 4  dex_bonus = 2 wis_bonus = 1  price = 65 )
      ( item_name = 'Windrunner Bow'         item_type = 'WEAPON' item_subtype = 'BOW'
        item_rarity = 'RARE'      description = 'Arrows loosed from it never seem to miss the wind.'
        required_level = 8  dex_bonus = 3 wis_bonus = 1  price = 190 )
      ( item_name = |Artemis's Bow|          item_type = 'WEAPON' item_subtype = 'BOW'
        item_rarity = 'LEGENDARY' description = 'A gift from a forgotten hunter-goddess.'
        required_level = 14 dex_bonus = 5 wis_bonus = 2  price = 720 )

      " ── ARMOR / SHIELD ──
      ( item_name = 'Wooden Shield'          item_type = 'ARMOR' item_subtype = 'SHIELD'
        item_rarity = 'COMMON'    description = 'Splintered at the edges but sturdy enough.'
        required_level = 1  con_bonus = 1                price = 15 )
      ( item_name = 'Iron Shield'            item_type = 'ARMOR' item_subtype = 'SHIELD'
        item_rarity = 'UNCOMMON'  description = 'Dented from use, never dented through.'
        required_level = 3  con_bonus = 2                price = 55 )
      ( item_name = 'Aegis of the Guard'     item_type = 'ARMOR' item_subtype = 'SHIELD'
        item_rarity = 'RARE'      description = 'Engraved with the sigil of a fallen order.'
        required_level = 8  con_bonus = 3 str_bonus = 1  price = 210 )
      ( item_name = 'Shield of the Ancients' item_type = 'ARMOR' item_subtype = 'SHIELD'
        item_rarity = 'LEGENDARY' description = 'Has never once been broken.'
        required_level = 15 con_bonus = 5 str_bonus = 2  price = 780 )

      " ── ARMOR / PLATE ──
      ( item_name = 'Dented Plate'           item_type = 'ARMOR' item_subtype = 'PLATE'
        item_rarity = 'COMMON'    description = 'Salvaged armor, hastily repaired.'
        required_level = 2  con_bonus = 1                price = 20 )
      ( item_name = |Knight's Plate|         item_type = 'ARMOR' item_subtype = 'PLATE'
        item_rarity = 'UNCOMMON'  description = 'Polished steel, properly fitted.'
        required_level = 5  con_bonus = 2 str_bonus = 1  price = 75 )
      ( item_name = 'Dragonscale Plate'      item_type = 'ARMOR' item_subtype = 'PLATE'
        item_rarity = 'RARE'      description = 'Forged from the scales of something enormous.'
        required_level = 10 con_bonus = 4                price = 240 )
      ( item_name = 'Armor of the Titan'     item_type = 'ARMOR' item_subtype = 'PLATE'
        item_rarity = 'LEGENDARY' description = 'Impossibly heavy, impossibly light to wear.'
        required_level = 16 con_bonus = 5 str_bonus = 3  price = 820 )

      " ── ARMOR / LEATHER ──
      ( item_name = 'Patched Leather'        item_type = 'ARMOR' item_subtype = 'LEATHER'
        item_rarity = 'COMMON'    description = 'Stitched together from spare hides.'
        required_level = 1  dex_bonus = 1                price = 12 )
      ( item_name = 'Studded Leather'        item_type = 'ARMOR' item_subtype = 'LEATHER'
        item_rarity = 'UNCOMMON'  description = 'Reinforced with rows of iron studs.'
        required_level = 4  dex_bonus = 2 con_bonus = 1  price = 60 )
      ( item_name = 'Shadowweave Leather'    item_type = 'ARMOR' item_subtype = 'LEATHER'
        item_rarity = 'RARE'      description = 'Muffles every footstep to silence.'
        required_level = 9  dex_bonus = 3 cha_bonus = 1  price = 200 )
      ( item_name = 'Cloak of the Void'      item_type = 'ARMOR' item_subtype = 'LEATHER'
        item_rarity = 'LEGENDARY' description = 'The stars seem to shift when you move in it.'
        required_level = 14 dex_bonus = 4 cha_bonus = 2  price = 730 )

      " ── CONSUMABLE / POTION ──
      ( item_name = 'Minor Health Draught'   item_type = 'CONSUMABLE' item_subtype = 'POTION'
        item_rarity = 'COMMON'    description = 'Tastes terrible, works well enough.'
        required_level = 1  con_bonus = 1                price = 8 )
      ( item_name = 'Potion of Vigor'        item_type = 'CONSUMABLE' item_subtype = 'POTION'
        item_rarity = 'UNCOMMON'  description = 'Warmth spreads through your limbs.'
        required_level = 3  con_bonus = 2                price = 35 )
      ( item_name = 'Elixir of Giant Strength' item_type = 'CONSUMABLE' item_subtype = 'POTION'
        item_rarity = 'RARE'      description = 'Your arms feel like they belong to something bigger.'
        required_level = 7  str_bonus = 3                price = 150 )
      ( item_name = 'Elixir of the Phoenix'  item_type = 'CONSUMABLE' item_subtype = 'POTION'
        item_rarity = 'LEGENDARY' description = 'A single drop is said to cheat death itself.'
        required_level = 12 con_bonus = 4 wis_bonus = 1  price = 600 )

      " ── CONSUMABLE / SCROLL ──
      ( item_name = 'Torn Scroll of Insight' item_type = 'CONSUMABLE' item_subtype = 'SCROLL'
        item_rarity = 'COMMON'    description = 'Half the page is missing, but the rest still helps.'
        required_level = 1  int_bonus = 1                price = 10 )
      ( item_name = 'Scroll of Clarity'      item_type = 'CONSUMABLE' item_subtype = 'SCROLL'
        item_rarity = 'UNCOMMON'  description = 'The words rearrange themselves into understanding.'
        required_level = 3  int_bonus = 2                price = 40 )
      ( item_name = 'Scroll of the Archmage' item_type = 'CONSUMABLE' item_subtype = 'SCROLL'
        item_rarity = 'RARE'      description = 'Sealed with a wax stamp no one can identify.'
        required_level = 8  int_bonus = 3 wis_bonus = 1  price = 170 )
      ( item_name = 'Scroll of Forbidden Knowledge' item_type = 'CONSUMABLE' item_subtype = 'SCROLL'
        item_rarity = 'LEGENDARY' description = 'Reading it changes something behind your eyes.'
        required_level = 13 int_bonus = 5                price = 650 )

      " ── MAGIC ITEM / WAND ──
      ( item_name = 'Splintered Wand'        item_type = 'MAGIC ITEM' item_subtype = 'WAND'
        item_rarity = 'COMMON'    description = 'Cracked down the middle, still sparks a little.'
        required_level = 2  int_bonus = 1                price = 20 )
      ( item_name = |Apprentice's Wand|      item_type = 'MAGIC ITEM' item_subtype = 'WAND'
        item_rarity = 'UNCOMMON'  description = 'Standard issue at any respectable academy.'
        required_level = 5  int_bonus = 2                price = 65 )
      ( item_name = 'Wand of Lightning'      item_type = 'MAGIC ITEM' item_subtype = 'WAND'
        item_rarity = 'RARE'      description = 'Crackles faintly when the air turns dry.'
        required_level = 9  int_bonus = 3 dex_bonus = 1  price = 220 )
      ( item_name = 'Staff of the Archon'    item_type = 'MAGIC ITEM' item_subtype = 'WAND'
        item_rarity = 'LEGENDARY' description = 'Once carried by a being who judged nations.'
        required_level = 15 int_bonus = 5 wis_bonus = 2  price = 800 )

      " ── MAGIC ITEM / RING ──
      ( item_name = 'Tarnished Ring'         item_type = 'MAGIC ITEM' item_subtype = 'RING'
        item_rarity = 'COMMON'    description = 'The engraving is worn smooth with age.'
        required_level = 1  wis_bonus = 1                price = 18 )
      ( item_name = 'Ring of Protection'     item_type = 'MAGIC ITEM' item_subtype = 'RING'
        item_rarity = 'UNCOMMON'  description = 'A faint warmth guards against harm.'
        required_level = 4  con_bonus = 1 wis_bonus = 1  price = 70 )
      ( item_name = 'Ring of the Sage'       item_type = 'MAGIC ITEM' item_subtype = 'RING'
        item_rarity = 'RARE'      description = 'Wearing it makes complex thoughts feel simple.'
        required_level = 9  wis_bonus = 3 int_bonus = 1  price = 210 )
      ( item_name = 'Ring of the Archdruid'  item_type = 'MAGIC ITEM' item_subtype = 'RING'
        item_rarity = 'LEGENDARY' description = 'Living vines grow briefly wherever it rests.'
        required_level = 15 wis_bonus = 5 con_bonus = 2  price = 790 )

      " ── MAGIC ITEM / AMULET ──
      ( item_name = 'Simple Amulet'          item_type = 'MAGIC ITEM' item_subtype = 'AMULET'
        item_rarity = 'COMMON'    description = 'A small trinket on a plain cord.'
        required_level = 1  cha_bonus = 1                price = 18 )
      ( item_name = 'Amulet of Persuasion'   item_type = 'MAGIC ITEM' item_subtype = 'AMULET'
        item_rarity = 'UNCOMMON'  description = 'Your words seem to land a little easier.'
        required_level = 4  cha_bonus = 2                price = 68 )
      ( item_name = 'Amulet of the Diplomat' item_type = 'MAGIC ITEM' item_subtype = 'AMULET'
        item_rarity = 'RARE'      description = 'Worn by envoys who never lost an argument.'
        required_level = 9  cha_bonus = 3 wis_bonus = 1  price = 215 )
      ( item_name = 'Crown Jewel of the Fae Court' item_type = 'MAGIC ITEM' item_subtype = 'AMULET'
        item_rarity = 'LEGENDARY' description = 'Taken - or perhaps given - by something not quite human.'
        required_level = 15 cha_bonus = 5 wis_bonus = 2  price = 790 )

      " ── MISCELLANEOUS / ROPE ──
      ( item_name = 'Frayed Rope'            item_type = 'MISCELLANEOUS' item_subtype = 'ROPE'
        item_rarity = 'COMMON'    description = '50 feet, mostly intact.'
        required_level = 1                                price = 5 )
      ( item_name = 'Silk Rope'              item_type = 'MISCELLANEOUS' item_subtype = 'ROPE'
        item_rarity = 'UNCOMMON'  description = 'Light, strong, and surprisingly comfortable to grip.'
        required_level = 2  dex_bonus = 1                price = 25 )

      " ── MISCELLANEOUS / TORCH ──
      ( item_name = 'Sputtering Torch'       item_type = 'MISCELLANEOUS' item_subtype = 'TORCH'
        item_rarity = 'COMMON'    description = 'Smokier than it should be, but it burns.'
        required_level = 1                                price = 4 )
      ( item_name = 'Everburning Torch'      item_type = 'MISCELLANEOUS' item_subtype = 'TORCH'
        item_rarity = 'UNCOMMON'  description = 'Never seems to need relighting.'
        required_level = 3  wis_bonus = 1                price = 30 )

    ).

    DATA lt_create TYPE TABLE FOR CREATE zi_rpg_loot_items\\LootItem.

    LOOP AT lt_seed INTO DATA(ls_seed).
      APPEND VALUE #(
        %cid          = |SEED_{ sy-tabix }|
        ItemName      = ls_seed-item_name
        ItemType      = ls_seed-item_type
        ItemSubtype   = ls_seed-item_subtype
        ItemRarity        = ls_seed-item_rarity
        Description   = ls_seed-description
        RequiredLevel = ls_seed-required_level
        StrBonus      = ls_seed-str_bonus
        DexBonus      = ls_seed-dex_bonus
        ConBonus      = ls_seed-con_bonus
        IntBonus      = ls_seed-int_bonus
        WisBonus      = ls_seed-wis_bonus
        ChaBonus      = ls_seed-cha_bonus
        Price         = ls_seed-price
      ) TO lt_create.
    ENDLOOP.

    MODIFY ENTITIES OF zi_rpg_loot_items
      ENTITY LootItem
        CREATE FIELDS ( ItemName ItemType ItemSubtype ItemRarity Description RequiredLevel
                        StrBonus DexBonus ConBonus IntBonus WisBonus ChaBonus Price )
        WITH lt_create
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES.

    out->write( |Created { lines( mapped-lootitem ) } of { lines( lt_seed ) } loot items.| ).

    IF failed-lootitem IS NOT INITIAL.
      out->write( |{ lines( failed-lootitem ) } failed:| ).
      LOOP AT reported-lootitem INTO DATA(ls_msg).
        IF ls_msg-%msg IS BOUND.
          out->write( ls_msg-%msg->if_message~get_text( ) ).
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

