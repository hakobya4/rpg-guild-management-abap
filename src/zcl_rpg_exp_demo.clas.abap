CLASS zcl_rpg_exp_demo DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS zcl_rpg_exp_demo IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.


    "  one expedition + a party directly into the tables (bypassing draft create), then resolves it  so you can.

    " Need at least two existing adventurers to form a party
    SELECT adventurer_id, adventurer_name
      FROM zrpg_adventurer
      ORDER BY adventurer_name
      INTO TABLE @DATA(lt_adv)
      UP TO 2 ROWS.

    IF lines( lt_adv ) < 2.
      out->write( 'Create at least two adventurers in the guild app first, then re-run.' ).
      RETURN.
    ENDIF.

    " Fresh start: remove any expedition this demo created before
    DELETE FROM zrpg_expedition WHERE expedition_name = 'Demo Expedition'.
    DELETE FROM zrpg_exp_members WHERE expedition_id NOT IN ( SELECT expedition_id FROM zrpg_expedition ).

    TRY.
        DATA(lv_exp_id) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_now)    = utclong_current( ).

        "  expedition already filled with quest requirements

        INSERT zrpg_expedition FROM @( VALUE #(
          client                = sy-mandt
          expedition_id         = lv_exp_id
          expedition_name       = 'Demo Expedition'
          status                = 'PLANNED'
          required_stat         = 'STR'
          required_level        = 1
          difficulty_class      = 10
          xp_reward             = 30
          created_at            = lv_now
          created_by            = sy-uname
          last_changed_at       = lv_now
          last_changed_by       = sy-uname
          local_last_changed_at = lv_now ) ).

        DATA lt_members TYPE STANDARD TABLE OF zrpg_exp_members WITH EMPTY KEY.
        LOOP AT lt_adv INTO DATA(ls_adv).
          APPEND VALUE #(
            client                = sy-mandt
            member_id             = cl_system_uuid=>create_uuid_x16_static( )
            expedition_id         = lv_exp_id
            adventurer_id         = ls_adv-adventurer_id
            local_last_changed_at = lv_now ) TO lt_members.
        ENDLOOP.
        INSERT zrpg_exp_members FROM TABLE @lt_members.

      CATCH cx_uuid_error INTO DATA(lx).
        out->write( |UUID generation failed: { lx->get_text( ) }| ).
        RETURN.
    ENDTRY.

    COMMIT WORK AND WAIT.
    out->write( |Seeded 'Demo Expedition' with { lines( lt_members ) } party members.| ).

    " Resolve it through the unmanaged behavior
    MODIFY ENTITIES OF zi_rpg_expedition
      ENTITY Expedition
        EXECUTE resolveExpedition
          FROM VALUE #( ( %tky-ExpeditionId = lv_exp_id
                          %tky-%is_draft    = if_abap_behv=>mk-off ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    LOOP AT reported-expedition INTO DATA(ls_rep).
      IF ls_rep-%msg IS BOUND.
        out->write( ls_rep-%msg->if_message~get_text( ) ).
      ENDIF.
    ENDLOOP.

    IF failed-expedition IS NOT INITIAL.
      out->write( 'Resolve failed - nothing was committed.' ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES.

    "  Show the outcome
    SELECT SINGLE status, successes FROM zrpg_expedition
      WHERE expedition_id = @lv_exp_id
      INTO @DATA(ls_outcome).
    out->write( |Result: { ls_outcome-status }, { ls_outcome-successes } checks passed.| ).

    SELECT m~member_roll, m~member_total, m~member_passed, m~xp_gained, a~adventurer_name
      FROM zrpg_exp_members AS m
      INNER JOIN zrpg_adventurer AS a ON a~adventurer_id = m~adventurer_id
      WHERE m~expedition_id = @lv_exp_id
      INTO TABLE @DATA(lt_rolls).
    LOOP AT lt_rolls INTO DATA(ls_roll).
      out->write( |{ ls_roll-adventurer_name }: rolled { ls_roll-member_roll } | &&
                  |(total { ls_roll-member_total }), | &&
                  |{ COND #( WHEN ls_roll-member_passed = abap_true THEN 'PASS' ELSE 'FAIL' ) }, | &&
                  |+{ ls_roll-xp_gained } XP| ).
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
