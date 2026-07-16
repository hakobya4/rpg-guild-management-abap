CLASS zcl_rpg_stat_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_rpg_quest_resolution.

ENDCLASS.



CLASS zcl_rpg_stat_check IMPLEMENTATION.

  METHOD zif_rpg_quest_resolution~get_check_modifier.

    " Look up the ability score matching the quest's required.
    DATA(lv_stat_value) = SWITCH #( iv_quest_stat
      WHEN 'STR' THEN iv_adventurer_str
      WHEN 'DEX' THEN iv_adventurer_dex
      WHEN 'CON' THEN iv_adventurer_con
      WHEN 'INT' THEN iv_adventurer_int
      WHEN 'WIS' THEN iv_adventurer_wis
      WHEN 'CHA' THEN iv_adventurer_cha
      ELSE 10 ).                     " neutral 0 modifier

    " Standard D&D ability modifier
    DATA(lv_ability_modifier) = ( lv_stat_value - 10 ) DIV 2.

    DATA(lv_level_bonus) = iv_adventurer_level - iv_required_level.

    rv_modifier = lv_ability_modifier + lv_level_bonus.

  ENDMETHOD.

ENDCLASS.

