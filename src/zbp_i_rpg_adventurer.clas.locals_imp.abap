*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lhc_Adventurer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Adventurer RESULT result.

    " Sets Level=1, XP=0 for every new adventurer
    METHODS initAdventurer FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Adventurer~initAdventurer.
    METHODS joinGuild FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~joinGuild RESULT result.
    METHODS validateAdventurerName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Adventurer~validateAdventurerName.
    DATA lt_existing TYPE TABLE OF zrpg_adventurer.
    METHODS setDefaultClass FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Adventurer~setDefaultClass.
    METHODS acceptQuest FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~acceptQuest RESULT result.

ENDCLASS.

CLASS lhc_Adventurer IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.

  METHOD initAdventurer.

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerLevel AdventurerXp )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_adventurer\\Adventurer.

    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).
      CHECK <adv>-AdventurerLevel = 0.
      APPEND VALUE #(
        %tky            = <adv>-%tky
        AdventurerLevel = 1
        AdventurerXp    = 0
      ) TO updates.
    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        UPDATE FIELDS ( AdventurerLevel AdventurerXp )
        WITH updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Adventurer = CORRESPONDING #(
      BASE ( reported-Adventurer ) rep-Adventurer ).

  ENDMETHOD.

  METHOD joinGuild.
    " ── Step 1: Read current adventurer data ──────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName GuildId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers)
      FAILED DATA(failed_read).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_adventurer\\Adventurer.

    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).

      " ── Step 2: Get the GuildId from the action parameter ───────
      DATA(lv_guild_id) = CONV sysuuid_x16( '' ).
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
        IF <key>-%tky = <adv>-%tky.
          lv_guild_id = <key>-%param-GuildId.
          EXIT.
        ENDIF.
      ENDLOOP.

      " ── Step 3: Validate the guild exists ───────────────────────
      SELECT SINGLE guild_id, guild_name
      FROM zrpg_guild
      WHERE guild_id = @lv_guild_id
      INTO @DATA(guild_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky             = <adv>-%tky
          %action-joinGuild = if_abap_behv=>mk-on
          %msg             = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Guild not found. Please select a valid guild.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 4: Validate not already in this guild ──────────────
      IF <adv>-GuildId = lv_guild_id.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky              = <adv>-%tky
          %action-joinGuild = if_abap_behv=>mk-on
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
                                text     = |{ <adv>-AdventurerName } is already|
                                        && | a member of { guild_data-guild_name }.| )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 5: Join the guild ──────────────────────────────────
      APPEND VALUE #(
        %tky    = <adv>-%tky
        GuildId = lv_guild_id
      ) TO updates.

      " Success message
      APPEND VALUE #(
        %tky = <adv>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |{ <adv>-AdventurerName } has joined|
                         && | { guild_data-guild_name }! ⚔️| )
      ) TO reported-Adventurer.

    ENDLOOP.

    " ── Step 6: Apply guild assignment ────────────────────────────
    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
        ENTITY Adventurer
          UPDATE FIELDS ( GuildId )
          WITH updates
        REPORTED DATA(rep)
        FAILED   DATA(fail).

      reported-Adventurer = CORRESPONDING #(
        BASE ( reported-Adventurer ) rep-Adventurer ).
      failed-Adventurer   = CORRESPONDING #(
        BASE ( failed-Adventurer ) fail-Adventurer ).
    ENDIF.

    " ── Step 7: Return updated adventurer ─────────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).

    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky   = adv-%tky
                        %param = CORRESPONDING #( adv ) ) ).

  ENDMETHOD.

  METHOD validateAdventurerName.
    " ── Step 1: Read the adventurer name ──────────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).
    DATA(lv_count) = 0.
    " ── Step 2: Check each instance ───────────────────────────────
    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).
      lv_count += 1.
      IF <adv>-AdventurerName IS INITIAL.

        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.

        APPEND VALUE #(
          %tky                   = <adv>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Adventurer name cannot be empty.' )
          %element-AdventurerName = if_abap_behv=>mk-on
        ) TO reported-Adventurer.

      ELSEIF strlen( <adv>-AdventurerName ) <= 2.

        " Optional — name must be at least 2 characters
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.

        APPEND VALUE #(
          %tky                    = <adv>-%tky
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = 'Adventurer name must be at least 3 characters.' )
          %element-AdventurerName = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.
    ENDLOOP.
    SELECT *
      FROM zrpg_adventurer
      WHERE adventurer_name = @<adv>-AdventurerName
      INTO TABLE @lt_existing.

    IF lt_existing IS NOT INITIAL.

      APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.

      APPEND VALUE #(
        %tky = <adv>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = |Adventurer name "{ <adv>-AdventurerName }" already exists.| )
        %element-AdventurerName = if_abap_behv=>mk-on
      ) TO reported-Adventurer.

    ENDIF.

  ENDMETHOD.

  METHOD setDefaultClass.
    " ── Step 1: Read newly created adventurers ─────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerClass )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_adventurer\\Adventurer.

    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).

      " Only set default if no class was already provided
      CHECK <adv>-AdventurerClass IS INITIAL.

      APPEND VALUE #(
        %tky            = <adv>-%tky
        AdventurerClass = 'FIGHTER'   " Default D&D class
      ) TO updates.

    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        UPDATE FIELDS ( AdventurerClass )
        WITH updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Adventurer = CORRESPONDING #(
      BASE ( reported-Adventurer ) rep-Adventurer ).
  ENDMETHOD.

  METHOD acceptQuest.
    " ── Step 1: Read adventurer data ──────────────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerId AdventurerName AdventurerLevel )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).

      " ── Step 2: Get QuestId from the action parameter ──────────
      " %param is on the keys table — loop to find matching entry
      DATA(lv_quest_id) = CONV sysuuid_x16( '' ).
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
        IF <key>-%tky = <adv>-%tky.
          lv_quest_id = <key>-%param-QuestId.  " ← field from abstract entity
          EXIT.
        ENDIF.
      ENDLOOP.

      " ── Step 3: Validate QuestId was provided ──────────────────
      IF lv_quest_id IS INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Please select a quest.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 4: Read quest directly from DB ────────────────────
      SELECT SINGLE quest_id, quest_name, status, required_level, xp_reward
      FROM zrpg_quest
      WHERE quest_id = @lv_quest_id
      INTO @DATA(quest_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Quest not found. Please select a valid quest.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 5: Quest must be OPEN ─────────────────────────────
      IF quest_data-status <> 'OPEN'.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |'{ quest_data-quest_name }' is no longer available.| )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 6: Level requirement check ────────────────────────
      IF <adv>-AdventurerLevel < quest_data-required_level.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |You must be level { quest_data-required_level }|
                           && | to take this quest.|
                           && | { <adv>-AdventurerName }|
                           && | is currently level { <adv>-AdventurerLevel }.| )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 7: Cross-BO update — assign quest to adventurer ───
      " Status and AdventurerId must NOT be readonly in ZI_RPG_QUEST BDEF
      MODIFY ENTITIES OF zi_rpg_quest
        ENTITY Quest
          UPDATE FIELDS ( Status AdventurerId )
          WITH VALUE #( (
            QuestId      = lv_quest_id
            Status       = 'IN_PROGRESS'
            AdventurerId = <adv>-AdventurerId
          ) )
        REPORTED DATA(rep_quest)
        FAILED   DATA(fail_quest).


      " ── Step 9: Success message ─────────────────────────────────
      APPEND VALUE #(
        %tky = <adv>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |Quest '{ quest_data-quest_name }' accepted! ⚔️|
                         && | XP Reward: { quest_data-xp_reward }.| )
      ) TO reported-Adventurer.

    ENDLOOP.

    " ── Step 10: Return updated adventurer ──────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).

    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky   = adv-%tky
                        %param = CORRESPONDING #( adv ) ) ).
  ENDMETHOD.
ENDCLASS.
