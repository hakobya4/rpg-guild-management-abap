*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lsc_zi_rpg_quest DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.



CLASS lsc_zi_rpg_quest IMPLEMENTATION.
  " Auto-links full loot catalog to quests
  METHOD save_modified.

    CHECK create-quest IS NOT INITIAL.

    SELECT item_id
      FROM zrpg_loot_items
      INTO TABLE @DATA(lt_loot_items).

    CHECK lt_loot_items IS NOT INITIAL.

    DATA lt_link TYPE STANDARD TABLE OF zrpg_quest_loot WITH EMPTY KEY.
    DATA(lv_now) = utclong_current( ).

    LOOP AT create-quest INTO DATA(created_quest).

      " Don't duplicate links if this somehow runs twice for the same quest
      SELECT SINGLE @abap_true
        FROM zrpg_quest_loot
        WHERE quest_id = @created_quest-QuestId
        INTO @DATA(lv_already_linked).

      CHECK lv_already_linked <> abap_true.

      LOOP AT lt_loot_items INTO DATA(ls_item).
        TRY.
            APPEND VALUE #(
              client                = sy-mandt
              loot_id               = cl_system_uuid=>create_uuid_x16_static( )
              quest_id              = created_quest-QuestId
              item_id               = ls_item-item_id
              created_at            = lv_now
              created_by            = sy-uname
              last_changed_at       = lv_now
              last_changed_by       = sy-uname
              local_last_changed_at = lv_now
            ) TO lt_link.
          CATCH cx_uuid_error.
            CONTINUE.
        ENDTRY.
      ENDLOOP.

    ENDLOOP.

    CHECK lt_link IS NOT INITIAL.

    INSERT zrpg_quest_loot FROM TABLE @lt_link.

  ENDMETHOD.

ENDCLASS.



