CLASS zcl_rpg_test_flavor_ai DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_rpg_test_flavor_ai IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    TRY.
        DATA(lv_text) = NEW zcl_rpg_npc_flavor_ai( )->generate_flavor_text(
                          iv_npc_name = 'Borin Ashhammer'
                          iv_npc_role = 'Blacksmith' ).
        out->write( lv_text ).
      CATCH cx_static_check INTO DATA(lx_error).
        out->write( |Exception class: { cl_abap_typedescr=>describe_by_object_ref( lx_error )->get_relative_name( ) }| ).
        out->write( |Message: { lx_error->get_text( ) }| ).

        IF lx_error->previous IS BOUND.
          out->write( |Previous exception class: { cl_abap_typedescr=>describe_by_object_ref( lx_error->previous )->get_relative_name( ) }| ).
          out->write( |Previous message: { lx_error->previous->get_text( ) }| ).
        ENDIF.

        TRY.
            DATA(lo_t100) = CAST if_t100_message( lx_error ).
            out->write( |T100 message class: { lo_t100->t100key-msgid } | &&
                        |number: { lo_t100->t100key-msgno } | &&
                        |attr1: { lo_t100->t100key-attr1 }| ).
          CATCH cx_sy_move_cast_error.
            out->write( 'Exception does not carry a T100 message.' ).
        ENDTRY.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
