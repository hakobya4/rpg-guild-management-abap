CLASS zcl_rpg_cleanup DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_rpg_cleanup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " ── 1. List all quests so you can identify the broken one ──────
    SELECT quest_id, quest_name, status, adventurer_id
      FROM zrpg_quest
      INTO TABLE @DATA(quests).

    LOOP AT quests INTO DATA(quest).
      out->write( |{ quest-quest_id } | && |{ quest-quest_name } | &&
                  |[{ quest-status }] adv: { quest-adventurer_id }| ).
    ENDLOOP.

    " ── 2. Put the broken quest's name here ────────────────────────
    DATA(lv_name) = 'Save the word'.   " <── change me

    SELECT SINGLE quest_id FROM zrpg_quest
      WHERE quest_name = @lv_name
      INTO @DATA(lv_quest_id).

    IF sy-subrc <> 0.
      out->write( |No quest named '{ lv_name }' found.| ).
      RETURN.
    ENDIF.

    " ── 3. Raw SQL delete (bypasses the BO) ────────────────────────
    DELETE FROM zrpg_quest WHERE quest_id = @lv_quest_id.
    out->write( |Deleted { sy-dbcnt } row(s) from zrpg_quest.| ).

    " Clean up any draft leftovers too
    DELETE FROM zrpg_quest_d WHERE questid = @lv_quest_id.
    out->write( |Deleted { sy-dbcnt } draft row(s).| ).

  ENDMETHOD.

ENDCLASS.
