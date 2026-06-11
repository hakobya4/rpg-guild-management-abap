*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lhc_Quest DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS:
      c_status_open        TYPE zrpg_quest-status VALUE 'OPEN',
      c_status_in_progress TYPE zrpg_quest-status VALUE 'IN_PROGRESS',
      c_status_completed   TYPE zrpg_quest-status VALUE 'COMPLETED'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Quest RESULT result.

    METHODS acceptQuest FOR MODIFY
      IMPORTING keys FOR ACTION Quest~acceptQuest RESULT result.

    " Validates and sets the COMPLETED status. XP awarding and level-up
    " are done by the caller (Adventurer~completeQuest) to avoid a
    " cyclic cross-BO modification back into the Adventurer BO.
    METHODS completeQuest FOR MODIFY
      IMPORTING keys FOR ACTION Quest~completeQuest RESULT result.

    METHODS validateQuestValues FOR VALIDATE ON SAVE
      IMPORTING keys FOR Quest~validateQuestValues.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Quest~setInitialStatus.

ENDCLASS.

CLASS lhc_Quest IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.

  METHOD acceptQuest.

    " The RAP framework acquires an exclusive lock on each quest instance
    " before this handler runs (lock master). Two adventurers accepting
    " the same quest at the same time are therefore serialized — the
    " second request re-reads the quest and fails the OPEN check below.
    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        FIELDS ( QuestName Status AdventurerId RequiredLevel XpReward )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE quests ASSIGNING FIELD-SYMBOL(<quest>)
        WITH KEY %tky = <key>-%tky.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Quest not found. Please select a valid quest.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 1: Adventurer from the action parameter ───────────
      DATA(lv_adventurer_id) = <key>-%param-AdventurerId.

      IF lv_adventurer_id IS INITIAL.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Please select an adventurer.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 2: Adventurer must exist as a persisted record ────
      SELECT SINGLE adventurer_name, adventurer_level
        FROM zrpg_adventurer
        WHERE adventurer_id = @lv_adventurer_id
        INTO @DATA(adventurer_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Adventurer does not exist or has not been saved yet.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 3: Quest must be OPEN ──────────────────────────────
      IF <quest>-Status <> c_status_open.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |Quest '{ <quest>-QuestName }' is not open|
                                          && | (status: { <quest>-Status }).| )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 4: Quest must not be assigned to another adventurer ─
      IF <quest>-AdventurerId IS NOT INITIAL.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |Quest '{ <quest>-QuestName }' is already|
                                          && | assigned to another adventurer.| )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 5: Level requirement check ─────────────────────────
      IF adventurer_data-adventurer_level < <quest>-RequiredLevel.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |You must be level { <quest>-RequiredLevel }|
                                          && | to take this quest.|
                                          && | { adventurer_data-adventurer_name }|
                                          && | is currently level|
                                          && | { adventurer_data-adventurer_level }.| )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 6: Assign quest and set IN_PROGRESS ────────────────
      APPEND VALUE #(
        %tky         = <quest>-%tky
        AdventurerId = lv_adventurer_id
        Status       = c_status_in_progress
      ) TO updates.

      APPEND VALUE #(
        %tky = <quest>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |Quest '{ <quest>-QuestName }' accepted by|
                         && | { adventurer_data-adventurer_name }! ⚔️|
                         && | XP Reward: { <quest>-XpReward }.| )
      ) TO reported-Quest.

    ENDLOOP.

    IF updates IS NOT INITIAL.
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
    ENDIF.

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
      IF <quest>-Status <> c_status_in_progress.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                  = <quest>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'Only IN_PROGRESS quests can be completed.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 3: An adventurer must be assigned ────────────────
      IF <quest>-AdventurerId IS INITIAL.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                  = <quest>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'No adventurer is assigned to this quest.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " ── Step 4: Mark quest as completed ───────────────────────
      " XP awarding and level-up happen in Adventurer~completeQuest.
      APPEND VALUE #(
        %tky   = <quest>-%tky
        Status = c_status_completed
      ) TO quest_updates.

      APPEND VALUE #(
        %tky = <quest>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |Quest '{ <quest>-QuestName }' completed!| )
      ) TO reported-Quest.

    ENDLOOP.

    " ── Step 5: Apply quest status updates ────────────────────
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

    " ── Step 6: Fill result ───────────────────────────────────
    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_quests).

    result = VALUE #( FOR quest IN result_quests
                      ( %tky   = quest-%tky
                        %param = CORRESPONDING #( quest ) ) ).

  ENDMETHOD.

  METHOD validateQuestValues.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        FIELDS ( RequiredLevel XpReward )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests).


    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).

      IF <quest>-RequiredLevel < 1.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                   = <quest>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Level requirement must be at least 1.' )
          %element-RequiredLevel = if_abap_behv=>mk-on
        ) TO reported-Quest.
      ENDIF.

      IF <quest>-XpReward < 1.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky              = <quest>-%tky
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
                                text     = 'XP reward must be at least 1.' )
          %element-XpReward = if_abap_behv=>mk-on
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
      APPEND VALUE #( %tky = <quest>-%tky  Status = c_status_open ) TO updates.
    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest UPDATE FIELDS ( Status ) WITH updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Quest = CORRESPONDING #( BASE ( reported-Quest ) rep-Quest ).

  ENDMETHOD.


ENDCLASS.


