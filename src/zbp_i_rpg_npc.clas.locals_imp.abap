CLASS lhc_Npc DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Npc RESULT result.

    METHODS generateNPC FOR MODIFY
      IMPORTING keys FOR ACTION Npc~generateNPC RESULT result.

    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Npc.

ENDCLASS.

CLASS lhc_Npc IMPLEMENTATION.


  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.

  METHOD precheck_delete.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      SELECT SINGLE quest_name
        FROM zrpg_quest
        WHERE npc_id = @<key>-NpcId
        INTO @DATA(lv_quest_name).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Npc.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |This NPC owns quest '{ lv_quest_name }' and cannot be deleted until that quest is deleted or reassigned.| )
        ) TO reported-Npc.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD generateNPC.

    DATA lt_create TYPE TABLE FOR CREATE zi_rpg_npc\\Npc.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      DATA(lv_npc_role) = <key>-%param-NpcRole.
      DATA(lv_npc_race) = <key>-%param-NpcRace.

      IF lv_npc_role IS INITIAL OR lv_npc_race IS INITIAL.
        APPEND VALUE #( %cid = <key>-%cid ) TO failed-Npc.
        APPEND VALUE #(
          %cid = <key>-%cid
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Please select both a race and a role.' )
        ) TO reported-Npc.
        CONTINUE.
      ENDIF.


      TRY.
          DATA(ls_generated) = NEW zcl_rpg_npc_ai( )->generate_npc(
                                    iv_npc_race = CONV #( lv_npc_race )
                                    iv_npc_role = CONV #( lv_npc_role ) ).


          APPEND VALUE #(
            %cid       = <key>-%cid
            NpcName    = ls_generated-npc_name
            NpcRace    = lv_npc_race
            NpcRole    = lv_npc_role
            FlavorText = ls_generated-flavor_text
          ) TO lt_create.

        CATCH cx_static_check INTO DATA(lx_error).
          APPEND VALUE #( %cid = <key>-%cid ) TO failed-Npc.
          APPEND VALUE #(
            %cid = <key>-%cid
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = |AI call failed: { lx_error->get_text( ) }| )
          ) TO reported-Npc.
      ENDTRY.

    ENDLOOP.

    CHECK lt_create IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_npc IN LOCAL MODE
      ENTITY Npc
        CREATE FIELDS ( NpcName NpcRace NpcRole FlavorText )
        WITH lt_create
      MAPPED   DATA(ls_create_mapped)
      FAILED   DATA(failed_create)
      REPORTED DATA(reported_create).

    failed-Npc   = CORRESPONDING #( BASE ( failed-Npc ) failed_create-Npc ).
    reported-Npc = CORRESPONDING #( BASE ( reported-Npc ) reported_create-Npc ).

    READ ENTITIES OF zi_rpg_npc IN LOCAL MODE
      ENTITY Npc ALL FIELDS
        WITH VALUE #( FOR ls_m IN ls_create_mapped-npc ( %tky = CORRESPONDING #( ls_m-%pky ) ) )
      RESULT DATA(created_npcs).

    LOOP AT ls_create_mapped-npc INTO DATA(ls_mapped).
      READ TABLE created_npcs WITH KEY NpcId = ls_mapped-%pky-NpcId INTO DATA(ls_created_npc).
      APPEND VALUE #(
        %cid   = ls_mapped-%cid
        %param = COND #( WHEN sy-subrc = 0
                          THEN CORRESPONDING #( ls_created_npc )
                          ELSE VALUE #( NpcId = ls_mapped-%pky-NpcId ) )
      ) TO result.


      APPEND VALUE #(
        %cid = ls_mapped-%cid
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = 'NPC generated.' )
      ) TO reported-Npc.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

