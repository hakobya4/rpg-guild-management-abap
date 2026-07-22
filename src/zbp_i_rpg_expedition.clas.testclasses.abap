" fixed d20 roll.
CLASS ltd_scripted_dice DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_rpg_dice_roller.
    DATA mv_d20 TYPE i VALUE 10.
ENDCLASS.

CLASS ltd_scripted_dice IMPLEMENTATION.
  METHOD zif_rpg_dice_roller~roll_dtwenty.   rv_roll = mv_d20. ENDMETHOD.
  METHOD zif_rpg_dice_roller~roll_stats.     rv_roll = 10.     ENDMETHOD.
  METHOD zif_rpg_dice_roller~roll_percentage. rv_roll = 50.    ENDMETHOD.
  METHOD zif_rpg_dice_roller~roll_between.    rv_roll = iv_min. ENDMETHOD.
ENDCLASS.


CLASS ltc_expedition DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
  TYPES tt_adv_id TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.

    " Seeds one PLANNED expedition + a two-adventurer party as ACTIVE data
    METHODS seed_active_expedition
      IMPORTING iv_dc            TYPE i DEFAULT 5
      EXPORTING ev_expedition_id TYPE sysuuid_x16
                et_adventurers   TYPE tt_adv_id

      RAISING   cx_uuid_error.

    METHODS resolve_success_completes  FOR TESTING RAISING cx_uuid_error.
    METHODS resolve_failure_fails      FOR TESTING RAISING cx_uuid_error.
    METHODS resolve_not_planned_fails  FOR TESTING RAISING cx_uuid_error.
    METHODS resolve_empty_party_fails  FOR TESTING RAISING cx_uuid_error.

ENDCLASS.


