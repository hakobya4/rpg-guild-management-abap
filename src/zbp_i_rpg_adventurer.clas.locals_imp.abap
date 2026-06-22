CLASS lsc_zi_rpg_adventurer DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zi_rpg_adventurer IMPLEMENTATION.
  " When an adventurer is deleted, return all their inventory items to the marketplace
  METHOD save_modified.
    LOOP AT delete-Adventurer INTO DATA(deleted_adv).

      " Items the deleted adventurer was holding
      SELECT item_id, amount
        FROM zrpg_inventory
        WHERE adventurerid = @deleted_adv-AdventurerId
        INTO TABLE @DATA(inv_items).

      " Return each stack to the marketplace and mark it available again
      LOOP AT inv_items INTO DATA(inv_item).
        UPDATE zrpg_marketplace
          SET amount_available = amount_available + @inv_item-amount,
              status           = 'AVAILABLE'
          WHERE item_id = @inv_item-item_id.
      ENDLOOP.

      " Remove the orphaned inventory rows
      DELETE FROM zrpg_inventory
        WHERE adventurerid = @deleted_adv-AdventurerId.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lhc_Adventurer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Every 10 XP the adventurer gains one level; the remainder is kept
    CONSTANTS c_xp_per_level TYPE i VALUE 10.
    CONSTANTS c_adventurer_class TYPE zrpg_adventurer-adventurer_class VALUE 'FIGHTER'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Adventurer RESULT result.

    " Sets Level=1, XP=0 for every new adventurer
    METHODS initAdventurer FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Adventurer~initAdventurer.
    METHODS joinGuild FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~joinGuild RESULT result.
    METHODS validateAdventurerInfo FOR VALIDATE ON SAVE
      IMPORTING keys FOR Adventurer~validateAdventurerInfo.
    METHODS acceptQuest FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~acceptQuest RESULT result.
    METHODS completeQuest FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~completeQuest RESULT result.
    METHODS buyItem FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~buyItem RESULT result.
    METHODS sellItem FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~sellItem RESULT result.

ENDCLASS.

