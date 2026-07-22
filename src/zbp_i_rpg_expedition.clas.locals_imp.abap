* Fully unmanaged behavior implementation for ZI_RPG_EXPEDITION.

CLASS lcl_buffer DEFINITION FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES tt_expedition TYPE STANDARD TABLE OF zrpg_expedition WITH EMPTY KEY.
    TYPES tt_member     TYPE STANDARD TABLE OF zrpg_exp_members WITH EMPTY KEY.
    TYPES tt_uuid       TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    CLASS-DATA mt_exp_create TYPE tt_expedition.
    CLASS-DATA mt_exp_update TYPE tt_expedition.
    CLASS-DATA mt_exp_delete TYPE tt_uuid.
    CLASS-DATA mt_mem_create TYPE tt_member.
    CLASS-DATA mt_mem_update TYPE tt_member.
    CLASS-DATA mt_mem_delete TYPE tt_uuid.

    " Merged view of one expedition
    CLASS-METHODS read_expedition
      IMPORTING iv_id    TYPE sysuuid_x16
      EXPORTING es_data  TYPE zrpg_expedition
                ev_found TYPE abap_bool.

    "  changed expedition into a table
    CLASS-METHODS store_exp_update
      IMPORTING is_data TYPE zrpg_expedition.

    " Merged view of one member
    CLASS-METHODS read_member
      IMPORTING iv_id    TYPE sysuuid_x16
      EXPORTING es_data  TYPE zrpg_exp_members
                ev_found TYPE abap_bool.

    " Upserts a changed member into the right buffer table
    CLASS-METHODS store_member_update
      IMPORTING is_data TYPE zrpg_exp_members.

    " Merged member list of one expedition (DB + buffer, minus deletions)
    CLASS-METHODS read_members
      IMPORTING iv_expedition_id  TYPE sysuuid_x16
      RETURNING VALUE(rt_members) TYPE tt_member.

    CLASS-METHODS clear.

ENDCLASS.


CLASS lcl_buffer IMPLEMENTATION.

  METHOD read_expedition.
    CLEAR: es_data, ev_found.

    IF line_exists( mt_exp_delete[ table_line = iv_id ] ).
      RETURN.
    ENDIF.

    READ TABLE mt_exp_create INTO es_data WITH KEY expedition_id = iv_id.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.

    READ TABLE mt_exp_update INTO es_data WITH KEY expedition_id = iv_id.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrpg_expedition
      WHERE expedition_id = @iv_id
      INTO @es_data.
    ev_found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD store_exp_update.
    " A row that only exists in the create buffer stays a create
    READ TABLE mt_exp_create ASSIGNING FIELD-SYMBOL(<create>)
      WITH KEY expedition_id = is_data-expedition_id.
    IF sy-subrc = 0.
      <create> = is_data.
      RETURN.
    ENDIF.

    READ TABLE mt_exp_update ASSIGNING FIELD-SYMBOL(<update>)
      WITH KEY expedition_id = is_data-expedition_id.
    IF sy-subrc = 0.
      <update> = is_data.
    ELSE.
      APPEND is_data TO mt_exp_update.
    ENDIF.
  ENDMETHOD.

  METHOD read_member.
    CLEAR: es_data, ev_found.

    IF line_exists( mt_mem_delete[ table_line = iv_id ] ).
      RETURN.
    ENDIF.

    READ TABLE mt_mem_create INTO es_data WITH KEY member_id = iv_id.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.

    READ TABLE mt_mem_update INTO es_data WITH KEY member_id = iv_id.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrpg_exp_members
      WHERE member_id = @iv_id
      INTO @es_data.
    ev_found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD store_member_update.
    READ TABLE mt_mem_create ASSIGNING FIELD-SYMBOL(<create>)
      WITH KEY member_id = is_data-member_id.
    IF sy-subrc = 0.
      <create> = is_data.
      RETURN.
    ENDIF.

    READ TABLE mt_mem_update ASSIGNING FIELD-SYMBOL(<update>)
      WITH KEY member_id = is_data-member_id.
    IF sy-subrc = 0.
      <update> = is_data.
    ELSE.
      APPEND is_data TO mt_mem_update.
    ENDIF.
  ENDMETHOD.

  METHOD read_members.
    SELECT * FROM zrpg_exp_members
      WHERE expedition_id = @iv_expedition_id
      INTO TABLE @rt_members.

    " Apply pending updates over the persisted state
    LOOP AT mt_mem_update INTO DATA(ls_update) WHERE expedition_id = iv_expedition_id.
      READ TABLE rt_members ASSIGNING FIELD-SYMBOL(<row>)
        WITH KEY member_id = ls_update-member_id.
      IF sy-subrc = 0.
        <row> = ls_update.
      ENDIF.
    ENDLOOP.

    " Remove pending deletions
    LOOP AT rt_members ASSIGNING <row>.
      IF line_exists( mt_mem_delete[ table_line = <row>-member_id ] ).
        DELETE rt_members USING KEY loop_key.
      ENDIF.
    ENDLOOP.

    " Add unsaved new members
    LOOP AT mt_mem_create INTO DATA(ls_create) WHERE expedition_id = iv_expedition_id.
      APPEND ls_create TO rt_members.
    ENDLOOP.
  ENDMETHOD.

  METHOD clear.
    CLEAR: mt_exp_create, mt_exp_update, mt_exp_delete,
           mt_mem_create, mt_mem_update, mt_mem_delete.
  ENDMETHOD.

