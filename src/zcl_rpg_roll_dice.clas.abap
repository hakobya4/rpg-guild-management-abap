CLASS zcl_rpg_roll_dice DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_rpg_dice_roller.

ENDCLASS.



CLASS zcl_rpg_roll_dice IMPLEMENTATION.

  METHOD zif_rpg_dice_roller~roll_dtwenty.
    rv_roll = cl_abap_random_int=>create(
                 seed = cl_abap_random=>seed( )
                 min  = 1
                 max  = 20 )->get_next( ).
  ENDMETHOD.

  METHOD zif_rpg_dice_roller~roll_stats.


   DATA: stat_rolls TYPE TABLE OF i,
        total_stats  TYPE i.

   DO 4 TIMES.
    DATA(stat_roll) = cl_abap_random_int=>create(
                 seed = cl_abap_random=>seed( )
                 min  = 1
                 max  = 6 )->get_next( ).
    INSERT stat_roll INTO TABLE stat_rolls.
    ENDDO.
    SORT stat_rolls ASCENDING.
    DELETE stat_rolls INDEX 1.
    LOOP AT stat_rolls INTO DATA(stat).
      rv_roll += stat.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_rpg_dice_roller~roll_percentage.
    rv_roll = cl_abap_random_int=>create(
                 seed = cl_abap_random=>seed( )
                 min  = 1
                 max  = 100 )->get_next( ).
  ENDMETHOD.

ENDCLASS.

