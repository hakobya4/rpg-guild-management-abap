*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lhc_Quest DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

   METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Quest RESULT result.

    METHODS acceptQuest FOR MODIFY
      IMPORTING keys FOR ACTION Quest~acceptQuest RESULT result.

    " Now applies XP and levels up the adventurer directly
    METHODS completeQuest FOR MODIFY
      IMPORTING keys FOR ACTION Quest~completeQuest RESULT result.

    METHODS validateLevelRequirement FOR VALIDATE ON SAVE
      IMPORTING keys FOR Quest~validateLevelRequirement.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Quest~setInitialStatus.

ENDCLASS.

CLASS lhc_Quest IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.

  METHOD acceptQuest.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests)
      FAILED DATA(failed_read).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.

    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).

      DATA(lv_adventurer_id) = CONV sysuuid_x16( '' ).
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
        IF <key>-%tky = <quest>-%tky.
          lv_adventurer_id = <key>-%param-QuestId.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF <quest>-Status <> 'OPEN'.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Only OPEN quests can be accepted' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky         = <quest>-%tky
        AdventurerId = lv_adventurer_id
        Status       = 'IN_PROGRESS'
      ) TO updates.

    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        UPDATE FIELDS ( AdventurerId Status )
        WITH updates
      REPORTED DATA(reported_update)
      FAILED   DATA(failed_update).

    reported-Quest = CORRESPONDING #(
      BASE ( reported-Quest ) reported_update-Quest ).
    failed-Quest   = CORRESPONDING #(
      BASE ( failed-Quest ) failed_update-Quest ).

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_quests).

    result = VALUE #( FOR quest IN result_quests
                      ( %tky   = quest-%tky
                        %param = CORRESPONDING #( quest ) ) ).
  ENDMETHOD.

  METHOD completeQuest.

    " ── Step 1: Read quest data ───────────────────────────────────
    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        FIELDS ( Status AdventurerId XpReward QuestName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests)
      FAILED DATA(failed_read).

    DATA quest_updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.

    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).

      " ── Step 2: Validate status ────────────────────────────────
      IF <quest>-Status <> 'IN_PROGRESS'.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                  = <quest>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'Only IN_PROGRESS quests can be completed' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 3: Mark quest as completed ───────────────────────
      APPEND VALUE #(
        %tky   = <quest>-%tky
        Status = 'COMPLETED'
      ) TO quest_updates.

      " ── Step 4: Apply XP to adventurer directly ───────────────
      " No Reward entity needed — XP is applied immediately
      SELECT SINGLE
        adventurer_id,
        adventurer_name,
        adventurer_level,
        adventurer_xp
      FROM zrpg_adventurer
      WHERE adventurer_id = @<quest>-AdventurerId
      INTO @DATA(adventurer_data).

      IF sy-subrc <> 0.
        " Quest completes but adventurer XP update is skipped
        APPEND VALUE #(
          %tky = <quest>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-warning
                   text     = 'Quest completed but adventurer not found for XP award.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 5: Calculate new XP and level ────────────────────
      DATA(new_xp)    = adventurer_data-adventurer_xp + <quest>-XpReward.
      DATA(new_level) = ( new_xp / 100 ) + 1.

      DATA(level_up_text) = ||.
      IF new_level > adventurer_data-adventurer_level.
        level_up_text = | 🎉 Level up! { adventurer_data-adventurer_name }|
                     && | is now level { new_level }!|.
      ENDIF.

      " ── Step 6: Update adventurer via cross-BO EML ────────────
      " Adventurer is now its own BO — MODIFY without IN LOCAL MODE
      MODIFY ENTITIES OF zi_rpg_adventurer
        ENTITY Adventurer
          UPDATE FIELDS ( AdventurerXp AdventurerLevel )
          WITH VALUE #( (
            AdventurerId    = adventurer_data-adventurer_id
            AdventurerXp    = new_xp
            AdventurerLevel = new_level
          ) )
        REPORTED DATA(reported_adv)
        FAILED   DATA(failed_adv).

      " ── Step 7: Success message with XP and level info ────────
      DATA(success_text) = |Quest '{ <quest>-QuestName }' completed!|
                        && | { adventurer_data-adventurer_name }|
                        && | gained { <quest>-XpReward } XP.|
                        && | Total XP: { new_xp }.|
                        && level_up_text.

      APPEND VALUE #(
        %tky = <quest>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = success_text )
      ) TO reported-Quest.

    ENDLOOP.

    " ── Step 8: Apply quest status updates ────────────────────
    IF quest_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
        ENTITY Quest
          UPDATE FIELDS ( Status )
          WITH quest_updates
        REPORTED DATA(reported_quest_update)
        FAILED   DATA(failed_quest_update).

      reported-Quest = CORRESPONDING #(
        BASE ( reported-Quest ) reported_quest_update-Quest ).
      failed-Quest   = CORRESPONDING #(
        BASE ( failed-Quest ) failed_quest_update-Quest ).
    ENDIF.

    " ── Step 9: Fill result ───────────────────────────────────
    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_quests).

    result = VALUE #( FOR quest IN result_quests
                      ( %tky   = quest-%tky
                        %param = CORRESPONDING #( quest ) ) ).

  ENDMETHOD.

  METHOD validateLevelRequirement.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        FIELDS ( Status AdventurerId RequiredLevel )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests).

    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).
      CHECK <quest>-Status       = 'IN_PROGRESS'.
      CHECK <quest>-AdventurerId IS NOT INITIAL.

      SELECT SINGLE adventurer_level, adventurer_name
      FROM zrpg_adventurer
      WHERE adventurer_id = @<quest>-AdventurerId
      INTO @DATA(adventurer_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky = <quest>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Adventurer not found.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      IF adventurer_data-adventurer_level < <quest>-RequiredLevel.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky = <quest>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |You must be level { <quest>-RequiredLevel }|
                           && | to accept this quest.|
                           && | { adventurer_data-adventurer_name }|
                           && | is currently level { adventurer_data-adventurer_level }.| )
        ) TO reported-Quest.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD setInitialStatus.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.

    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).
      CHECK <quest>-Status IS INITIAL.
      APPEND VALUE #( %tky = <quest>-%tky  Status = 'OPEN' ) TO updates.
    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest UPDATE FIELDS ( Status ) WITH updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Quest = CORRESPONDING #( BASE ( reported-Quest ) rep-Quest ).

  ENDMETHOD.

ENDCLASS.