CLASS lhc_Adventurer IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.

  METHOD initAdventurer.

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerLevel AdventurerXp AdventurerGold AdventurerClass )
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
        AdventurerClass = c_adventurer_class
      ) TO updates.
    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        UPDATE FIELDS ( AdventurerLevel AdventurerXp AdventurerGold )
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

  METHOD validateAdventurerInfo.
    " ── Step 1: Read the adventurer name ──────────────────────────
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName AdventurerClass )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    " ── Step 2: Check each instance ───────────────────────────────
    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).

      DATA(lv_name) = <adv>-AdventurerName.
      DATA(lv_class) = <adv>-AdventurerClass.

      IF lv_class IS INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                    = <adv>-%tky
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = 'Adventurer class cannot be empty.' )
          %element-AdventurerClass = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

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
        FIELDS ( AdventurerName AdventurerLevel AdventurerGold )
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
      " Quantity from the action parameter (default 1)
      DATA(lv_amount) = <key>-%param-Amount.
      IF lv_amount < 1.
        lv_amount = 1.
      ENDIF.

      " Read the item price and check the adventurer can afford the TOTAL
      " BEFORE the sale runs, so stock is not decremented on a failed buy.
      SELECT SINGLE item_name, item_type, item_subtype, description, required_level, price
        FROM zrpg_marketplace
        WHERE item_id = @lv_item_id
        INTO @DATA(item_data).

      DATA(lv_total_cost) = lv_amount * item_data-price.

      IF sy-subrc = 0 AND <adv>-AdventurerGold < lv_total_cost.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %action-buyItem = if_abap_behv=>mk-on
          %msg            = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = |{ <adv>-AdventurerName } cannot afford|
                                      && | { lv_amount }x '{ item_data-item_name }'.|
                                      && | Cost: { lv_total_cost },|
                                      && | gold: { <adv>-AdventurerGold }.| )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Delegate to the Marketplace BO action (passes the quantity)
      MODIFY ENTITIES OF zi_rpg_marketplace
        ENTITY Marketplace
          EXECUTE buyItem
          FROM VALUE #( ( ItemId              = lv_item_id
                          %param-AdventurerId = <adv>-AdventurerId
                          %param-Amount       = lv_amount ) )
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

      " Sale succeeded — deduct the total cost from the adventurer's gold
      " (own BO, local mode — done per purchase inside the loop).
      DATA(new_gold) = <adv>-AdventurerGold - lv_total_cost.
      MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
        ENTITY Adventurer
          UPDATE FIELDS ( AdventurerGold )
          WITH VALUE #( ( %tky           = <adv>-%tky
                          AdventurerGold = new_gold ) )
        REPORTED DATA(rep_gold)
        FAILED   DATA(fail_gold).

      reported-Adventurer = CORRESPONDING #(
        BASE ( reported-Adventurer ) rep_gold-Adventurer ).

      APPEND VALUE #(
        %tky = <adv>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |{ lv_total_cost } gold spent.|
                         && | { <adv>-AdventurerName } now has { new_gold } gold.| )
      ) TO reported-Adventurer.
      " ── Add the bought units to the adventurer's inventory ─────
      " One inventory row per (adventurer, item); accumulate the amount.
      SELECT SINGLE inventory_id, amount
        FROM zrpg_inventory
        WHERE adventurerid = @<adv>-AdventurerId
          AND item_id       = @lv_item_id
        INTO @DATA(inv_row).

      IF sy-subrc = 0.
        " Already owned — increase the quantity
        MODIFY ENTITIES OF zi_rpg_inventory
          ENTITY Inventory
            UPDATE FIELDS ( Amount )
            WITH VALUE #( ( InventoryId = inv_row-inventory_id
                            Amount      = inv_row-amount + lv_amount ) )
          REPORTED DATA(rep_inv_u)
          FAILED   DATA(fail_inv_u).
      ELSE.
        " First time owning this item — create a new inventory row
        MODIFY ENTITIES OF zi_rpg_inventory
          ENTITY Inventory
            CREATE FIELDS ( AdventurerId ItemId ItemName ItemType ItemSubtype Description Amount RequiredLevel Price )
              WITH VALUE #( ( %cid         = |INV_{ lv_item_id }|
                            AdventurerId = <adv>-AdventurerId
                            ItemId       = lv_item_id
                            ItemName     = item_data-item_name
                            ItemType     = item_data-item_type
                            ItemSubtype  = item_data-item_subtype
                            Description  = item_data-description
                            Amount       = lv_amount
                            RequiredLevel = item_data-required_level
                            Price        = item_data-price ) )
          REPORTED DATA(rep_inv_c)
          FAILED   DATA(fail_inv_c).
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

  METHOD sellItem.
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName AdventurerGold )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE adventurers ASSIGNING FIELD-SYMBOL(<adv>)
        WITH KEY %tky = <key>-%tky.
      CHECK sy-subrc = 0.

      DATA(lv_item_id) = <key>-%param-ItemId.
      IF lv_item_id IS INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #( %tky = <adv>-%tky  %action-sellItem = if_abap_behv=>mk-on
          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                        text = 'Please select an item to sell.' ) ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Read THIS adventurer's inventory row (key + ownership in one WHERE)
      SELECT SINGLE inventory_id, item_name, price, amount
        FROM zrpg_inventory
        WHERE item_id      = @lv_item_id
          AND adventurerid = @<adv>-AdventurerId
        INTO @DATA(inv).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #( %tky = <adv>-%tky  %action-sellItem = if_abap_behv=>mk-on
          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                        text = 'That item is not in your inventory.' ) ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Validate the amount FIRST ──
      DATA(lv_amount_sold) = <key>-%param-Amount.
      IF lv_amount_sold < 1.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #( %tky = <adv>-%tky  %action-sellItem = if_abap_behv=>mk-on
          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                        text = 'Enter how many to sell (at least 1).' ) ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.
      IF lv_amount_sold > inv-amount.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #( %tky = <adv>-%tky  %action-sellItem = if_abap_behv=>mk-on
          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                        text = |You only own { inv-amount } of '{ inv-item_name }'.| ) ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      DATA(lv_refund) = lv_amount_sold * inv-price.
      DATA(new_gold)  = <adv>-AdventurerGold + lv_refund.

      " ── Remove or reduce the stack, keyed by InventoryId ──
      DATA inv_failed TYPE RESPONSE FOR FAILED zi_rpg_inventory.
      IF lv_amount_sold = inv-amount.
        MODIFY ENTITIES OF zi_rpg_inventory
          ENTITY Inventory
            DELETE FROM VALUE #( ( InventoryId = inv-inventory_id ) )
          FAILED inv_failed REPORTED DATA(rep_del).
      ELSE.
        MODIFY ENTITIES OF zi_rpg_inventory
          ENTITY Inventory
            UPDATE FIELDS ( Amount )
            WITH VALUE #( ( InventoryId = inv-inventory_id
                            Amount      = inv-amount - lv_amount_sold ) )
          FAILED inv_failed REPORTED DATA(rep_upd).
      ENDIF.

      IF inv_failed-Inventory IS NOT INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        CONTINUE.
      ENDIF.

      " ── Credit gold (own BO → local mode) ──
      MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
        ENTITY Adventurer
          UPDATE FIELDS ( AdventurerGold )
          WITH VALUE #( ( %tky = <adv>-%tky  AdventurerGold = new_gold ) )
        REPORTED DATA(rep_gold) FAILED DATA(fail_gold).
      reported-Adventurer = CORRESPONDING #( BASE ( reported-Adventurer ) rep_gold-Adventurer ).

      APPEND VALUE #( %tky = <adv>-%tky
        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
          text = |Sold { lv_amount_sold }x '{ inv-item_name }' for { lv_refund } gold.| ) ) TO reported-Adventurer.

      SELECT SINGLE amount_available
          FROM zrpg_marketplace
          WHERE item_id = @lv_item_id
            INTO @DATA(item_available).

      MODIFY ENTITIES OF zi_rpg_marketplace
         ENTITY Marketplace
           UPDATE FIELDS ( AmountAvailable )
           WITH VALUE #( ( ItemId = lv_item_id  AmountAvailable = item_available + lv_amount_sold ) )
         REPORTED DATA(rep_amount) FAILED DATA(fail_amount).

      IF fail_amount-Marketplace IS NOT INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        CONTINUE.
      ENDIF.

    ENDLOOP.

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).
    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky = adv-%tky  %param = CORRESPONDING #( adv ) ) ).
  ENDMETHOD.
ENDCLASS.
