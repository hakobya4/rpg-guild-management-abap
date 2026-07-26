CLASS zcl_rpg_quest_ai DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_quest_details,
             quest_name       TYPE string,
             description      TYPE string,
             required_stat    TYPE string,
             difficulty_class TYPE i,
             required_level   TYPE i,
             xp_reward        TYPE i,
             gold_reward      TYPE i,
           END OF ty_quest_details.

    "! Calls the Anthropic Messages API to design a full quest tailored to an NPC
    METHODS generate_quest_details
      IMPORTING
                iv_npc_name        TYPE string OPTIONAL
                iv_npc_race        TYPE string OPTIONAL
                iv_npc_role        TYPE string OPTIONAL
                iv_npc_flavor_text TYPE string OPTIONAL
      RETURNING VALUE(rs_quest)    TYPE ty_quest_details
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



CLASS zcl_rpg_quest_ai IMPLEMENTATION.

  METHOD generate_quest_details.

    SELECT SINGLE anthropic_api_key
      FROM zrpg_ai_config
      INTO @DATA(lv_api_key).

    IF sy-subrc <> 0 OR lv_api_key IS INITIAL.
      rs_quest-quest_name = 'AI not configured - run ZCL_RPG_SET_AI_KEY first.'.
      RETURN.
    ENDIF.

    DATA(lv_context) = COND string(
      WHEN iv_npc_name IS NOT INITIAL
        THEN |Design a short fantasy quest given out by an NPC named { iv_npc_name }, | &&
             |a { iv_npc_race } { iv_npc_role } described as: { iv_npc_flavor_text }.|
        ELSE |Design a short, dangerous fantasy expedition quest for a full party of | &&
             |adventurers to undertake together, posted on a guild's expedition board.| ).

    DATA(lv_prompt) =
      |{ lv_context } | &&
      |Reply with ONLY a single JSON object, no markdown code fences, no preamble, | &&
      |with exactly these keys: quest_name (string), description (string, 1-2 sentences), | &&
      |required_stat (one of STR, DEX, CON, INT, WIS, CHA), difficulty_class (integer 5-20), | &&
      |required_level (integer 1-10), xp_reward (integer 10-200), gold_reward (integer 10-500).|.

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
      max_tokens = 400
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

    IF lines( ls_response-content ) = 0.
      " TEMPORARY DEBUG: surface exactly what came back instead of
      " silently returning an empty quest.
      rs_quest-quest_name = |[DEBUG] body: { lv_response_json }|.
      RETURN.
    ENDIF.

    DATA(lv_quest_json) = ls_response-content[ 1 ]-text.

    " The model sometimes wraps its JSON in a code fence despite instructions not to -
    " strip it defensively rather than fail the whole action over formatting.
    REPLACE ALL OCCURRENCES OF '```json' IN lv_quest_json WITH ''.
    REPLACE ALL OCCURRENCES OF '```'     IN lv_quest_json WITH ''.
    CONDENSE lv_quest_json.

    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_quest_json
      CHANGING  data = rs_quest ).

  ENDMETHOD.

ENDCLASS.

