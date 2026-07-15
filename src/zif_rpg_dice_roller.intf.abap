INTERFACE zif_rpg_dice_roller
  PUBLIC.

    "! Returns a number 1-100.
    METHODS roll_dtwenty
      RETURNING VALUE(rv_roll) TYPE i.

    METHODS roll_stats
      RETURNING VALUE(rv_roll) TYPE i.

ENDINTERFACE.