CLASS ltc_expedition IMPLEMENTATION.

  METHOD class_setup.
    " Own tables + draft tables (BO is draft-enabled), the interface view
    " (RAP addresses instances through it), and the adventurer BO's table +
    " view (the resolve action updates adventurer XP cross-BO).
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZRPG_EXPEDITION' ) ( 'ZRPG_EXPED_D' ) ( 'ZI_RPG_EXPEDITION' )
        ( 'ZRPG_EXP_MEMBERS' ) ( 'ZRPG_EXP_MEM_D' )
        ( 'ZRPG_ADVENTURER' ) ( 'ZRPG_DADVENTURER' ) ( 'ZI_RPG_ADVENTURER' )
        ( 'ZRPG_GUILD' ) ( 'ZRPG_GUILD_D' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    sql_environment->clear_doubles( ).
    CLEAR lhc_expedition=>go_dice_roller.
    " The unmanaged buffer is static - clear it or state leaks between tests
    lcl_buffer=>clear( ).
  ENDMETHOD.

  METHOD seed_active_expedition.
    ev_expedition_id = cl_system_uuid=>create_uuid_x16_static( ).

    DATA exps TYPE STANDARD TABLE OF zrpg_expedition WITH EMPTY KEY.
    exps = VALUE #( ( expedition_id = ev_expedition_id expedition_name = 'Test Run'
                      status = 'PLANNED' required_stat = 'STR' required_level = 1
                      difficulty_class = iv_dc xp_reward = 30
                      created_by = sy-uname ) ).
    sql_environment->insert_test_data( exps ).

    " Two party members, each an adventurer with STR 10 (modifier +0)
    DATA members TYPE STANDARD TABLE OF zrpg_exp_members WITH EMPTY KEY.
    DATA advs     TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    DATA adv_view TYPE STANDARD TABLE OF zi_rpg_adventurer WITH EMPTY KEY.

    DO 2 TIMES.
      DATA(lv_adv_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND lv_adv_id TO et_adventurers.

      APPEND VALUE #( member_id = cl_system_uuid=>create_uuid_x16_static( )
                      expedition_id = ev_expedition_id
                      adventurer_id = lv_adv_id ) TO members.

      APPEND VALUE #( adventurer_id = lv_adv_id adventurer_name = |Hero{ sy-index }|
                      adventurer_level = 1 adventurer_xp = 0
                      adv_str = 10 adv_dex = 10 adv_con = 10
                      adv_int = 10 adv_wis = 10 adv_cha = 10
                      created_by = sy-uname ) TO advs.
      APPEND VALUE #( AdventurerId = lv_adv_id AdventurerName = |Hero{ sy-index }|
                      AdventurerLevel = 1 AdventurerXp = 0
                      AdvStr = 10 AdvDex = 10 AdvCon = 10
                      AdvInt = 10 AdvWis = 10 AdvCha = 10
                      CreatedBy = sy-uname ) TO adv_view.
    ENDDO.

    sql_environment->insert_test_data( members ).
    sql_environment->insert_test_data( advs ).
    sql_environment->insert_test_data( adv_view ).
  ENDMETHOD.

  METHOD resolve_success_completes.
    seed_active_expedition( IMPORTING ev_expedition_id = DATA(exp_id)
                                      et_adventurers   = DATA(adv_ids) ).

    " d20 = 20 vs DC 5 -> both members pass -> majority -> COMPLETED
    DATA(dice) = NEW ltd_scripted_dice( ).
    dice->mv_d20 = 20.
    lhc_expedition=>go_dice_roller = dice.

    MODIFY ENTITIES OF zi_rpg_expedition
      ENTITY Expedition
        EXECUTE resolveExpedition
          FROM VALUE #( ( %tky-ExpeditionId = exp_id
                          %tky-%is_draft    = if_abap_behv=>mk-off ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-expedition
      msg = 'A party that mostly passes must resolve without failure' ).

    COMMIT ENTITIES.

    SELECT SINGLE status, successes FROM zrpg_expedition
      WHERE expedition_id = @exp_id INTO @DATA(ls_exp).
    cl_abap_unit_assert=>assert_equals(
      act = ls_exp-status exp = 'COMPLETED'
      msg = 'A passing party must complete the expedition' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_exp-successes exp = 2
      msg = 'Both members passed, so successes must be 2' ).

    " 30 XP split across 2 members = 15 each; level 1 xp 0 -> level 2 xp 5
        DATA(lv_first_adv) = adv_ids[ 1 ].

    SELECT SINGLE adventurer_xp, adventurer_level FROM zrpg_adventurer
      WHERE adventurer_id = @lv_first_adv INTO @DATA(ls_adv).
    cl_abap_unit_assert=>assert_equals(
      act = ls_adv-adventurer_level exp = 2
      msg = '15 XP awarded must level the adventurer 1 -> 2' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_adv-adventurer_xp exp = 5
      msg = 'The XP remainder after leveling must be kept' ).
  ENDMETHOD.

  METHOD resolve_failure_fails.
    seed_active_expedition( EXPORTING iv_dc            = 25
                            IMPORTING ev_expedition_id = DATA(exp_id)
                                      et_adventurers   = DATA(adv_ids) ).

    " d20 = 1 vs DC 25 -> both fail -> minority -> FAILED, no XP
    DATA(dice) = NEW ltd_scripted_dice( ).
    dice->mv_d20 = 1.
    lhc_expedition=>go_dice_roller = dice.

    MODIFY ENTITIES OF zi_rpg_expedition
      ENTITY Expedition
        EXECUTE resolveExpedition
          FROM VALUE #( ( %tky-ExpeditionId = exp_id
                          %tky-%is_draft    = if_abap_behv=>mk-off ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES.

    SELECT SINGLE status, successes FROM zrpg_expedition
      WHERE expedition_id = @exp_id INTO @DATA(ls_exp).
    cl_abap_unit_assert=>assert_equals(
      act = ls_exp-status exp = 'FAILED'
      msg = 'A party that mostly fails must fail the expedition' ).
     DATA(lv_first_adv) = adv_ids[ 1 ].

    SELECT SINGLE adventurer_xp, adventurer_level FROM zrpg_adventurer
      WHERE adventurer_id = @lv_first_adv INTO @DATA(ls_adv).
    cl_abap_unit_assert=>assert_equals(
      act = ls_adv-adventurer_level exp = 1
      msg = 'A failed expedition must not grant XP or levels' ).
  ENDMETHOD.

  METHOD resolve_not_planned_fails.
    seed_active_expedition( IMPORTING ev_expedition_id = DATA(exp_id)
                                      et_adventurers   = DATA(adv_ids) ).

    " Force the expedition out of PLANNED
    UPDATE zrpg_expedition SET status = 'COMPLETED' WHERE expedition_id = @exp_id.

    lhc_expedition=>go_dice_roller = NEW ltd_scripted_dice( ).

    MODIFY ENTITIES OF zi_rpg_expedition
      ENTITY Expedition
        EXECUTE resolveExpedition
          FROM VALUE #( ( %tky-ExpeditionId = exp_id
                          %tky-%is_draft    = if_abap_behv=>mk-off ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-expedition
      msg = 'Only a PLANNED expedition may be resolved' ).
  ENDMETHOD.

  METHOD resolve_empty_party_fails.
    DATA(exp_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA exps TYPE STANDARD TABLE OF zrpg_expedition WITH EMPTY KEY.
    exps = VALUE #( ( expedition_id = exp_id expedition_name = 'Lonely'
                      status = 'PLANNED' required_stat = 'STR' required_level = 1
                      difficulty_class = 5 xp_reward = 30 created_by = sy-uname ) ).
    sql_environment->insert_test_data( exps ).

    lhc_expedition=>go_dice_roller = NEW ltd_scripted_dice( ).

    MODIFY ENTITIES OF zi_rpg_expedition
      ENTITY Expedition
        EXECUTE resolveExpedition
          FROM VALUE #( ( %tky-ExpeditionId = exp_id
                          %tky-%is_draft    = if_abap_behv=>mk-off ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-expedition
      msg = 'An expedition with no party members cannot be resolved' ).
  ENDMETHOD.

ENDCLASS.
