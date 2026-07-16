INTERFACE zif_rpg_quest_resolution
  PUBLIC.

  METHODS get_check_modifier
    IMPORTING iv_adventurer_level  TYPE zrpg_adventurer-adventurer_level
              iv_required_level    TYPE zrpg_quest-required_level
              iv_quest_stat        TYPE zrpg_quest-required_stat
              iv_adventurer_str    TYPE  zrpg_adventurer-adv_str
              iv_adventurer_dex    TYPE zrpg_adventurer-adv_dex
              iv_adventurer_con    TYPE zrpg_adventurer-adv_con
              iv_adventurer_int    TYPE  zrpg_adventurer-adv_int
              iv_adventurer_wis    TYPE zrpg_adventurer-adv_wis
              iv_adventurer_cha    TYPE  zrpg_adventurer-adv_cha
    RETURNING VALUE(rv_modifier) TYPE i.

ENDINTERFACE.
