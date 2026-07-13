INTERFACE zif_rpg_quest_resolution
  PUBLIC.

    METHODS get_success_chance
      IMPORTING iv_adventurer_level    TYPE zrpg_adventurer-adventurer_level
                iv_required_level      TYPE zrpg_quest-required_level
      RETURNING VALUE(rv_chance_pct)   TYPE i.

ENDINTERFACE.
