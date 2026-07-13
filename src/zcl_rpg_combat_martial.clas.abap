CLASS zcl_rpg_combat_martial DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_rpg_quest_resolution.

ENDCLASS.



CLASS zcl_rpg_combat_martial IMPLEMENTATION.
  METHOD zif_rpg_quest_resolution~get_success_chance.
    rv_chance_pct = 50 + ( iv_adventurer_level - iv_required_level ) * 5.
    IF rv_chance_pct > 95.
      rv_chance_pct = 95.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

