*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lhc_Guild DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Guild RESULT result.

    METHODS validateGuildName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Guild~validateGuildName.

    " Blocks deletion of guilds that still have members
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Guild.
ENDCLASS.

CLASS lhc_Guild IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.

  METHOD validateGuildName.

    READ ENTITIES OF zi_rpg_guild IN LOCAL MODE
      ENTITY Guild
        FIELDS ( GuildName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(guilds).

    LOOP AT guilds ASSIGNING FIELD-SYMBOL(<guild>).

      DATA(lv_name) = <guild>-GuildName.

      " Rule 1: name must not be empty
      IF lv_name IS INITIAL.
        APPEND VALUE #( %tky = <guild>-%tky ) TO failed-Guild.
        APPEND VALUE #(
          %tky               = <guild>-%tky
          %msg               = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Guild name cannot be empty.' )
          %element-GuildName = if_abap_behv=>mk-on
        ) TO reported-Guild.
        CONTINUE.
      ENDIF.

      " Rule 2: name must contain at least 3 letters
      DATA lv_letter_count TYPE i.
      FIND ALL OCCURRENCES OF PCRE '[a-zA-Z]' IN lv_name
        MATCH COUNT lv_letter_count.
      IF lv_letter_count < 3.
        APPEND VALUE #( %tky = <guild>-%tky ) TO failed-Guild.
        APPEND VALUE #(
          %tky               = <guild>-%tky
          %msg               = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Guild name must contain at least 3 letters.' )
          %element-GuildName = if_abap_behv=>mk-on
        ) TO reported-Guild.
        CONTINUE.
      ENDIF.

      " Rule 3: name must be unique (case-insensitive, ignoring this record)
      SELECT SINGLE guild_id
        FROM zrpg_guild
        WHERE upper( guild_name ) = @( to_upper( lv_name ) )
          AND guild_id          <> @<guild>-GuildId
        INTO @DATA(lv_duplicate_id).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky = <guild>-%tky ) TO failed-Guild.
        APPEND VALUE #(
          %tky               = <guild>-%tky
          %msg               = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Guild name "{ lv_name }" already exists.| )
          %element-GuildName = if_abap_behv=>mk-on
        ) TO reported-Guild.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD precheck_delete.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      SELECT COUNT(*)
        FROM zrpg_adventurer
        WHERE guild_id = @<key>-GuildId
        INTO @DATA(lv_member_count).

      IF lv_member_count > 0.
        APPEND VALUE #( %tky        = <key>-%tky
                        %fail-cause = if_abap_behv=>cause-dependency
        ) TO failed-Guild.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Guild cannot be deleted:|
                           && | { lv_member_count } adventurer(s) are still members.| )
        ) TO reported-Guild.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

