* Fully unmanaged behavior implementation for ZI_RPG_EXPEDITION.

CLASS lcl_buffer DEFINITION FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES tt_expedition   TYPE STANDARD TABLE OF zrpg_expedition WITH EMPTY KEY.
    TYPES tt_member       TYPE STANDARD TABLE OF zrpg_exp_members WITH EMPTY KEY.
    TYPES tt_uuid         TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    TYPES tt_expedition_d TYPE STANDARD TABLE OF zrpg_exped_d   WITH EMPTY KEY.
    TYPES tt_member_d     TYPE STANDARD TABLE OF zrpg_exp_mem_d WITH EMPTY KEY.

    CLASS-DATA mt_exp_create TYPE tt_expedition.
    CLASS-DATA mt_exp_update TYPE tt_expedition.
    CLASS-DATA mt_exp_delete TYPE tt_uuid.
    CLASS-DATA mt_mem_create TYPE tt_member.
    CLASS-DATA mt_mem_update TYPE tt_member.
    CLASS-DATA mt_mem_delete TYPE tt_uuid.


    CLASS-DATA mt_exp_create_d TYPE tt_expedition_d.
    CLASS-DATA mt_exp_update_d TYPE tt_expedition_d.
    CLASS-DATA mt_exp_delete_d TYPE tt_uuid.
    CLASS-DATA mt_mem_create_d TYPE tt_member_d.
    CLASS-DATA mt_mem_update_d TYPE tt_member_d.
    CLASS-DATA mt_mem_delete_d TYPE tt_uuid.

    CLASS-METHODS read_expedition
      IMPORTING iv_id       TYPE sysuuid_x16
                iv_is_draft TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off
      EXPORTING es_data     TYPE zrpg_expedition
                ev_found    TYPE abap_bool.

    " Buffers a brand-new expedition row (create-only, no existing row to merge)
    CLASS-METHODS store_exp_create
      IMPORTING is_data     TYPE zrpg_expedition
                iv_is_draft TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off.

    "  changed expedition into a table
    CLASS-METHODS store_exp_update
      IMPORTING is_data     TYPE zrpg_expedition
                iv_is_draft TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off.

    " Merged view of one member - draft or active, same output shape
    CLASS-METHODS read_member
      IMPORTING iv_id       TYPE sysuuid_x16
                iv_is_draft TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off
      EXPORTING es_data     TYPE zrpg_exp_members
                ev_found    TYPE abap_bool.

    " Buffers a brand-new member row (create-only, no existing row to merge)
    CLASS-METHODS store_member_create
      IMPORTING is_data     TYPE zrpg_exp_members
                iv_is_draft TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off.

    " Upserts a changed member into the right buffer table
    CLASS-METHODS store_member_update
      IMPORTING is_data     TYPE zrpg_exp_members
                iv_is_draft TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off.

    " Merged member list of one expedition (DB + buffer, minus deletions)
    CLASS-METHODS read_members
      IMPORTING iv_expedition_id  TYPE sysuuid_x16
                iv_is_draft       TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off
      RETURNING VALUE(rt_members) TYPE tt_member.

    CLASS-METHODS clear.

  PRIVATE SECTION.
    " Field-by-field conversions - active table columns are snake_case
    " (expedition_id), draft table columns match the entity element names
    " with no separators (EXPEDITIONID), so plain CORRESPONDING can't
    " bridge the two; every field is mapped explicitly here instead.
    CLASS-METHODS to_active_exp
      IMPORTING is_draft        TYPE zrpg_exped_d
      RETURNING VALUE(rs_active) TYPE zrpg_expedition.
    CLASS-METHODS to_draft_exp
      IMPORTING is_active     TYPE zrpg_expedition
      RETURNING VALUE(rs_draft) TYPE zrpg_exped_d.
    CLASS-METHODS to_active_mem
      IMPORTING is_draft        TYPE zrpg_exp_mem_d
      RETURNING VALUE(rs_active) TYPE zrpg_exp_members.
    CLASS-METHODS to_draft_mem
      IMPORTING is_active     TYPE zrpg_exp_members
      RETURNING VALUE(rs_draft) TYPE zrpg_exp_mem_d.

ENDCLASS.