ENDCLASS.



" Behavior handler
CLASS lhc_expedition DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.
    "  tests inject
    CLASS-DATA go_dice_roller TYPE REF TO zif_rpg_dice_roller.

  PRIVATE SECTION.

    CONSTANTS:
      c_status_planned   TYPE zrpg_expedition-status VALUE 'PLANNED',
      c_status_completed TYPE zrpg_expedition-status VALUE 'COMPLETED',
      c_status_failed    TYPE zrpg_expedition-status VALUE 'FAILED',
      c_max_party_size   TYPE i VALUE 4,
      " Keep in sync with c_xp_per_level in ZBP_I_RPG_QUEST
      c_xp_per_level     TYPE i VALUE 10.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Expedition RESULT result.

    "numbering
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Expedition.
    METHODS earlynumbering_cba_member FOR NUMBERING
      IMPORTING entities FOR CREATE Expedition\_Member.

    " Expedition CRUD
    METHODS create FOR MODIFY
      IMPORTING entities FOR CREATE Expedition.
    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE Expedition.
    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE Expedition.
    METHODS read FOR READ
      IMPORTING keys FOR READ Expedition RESULT result.
    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Expedition.

    "  Member operations
    METHODS cba_member FOR MODIFY
      IMPORTING entities_cba FOR CREATE Expedition\_Member.
    METHODS rba_member FOR READ
      IMPORTING keys_rba FOR READ Expedition\_Member FULL result_requested
      RESULT    result LINK association_links.
    METHODS read_member FOR READ
      IMPORTING keys FOR READ Member RESULT result.
    METHODS delete_member FOR MODIFY
      IMPORTING keys FOR DELETE Member.

    " --- action, validations, determinations ---
    METHODS resolveExpedition FOR MODIFY
      IMPORTING keys FOR ACTION Expedition~resolveExpedition RESULT result.
    METHODS validateQuest FOR VALIDATE ON SAVE
      IMPORTING keys FOR Expedition~validateQuest.
    METHODS validateMember FOR VALIDATE ON SAVE
      IMPORTING keys FOR Member~validateMember.
    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Expedition~setInitialStatus.
    METHODS deriveQuestReqs FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Expedition~deriveQuestReqs.
    METHODS update_member FOR MODIFY
      IMPORTING entities FOR UPDATE Member.
    METHODS rba_Expedition FOR READ
      IMPORTING keys_rba FOR READ Member\_Expedition FULL result_requested RESULT result LINK association_links.

ENDCLASS.


