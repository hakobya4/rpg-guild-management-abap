CLASS zcl_rpg_noncombat DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_rpg_quest_resolution.

ENDCLASS.



CLASS zcl_rpg_noncombat IMPLEMENTATION.

  METHOD zif_rpg_quest_resolution~get_success_chance.
    " No combat mechanics involved 100% chance to complete
    rv_chance_pct = 100.
  ENDMETHOD.

ENDCLASS.