CLASS lcl_buffer IMPLEMENTATION.

  METHOD to_active_exp.
    rs_active-expedition_id         = is_draft-expeditionid.
    rs_active-expedition_name       = is_draft-expeditionname.
    rs_active-quest_id              = is_draft-questid.
    rs_active-status                = is_draft-status.
    rs_active-required_stat         = is_draft-requiredstat.
    rs_active-required_level        = is_draft-requiredlevel.
    rs_active-difficulty_class      = is_draft-difficultyclass.
    rs_active-xp_reward             = is_draft-xpreward.
    rs_active-successes             = is_draft-successes.
    rs_active-created_at            = is_draft-createdat.
    rs_active-created_by            = is_draft-createdby.
    rs_active-last_changed_at       = is_draft-lastchangedat.
    rs_active-last_changed_by       = is_draft-lastchangedby.
    rs_active-local_last_changed_at = is_draft-locallastchangedat.
  ENDMETHOD.

  METHOD to_draft_exp.
    rs_draft-expeditionid       = is_active-expedition_id.
    rs_draft-expeditionname     = is_active-expedition_name.
    rs_draft-questid            = is_active-quest_id.
    rs_draft-status             = is_active-status.
    rs_draft-requiredstat       = is_active-required_stat.
    rs_draft-requiredlevel      = is_active-required_level.
    rs_draft-difficultyclass    = is_active-difficulty_class.
    rs_draft-xpreward           = is_active-xp_reward.
    rs_draft-successes          = is_active-successes.
    rs_draft-createdat          = is_active-created_at.
    rs_draft-createdby          = is_active-created_by.
    rs_draft-lastchangedat      = is_active-last_changed_at.
    rs_draft-lastchangedby      = is_active-last_changed_by.
    rs_draft-locallastchangedat = is_active-local_last_changed_at.
  ENDMETHOD.

  METHOD to_active_mem.
    rs_active-member_id             = is_draft-memberid.
    rs_active-expedition_id         = is_draft-expeditionid.
    rs_active-adventurer_id         = is_draft-adventurerid.
    rs_active-member_roll           = is_draft-memberroll.
    rs_active-member_total          = is_draft-membertotal.
    rs_active-member_passed         = is_draft-memberpassed.
    rs_active-xp_gained             = is_draft-xpgained.
    rs_active-local_last_changed_at = is_draft-locallastchangedat.
  ENDMETHOD.

  METHOD to_draft_mem.
    rs_draft-memberid           = is_active-member_id.
    rs_draft-expeditionid       = is_active-expedition_id.
    rs_draft-adventurerid       = is_active-adventurer_id.
    rs_draft-memberroll         = is_active-member_roll.
    rs_draft-membertotal        = is_active-member_total.
    rs_draft-memberpassed       = is_active-member_passed.
    rs_draft-xpgained           = is_active-xp_gained.
    rs_draft-locallastchangedat = is_active-local_last_changed_at.
  ENDMETHOD.

  METHOD read_expedition.
    " Checks draft AND active storage regardless of iv_is_draft - determinations
    " have been observed receiving an %is_draft value that doesn't reliably
    " match if_abap_behv=>mk-on even for a genuine draft-create, so the read
    " path no longer trusts that flag; it just looks everywhere a row could be.
    CLEAR: es_data, ev_found.

    IF line_exists( mt_exp_delete_d[ table_line = iv_id ] )
    OR line_exists( mt_exp_delete[ table_line = iv_id ] ).
      RETURN.
    ENDIF.

    READ TABLE mt_exp_create_d INTO DATA(ls_draft) WITH KEY expeditionid = iv_id.
    IF sy-subrc = 0.
      es_data  = to_active_exp( ls_draft ).
      ev_found = abap_true.
      RETURN.
    ENDIF.

    READ TABLE mt_exp_update_d INTO ls_draft WITH KEY expeditionid = iv_id.
    IF sy-subrc = 0.
      es_data  = to_active_exp( ls_draft ).
      ev_found = abap_true.
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

    SELECT SINGLE * FROM zrpg_exped_d
      WHERE expeditionid = @iv_id
      INTO @ls_draft.
    IF sy-subrc = 0.
      es_data  = to_active_exp( ls_draft ).
      ev_found = abap_true.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrpg_expedition
      WHERE expedition_id = @iv_id
      INTO @es_data.
    ev_found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD store_exp_create.
    IF iv_is_draft = if_abap_behv=>mk-on.
      APPEND to_draft_exp( is_data ) TO mt_exp_create_d.
    ELSE.
      APPEND is_data TO mt_exp_create.
    ENDIF.
  ENDMETHOD.

  METHOD store_exp_update.
    " Update whichever buffer the row is CURRENTLY sitting in, rather than
    " trusting iv_is_draft - see the note on read_expedition. Only falls
    " back to iv_is_draft to pick a destination when the row isn't found
    " buffered anywhere yet (first update after a plain DB read).
    DATA(ls_draft) = to_draft_exp( is_data ).

    READ TABLE mt_exp_create_d ASSIGNING FIELD-SYMBOL(<create_d>)
      WITH KEY expeditionid = ls_draft-expeditionid.
    IF sy-subrc = 0.
      <create_d> = ls_draft.
      RETURN.
    ENDIF.

    READ TABLE mt_exp_update_d ASSIGNING FIELD-SYMBOL(<update_d>)
      WITH KEY expeditionid = ls_draft-expeditionid.
    IF sy-subrc = 0.
      <update_d> = ls_draft.
      RETURN.
    ENDIF.

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
      RETURN.
    ENDIF.

    " Not buffered yet anywhere - fall back to the caller's hint
    IF iv_is_draft = if_abap_behv=>mk-on.
      APPEND ls_draft TO mt_exp_update_d.
    ELSE.
      APPEND is_data TO mt_exp_update.
    ENDIF.
  ENDMETHOD.

  METHOD read_member.
    " See read_expedition - checks draft AND active storage regardless of
    " iv_is_draft, since that flag isn't reliable in every calling context.
    CLEAR: es_data, ev_found.

    IF line_exists( mt_mem_delete_d[ table_line = iv_id ] )
    OR line_exists( mt_mem_delete[ table_line = iv_id ] ).
      RETURN.
    ENDIF.

    READ TABLE mt_mem_create_d INTO DATA(ls_draft) WITH KEY memberid = iv_id.
    IF sy-subrc = 0.
      es_data  = to_active_mem( ls_draft ).
      ev_found = abap_true.
      RETURN.
    ENDIF.

    READ TABLE mt_mem_update_d INTO ls_draft WITH KEY memberid = iv_id.
    IF sy-subrc = 0.
      es_data  = to_active_mem( ls_draft ).
      ev_found = abap_true.
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

    SELECT SINGLE * FROM zrpg_exp_mem_d
      WHERE memberid = @iv_id
      INTO @ls_draft.
    IF sy-subrc = 0.
      es_data  = to_active_mem( ls_draft ).
      ev_found = abap_true.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrpg_exp_members
      WHERE member_id = @iv_id
      INTO @es_data.
    ev_found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD store_member_create.
    IF iv_is_draft = if_abap_behv=>mk-on.
      APPEND to_draft_mem( is_data ) TO mt_mem_create_d.
    ELSE.
      APPEND is_data TO mt_mem_create.
    ENDIF.
  ENDMETHOD.

  METHOD store_member_update.
    " See store_exp_update - updates whichever buffer the row is currently
    " in, only falling back to iv_is_draft if it isn't buffered anywhere yet.
    DATA(ls_draft) = to_draft_mem( is_data ).

    READ TABLE mt_mem_create_d ASSIGNING FIELD-SYMBOL(<create_d>)
      WITH KEY memberid = ls_draft-memberid.
    IF sy-subrc = 0.
      <create_d> = ls_draft.
      RETURN.
    ENDIF.

    READ TABLE mt_mem_update_d ASSIGNING FIELD-SYMBOL(<update_d>)
      WITH KEY memberid = ls_draft-memberid.
    IF sy-subrc = 0.
      <update_d> = ls_draft.
      RETURN.
    ENDIF.

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
      RETURN.
    ENDIF.

    IF iv_is_draft = if_abap_behv=>mk-on.
      APPEND ls_draft TO mt_mem_update_d.
    ELSE.
      APPEND is_data TO mt_mem_update.
    ENDIF.
  ENDMETHOD.

  METHOD read_members.
    " Merges the draft-side view AND the active-side view regardless of
    " iv_is_draft (see read_expedition) - a given member only ever lives in
    " one representation in practice, so combining both is safe and avoids
    " depending on a flag that isn't reliable in every calling context.
    CLEAR rt_members.

    DATA lt_draft TYPE tt_member_d.

    SELECT * FROM zrpg_exp_mem_d
      WHERE expeditionid = @iv_expedition_id
      INTO TABLE @lt_draft.

    LOOP AT mt_mem_update_d INTO DATA(ls_update_d) WHERE expeditionid = iv_expedition_id.
      READ TABLE lt_draft ASSIGNING FIELD-SYMBOL(<row_d>)
        WITH KEY memberid = ls_update_d-memberid.
      IF sy-subrc = 0.
        <row_d> = ls_update_d.
      ELSE.
        APPEND ls_update_d TO lt_draft.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_draft ASSIGNING <row_d>.
      IF line_exists( mt_mem_delete_d[ table_line = <row_d>-memberid ] ).
        DELETE lt_draft USING KEY loop_key.
      ENDIF.
    ENDLOOP.

    LOOP AT mt_mem_create_d INTO DATA(ls_create_d) WHERE expeditionid = iv_expedition_id.
      APPEND ls_create_d TO lt_draft.
    ENDLOOP.

    LOOP AT lt_draft INTO DATA(ls_draft_row).
      APPEND to_active_mem( ls_draft_row ) TO rt_members.
    ENDLOOP.

    SELECT * FROM zrpg_exp_members
      WHERE expedition_id = @iv_expedition_id
      INTO TABLE @DATA(lt_active).

    " Apply pending updates over the persisted state
    LOOP AT mt_mem_update INTO DATA(ls_update) WHERE expedition_id = iv_expedition_id.
      READ TABLE lt_active ASSIGNING FIELD-SYMBOL(<row>)
        WITH KEY member_id = ls_update-member_id.
      IF sy-subrc = 0.
        <row> = ls_update.
      ELSE.
        APPEND ls_update TO lt_active.
      ENDIF.
    ENDLOOP.

    " Remove pending deletions
    LOOP AT lt_active ASSIGNING <row>.
      IF line_exists( mt_mem_delete[ table_line = <row>-member_id ] ).
        DELETE lt_active USING KEY loop_key.
      ENDIF.
    ENDLOOP.

    " Add unsaved new members
    LOOP AT mt_mem_create INTO DATA(ls_create) WHERE expedition_id = iv_expedition_id.
      APPEND ls_create TO lt_active.
    ENDLOOP.

    APPEND LINES OF lt_active TO rt_members.
  ENDMETHOD.

  METHOD clear.
    CLEAR: mt_exp_create, mt_exp_update, mt_exp_delete,
           mt_mem_create, mt_mem_update, mt_mem_delete,
           mt_exp_create_d, mt_exp_update_d, mt_exp_delete_d,
           mt_mem_create_d, mt_mem_update_d, mt_mem_delete_d.
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
                        %is_draft    = <entity>-%is_draft
                        ExpeditionId = <entity>-ExpeditionId ) TO mapped-expedition.
        CONTINUE.
      ENDIF.
      TRY.
          APPEND VALUE #( %cid         = <entity>-%cid
                          %is_draft    = <entity>-%is_draft
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
          APPEND VALUE #( %cid      = <member>-%cid
                          %is_draft = <member>-%is_draft
                          MemberId  = <member>-MemberId ) TO mapped-member.
          CONTINUE.
        ENDIF.
        TRY.
            APPEND VALUE #( %cid      = <member>-%cid
                            %is_draft = <member>-%is_draft
                            MemberId  = cl_system_uuid=>create_uuid_x16_static( ) )
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

      lcl_buffer=>store_exp_create( is_data = ls_db iv_is_draft = <entity>-%is_draft ).
    ENDLOOP.
  ENDMETHOD.

  METHOD update.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).
      lcl_buffer=>read_expedition( EXPORTING iv_id       = <entity>-ExpeditionId
                                             iv_is_draft = <entity>-%is_draft
                                   IMPORTING es_data     = DATA(ls_current)
                                             ev_found    = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <entity>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-expedition.
        CONTINUE.
      ENDIF.

      IF <entity>-%is_draft = if_abap_behv=>mk-on.
        " Only ExpeditionName/QuestId are ever user-editable (everything
        " else is field(readonly)) - no "mapping for" clause exists for the
        " draft table, so %control is applied by hand instead of USING CONTROL
        IF <entity>-%control-ExpeditionName = if_abap_behv=>mk-on.
          ls_current-expedition_name = <entity>-ExpeditionName.
        ENDIF.
        IF <entity>-%control-QuestId = if_abap_behv=>mk-on.
          ls_current-quest_id = <entity>-QuestId.
        ENDIF.
        ls_current-last_changed_at       = utclong_current( ).
        ls_current-last_changed_by       = sy-uname.
        ls_current-local_last_changed_at = ls_current-last_changed_at.
        lcl_buffer=>store_exp_update( is_data = ls_current iv_is_draft = if_abap_behv=>mk-on ).
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
      IF <key>-%is_draft = if_abap_behv=>mk-on.
        " A never-saved draft just disappears from the draft-create buffer
        DELETE lcl_buffer=>mt_exp_create_d WHERE expeditionid = <key>-ExpeditionId.
        IF sy-subrc = 0.
          DELETE lcl_buffer=>mt_mem_create_d WHERE expeditionid = <key>-ExpeditionId.
          CONTINUE.
        ENDIF.
        DELETE lcl_buffer=>mt_exp_update_d WHERE expeditionid = <key>-ExpeditionId.
        APPEND <key>-ExpeditionId TO lcl_buffer=>mt_exp_delete_d.
        DELETE lcl_buffer=>mt_mem_create_d WHERE expeditionid = <key>-ExpeditionId.
        CONTINUE.
      ENDIF.

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
      lcl_buffer=>read_expedition( EXPORTING iv_id       = <key>-ExpeditionId
                                             iv_is_draft = <key>-%is_draft
                                   IMPORTING es_data     = DATA(ls_data)
                                             ev_found    = DATA(lv_found) ).
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
      lcl_buffer=>read_expedition( EXPORTING iv_id       = <cba>-ExpeditionId
                                             iv_is_draft = <cba>-%is_draft
                                   IMPORTING ev_found    = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <cba>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-expedition.
        CONTINUE.
      ENDIF.

      LOOP AT <cba>-%target ASSIGNING FIELD-SYMBOL(<member>).
        DATA(ls_db) = CORRESPONDING zrpg_exp_members( <member> MAPPING FROM ENTITY ).
        ls_db-expedition_id         = <cba>-ExpeditionId.
        ls_db-local_last_changed_at = utclong_current( ).

        lcl_buffer=>store_member_create( is_data = ls_db iv_is_draft = <cba>-%is_draft ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_member.
    LOOP AT keys_rba ASSIGNING FIELD-SYMBOL(<key>).
      DATA(lt_members) = lcl_buffer=>read_members( iv_expedition_id = <key>-ExpeditionId
                                                    iv_is_draft      = <key>-%is_draft ).
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
      lcl_buffer=>read_member( EXPORTING iv_id       = <entity>-MemberId
                                         iv_is_draft = <entity>-%is_draft
                               IMPORTING es_data     = DATA(ls_current)
                                         ev_found    = DATA(lv_found) ).
      IF lv_found = abap_false.
        APPEND VALUE #( %tky        = <entity>-%tky
                        %fail-cause = if_abap_behv=>cause-not_found ) TO failed-member.
        CONTINUE.
      ENDIF.

      IF <entity>-%is_draft = if_abap_behv=>mk-on.
        " Only AdventurerId is ever user-editable, and only at create - no
        " "mapping for" clause exists for the draft table, so %control is
        " applied by hand instead of USING CONTROL
        IF <entity>-%control-AdventurerId = if_abap_behv=>mk-on.
          ls_current-adventurer_id = <entity>-AdventurerId.
        ENDIF.
        ls_current-local_last_changed_at = utclong_current( ).
        lcl_buffer=>store_member_update( is_data = ls_current iv_is_draft = if_abap_behv=>mk-on ).
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
      lcl_buffer=>read_member( EXPORTING iv_id       = <key>-MemberId
                                         iv_is_draft = <key>-%is_draft
                               IMPORTING es_data     = DATA(ls_data)
                                         ev_found    = DATA(lv_found) ).
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
      IF <key>-%is_draft = if_abap_behv=>mk-on.
        DELETE lcl_buffer=>mt_mem_create_d WHERE memberid = <key>-MemberId.
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.
        DELETE lcl_buffer=>mt_mem_update_d WHERE memberid = <key>-MemberId.
        APPEND <key>-MemberId TO lcl_buffer=>mt_mem_delete_d.
        CONTINUE.
      ENDIF.

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

      IF <key>-%is_draft = if_abap_behv=>mk-on.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-expedition.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Only an activated expedition can be resolved.' )
        ) TO reported-expedition.
        CONTINUE.
      ENDIF.

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
      lcl_buffer=>read_expedition( EXPORTING iv_id       = <key>-ExpeditionId
                                             iv_is_draft = <key>-%is_draft
                                   IMPORTING es_data     = DATA(ls_exp)
                                             ev_found    = DATA(lv_found) ).
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
      lcl_buffer=>read_member( EXPORTING iv_id       = <key>-MemberId
                                         iv_is_draft = <key>-%is_draft
                               IMPORTING es_data     = DATA(ls_member)
                                         ev_found    = DATA(lv_found) ).
      CHECK lv_found = abap_true.

      DATA(lt_party) = lcl_buffer=>read_members( iv_expedition_id = ls_member-expedition_id
                                                  iv_is_draft      = <key>-%is_draft ).

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

      lcl_buffer=>read_expedition( EXPORTING iv_id       = ls_member-expedition_id
                                             iv_is_draft = <key>-%is_draft
                                   IMPORTING es_data     = DATA(ls_exp)
                                             ev_found    = DATA(lv_exp_found) ).
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
      lcl_buffer=>read_expedition( EXPORTING iv_id       = <key>-ExpeditionId
                                             iv_is_draft = <key>-%is_draft
                                   IMPORTING es_data     = DATA(ls_exp)
                                             ev_found    = DATA(lv_found) ).
      CHECK lv_found = abap_true AND ls_exp-status IS INITIAL.
      ls_exp-status = c_status_planned.
      lcl_buffer=>store_exp_update( is_data = ls_exp iv_is_draft = <key>-%is_draft ).
    ENDLOOP.
  ENDMETHOD.

  METHOD deriveQuestReqs.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      lcl_buffer=>read_expedition( EXPORTING iv_id       = <key>-ExpeditionId
                                             iv_is_draft = <key>-%is_draft
                                   IMPORTING es_data     = DATA(ls_exp)
                                             ev_found    = DATA(lv_found) ).
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
      lcl_buffer=>store_exp_update( is_data = ls_exp iv_is_draft = <key>-%is_draft ).
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

    " Draft-side persistence - durable storage for an expedition/party still
    " being edited across separate requests, before Activate
    IF lcl_buffer=>mt_exp_create_d IS NOT INITIAL.
      INSERT zrpg_exped_d FROM TABLE @lcl_buffer=>mt_exp_create_d.
    ENDIF.
    IF lcl_buffer=>mt_exp_update_d IS NOT INITIAL.
      UPDATE zrpg_exped_d FROM TABLE @lcl_buffer=>mt_exp_update_d.
    ENDIF.
    LOOP AT lcl_buffer=>mt_exp_delete_d INTO DATA(lv_exp_id_d).
      DELETE FROM zrpg_exped_d WHERE expeditionid = @lv_exp_id_d.
      DELETE FROM zrpg_exp_mem_d WHERE expeditionid = @lv_exp_id_d.
    ENDLOOP.

    IF lcl_buffer=>mt_mem_create_d IS NOT INITIAL.
      INSERT zrpg_exp_mem_d FROM TABLE @lcl_buffer=>mt_mem_create_d.
    ENDIF.
    IF lcl_buffer=>mt_mem_update_d IS NOT INITIAL.
      UPDATE zrpg_exp_mem_d FROM TABLE @lcl_buffer=>mt_mem_update_d.
    ENDIF.
    LOOP AT lcl_buffer=>mt_mem_delete_d INTO DATA(lv_mem_id_d).
      DELETE FROM zrpg_exp_mem_d WHERE memberid = @lv_mem_id_d.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup.
    lcl_buffer=>clear( ).
  ENDMETHOD.

ENDCLASS.


