CLASS zcl_rpg_roll_dice DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_rpg_dice_roller.

ENDCLASS.



CLASS zcl_rpg_roll_dice IMPLEMENTATION.

  METHOD zif_rpg_dice_roller~roll_percentage.
    rv_roll = cl_abap_random_int=>create(
                 seed = cl_abap_random=>seed( )
                 min  = 1
                 max  = 100 )->get_next( ).
  ENDMETHOD.

ENDCLASS.

