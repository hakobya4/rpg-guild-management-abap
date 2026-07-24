CLASS zcl_rpg_npc_ai DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "! Calls the Anthropic Messages API
    METHODS generate_flavor_text
      IMPORTING
                iv_npc_role           TYPE string
                iv_npc_race           TYPE string
                iv_npc_name           TYPE string
      RETURNING VALUE(rv_flavor_text) TYPE string
      RAISING   cx_static_check.
    METHODS generate_npc_name
      IMPORTING
                iv_npc_role        TYPE string
                iv_npc_race        TYPE string
      RETURNING VALUE(rv_npc_name) TYPE string
      RAISING   cx_static_check.

  PRIVATE SECTION.
    CONSTANTS c_base_url       TYPE string VALUE 'https://api.anthropic.com'.
    CONSTANTS c_anthropic_vers TYPE string VALUE '2023-06-01'.
    CONSTANTS c_model          TYPE string VALUE 'claude-haiku-4-5-20251001'.

    TYPES: BEGIN OF ty_content_block,
             type TYPE string,
             text TYPE string,
           END OF ty_content_block,
           tt_content_block TYPE STANDARD TABLE OF ty_content_block WITH EMPTY KEY.

    TYPES: BEGIN OF ty_claude_response,
             id      TYPE string,
             type    TYPE string,
             role    TYPE string,
             content TYPE tt_content_block,
           END OF ty_claude_response.

ENDCLASS.



CLASS zcl_rpg_npc_ai IMPLEMENTATION.

  METHOD generate_npc_name.
    SELECT SINGLE anthropic_api_key
       FROM zrpg_ai_config
       INTO @DATA(lv_api_key).

    IF sy-subrc <> 0 OR lv_api_key IS INITIAL.
      rv_npc_name = 'AI not configured - run ZCL_RPG_SET_AI_KEY first.'.
      RETURN.
    ENDIF.
    DATA(lv_npc_name_prompt) = |Generate a name for a character who's race is { iv_npc_race } | &&
                       |and who works as a { iv_npc_role } in a fantasy adventurers' guild town.|.

    DATA(ls_response) = VALUE ty_claude_response( ).

    " Build the JSON request body by serializing a plain ABAP structure -
    " much less error-prone than hand-building the JSON string.
    TYPES: BEGIN OF ty_message,
             role    TYPE string,
             content TYPE string,
           END OF ty_message,
           tt_message TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

    TYPES: BEGIN OF ty_claude_request,
             model      TYPE string,
             max_tokens TYPE i,
             messages   TYPE tt_message,
           END OF ty_claude_request.

    DATA(ls_claude_request) = VALUE ty_claude_request(
      model      = c_model
      max_tokens = 300
      messages   = VALUE #( ( role = 'user' content = lv_npc_name_prompt ) ) ).

    DATA(lv_request_json) = /ui2/cl_json=>serialize(
                               data             = ls_claude_request
                               compress         = abap_true
                               pretty_name      = /ui2/cl_json=>pretty_mode-low_case ).

    DATA(lo_destination) = cl_http_destination_provider=>create_by_url( c_base_url ).

    DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

    DATA(lo_request) = lo_client->get_http_request( ).
    lo_request->set_header_field( i_name = 'Content-Type'      i_value = 'application/json' ).
    lo_request->set_header_field( i_name = 'x-api-key'         i_value = CONV string( lv_api_key ) ).
    lo_request->set_header_field( i_name = 'anthropic-version' i_value = c_anthropic_vers ).
    lo_request->set_uri_path( '/v1/messages' ).
    lo_request->set_text( lv_request_json ).

    DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).

    DATA(lv_response_json) = lo_response->get_text( ).

    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_response_json
      CHANGING  data = ls_response ).

    IF lines( ls_response-content ) > 0.
      rv_npc_name = ls_response-content[ 1 ]-text.
    ELSE.
      " TEMPORARY DEBUG: surface exactly what came back instead of
      " silently returning an empty string.
      rv_npc_name = |[DEBUG] body: { lv_response_json }|.
    ENDIF.
  ENDMETHOD.

  METHOD generate_flavor_text.

    SELECT SINGLE anthropic_api_key
      FROM zrpg_ai_config
      INTO @DATA(lv_api_key).

    IF sy-subrc <> 0 OR lv_api_key IS INITIAL.
      rv_flavor_text = 'AI not configured - run ZCL_RPG_SET_AI_KEY first.'.
      RETURN.
    ENDIF.

    DATA(lv_prompt) = |Write a single short paragraph (2-3 sentences) of vivid | &&
                       |fantasy flavor text describing an NPC named { iv_npc_name } who's race is { iv_npc_race }| &&
                       |who works as a { iv_npc_role } in a fantasy adventurers' guild town. | &&
                       |Write only the description itself, no preamble.|.

    DATA(ls_response) = VALUE ty_claude_response( ).

    " Build the JSON request body by serializing a plain ABAP structure -
    " much less error-prone than hand-building the JSON string.
    TYPES: BEGIN OF ty_message,
             role    TYPE string,
             content TYPE string,
           END OF ty_message,
           tt_message TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

    TYPES: BEGIN OF ty_claude_request,
             model      TYPE string,
             max_tokens TYPE i,
             messages   TYPE tt_message,
           END OF ty_claude_request.

    DATA(ls_claude_request) = VALUE ty_claude_request(
      model      = c_model
      max_tokens = 300
      messages   = VALUE #( ( role = 'user' content = lv_prompt ) ) ).

    DATA(lv_request_json) = /ui2/cl_json=>serialize(
                               data             = ls_claude_request
                               compress         = abap_true
                               pretty_name      = /ui2/cl_json=>pretty_mode-low_case ).

    DATA(lo_destination) = cl_http_destination_provider=>create_by_url( c_base_url ).

    DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

    DATA(lo_request) = lo_client->get_http_request( ).
    lo_request->set_header_field( i_name = 'Content-Type'      i_value = 'application/json' ).
    lo_request->set_header_field( i_name = 'x-api-key'         i_value = CONV string( lv_api_key ) ).
    lo_request->set_header_field( i_name = 'anthropic-version' i_value = c_anthropic_vers ).
    lo_request->set_uri_path( '/v1/messages' ).
    lo_request->set_text( lv_request_json ).

    DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).

    DATA(lv_response_json) = lo_response->get_text( ).

    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_response_json
      CHANGING  data = ls_response ).

    IF lines( ls_response-content ) > 0.
      rv_flavor_text = ls_response-content[ 1 ]-text.
    ELSE.
      " TEMPORARY DEBUG: surface exactly what came back instead of
      " silently returning an empty string.
      rv_flavor_text = |[DEBUG] body: { lv_response_json }|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

