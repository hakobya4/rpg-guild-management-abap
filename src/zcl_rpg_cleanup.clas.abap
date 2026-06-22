CLASS zcl_rpg_cleanup DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_rpg_cleanup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.


    "  Put the broken data's name here ────────────────────────
    DATA(lv_name) = 'Potion'.

    SELECT SINGLE item_id FROM zrpg_inventory
      WHERE item_name = @lv_name
      INTO @DATA(lv_name_id).

    IF sy-subrc <> 0.
      out->write( |No quest named '{ lv_name }' found.| ).
      RETURN.
    ENDIF.

    " ── 3. Raw SQL delete (bypasses the BO) ────────────────────────
    DELETE FROM zrpg_inventory WHERE item_id = @lv_name_id.
    out->write( |Deleted { sy-dbcnt } row(s) from zrpg_quest.| ).

*    " Clean up any draft leftovers too
*    DELETE FROM zrpg_quest_d WHERE questid = @lv_name_id.
*    out->write( |Deleted { sy-dbcnt } draft row(s).| ).

  ENDMETHOD.

ENDCLASS.