CLASS lhc_Quest DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.
    CLASS-DATA go_dice_roller TYPE REF TO zif_rpg_dice_roller.

  PRIVATE SECTION.

    CONSTANTS:
      c_status_open        TYPE zrpg_quest-status VALUE 'OPEN',
      c_status_in_progress TYPE zrpg_quest-status VALUE 'IN_PROGRESS',
      c_status_completed   TYPE zrpg_quest-status VALUE 'COMPLETED',
      c_status_failed      TYPE zrpg_quest-status VALUE 'FAILED',
      c_xp_per_level       TYPE i                 VALUE 10,

      " Loot odds: 30% chance of any drop
      " COMMON 60% / UNCOMMON 25% / RARE 10% / LEGENDARY (remainder) 5%.
      c_pct_any_drop       TYPE i VALUE 30,
      c_pct_common         TYPE i VALUE 60,
      c_pct_uncommon       TYPE i VALUE 25,
      c_pct_rare           TYPE i VALUE 10.

    TYPES:
      BEGIN OF ty_quest_info,
        quest_id         TYPE zrpg_quest-quest_id,
        quest_name       TYPE zrpg_quest-quest_name,
        status           TYPE zrpg_quest-status,
        adventurer_id    TYPE zrpg_quest-adventurer_id,
        required_level   TYPE zrpg_quest-required_level,
        required_stat    TYPE zrpg_quest-required_stat,
        difficulty_class TYPE zrpg_quest-difficulty_class,
        xp_reward        TYPE zrpg_quest-xp_reward,
        gold_reward      TYPE zrpg_quest-gold_reward,
      END OF ty_quest_info,

      BEGIN OF ty_adventurer_info,
        adventurer_id    TYPE zrpg_adventurer-adventurer_id,
        created_by       TYPE zrpg_adventurer-created_by,
        adventurer_gold  TYPE zrpg_adventurer-adventurer_gold,
        adventurer_xp    TYPE zrpg_adventurer-adventurer_xp,
        adventurer_level TYPE zrpg_adventurer-adventurer_level,
        adv_str          TYPE zrpg_adventurer-adv_str,
        adv_dex          TYPE zrpg_adventurer-adv_dex,
        adv_con          TYPE zrpg_adventurer-adv_con,
        adv_int          TYPE zrpg_adventurer-adv_int,
        adv_wis          TYPE zrpg_adventurer-adv_wis,
        adv_cha          TYPE zrpg_adventurer-adv_cha,
      END OF ty_adventurer_info,

      " d20 + modifier vs difficulty class
      BEGIN OF ty_check_result,
        roll     TYPE i,
        modifier TYPE i,
        total    TYPE i,
        success  TYPE abap_bool,
      END OF ty_check_result,

      BEGIN OF ty_step_outcome,
        ok       TYPE abap_bool,
        msg      TYPE string,
        severity TYPE if_abap_behv_message=>t_severity,
      END OF ty_step_outcome.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Quest RESULT result.

    " Roll the d20 check for a quest against an adventurer's stats
    METHODS resolve_check
      IMPORTING is_quest        TYPE ty_quest_info
                is_adventurer   TYPE ty_adventurer_info
      RETURNING VALUE(rs_check) TYPE ty_check_result.

    " Pay out XP / level-ups / gold for a passed quest
    METHODS grant_rewards
      IMPORTING is_quest          TYPE ty_quest_info
                is_adventurer     TYPE ty_adventurer_info
      RETURNING VALUE(rs_outcome) TYPE ty_step_outcome.

    " Roll the loot drop, pick an eligible item, add it to the inventory
    METHODS award_loot
      IMPORTING is_quest          TYPE ty_quest_info
                is_adventurer     TYPE ty_adventurer_info
      RETURNING VALUE(rs_outcome) TYPE ty_step_outcome.

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
    METHODS previewLootOdds FOR MODIFY
      IMPORTING keys FOR ACTION Quest~previewLootOdds RESULT result.

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

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      SELECT SINGLE quest_name, status, adventurer_id, required_level, xp_reward
        FROM zrpg_quest
        WHERE quest_id = @<key>-QuestId
        INTO @DATA(quest_data).

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
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <key>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Please select an adventurer.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " Adventurer must be created
      SELECT SINGLE adventurer_name, adventurer_level, created_by
        FROM zrpg_adventurer
        WHERE adventurer_id = @lv_adventurer_id
        INTO @DATA(adventurer_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <key>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Adventurer not found. Save the adventurer first.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " Only the owning player may accept quests for this adventurer
      IF zcl_rpg_ownership=>is_owner( adventurer_data-created_by ) = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <key>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'You can only accept quests for your own adventurer.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " Quest must be OPEN
      IF quest_data-status <> c_status_open.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <key>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |Quest '{ quest_data-quest_name  }' is not open| )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " Quest must not be assigned to another adventurer
      IF quest_data-adventurer_id IS NOT INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <key>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |Quest is already assigned to another adventurer.| )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " Level requirement check
      IF adventurer_data-adventurer_level < quest_data-required_level.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <key>-%tky
          %action-acceptQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |You must be level { quest_data-required_level }| )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      "Assign quest and set IN_PROGRESS
      APPEND VALUE #(
        %tky         = <key>-%tky
        AdventurerId = lv_adventurer_id
        Status       = c_status_in_progress
      ) TO updates.

      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |Quest '{ quest_data-quest_name }' accepted. | )
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

    DATA quest_updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.
    DATA ls_quest      TYPE ty_quest_info.
    DATA ls_adventurer TYPE ty_adventurer_info.

    IF go_dice_roller IS INITIAL.
      go_dice_roller = NEW zcl_rpg_roll_dice( ).
    ENDIF.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      CLEAR: ls_quest, ls_adventurer.

      SELECT SINGLE quest_id, quest_name, status, adventurer_id, required_level,
                    required_stat, difficulty_class, xp_reward, gold_reward
        FROM zrpg_quest
        WHERE quest_id = @<key>-QuestId
        INTO CORRESPONDING FIELDS OF @ls_quest.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                  = <key>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'Only an in-progress quest can be completed.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      "  An adventurer must be assigned
      IF ls_quest-adventurer_id IS INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                  = <key>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'No adventurer is assigned to this quest.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      SELECT SINGLE adventurer_id, created_by, adventurer_gold, adventurer_xp, adventurer_level,
                    adv_str, adv_dex, adv_con, adv_int, adv_wis, adv_cha
        FROM zrpg_adventurer
        WHERE adventurer_id = @ls_quest-adventurer_id
        INTO CORRESPONDING FIELDS OF @ls_adventurer.

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                  = <key>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'Assigned adventurer no longer exists.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " Only the player who owns the assigned adventurer may resolve the quest
      IF zcl_rpg_ownership=>is_owner( ls_adventurer-created_by ) = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                  = <key>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'Only the owner of the assigned adventurer can complete this quest.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      DATA(ls_check) = resolve_check( is_quest      = ls_quest
                                      is_adventurer = ls_adventurer ).

      DATA(lv_roll_text) = |(rolled { ls_check-roll } | &&
                           |{ COND #( WHEN ls_check-modifier >= 0 THEN '+' ELSE '' ) }{ ls_check-modifier } | &&
                           |= { ls_check-total } vs DC { ls_quest-difficulty_class })|.

      IF ls_check-success = abap_true.

        DATA(ls_rewards) = grant_rewards( is_quest      = ls_quest
                                          is_adventurer = ls_adventurer ).
        IF ls_rewards-ok = abap_false.
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
          APPEND VALUE #(
            %tky = <key>-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = ls_rewards-msg )
          ) TO reported-Quest.
          CONTINUE.
        ENDIF.

        APPEND VALUE #(
          %tky   = <key>-%tky
          Status = c_status_completed
        ) TO quest_updates.

        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-success
                   text     = |Completed! { lv_roll_text }| )
        ) TO reported-Quest.

        DATA(ls_loot) = award_loot( is_quest      = ls_quest
                                    is_adventurer = ls_adventurer ).
        IF ls_loot-ok = abap_false.
          " Loot was rolled but could not be written - fail the whole action
          " so the player never sees a success that didn't actually happen.
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-Quest.
          APPEND VALUE #(
            %tky = <key>-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = ls_loot-msg )
          ) TO reported-Quest.
          CONTINUE.
        ELSEIF ls_loot-msg IS NOT INITIAL.
          APPEND VALUE #(
            %tky = <key>-%tky
            %msg = new_message_with_text(
                     severity = ls_loot-severity
                     text     = ls_loot-msg )
          ) TO reported-Quest.
        ENDIF.

      ELSE.
        "  Failure: mark quest failed, no rewards, no XP/gold change
        APPEND VALUE #(
          %tky   = <key>-%tky
          Status = c_status_failed
        ) TO quest_updates.

        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Failed! { lv_roll_text }| )
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
        FIELDS ( RequiredLevel XpReward GoldReward QuestName QuestTypeName RequiredStat DifficultyClass )
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
          %element-QuestName = if_abap_behv=>mk-on
        ) TO reported-Quest.
      ENDIF.

      IF <quest>-QuestTypeName IS INITIAL.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %msg                = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Please choose a quest type.' )
          %element-QuestTypeName = if_abap_behv=>mk-on
        ) TO reported-Quest.
      ENDIF.

      IF <quest>-RequiredStat IS INITIAL.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %msg                = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Please choose a quest stat.' )
          %element-RequiredStat = if_abap_behv=>mk-on
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

      IF <quest>-DifficultyClass < 1.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                   = <quest>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Difficulty class must be at least 1.' )
          %element-DifficultyClass = if_abap_behv=>mk-on
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
      IF <quest>-Status <> c_status_in_progress.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-giveupQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Only an in-progress quest can be given up.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      " Only the owner of the assigned adventurer may give up the quest
      SELECT SINGLE created_by
        FROM zrpg_adventurer
        WHERE adventurer_id = @<quest>-AdventurerId
        INTO @DATA(lv_owner).
      IF sy-subrc = 0 AND zcl_rpg_ownership=>is_owner( lv_owner ) = abap_false.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                = <quest>-%tky
          %action-giveupQuest = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Only the owner of the assigned adventurer can give up this quest.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

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

  METHOD previewLootOdds.

    DATA(lo_loot) = NEW zcl_rpg_loot_amdp( ).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      DATA(lv_quest_id_hex) = CONV zcl_rpg_loot_amdp=>ty_quest_id_hex( <key>-QuestId ).

      lo_loot->get_loot_probabilities(
        EXPORTING iv_quest_id      = lv_quest_id_hex
        IMPORTING et_probabilities = DATA(lt_probabilities) ).

      IF lt_probabilities IS INITIAL.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-warning
                   text     = 'This quest has no loot linked yet.' )
        ) TO reported-Quest.
        CONTINUE.
      ENDIF.

      LOOP AT lt_probabilities INTO DATA(ls_probability).
        DATA(lv_text) = COND string(
          WHEN ls_probability-dimension = 'DROP_CHANCE'
            THEN |Chance of any loot at all: { ls_probability-probability_pct }%|
          ELSE |{ ls_probability-dimension }: { ls_probability-value } - { ls_probability-probability_pct }% | ).
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-success
                   text     = lv_text )
        ) TO reported-Quest.
      ENDLOOP.
    ENDLOOP.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_quests_loot).

    result = VALUE #( FOR quest IN result_quests_loot
                      ( %tky   = quest-%tky
                        %param = CORRESPONDING #( quest ) ) ).

  ENDMETHOD.
  METHOD resolve_check.

    rs_check-modifier = NEW zcl_rpg_stat_check( )->zif_rpg_quest_resolution~get_check_modifier(
                            iv_quest_stat       = is_quest-required_stat
                            iv_adventurer_level = is_adventurer-adventurer_level
                            iv_required_level   = is_quest-required_level
                            iv_adventurer_str   = is_adventurer-adv_str
                            iv_adventurer_dex   = is_adventurer-adv_dex
                            iv_adventurer_con   = is_adventurer-adv_con
                            iv_adventurer_int   = is_adventurer-adv_int
                            iv_adventurer_wis   = is_adventurer-adv_wis
                            iv_adventurer_cha   = is_adventurer-adv_cha ).

    rs_check-roll    = go_dice_roller->roll_dtwenty( ).
    rs_check-total   = rs_check-roll + rs_check-modifier.
    rs_check-success = xsdbool( rs_check-total >= is_quest-difficulty_class ).

  ENDMETHOD.

  METHOD grant_rewards.

    DATA(total_xp)      = is_adventurer-adventurer_xp + is_quest-xp_reward.
    DATA(levels_gained) = total_xp DIV c_xp_per_level.

    MODIFY ENTITIES OF zi_rpg_adventurer
      ENTITY Adventurer
        UPDATE FIELDS ( AdventurerGold AdventurerXp AdventurerLevel )
        WITH VALUE #( ( AdventurerId    = is_quest-adventurer_id
                        AdventurerGold  = is_adventurer-adventurer_gold + is_quest-gold_reward
                        AdventurerXp    = total_xp MOD c_xp_per_level
                        AdventurerLevel = is_adventurer-adventurer_level + levels_gained ) )
      REPORTED DATA(reported_adv)
      FAILED   DATA(failed_adv).

    IF failed_adv-adventurer IS NOT INITIAL.
      rs_outcome-ok  = abap_false.
      rs_outcome-msg = 'The quest was passed, but the rewards could not be applied - nothing was saved.'.
      RETURN.
    ENDIF.

    rs_outcome-ok = abap_true.

  ENDMETHOD.

  METHOD award_loot.

    rs_outcome-ok = abap_true.

    " Chance of any drop at all
    IF go_dice_roller->roll_percentage( ) > c_pct_any_drop.
      RETURN. " no drop this time - not an error, no message
    ENDIF.

    " Rarity roll (COMMON / UNCOMMON / RARE / LEGENDARY)
    DATA(lv_rarity_roll) = go_dice_roller->roll_percentage( ).
    DATA(lv_rarity) = COND zrpg_loot_items-item_rarity(
      WHEN lv_rarity_roll <= c_pct_common                              THEN 'COMMON'
      WHEN lv_rarity_roll <= c_pct_common + c_pct_uncommon             THEN 'UNCOMMON'
      WHEN lv_rarity_roll <= c_pct_common + c_pct_uncommon + c_pct_rare THEN 'RARE'
      ELSE                                                                  'LEGENDARY' ).

    " Eligible items: this quest's loot pool, rolled rarity, level gate
    SELECT li~item_id, li~item_name, li~item_type, li~item_subtype,
           li~description, li~required_level, li~price, li~str_bonus,
           li~dex_bonus, li~con_bonus, li~int_bonus, li~wis_bonus, li~cha_bonus
      FROM zrpg_quest_loot AS ql
      INNER JOIN zrpg_loot_items AS li ON ql~item_id = li~item_id
      WHERE ql~quest_id        = @is_quest-quest_id
        AND li~item_rarity     = @lv_rarity
        AND li~required_level <= @is_adventurer-adventurer_level
      INTO TABLE @DATA(lt_eligible).

    IF lt_eligible IS INITIAL.
      rs_outcome-msg      = |A { lv_rarity } drop was rolled, but no eligible item matched your level.|.
      rs_outcome-severity = if_abap_behv_message=>severity-information.
      RETURN.
    ENDIF.

    " Uniform pick - roll_between has no modulo bias toward low indexes
    DATA(ls_item) = lt_eligible[ go_dice_roller->roll_between( iv_min = 1
                                                               iv_max = lines( lt_eligible ) ) ].

    SELECT SINGLE inventory_id, amount
      FROM zrpg_inventory
      WHERE adventurerid = @is_quest-adventurer_id
        AND item_id      = @ls_item-item_id
      INTO @DATA(ls_owned).

    DATA lv_write_failed TYPE abap_bool.

    IF sy-subrc = 0.
      " Already own it - just add another one, no repeated bonus
      MODIFY ENTITIES OF zi_rpg_inventory
        ENTITY Inventory
          UPDATE FIELDS ( Amount )
          WITH VALUE #( ( InventoryId = ls_owned-inventory_id
                          Amount      = ls_owned-amount + 1 ) )
        REPORTED DATA(reported_upd)
        FAILED   DATA(failed_upd).
      lv_write_failed = xsdbool( failed_upd-inventory IS NOT INITIAL ).
    ELSE.
      " First time owning this loot item - create it
      MODIFY ENTITIES OF zi_rpg_inventory
        ENTITY Inventory
          CREATE FIELDS ( AdventurerId ItemId ItemName ItemType ItemSubtype ItemRarity
                          Description RequiredLevel Price Amount
                          StrBonus DexBonus ConBonus IntBonus WisBonus ChaBonus )
            WITH VALUE #( ( %cid          = |LOOT_{ ls_item-item_id }|
                            AdventurerId  = is_quest-adventurer_id
                            ItemId        = ls_item-item_id
                            ItemName      = ls_item-item_name
                            ItemType      = ls_item-item_type
                            ItemSubtype   = ls_item-item_subtype
                            ItemRarity    = lv_rarity
                            Description   = ls_item-description
                            RequiredLevel = ls_item-required_level
                            Price         = ls_item-price
                            Amount        = 1
                            StrBonus      = ls_item-str_bonus
                            DexBonus      = ls_item-dex_bonus
                            ConBonus      = ls_item-con_bonus
                            IntBonus      = ls_item-int_bonus
                            WisBonus      = ls_item-wis_bonus
                            ChaBonus      = ls_item-cha_bonus ) )
        REPORTED DATA(reported_crt)
        FAILED   DATA(failed_crt).

      IF failed_crt-inventory IS NOT INITIAL.
        lv_write_failed = abap_true.
      ELSE.
        " First copy of the item also grants its stat bonuses
        MODIFY ENTITIES OF zi_rpg_adventurer
          ENTITY Adventurer
            UPDATE FIELDS ( AdvStr AdvDex AdvCon AdvInt AdvWis AdvCha )
            WITH VALUE #( ( AdventurerId = is_quest-adventurer_id
                            AdvStr = is_adventurer-adv_str + ls_item-str_bonus
                            AdvDex = is_adventurer-adv_dex + ls_item-dex_bonus
                            AdvCon = is_adventurer-adv_con + ls_item-con_bonus
                            AdvInt = is_adventurer-adv_int + ls_item-int_bonus
                            AdvWis = is_adventurer-adv_wis + ls_item-wis_bonus
                            AdvCha = is_adventurer-adv_cha + ls_item-cha_bonus ) )
          REPORTED DATA(reported_stat)
          FAILED   DATA(failed_stat).
        lv_write_failed = xsdbool( failed_stat-adventurer IS NOT INITIAL ).
      ENDIF.
    ENDIF.

    IF lv_write_failed = abap_true.
      rs_outcome-ok  = abap_false.
      rs_outcome-msg = 'The loot reward could not be saved - the quest was not completed.'.
      RETURN.
    ENDIF.

    rs_outcome-msg      = |Loot! You received a { lv_rarity } item: '{ ls_item-item_name }'.|.
    rs_outcome-severity = if_abap_behv_message=>severity-success.

  ENDMETHOD.

ENDCLASS.





