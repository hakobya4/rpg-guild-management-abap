CLASS zcl_rpg_combat_caster DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_rpg_quest_resolution.

ENDCLASS.



CLASS zcl_rpg_combat_caster IMPLEMENTATION.

  METHOD zif_rpg_quest_resolution~get_success_chance.
   DATA lo_roller TYPE REF TO zif_rpg_dice_roller.
      lo_roller = NEW zcl_rpg_roll_dice( ).
    " Casters have a lower chance to succeed in a combat at levels that match the requirements but at higher levels they are better.
    rv_chance_pct = lo_roller->roll_dtwenty(  ) + ( iv_adventurer_level - iv_required_level ).
  ENDMETHOD.

ENDCLASS.
