INTERFACE zif_rpg_dice_roller
  PUBLIC.

    " Returns a number 1-20 (d20).
    METHODS roll_dtwenty
      RETURNING VALUE(rv_roll) TYPE i.
   " Rolls 4d6, drops the lowest, and sums the rest
    METHODS roll_stats
      RETURNING VALUE(rv_roll) TYPE i.

ENDINTERFACE.
