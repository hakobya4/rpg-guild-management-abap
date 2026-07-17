CLASS zcl_rpg_loot_amdp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.

    TYPES ty_quest_id_hex TYPE c LENGTH 32.


    TYPES: BEGIN OF ty_loot_probability,
             dimension       TYPE c LENGTH 20,
             value           TYPE c LENGTH 30,
             probability_pct TYPE i,
           END OF ty_loot_probability,
           tt_loot_probability TYPE STANDARD TABLE OF ty_loot_probability WITH EMPTY KEY.

    METHODS get_item_count
      AMDP OPTIONS CDS SESSION CLIENT DEPENDENT READ-ONLY
      EXPORTING VALUE(rv_count) TYPE i.

    METHODS get_loot_probabilities
      AMDP OPTIONS CDS SESSION CLIENT DEPENDENT READ-ONLY
      IMPORTING VALUE(iv_quest_id)      TYPE ty_quest_id_hex
      EXPORTING VALUE(et_probabilities) TYPE tt_loot_probability.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rpg_loot_amdp IMPLEMENTATION.

  METHOD get_item_count BY DATABASE PROCEDURE FOR HDB LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY
    USING zrpg_inventory.

    SELECT COUNT(*) INTO rv_count FROM zrpg_inventory;

  ENDMETHOD.


  METHOD get_loot_probabilities BY DATABASE PROCEDURE FOR HDB LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY
    USING zrpg_quest_loot zrpg_marketplace.
    et_probabilities = select 'RARITY' AS dimension,
     m.item_rarity as value,
    cast( count(*) * 100 / total.cnt as integer ) as probability_pct
   from zrpg_quest_loot as l
   inner join zrpg_marketplace as m
     on l.item_id = m.item_id
   cross join ( select count(*) as cnt
    from zrpg_quest_loot
    where quest_id = :iv_quest_id ) as total
   where l.quest_id = :iv_quest_id
   GROUP BY m.item_rarity, total.cnt

 union all

 select 'ITEM_TYPE' as dimension,
 m.item_type AS value,
          CAST( COUNT(*) * 100 / total.cnt AS INTEGER ) AS probability_pct
     FROM zrpg_quest_loot AS l
     INNER JOIN zrpg_marketplace AS m
       ON l.item_id = m.item_id
     CROSS JOIN ( SELECT COUNT(*) AS cnt
                    FROM zrpg_quest_loot
                   WHERE quest_id = :iv_quest_id ) AS total
    WHERE l.quest_id = :iv_quest_id
    GROUP BY m.item_type, total.cnt;

  ENDMETHOD.

ENDCLASS.

