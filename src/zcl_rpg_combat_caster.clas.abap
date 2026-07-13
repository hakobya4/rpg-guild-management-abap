CLASS zcl_rpg_combat_caster DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_rpg_quest_resolution.

ENDCLASS.



CLASS zcl_rpg_combat_caster IMPLEMENTATION.

  METHOD zif_rpg_quest_resolution~get_success_chance.
    " Casters have a lower chance to succeed in a combat at levels that match the requirements but at higher levels they are better.
    rv_chance_pct = 40 + ( iv_adventurer_level - iv_required_level ) * 8.

    IF rv_chance_pct > 95.
      rv_chance_pct = 95.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