CLASS lhc_expedition IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).
      IF <entity>-ExpeditionId IS NOT INITIAL.
        APPEND VALUE #( %cid         = <entity>-%cid
                        ExpeditionId = <entity>-ExpeditionId ) TO mapped-expedition.
        CONTINUE.
      ENDIF.
      TRY.
          APPEND VALUE #( %cid         = <entity>-%cid
                          ExpeditionId = cl_system_uuid=>create_uuid_x16_static( ) )
            TO mapped-expedition.
        CATCH cx_uuid_error.
          APPEND VALUE #( %cid = <entity>-%cid ) TO failed-expedition.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_cba_member.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<cba>).
      LOOP AT <cba>-%target ASSIGNING FIELD-SYMBOL(<member>).
        IF <member>-MemberId IS NOT INITIAL.
          APPEND VALUE #( %cid     = <member>-%cid
                          MemberId = <member>-MemberId ) TO mapped-member.
          CONTINUE.
        ENDIF.
        TRY.
            APPEND VALUE #( %cid     = <member>-%cid
                            MemberId = cl_system_uuid=>create_uuid_x16_static( ) )
              TO mapped-member.
          CATCH cx_uuid_error.
            APPEND VALUE #( %cid = <member>-%cid ) TO failed-member.
        ENDTRY.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD create.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).
      DATA(ls_db) = CORRESPONDING zrpg_expedition( <entity> MAPPING FROM ENTITY ).
      DATA(lv_now) = utclong_current( ).
      ls_db-created_at            = lv_now.
      ls_db-created_by            = sy-uname.
      ls_db-last_changed_at       = lv_now.
      ls_db-last_changed_by       = sy-uname.
      ls_db-local_last_changed_at = lv_now.
      APPEND ls_db TO lcl_buffer=>mt_exp_create.
    ENDLOOP.
  ENDMETHOD.

  METHOD update.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).
      lcl_buffer=>read_expedition( EXPORTING iv_id    = <entity>-ExpeditionId
                                   IMPORTING es_data  = DATA(ls_current)
                                             ev_found = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <entity>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-expedition.
        CONTINUE.
      ENDIF.

      " Only fields flagged in %control are taken over from the request
      DATA(ls_new) = CORRESPONDING zrpg_expedition(
                       BASE ( ls_current ) <entity> MAPPING FROM ENTITY USING CONTROL ).
      ls_new-last_changed_at       = utclong_current( ).
      ls_new-last_changed_by       = sy-uname.
      ls_new-local_last_changed_at = ls_new-last_changed_at.
      lcl_buffer=>store_exp_update( ls_new ).
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      " A never-saved expedition just disappears from the create buffer
      DELETE lcl_buffer=>mt_exp_create WHERE expedition_id = <key>-ExpeditionId.
      IF sy-subrc = 0.
        DELETE lcl_buffer=>mt_mem_create WHERE expedition_id = <key>-ExpeditionId.
        CONTINUE.
      ENDIF.
      DELETE lcl_buffer=>mt_exp_update WHERE expedition_id = <key>-ExpeditionId.
      APPEND <key>-ExpeditionId TO lcl_buffer=>mt_exp_delete.
      " Composition: deleting the root takes its members with it
      DELETE lcl_buffer=>mt_mem_create WHERE expedition_id = <key>-ExpeditionId.
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lcl_buffer=>read_expedition( EXPORTING iv_id    = <key>-ExpeditionId
                                   IMPORTING es_data  = DATA(ls_data)
                                             ev_found = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <key>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-expedition.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = <key>-%tky ) TO result ASSIGNING FIELD-SYMBOL(<result>).
      <result> = CORRESPONDING #( BASE ( <result> ) ls_data MAPPING TO ENTITY ).
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.

    TRY.
        DATA(lo_lock) = cl_abap_lock_object_factory=>get_instance( iv_name = 'EZRPG_EXPED' ).
        LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
          TRY.
              lo_lock->enqueue(
                it_parameter = VALUE #( ( name  = 'EXPEDITION_ID'
                                          value = REF #( <key>-ExpeditionId ) ) ) ).
            CATCH cx_abap_foreign_lock.
              APPEND VALUE #( ExpeditionId = <key>-ExpeditionId
                               %fail-cause  = if_abap_behv=>cause-locked ) TO failed-expedition.
              APPEND VALUE #(
                ExpeditionId = <key>-ExpeditionId
                %msg = new_message_with_text(
                         severity = if_abap_behv_message=>severity-error
                         text     = 'The expedition is currently locked by another user.' )
              ) TO reported-expedition.
          ENDTRY.
        ENDLOOP.
      CATCH cx_abap_lock_failure.
        " Lock object missing or enqueue unavailable - proceed without lock
    ENDTRY.
  ENDMETHOD.

  METHOD cba_member.
    LOOP AT entities_cba ASSIGNING FIELD-SYMBOL(<cba>).
      lcl_buffer=>read_expedition( EXPORTING iv_id    = <cba>-ExpeditionId
                                   IMPORTING ev_found = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <cba>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-expedition.
        CONTINUE.
      ENDIF.

      LOOP AT <cba>-%target ASSIGNING FIELD-SYMBOL(<member>).
        DATA(ls_db) = CORRESPONDING zrpg_exp_members( <member> MAPPING FROM ENTITY ).
        ls_db-expedition_id         = <cba>-ExpeditionId.
        ls_db-local_last_changed_at = utclong_current( ).
        APPEND ls_db TO lcl_buffer=>mt_mem_create.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_member.
    LOOP AT keys_rba ASSIGNING FIELD-SYMBOL(<key>).
      DATA(lt_members) = lcl_buffer=>read_members( <key>-ExpeditionId ).
      LOOP AT lt_members INTO DATA(ls_member).
        INSERT VALUE #( source-%tky = <key>-%tky
                        target-%tky = VALUE #( MemberId = ls_member-member_id ) )
          INTO TABLE association_links.
        IF result_requested = abap_true.
          APPEND VALUE #( %tky-MemberId = ls_member-member_id )
            TO result ASSIGNING FIELD-SYMBOL(<result>).
          <result> = CORRESPONDING #( BASE ( <result> ) ls_member MAPPING TO ENTITY ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD update_member.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).
      lcl_buffer=>read_member( EXPORTING iv_id    = <entity>-MemberId
                               IMPORTING es_data  = DATA(ls_current)
                                         ev_found = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <entity>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-member.
        CONTINUE.
      ENDIF.

      " Only fields flagged in %control are taken over from the request
      DATA(ls_new) = CORRESPONDING zrpg_exp_members(
                       BASE ( ls_current ) <entity> MAPPING FROM ENTITY USING CONTROL ).
      ls_new-local_last_changed_at = utclong_current( ).
      lcl_buffer=>store_member_update( ls_new ).
    ENDLOOP.
  ENDMETHOD.

  METHOD read_member.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lcl_buffer=>read_member( EXPORTING iv_id    = <key>-MemberId
                               IMPORTING es_data  = DATA(ls_data)
                                         ev_found = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <key>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-member.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = <key>-%tky ) TO result ASSIGNING FIELD-SYMBOL(<result>).
      <result> = CORRESPONDING #( BASE ( <result> ) ls_data MAPPING TO ENTITY ).
    ENDLOOP.
  ENDMETHOD.

  METHOD delete_member.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DELETE lcl_buffer=>mt_mem_create WHERE member_id = <key>-MemberId.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
      DELETE lcl_buffer=>mt_mem_update WHERE member_id = <key>-MemberId.
      APPEND <key>-MemberId TO lcl_buffer=>mt_mem_delete.
    ENDLOOP.
  ENDMETHOD.

  METHOD resolveExpedition.

    IF go_dice_roller IS INITIAL.
      go_dice_roller = NEW zcl_rpg_roll_dice( ).
    ENDIF.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      lcl_buffer=>read_expedition( EXPORTING iv_id    = <key>-ExpeditionId
                                   IMPORTING es_data  = DATA(ls_exp)
                                             ev_found = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <key>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-expedition.
        CONTINUE.
      ENDIF.

      IF ls_exp-status <> c_status_planned.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-expedition.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Only a PLANNED expedition can be resolved.' )
        ) TO reported-expedition.
        CONTINUE.
      ENDIF.

      " Only the player who planned the expedition may resolve it
      IF zcl_rpg_ownership=>is_owner( ls_exp-created_by ) = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-expedition.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Only the player who planned this expedition can resolve it.' )
        ) TO reported-expedition.
        CONTINUE.
      ENDIF.

      DATA(lt_members) = lcl_buffer=>read_members( <key>-ExpeditionId ).
      IF lt_members IS INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-expedition.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Add at least one party member before resolving.' )
        ) TO reported-expedition.
        CONTINUE.
      ENDIF.

      " Every member rolls d20 + stat modifier against the expedition DC
      DATA(lv_successes) = 0.
      DATA(lv_reward_failed) = abap_false.

      LOOP AT lt_members ASSIGNING FIELD-SYMBOL(<member>).

        SELECT SINGLE adventurer_level, adventurer_xp,
                      adv_str, adv_dex, adv_con, adv_int, adv_wis, adv_cha
          FROM zrpg_adventurer
          WHERE adventurer_id = @<member>-adventurer_id
          INTO @DATA(ls_adv).
        IF sy-subrc <> 0.
          " Member references a deleted adventurer - counts as a failed check
          <member>-member_roll   = 0.
          <member>-member_total  = 0.
          <member>-member_passed = abap_false.
          lcl_buffer=>store_member_update( <member> ).
          CONTINUE.
        ENDIF.

        DATA(lv_modifier) = NEW zcl_rpg_stat_check( )->zif_rpg_quest_resolution~get_check_modifier(
                                iv_quest_stat       = ls_exp-required_stat
                                iv_adventurer_level = ls_adv-adventurer_level
                                iv_required_level   = ls_exp-required_level
                                iv_adventurer_str   = ls_adv-adv_str
                                iv_adventurer_dex   = ls_adv-adv_dex
                                iv_adventurer_con   = ls_adv-adv_con
                                iv_adventurer_int   = ls_adv-adv_int
                                iv_adventurer_wis   = ls_adv-adv_wis
                                iv_adventurer_cha   = ls_adv-adv_cha ).

        <member>-member_roll   = go_dice_roller->roll_dtwenty( ).
        <member>-member_total  = <member>-member_roll + lv_modifier.
        <member>-member_passed = xsdbool( <member>-member_total >= ls_exp-difficulty_class ).
        IF <member>-member_passed = abap_true.
          lv_successes += 1.
        ENDIF.
        lcl_buffer=>store_member_update( <member> ).
      ENDLOOP.

      " Majority of the party must pass
      DATA(lv_party_size) = lines( lt_members ).
      DATA(lv_won) = xsdbool( lv_successes * 2 >= lv_party_size ).

      IF lv_won = abap_true.
        " XP reward split evenly across the party, at least 1 each
        DATA(lv_xp_each) = ls_exp-xp_reward DIV lv_party_size.
        IF lv_xp_each < 1.
          lv_xp_each = 1.
        ENDIF.

        LOOP AT lt_members ASSIGNING <member>.
          lcl_buffer=>read_member( EXPORTING iv_id    = <member>-member_id
                                   IMPORTING es_data  = DATA(ls_member_now)
                                             ev_found = DATA(lv_member_found) ).
          IF lv_member_found = abap_false.
            CONTINUE.
          ENDIF.
          ls_member_now-xp_gained = lv_xp_each.
          lcl_buffer=>store_member_update( ls_member_now ).

          SELECT SINGLE adventurer_xp, adventurer_level
            FROM zrpg_adventurer
            WHERE adventurer_id = @ls_member_now-adventurer_id
            INTO @DATA(ls_progress).
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.

          " Keep in sync with the leveling rule in ZBP_I_RPG_QUEST
          DATA(lv_total_xp) = ls_progress-adventurer_xp + lv_xp_each.
          MODIFY ENTITIES OF zi_rpg_adventurer
            ENTITY Adventurer
              UPDATE FIELDS ( AdventurerXp AdventurerLevel )
              WITH VALUE #( ( AdventurerId    = ls_member_now-adventurer_id
                              AdventurerXp    = lv_total_xp MOD c_xp_per_level
                              AdventurerLevel = ls_progress-adventurer_level
                                              + lv_total_xp DIV c_xp_per_level ) )
            REPORTED DATA(reported_adv)
            FAILED   DATA(failed_adv).
          IF failed_adv-adventurer IS NOT INITIAL.
            lv_reward_failed = abap_true.
          ENDIF.
        ENDLOOP.

        IF lv_reward_failed = abap_true.
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-expedition.
          APPEND VALUE #(
            %tky = <key>-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = 'The XP rewards could not be applied - the expedition was not resolved.' )
          ) TO reported-expedition.
          CONTINUE.
        ENDIF.

        ls_exp-status = c_status_completed.
      ELSE.
        ls_exp-status = c_status_failed.
      ENDIF.

      ls_exp-successes       = lv_successes.
      ls_exp-last_changed_at = utclong_current( ).
      ls_exp-last_changed_by = sy-uname.
      lcl_buffer=>store_exp_update( ls_exp ).

      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
                 severity = COND #( WHEN lv_won = abap_true
                                    THEN if_abap_behv_message=>severity-success
                                    ELSE if_abap_behv_message=>severity-error )
                 text     = |Expedition { COND string( WHEN lv_won = abap_true
                                                       THEN 'succeeded' ELSE 'failed' ) }: |
                         && |{ lv_successes } of { lv_party_size } checks passed vs DC { ls_exp-difficulty_class }.| )
      ) TO reported-expedition.

    ENDLOOP.

    " Return the updated instances
    READ ENTITIES OF zi_rpg_expedition IN LOCAL MODE
      ENTITY Expedition ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR exp IN lt_result
                      ( %tky   = exp-%tky
                        %param = CORRESPONDING #( exp ) ) ).
  ENDMETHOD.

  METHOD validateQuest.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lcl_buffer=>read_expedition( EXPORTING iv_id    = <key>-ExpeditionId
                                   IMPORTING es_data  = DATA(ls_exp)
                                             ev_found = DATA(lv_found) ).
      CHECK lv_found = abap_true.

      SELECT SINGLE @abap_true FROM zrpg_quest
        WHERE quest_id = @ls_exp-quest_id
        INTO @DATA(lv_quest_exists).

      IF lv_quest_exists <> abap_true.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-expedition.
        APPEND VALUE #(
          %tky            = <key>-%tky
          %msg            = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = 'Choose an existing quest for the expedition.' )
          %element-QuestId = if_abap_behv=>mk-on
        ) TO reported-expedition.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMember.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lcl_buffer=>read_member( EXPORTING iv_id    = <key>-MemberId
                               IMPORTING es_data  = DATA(ls_member)
                                         ev_found = DATA(lv_found) ).
      CHECK lv_found = abap_true.

      DATA(lt_party) = lcl_buffer=>read_members( ls_member-expedition_id ).

      " Party size 1..4
      IF lines( lt_party ) > c_max_party_size.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-member.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |A party can have at most { c_max_party_size } members.| )
        ) TO reported-member.
        CONTINUE.
      ENDIF.

      " No adventurer twice in the same party
      LOOP AT lt_party TRANSPORTING NO FIELDS
        WHERE adventurer_id = ls_member-adventurer_id
          AND member_id    <> ls_member-member_id.
        EXIT.
      ENDLOOP.
      IF sy-subrc = 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-member.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'This adventurer is already in the party.' )
        ) TO reported-member.
        CONTINUE.
      ENDIF.

      " Member must exist and meet the expedition's level requirement
      SELECT SINGLE adventurer_name, adventurer_level
        FROM zrpg_adventurer
        WHERE adventurer_id = @ls_member-adventurer_id
        INTO @DATA(ls_adv).
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-member.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Choose an existing adventurer for the party.' )
        ) TO reported-member.
        CONTINUE.
      ENDIF.

      lcl_buffer=>read_expedition( EXPORTING iv_id    = ls_member-expedition_id
                                   IMPORTING es_data  = DATA(ls_exp)
                                             ev_found = DATA(lv_exp_found) ).
      IF lv_exp_found = abap_true AND ls_adv-adventurer_level < ls_exp-required_level.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-member.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |{ ls_adv-adventurer_name } must be level { ls_exp-required_level } for this expedition.| )
        ) TO reported-member.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD setInitialStatus.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lcl_buffer=>read_expedition( EXPORTING iv_id    = <key>-ExpeditionId
                                   IMPORTING es_data  = DATA(ls_exp)
                                             ev_found = DATA(lv_found) ).
      CHECK lv_found = abap_true AND ls_exp-status IS INITIAL.
      ls_exp-status = c_status_planned.
      lcl_buffer=>store_exp_update( ls_exp ).
    ENDLOOP.
  ENDMETHOD.

  METHOD deriveQuestReqs.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lcl_buffer=>read_expedition( EXPORTING iv_id    = <key>-ExpeditionId
                                   IMPORTING es_data  = DATA(ls_exp)
                                             ev_found = DATA(lv_found) ).
      CHECK lv_found = abap_true AND ls_exp-quest_id IS NOT INITIAL.

      SELECT SINGLE required_stat, required_level, difficulty_class, xp_reward
        FROM zrpg_quest
        WHERE quest_id = @ls_exp-quest_id
        INTO @DATA(ls_quest).
      CHECK sy-subrc = 0.

      ls_exp-required_stat    = ls_quest-required_stat.
      ls_exp-required_level   = ls_quest-required_level.
      ls_exp-difficulty_class = ls_quest-difficulty_class.
      ls_exp-xp_reward        = ls_quest-xp_reward.
      lcl_buffer=>store_exp_update( ls_exp ).
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_Expedition.
  ENDMETHOD.

