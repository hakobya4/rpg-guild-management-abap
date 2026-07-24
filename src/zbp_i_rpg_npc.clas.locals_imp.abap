CLASS lhc_Npc DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.


    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Npc RESULT result.


    METHODS generateNPC FOR MODIFY
      IMPORTING keys FOR ACTION Npc~generateNPC RESULT result.


ENDCLASS.

CLASS lhc_Npc IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.



  METHOD generateNPC.
    "  call the LLM via the ABAP HTTP
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

    DATA(lv_npc_role) = <key>-%param-NpcRole.
      SELECT SINGLE npc_name, npc_role
      FROM zrpg_npc
      WHERE npc_id = @<key>-NpcId
      INTO @DATA(npc_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Npc.
        APPEND VALUE #(
          %tky                        = <key>-%tky
          %action-generateNPC = if_abap_behv=>mk-on
          %msg                        = new_message_with_text(
                                          severity = if_abap_behv_message=>severity-error
                                          text     = 'NPC not found.' )
        ) TO reported-Npc.
        CONTINUE.
      ENDIF.

      TRY.
          DATA(lv_npc_name) = NEW zcl_rpg_npc_ai( )->generate_npc_name(
                                    iv_npc_race = CONV #( npc_data-npc_name )
                                    iv_npc_role = CONV #( npc_data-npc_role ) ).
          IF lv_npc_name IS NOT INITIAL.
            DATA(lv_flavor_text) = NEW zcl_rpg_npc_ai( )->generate_flavor_text(
                                    iv_npc_name = lv_npc_name
                                    iv_npc_race = CONV #( npc_data-npc_name )
                                    iv_npc_role = CONV #( npc_data-npc_role ) ).

             MODIFY ENTITIES OF zi_rpg_npc IN LOCAL MODE
            ENTITY Npc
              UPDATE FIELDS ( NpcName FlavorText )
              WITH VALUE #( ( NpcId      = <key>-NpcId
                              NpcName    = lv_npc_name
                              FlavorText = lv_flavor_text ) )
            FAILED   DATA(fail_npc)
            REPORTED DATA(rep_npc).

          APPEND VALUE #(
            %tky = <key>-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-success
                     text     = 'Flavor text generated.' )
          ) TO reported-Npc.


          ENDIF.
       CATCH cx_static_check INTO DATA(lx_error).
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-Npc.
          APPEND VALUE #(
            %tky                        = <key>-%tky
            %action-generateNPC = if_abap_behv=>mk-on
            %msg                        = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = |AI call failed: { lx_error->get_text( ) }| )
          ) TO reported-Npc.

      ENDTRY.
    ENDLOOP.

    READ ENTITIES OF zi_rpg_npc IN LOCAL MODE
      ENTITY Npc ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_npcs).

    result = VALUE #( FOR npc IN result_npcs
                      ( %tky   = npc-%tky
                        %param = CORRESPONDING #( npc ) ) ).
  ENDMETHOD.

ENDCLASS.
