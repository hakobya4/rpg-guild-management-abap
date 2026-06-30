*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lhc_Quest DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS:
      c_status_open        TYPE zrpg_quest-status VALUE 'OPEN',
      c_status_in_progress TYPE zrpg_quest-status VALUE 'IN_PROGRESS',
      c_status_completed   TYPE zrpg_quest-status VALUE 'COMPLETED',
      c_xp_per_level       TYPE i                 VALUE 10.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Quest RESULT result.

    METHODS acceptQuest FOR MODIFY
      IMPORTING keys FOR ACTION Quest~acceptQuest RESULT result.

    METHODS completeQuest FOR MODIFY
      IMPORTING keys FOR ACTION Quest~completeQuest RESULT result.

    " Enables the Complete button only for IN_PROGRESS quests
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Quest RESULT result.

    METHODS validateQuestValues FOR VALIDATE ON SAVE
      IMPORTING keys FOR Quest~validateQuestValues.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Quest~setInitialStatus.
    METHODS giveupQuest FOR MODIFY
      IMPORTING keys FOR ACTION Quest~giveupQuest RESULT result.

ENDCLASS.

CLASS lhc_Quest IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(quests).

    result = VALUE #( FOR <q> IN quests
      ( %tky                 = <q>-%tky
        %action-completeQuest = COND #( WHEN <q>-Status = c_status_in_progress
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        %action-giveupQuest = COND #( WHEN <q>-Status = c_status_in_progress
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.


  METHOD acceptQuest.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        FIELDS ( QuestName Status AdventurerId RequiredLevel XpReward )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE quests ASSIGNING FIELD-SYMBOL(<quest>)
        WITH TABLE KEY id COMPONENTS %tky = <key>-%tky.
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

      "Adventurer from the action parameter
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

      " Adventurer must be created
      SELECT SINGLE adventurer_name, adventurer_level
        FROM zrpg_adventurer
        WHERE adventurer_id = @lv_adventurer_id
        INTO @DATA(adventurer_data).

      " Quest must be OPEN
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

      " Quest must not be assigned to another adventurer
      IF <quest>-AdventurerId IS NOT INITIAL.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |Quest is already assigned to another adventurer.| )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " Level requirement check
      IF adventurer_data-adventurer_level < <quest>-RequiredLevel.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |You must be level { <quest>-RequiredLevel }| )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      "Assign quest and set IN_PROGRESS
      APPEND VALUE #(
        %tky         = <quest>-%tky
        AdventurerId = lv_adventurer_id
        Status       = c_status_in_progress
      ) TO updates.

      APPEND VALUE #(
        %tky = <quest>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |Quest '{ <quest>-QuestName }' accepted. | )
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

    "Read quest data
    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        FIELDS ( Status AdventurerId XpReward QuestName RequiredLevel GoldReward )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests)
      FAILED DATA(failed_read).

    DATA quest_updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.

    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).

      "update adventurer values

      SELECT SINGLE adventurer_id, adventurer_gold, adventurer_xp, adventurer_level
        FROM zrpg_adventurer
        WHERE adventurer_id = @<quest>-AdventurerId
        INTO @DATA(lv_adv_stats).

      "  An adventurer must be assigned
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


      "  Mark quest as completed
      APPEND VALUE #(
        %tky   = <quest>-%tky
        Status = c_status_completed
      ) TO quest_updates.
      IF sy-subrc = 0.
        DATA(total_xp)      = lv_adv_stats-adventurer_xp + <quest>-XpReward.
        DATA(levels_gained) = total_xp DIV c_xp_per_level.
        DATA(new_level)     = lv_adv_stats-adventurer_level + levels_gained.
        DATA(new_xp)        = total_xp MOD c_xp_per_level.
        DATA(new_gold)      = lv_adv_stats-adventurer_gold + <quest>-GoldReward.

        MODIFY ENTITIES OF zi_rpg_adventurer
          ENTITY Adventurer
          UPDATE FIELDS ( AdventurerGold AdventurerXP AdventurerLevel  )
            WITH VALUE #( ( AdventurerId   = <quest>-AdventurerId
                       AdventurerGold = new_gold
                       AdventurerXp = new_xp
                       AdventurerLevel = new_level  ) )
          REPORTED DATA(rep_adv)
          FAILED   DATA(fail_adv).

        APPEND VALUE #(
        %tky = <quest>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |Quest '{ <quest>-QuestName }' completed!| )
         ) TO reported-Quest.
      ENDIF.
    ENDLOOP.

    " Apply quest status updates
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

    "  Result
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
        FIELDS ( RequiredLevel XpReward GoldReward QuestName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests).


    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).
      IF <quest>-QuestName IS INITIAL.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                   = <quest>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Please provide a name for this quest.' )
          %element-RequiredLevel = if_abap_behv=>mk-on
        ) TO reported-Quest.
      ENDIF.
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
      IF <quest>-GoldReward < 1.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Gold reward must be at least 1.' )
          %element-GoldReward = if_abap_behv=>mk-on
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


  METHOD giveupQuest.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
     ENTITY Quest
     FIELDS ( Status AdventurerId )
     WITH CORRESPONDING #( keys )
     RESULT DATA(quests).

    DATA quest_updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.


    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).
      APPEND VALUE #(
          %tky   = <quest>-%tky
          Status = c_status_open
          AdventurerId = VALUE sysuuid_x16( )
        ) TO quest_updates.
    ENDLOOP.
    IF quest_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
        ENTITY Quest
          UPDATE FIELDS ( Status AdventurerId )
          WITH quest_updates
        REPORTED DATA(reported_quest_update)
        FAILED   DATA(failed_quest_update).

      reported-Quest = CORRESPONDING #(
        BASE ( reported-Quest ) reported_quest_update-Quest ).
      failed-Quest   = CORRESPONDING #(
        BASE ( failed-Quest ) failed_quest_update-Quest ).
    ENDIF.

    "  Result
    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_quests).

    result = VALUE #( FOR quest IN result_quests
                      ( %tky   = quest-%tky
                        %param = CORRESPONDING #( quest ) ) ).
  ENDMETHOD.

ENDCLASS.


