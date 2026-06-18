*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lhc_Adventurer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Every 10 XP the adventurer gains one level; the remainder is kept
    CONSTANTS c_xp_per_level TYPE i VALUE 10.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Adventurer RESULT result.

    " Sets Level=1, XP=0 for every new adventurer
    METHODS initAdventurer FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Adventurer~initAdventurer.
    METHODS joinGuild FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~joinGuild RESULT result.
    METHODS validateAdventurerName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Adventurer~validateAdventurerName.
    METHODS setDefaultClass FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Adventurer~setDefaultClass.
    METHODS acceptQuest FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~acceptQuest RESULT result.
    METHODS completeQuest FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~completeQuest RESULT result.
    METHODS buyItem FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~buyItem RESULT result.

ENDCLASS.

CLASS lhc_Adventurer IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.

  METHOD initAdventurer.

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerLevel AdventurerXp AdventurerGold )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_adventurer\\Adventurer.

    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).
      CHECK <adv>-AdventurerLevel = 0.
      APPEND VALUE #(
        %tky            = <adv>-%tky
        AdventurerLevel = 1
        AdventurerXp    = 0
        AdventurerGold  = 0
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

    " ── Step 2: Check each instance ───────────────────────────────
    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).

      DATA(lv_name) = <adv>-AdventurerName.

      " Rule 1: name must not be empty
      IF lv_name IS INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                    = <adv>-%tky
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = 'Adventurer name cannot be empty.' )
          %element-AdventurerName = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Rule 2: name must not contain numbers
      IF lv_name CA '0123456789'.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                    = <adv>-%tky
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = 'Adventurer name cannot contain numbers.' )
          %element-AdventurerName = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Rule 3: name must contain at least 3 letters
      DATA lv_letter_count TYPE i.
      FIND ALL OCCURRENCES OF PCRE '[a-zA-Z]' IN lv_name
        MATCH COUNT lv_letter_count.
      IF lv_letter_count < 3.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                    = <adv>-%tky
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = 'Adventurer name must contain at least 3 letters.' )
          %element-AdventurerName = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Rule 4: name must be unique (case-insensitive, ignoring this record)
      SELECT SINGLE adventurer_id
        FROM zrpg_adventurer
        WHERE upper( adventurer_name ) = @( to_upper( lv_name ) )
          AND adventurer_id          <> @<adv>-AdventurerId
        INTO @DATA(lv_duplicate_id).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                    = <adv>-%tky
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = |Adventurer name "{ lv_name }" already exists.| )
          %element-AdventurerName = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.

    ENDLOOP.

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
    " Read adventurer data ──────────────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName AdventurerLevel )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE adventurers ASSIGNING FIELD-SYMBOL(<adv>)
        WITH KEY %tky = <key>-%tky.
      CHECK sy-subrc = 0.

      " ── Step 2: Adventurer must be persisted before taking quests ─
      " A draft that was never activated does not exist in the active
      " table yet and therefore cannot accept quests.
      SELECT SINGLE @abap_true
        FROM zrpg_adventurer
        WHERE adventurer_id = @<adv>-AdventurerId
        INTO @DATA(lv_persisted).

      IF <key>-%is_draft = if_abap_behv=>mk-on OR lv_persisted <> abap_true.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                 = <adv>-%tky
          %action-acceptQuest  = if_abap_behv=>mk-on
          %msg                 = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Save the adventurer before accepting quests.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 3: Validate QuestId was provided ──────────────────
      DATA(lv_quest_id) = <key>-%param-QuestId.
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

      " ── Step 4: Delegate to the Quest BO action ────────────────
      " All quest-side rules (OPEN status, level requirement, not yet
      " assigned) live in one place: Quest~acceptQuest. The RAP lock
      " on the quest instance serializes concurrent accept attempts.
      MODIFY ENTITIES OF zi_rpg_quest
        ENTITY Quest
          EXECUTE acceptQuest
          FROM VALUE #( ( QuestId             = lv_quest_id
                          %param-AdventurerId = <adv>-AdventurerId ) )
        FAILED   DATA(quest_failed)
        REPORTED DATA(quest_reported).

      " ── Step 5: Relay quest messages to the adventurer UI ──────
      LOOP AT quest_reported-Quest ASSIGNING FIELD-SYMBOL(<quest_msg>).
        IF <quest_msg>-%msg IS BOUND.
          APPEND VALUE #( %tky = <adv>-%tky
                          %msg = <quest_msg>-%msg ) TO reported-Adventurer.
        ENDIF.
      ENDLOOP.

      IF quest_failed-Quest IS NOT INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        CONTINUE.
      ENDIF.

    ENDLOOP.

    " ── Step 6: Return updated adventurer ───────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).

    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky   = adv-%tky
                        %param = CORRESPONDING #( adv ) ) ).
  ENDMETHOD.

  METHOD completeQuest.
    " ── Step 1: Read adventurer data ──────────────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE adventurers ASSIGNING FIELD-SYMBOL(<adv>)
        WITH KEY %tky = <key>-%tky.
      CHECK sy-subrc = 0.

      " ── Step 2: Validate QuestId was provided ──────────────────
      DATA(lv_quest_id) = <key>-%param-QuestId.
      IF lv_quest_id IS INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                  = <adv>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'Please select a quest.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 3: Quest must belong to this adventurer ───────────
      " Only the adventurer who accepted the quest may complete it.
      SELECT SINGLE quest_name, status, adventurer_id, xp_reward, gold_reward
        FROM zrpg_quest
        WHERE quest_id = @lv_quest_id
        INTO @DATA(quest_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                  = <adv>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = 'Quest not found. Please select a valid quest.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      IF quest_data-adventurer_id IS INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                  = <adv>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = |Quest '{ quest_data-quest_name }' has not|
                                            && | been accepted yet.| )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      IF quest_data-adventurer_id <> <adv>-AdventurerId.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                  = <adv>-%tky
          %action-completeQuest = if_abap_behv=>mk-on
          %msg                  = new_message_with_text(
                                    severity = if_abap_behv_message=>severity-error
                                    text     = |Quest '{ quest_data-quest_name }' belongs to|
                                            && | another adventurer. Only the adventurer who|
                                            && | accepted it can complete it.| )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 4: Delegate the status change to the Quest BO ─────
      " Quest~completeQuest validates IN_PROGRESS and sets COMPLETED.
      MODIFY ENTITIES OF zi_rpg_quest
        ENTITY Quest
          EXECUTE completeQuest
          FROM VALUE #( ( QuestId = lv_quest_id ) )
        FAILED   DATA(quest_failed)
        REPORTED DATA(quest_reported).

      " Relay quest messages to the adventurer UI
      LOOP AT quest_reported-Quest ASSIGNING FIELD-SYMBOL(<quest_msg>).
        IF <quest_msg>-%msg IS BOUND.
          APPEND VALUE #( %tky = <adv>-%tky
                          %msg = <quest_msg>-%msg ) TO reported-Adventurer.
        ENDIF.
      ENDLOOP.

      IF quest_failed-Quest IS NOT INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Step 5: Award XP — every 10 XP grants one level ────────
      " Read from the transactional buffer so completing several
      " quests in one request accumulates correctly.
      READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
        ENTITY Adventurer
          FIELDS ( AdventurerLevel AdventurerXp AdventurerGold )
          WITH VALUE #( ( %tky = <adv>-%tky ) )
        RESULT DATA(current_stats).

      READ TABLE current_stats ASSIGNING FIELD-SYMBOL(<stats>) INDEX 1.
      CHECK sy-subrc = 0.

      DATA(total_xp)      = <stats>-AdventurerXp + quest_data-xp_reward.
      DATA(levels_gained) = total_xp DIV c_xp_per_level.
      DATA(new_level)     = <stats>-AdventurerLevel + levels_gained.
      DATA(new_xp)        = total_xp MOD c_xp_per_level.
      DATA(new_gold)    = <stats>-AdventurerGold + quest_data-gold_reward.

      MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
        ENTITY Adventurer
          UPDATE FIELDS ( AdventurerLevel AdventurerXp AdventurerGold )
          WITH VALUE #( ( %tky            = <adv>-%tky
                          AdventurerLevel = new_level
                          AdventurerXp    = new_xp
                          AdventurerGold = new_gold ) )
        REPORTED DATA(rep_xp)
        FAILED   DATA(fail_xp).

      reported-Adventurer = CORRESPONDING #(
        BASE ( reported-Adventurer ) rep_xp-Adventurer ).

      " ── Step 6: Success message with XP and level info ─────────
      DATA(level_up_text) = ||.
      IF levels_gained > 0.
        level_up_text = | 🎉 Level up! { <adv>-AdventurerName }|
                     && | is now level { new_level }!|.
      ENDIF.

      APPEND VALUE #(
        %tky = <adv>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |{ <adv>-AdventurerName } gained|
                         && | { quest_data-xp_reward } XP.|
                         && | Remaining XP: { new_xp }.|
                         && level_up_text )
      ) TO reported-Adventurer.

    ENDLOOP.

    " ── Step 7: Return updated adventurer (new level/XP included) ─
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).

    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky   = adv-%tky
                        %param = CORRESPONDING #( adv ) ) ).
  ENDMETHOD.
  METHOD buyItem.
   " Read adventurer data ──────────────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName AdventurerLevel )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE adventurers ASSIGNING FIELD-SYMBOL(<adv>)
        WITH KEY %tky = <key>-%tky.
      CHECK sy-subrc = 0.

      "Adventurer must be persisted before buying items ─
      " A draft that was never activated does not exist in the active
      " table yet and therefore cannot buy items.
      SELECT SINGLE @abap_true
        FROM zrpg_adventurer
        WHERE adventurer_id = @<adv>-AdventurerId
        INTO @DATA(lv_persisted).

      IF <key>-%is_draft = if_abap_behv=>mk-on OR lv_persisted <> abap_true.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                 = <adv>-%tky
          %action-buyItem  = if_abap_behv=>mk-on
          %msg                 = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Save the adventurer before buying items.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Validate ItemId was provided ──────────────────
      DATA(lv_item_id) = <key>-%param-ItemId.
      IF lv_item_id IS INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Please select am item.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Delegate to the Marketplace BO action
      MODIFY ENTITIES OF zi_rpg_marketplace
        ENTITY Marketplace
          EXECUTE buyItem
          FROM VALUE #( ( ItemId             = lv_item_id
                          %param-AdventurerId = <adv>-AdventurerId ) )
        FAILED   DATA(sale_failed)
        REPORTED DATA(sale_reported).

      LOOP AT sale_reported-Marketplace ASSIGNING FIELD-SYMBOL(<item_msg>).
        IF <item_msg>-%msg IS BOUND.
          APPEND VALUE #( %tky = <adv>-%tky
                          %msg = <item_msg>-%msg ) TO reported-Adventurer.
        ENDIF.
      ENDLOOP.

      IF sale_failed-Marketplace IS NOT INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        CONTINUE.
      ENDIF.

    ENDLOOP.

    "  Return updated adventurer
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).

    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky   = adv-%tky
                        %param = CORRESPONDING #( adv ) ) ).
  ENDMETHOD.

ENDCLASS.
