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

    METHODS get_loot_probabilities
      AMDP OPTIONS CDS SESSION CLIENT DEPENDENT READ-ONLY
      IMPORTING VALUE(iv_quest_id)      TYPE ty_quest_id_hex
                VALUE(iv_quest_level)     TYPE i
      EXPORTING VALUE(et_probabilities) TYPE tt_loot_probability.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rpg_loot_amdp IMPLEMENTATION.

  METHOD get_loot_probabilities BY DATABASE PROCEDURE FOR HDB LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY
    USING zrpg_quest_loot zrpg_loot_items.
    DECLARE lv_shift DOUBLE;
    lv_shift := CASE WHEN :iv_quest_level >= 20 THEN 1.0
                     WHEN :iv_quest_level <= 1 THEN 0
                      ELSE :iv_quest_level / 20.0
                 END;
    et_probabilities =
      select 'DROP_CHANCE' as dimension, 'ANY_LOOT' as value,
             30 as probability_pct
                from dummy
*    DUMMY is  one-row table, so this always yields exactly one constant row (LIMIT is not allowed before UNION).
    union all
    select 'RARITY' as dimension,
           m.item_rarity as value,
           case m.item_rarity
             when 'COMMON'    then cast( 60 - 40.0 * :lv_shift as integer )
             when 'UNCOMMON'  then cast( 25 + ( 40.0 / 6 ) * :lv_shift as integer )
             when 'RARE'      then cast( 10 + ( 80.0 / 6 ) * :lv_shift as integer )
             when 'LEGENDARY' then cast( 5 + ( 120.0 / 6 ) * :lv_shift as integer )
             else 0
           end as probability_pct
      from zrpg_quest_loot as l
      inner join zrpg_loot_items as m
        on l.item_id = m.item_id
     where l.quest_id = :iv_quest_id
     group by m.item_rarity

    union all

    select 'ITEM_TYPE' as dimension,
           m.item_type as value,
           cast( count(*) * 100 / total.cnt as integer ) as probability_pct
      from zrpg_quest_loot as l
      inner join zrpg_loot_items as m
        on l.item_id = m.item_id
      cross join ( select count(*) as cnt
                     from zrpg_quest_loot
                    where quest_id = :iv_quest_id ) as total
     where l.quest_id = :iv_quest_id
     group by m.item_type, total.cnt;

  ENDMETHOD.

ENDCLASS.

