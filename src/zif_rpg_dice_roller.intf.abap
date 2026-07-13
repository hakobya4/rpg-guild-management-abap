INTERFACE zif_rpg_dice_roller
  PUBLIC.

    "! Returns a number 1-100.
    METHODS roll_percentage
      RETURNING VALUE(rv_roll) TYPE i.

ENDINTERFACE.
