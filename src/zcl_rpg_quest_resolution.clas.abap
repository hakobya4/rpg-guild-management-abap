CLASS zcl_rpg_quest_resolution DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    "decides combat quest vs not a combat quest
    CLASS-METHODS create_strategy
      IMPORTING iv_quest_type       TYPE zrpg_quest-quest_type_name
                iv_adventurer_class TYPE zrpg_adventurer-adventurer_class
                iv_quest_difficulty TYPE zrpg_quest-difficulty_class
                iv_quest_stat       TYPE zrpg_quest-required_stat
                iv_adventurer_str   TYPE  zrpg_adventurer-adv_str
                iv_adventurer_dex   TYPE zrpg_adventurer-adv_dex
                iv_adventurer_con   TYPE zrpg_adventurer-adv_con
                iv_adventurer_int   TYPE  zrpg_adventurer-adv_int
                iv_adventurer_wis   TYPE zrpg_adventurer-adv_wis
                iv_adventurer_cha   TYPE  zrpg_adventurer-adv_cha
      RETURNING VALUE(ro_strategy)  TYPE REF TO zif_rpg_quest_resolution.

ENDCLASS.



CLASS zcl_rpg_quest_resolution IMPLEMENTATION.

  METHOD create_strategy.
    CASE iv_quest_type.
      WHEN 'COMBAT'.
        ro_strategy = zcl_rpg_combat=>create_strategy( iv_adventurer_class ).
      WHEN OTHERS.
        ro_strategy = NEW zcl_rpg_noncombat( ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.

