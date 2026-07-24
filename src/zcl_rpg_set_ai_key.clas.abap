CLASS zcl_rpg_set_ai_key DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_rpg_set_ai_key IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    DATA(lv_key) = ''.

    MODIFY zrpg_ai_config FROM @( VALUE #( client            = sy-mandt
                                            anthropic_api_key = lv_key ) ).

    IF sy-subrc = 0.
      out->write( 'API key saved.' ).
    ELSE.
      out->write( 'Save failed.' ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.