ENDCLASS.


" Saver - persists the buffer.

CLASS lsc_zi_rpg_expedition DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save REDEFINITION.
    METHODS cleanup REDEFINITION.

ENDCLASS.


CLASS lsc_zi_rpg_expedition IMPLEMENTATION.

  METHOD save.
    IF lcl_buffer=>mt_exp_create IS NOT INITIAL.
      INSERT zrpg_expedition FROM TABLE @lcl_buffer=>mt_exp_create.
    ENDIF.
    IF lcl_buffer=>mt_exp_update IS NOT INITIAL.
      UPDATE zrpg_expedition FROM TABLE @lcl_buffer=>mt_exp_update.
    ENDIF.
    LOOP AT lcl_buffer=>mt_exp_delete INTO DATA(lv_exp_id).
      DELETE FROM zrpg_expedition WHERE expedition_id = @lv_exp_id.
      " Composition cascade: the root takes its members with it
      DELETE FROM zrpg_exp_members WHERE expedition_id = @lv_exp_id.
    ENDLOOP.

    IF lcl_buffer=>mt_mem_create IS NOT INITIAL.
      INSERT zrpg_exp_members FROM TABLE @lcl_buffer=>mt_mem_create.
    ENDIF.
    IF lcl_buffer=>mt_mem_update IS NOT INITIAL.
      UPDATE zrpg_exp_members FROM TABLE @lcl_buffer=>mt_mem_update.
    ENDIF.
    LOOP AT lcl_buffer=>mt_mem_delete INTO DATA(lv_mem_id).
      DELETE FROM zrpg_exp_members WHERE member_id = @lv_mem_id.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup.
    lcl_buffer=>clear( ).
  ENDMETHOD.

ENDCLASS.

