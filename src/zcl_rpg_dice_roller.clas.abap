CLASS zcl_rpg_dice_roller DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_rpg_dice_roller.

    METHODS constructor
      IMPORTING iv_fixed_roll TYPE i.

  PRIVATE SECTION.
    DATA mv_fixed_roll TYPE i.

ENDCLASS.



CLASS zcl_rpg_dice_roller IMPLEMENTATION.

  METHOD constructor.
    mv_fixed_roll = iv_fixed_roll.
  ENDMETHOD.

  METHOD zif_rpg_dice_roller~roll_percentage.
    rv_roll = mv_fixed_roll.
  ENDMETHOD.

ENDCLASS.

