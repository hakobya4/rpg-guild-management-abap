CLASS lsc_zi_rpg_adventurer DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.



CLASS lsc_zi_rpg_adventurer IMPLEMENTATION.
  " When an adventurer is deleted, return all their inventory items to the marketplace and all the quest items in progress to quests
  METHOD save_modified.
    LOOP AT delete-adventurer INTO DATA(deleted_adv).

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

      "Items to be returned to quest
      SELECT quest_id, status
        FROM zrpg_quest
        WHERE adventurer_id = @deleted_adv-AdventurerId AND status = 'IN_PROGRESS'
        INTO TABLE @DATA(adv_quest_incomp).

      "Return the in progress quests to quest buisiness object
      LOOP AT adv_quest_incomp INTO DATA(adv_quest).
        UPDATE zrpg_quest
          SET  status   = 'OPEN', adventurer_id =  @( VALUE sysuuid_x16( ) )
          WHERE quest_id = @adv_quest-quest_id.
      ENDLOOP.

      " Remove the inventory and quests that are not useful
      DELETE FROM zrpg_inventory
        WHERE adventurerid = @deleted_adv-AdventurerId.
      DELETE FROM zrpg_quest
        WHERE adventurer_id = @deleted_adv-AdventurerId .

    ENDLOOP.

  ENDMETHOD.



ENDCLASS.


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
    METHODS validateAdventurerInfo FOR VALIDATE ON SAVE
      IMPORTING keys FOR Adventurer~validateAdventurerInfo.
    METHODS acceptQuest FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~acceptQuest RESULT result.
    METHODS buyItem FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~buyItem RESULT result.
    METHODS joinGuild FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~joinGuild RESULT result.
    METHODS quitGuild FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~quitGuild RESULT result.
    METHODS rollStats FOR MODIFY
      IMPORTING keys FOR ACTION Adventurer~rollStats RESULT result.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Adventurer.
    METHODS validateOwnership FOR VALIDATE ON SAVE
      IMPORTING keys FOR Adventurer~validateOwnership.

ENDCLASS.

CLASS lhc_Adventurer IMPLEMENTATION.

  METHOD get_global_authorizations.
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
        AdventurerClass = COND #( WHEN <adv>-AdventurerClass IS INITIAL
                                   THEN c_adventurer_class
                                   ELSE <adv>-AdventurerClass )
      ) TO updates.
    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        UPDATE FIELDS ( AdventurerLevel AdventurerXp AdventurerGold AdventurerClass )
        WITH updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Adventurer = CORRESPONDING #(
      BASE ( reported-Adventurer ) rep-Adventurer ).

  ENDMETHOD.



  METHOD validateAdventurerInfo.
    " Read the adventurer name
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName AdventurerClass AdvStr AdvDex AdvCon AdvInt AdvWis AdvCha )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    DATA lt_name_range TYPE RANGE OF zrpg_adventurer-adventurer_name.
    lt_name_range = VALUE #( FOR a IN adventurers
                             WHERE ( AdventurerName IS NOT INITIAL )
                             ( sign = 'I' option = 'EQ' low = to_upper( a-AdventurerName ) ) ).
    IF lt_name_range IS NOT INITIAL.
      SELECT adventurer_id, upper( adventurer_name ) AS uname
        FROM zrpg_adventurer
        WHERE upper( adventurer_name ) IN @lt_name_range
        INTO TABLE @DATA(lt_existing_names).
    ENDIF.

    DATA lt_seen TYPE HASHED TABLE OF zrpg_adventurer-adventurer_name WITH UNIQUE KEY table_line.

    "  Check each instance
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

      " name must not be empty
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

      " name must not contain numbers
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

      " name must contain at least 3 letters
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

      "  name must be unique
      DATA(lv_uname) = to_upper( lv_name ).
      DATA(lv_duplicate) = abap_false.
      LOOP AT lt_existing_names TRANSPORTING NO FIELDS
        WHERE uname = lv_uname AND adventurer_id <> <adv>-AdventurerId.
        lv_duplicate = abap_true.
        EXIT.
      ENDLOOP.
      IF lv_duplicate = abap_false AND line_exists( lt_seen[ table_line = lv_uname ] ).
        lv_duplicate = abap_true.
      ENDIF.
      INSERT CONV zrpg_adventurer-adventurer_name( lv_uname ) INTO TABLE lt_seen.

      IF lv_duplicate = abap_true.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                    = <adv>-%tky
          %msg                    = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = |Adventurer name "{ lv_name }" already exists.| )
          %element-AdventurerName = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.

      IF <adv>-AdvStr < 1 .
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %msg            = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Strength must be higher than 1' )
          %element-AdvStr = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.

      IF <adv>-AdvDex < 1.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %msg            = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Dexterity must be higher than 1.' )
          %element-AdvDex = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.

      IF <adv>-AdvCon < 1.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %msg            = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Constitution must be higher than 1.' )
          %element-AdvCon = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.

      IF <adv>-AdvInt < 1.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %msg            = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Intelligence must be higher than 1.' )
          %element-AdvInt = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.

      IF <adv>-AdvWis < 1.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %msg            = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Wisdom must be higher than 1.' )
          %element-AdvWis = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.

      IF <adv>-AdvCha < 1.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %msg            = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Charisma must be higher than 1.' )
          %element-AdvCha = if_abap_behv=>mk-on
        ) TO reported-Adventurer.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateOwnership.
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( CreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    LOOP AT adventurers ASSIGNING FIELD-SYMBOL(<adv>).
      IF zcl_rpg_ownership=>is_owner( <adv>-CreatedBy ) = abap_false.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Only the player who created this adventurer can change it.' )
        ) TO reported-Adventurer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_delete.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      SELECT SINGLE created_by
        FROM zrpg_adventurer
        WHERE adventurer_id = @<key>-AdventurerId
        INTO @DATA(lv_created_by).

      IF sy-subrc = 0 AND zcl_rpg_ownership=>is_owner( lv_created_by ) = abap_false.
        APPEND VALUE #( %tky        = <key>-%tky
                        %fail-cause = if_abap_behv=>cause-unauthorized
        ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Only the player who created this adventurer can delete it.' )
        ) TO reported-Adventurer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD acceptQuest.
    " Read adventurer data
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( AdventurerName AdventurerLevel CreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE adventurers ASSIGNING FIELD-SYMBOL(<adv>)
        WITH TABLE KEY id COMPONENTS %tky = <key>-%tky.
      CHECK sy-subrc = 0.

      " Adventurer must be activated/ created before taking quests .
      SELECT SINGLE @abap_true " checks whether the where statement is true without fetching the table.
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

      " Only the owning player may act for this adventurer
      IF zcl_rpg_ownership=>is_owner( <adv>-CreatedBy ) = abap_false.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'You can only accept quests for your own adventurer.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Validate QuestId was provided
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

      " Runs acceptQuest from Quest business object
      MODIFY ENTITIES OF zi_rpg_quest
        ENTITY Quest
          EXECUTE acceptQuest
          FROM VALUE #( ( QuestId             = lv_quest_id
                          %param-AdventurerId = <adv>-AdventurerId ) )
        FAILED   DATA(quest_failed)
        REPORTED DATA(quest_reported).

      " Relay quest messages
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

    " Return updated adventurer
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).

    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky   = adv-%tky
                        %param = CORRESPONDING #( adv ) ) ).
  ENDMETHOD.

  METHOD buyItem.
    " Read adventurer data
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
      FIELDS ( AdventurerName AdventurerLevel AdventurerGold CreatedBy
                 AdvStr AdvDex AdvCon AdvInt AdvWis AdvCha )
      WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE adventurers ASSIGNING FIELD-SYMBOL(<adv>)
        WITH TABLE KEY id COMPONENTS %tky = <key>-%tky.
      CHECK sy-subrc = 0.

      "Adventurer must exist
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

      " Only the owning player may act for this adventurer
      IF zcl_rpg_ownership=>is_owner( <adv>-CreatedBy ) = abap_false.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'You can only buy items for your own adventurer.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Validate ItemId was provided
      DATA(lv_item_id) = <key>-%param-ItemId.
      IF lv_item_id IS INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Please select an item.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.
      " Amount of item
      DATA(lv_amount) = <key>-%param-Amount.
      IF lv_amount < 1.
        lv_amount = 1.
      ENDIF.

      " Checks on item requirments
      SELECT SINGLE item_name, item_type, item_subtype, description, required_level, price,
                     str_bonus, dex_bonus, con_bonus, int_bonus, wis_bonus, cha_bonus
         FROM zrpg_marketplace
         WHERE item_id = @lv_item_id
         INTO @DATA(item_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %action-buyItem = if_abap_behv=>mk-on
          %msg            = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = 'Item not found. Select a valid item.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.


      DATA(lv_total_cost) = lv_amount * item_data-price.

      IF <adv>-AdventurerGold < lv_total_cost.
        " gold-check failure — drop the "sy-subrc = 0 AND" entirely
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky            = <adv>-%tky
          %action-buyItem = if_abap_behv=>mk-on
          %msg            = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = |Not enough gold|
                         )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Marketpace uses buyItem
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

      " remove gold spent
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

      IF fail_gold-Adventurer IS NOT INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'The gold payment could not be applied - the purchase was cancelled.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      "update adventurer inventory from sale
      SELECT SINGLE inventory_id, amount
        FROM zrpg_inventory
        WHERE adventurerid = @<adv>-AdventurerId
          AND item_id       = @lv_item_id
        INTO @DATA(inv_row).

      IF sy-subrc = 0.
        " Already owned, do not create a new row, increase the quantity
        MODIFY ENTITIES OF zi_rpg_inventory
          ENTITY Inventory
            UPDATE FIELDS ( Amount )
            WITH VALUE #( ( InventoryId = inv_row-inventory_id
                            Amount      = inv_row-amount + lv_amount ) )
          REPORTED DATA(rep_inv_u)
          FAILED   DATA(fail_inv_u).
      ELSE.

        IF fail_inv_u-Inventory IS NOT INITIAL.
          APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
          APPEND VALUE #(
            %tky = <adv>-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = 'The item could not be added to the inventory - the purchase was cancelled.' )
          ) TO reported-Adventurer.
          CONTINUE.
        ENDIF.
        " First time owning this item, create a new row
        MODIFY ENTITIES OF zi_rpg_inventory
          ENTITY Inventory
            CREATE FIELDS ( AdventurerId ItemId ItemName ItemType ItemSubtype Description Amount RequiredLevel Price
                            StrBonus DexBonus ConBonus IntBonus WisBonus ChaBonus )
              WITH VALUE #( ( %cid         = |INV_{ lv_item_id }|
                            AdventurerId = <adv>-AdventurerId
                            ItemId       = lv_item_id
                            ItemName     = item_data-item_name
                            ItemType     = item_data-item_type
                            ItemSubtype  = item_data-item_subtype
                            Description  = item_data-description
                            Amount       = lv_amount
                            RequiredLevel = item_data-required_level
                            Price        = item_data-price
                            StrBonus     = item_data-str_bonus
                            DexBonus     = item_data-dex_bonus
                            ConBonus     = item_data-con_bonus
                            IntBonus     = item_data-int_bonus
                            WisBonus     = item_data-wis_bonus
                            ChaBonus     = item_data-cha_bonus  ) )
          REPORTED DATA(rep_inv_c)
          FAILED   DATA(fail_inv_c).

        IF fail_inv_c-Inventory IS NOT INITIAL.
          APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
          APPEND VALUE #(
            %tky = <adv>-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = 'The item could not be added to the inventory - the purchase was cancelled.' )
          ) TO reported-Adventurer.
          CONTINUE.
        ENDIF.
      ENDIF.
      MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
        ENTITY Adventurer
        UPDATE FIELDS ( AdvStr AdvDex AdvCon AdvInt AdvWis AdvCha )
        WITH VALUE #( ( AdventurerId = <adv>-AdventurerId
                    AdvStr = <adv>-AdvStr + item_data-str_bonus
                    AdvDex = <adv>-AdvDex + item_data-dex_bonus
                    AdvCon = <adv>-AdvCon + item_data-con_bonus
                    AdvInt = <adv>-AdvInt + item_data-int_bonus
                    AdvWis = <adv>-AdvWis + item_data-wis_bonus
                    AdvCha = <adv>-AdvCha + item_data-cha_bonus ) )
      REPORTED DATA(rep_stat_buy)
      FAILED   DATA(fail_stat_buy).

      reported-Adventurer = CORRESPONDING #(
        BASE ( reported-Adventurer ) rep_stat_buy-Adventurer ).
      IF fail_stat_buy-Adventurer IS NOT INITIAL.
        APPEND VALUE #( %tky = <adv>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky = <adv>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'The item bonuses could not be applied - the purchase was cancelled.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Success message only after every write went through
      APPEND VALUE #(
        %tky = <adv>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |{ lv_total_cost } gold spent.|
                         && | { <adv>-AdventurerName } now has { new_gold } gold.| )
      ) TO reported-Adventurer.

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

  METHOD joinGuild.


    DATA updates TYPE TABLE FOR UPDATE zi_rpg_adventurer\\Adventurer.


    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).


      SELECT SINGLE adventurer_name, guild_id, created_by
        FROM zrpg_adventurer
        WHERE adventurer_id = @<key>-AdventurerId
        INTO @DATA(adv_data).

      IF sy-subrc <> 0 OR <key>-%is_draft = if_abap_behv=>mk-on.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky              = <key>-%tky
          %action-joinGuild = if_abap_behv=>mk-on
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
                                text     = 'Save the adventurer before joining a guild.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Only the owning player may act for this adventurer
      IF zcl_rpg_ownership=>is_owner( adv_data-created_by ) = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky              = <key>-%tky
          %action-joinGuild = if_abap_behv=>mk-on
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
                                text     = 'You can only manage guild membership for your own adventurer.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      DATA(lv_guild_id) = <key>-%param-GuildId.

      " Guild must exist
      SELECT SINGLE guild_id, guild_name
        FROM zrpg_guild
        WHERE guild_id = @lv_guild_id
        INTO @DATA(guild_data).

      IF <key>-%is_draft = if_abap_behv=>mk-on OR sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky              = <key>-%tky
          %action-joinGuild = if_abap_behv=>mk-on
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
                                text     = 'Guild not found. Please select a valid guild.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      " Already a member?
      IF adv_data-guild_id = lv_guild_id.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky              = <key>-%tky
          %action-joinGuild = if_abap_behv=>mk-on
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
text     = |{ adv_data-adventurer_name } is already a member of { guild_data-guild_name }.| )        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = <key>-%tky  GuildId = lv_guild_id ) TO updates.


      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |{ adv_data-adventurer_name } has joined { guild_data-guild_name }!| )
      ) TO reported-Adventurer.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
        ENTITY Adventurer
          UPDATE FIELDS ( GuildId ) WITH updates
        REPORTED DATA(rep) FAILED DATA(fail).
      reported-Adventurer = CORRESPONDING #( BASE ( reported-Adventurer ) rep-Adventurer ).
      failed-Adventurer   = CORRESPONDING #( BASE ( failed-Adventurer ) fail-Adventurer ).
    ENDIF.

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).

    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky = adv-%tky  %param = CORRESPONDING #( adv ) ) ).
  ENDMETHOD.

  METHOD quitGuild.
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( GuildId CreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_adventurer\\Adventurer.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE adventurers ASSIGNING FIELD-SYMBOL(<adv>)
        WITH KEY %tky = <key>-%tky.


      IF sy-subrc <> 0 OR <key>-%is_draft = if_abap_behv=>mk-on.

        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                 = <key>-%tky
          %action-quitGuild  = if_abap_behv=>mk-on
          %msg                 = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Join the guild before trying to quit.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      IF zcl_rpg_ownership=>is_owner( <adv>-CreatedBy ) = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky              = <key>-%tky
          %action-quitGuild = if_abap_behv=>mk-on
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
                                text     = 'You can only manage guild membership for your own adventurer.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      IF <adv>-GuildId = VALUE sysuuid_x16( ).
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky                 = <key>-%tky
          %action-quitGuild  = if_abap_behv=>mk-on
          %msg                 = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Adventurer is not in a guild.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky    = <key>-%tky
                      GuildId = VALUE sysuuid_x16( ) ) TO updates.   " 16 zeros = no guild
    ENDLOOP.

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        UPDATE FIELDS ( GuildId )
        WITH updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Adventurer = CORRESPONDING #( BASE ( reported-Adventurer ) rep-Adventurer ).

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS
      WITH CORRESPONDING #( keys )
    RESULT DATA(result_adventurers).

    result = VALUE #( FOR adv IN result_adventurers
                      ( %tky   = adv-%tky
                        %param = CORRESPONDING #( adv ) ) ).
  ENDMETHOD.

  METHOD rollStats.
        READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        FIELDS ( CreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(adventurers).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_adventurer\\Adventurer.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

    " Only the owning player may act for this adventurer
      READ TABLE adventurers ASSIGNING FIELD-SYMBOL(<owner_check>)
        WITH KEY %tky = <key>-%tky.
      IF sy-subrc = 0 AND zcl_rpg_ownership=>is_owner( <owner_check>-CreatedBy ) = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Adventurer.
        APPEND VALUE #(
          %tky              = <key>-%tky
          %action-rollStats = if_abap_behv=>mk-on
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
                                text     = 'You can only roll stats for your own adventurer.' )
        ) TO reported-Adventurer.
        CONTINUE.
      ENDIF.

      DATA lo_roller TYPE REF TO zif_rpg_dice_roller.
      lo_roller = NEW zcl_rpg_roll_dice( ).


      APPEND VALUE #(
        %tky   = <key>-%tky
        AdvStr = lo_roller->roll_stats( )
        AdvDex = lo_roller->roll_stats( )
        AdvCon = lo_roller->roll_stats( )
        AdvInt = lo_roller->roll_stats( )
        AdvWis = lo_roller->roll_stats( )
        AdvCha = lo_roller->roll_stats( )
      ) TO updates.



      MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
       ENTITY Adventurer
         UPDATE FIELDS ( AdvStr AdvDex AdvCon AdvInt AdvWis AdvCha )
         WITH updates
       REPORTED DATA(rep)
       FAILED   DATA(fail).

      reported-Adventurer = CORRESPONDING #( BASE ( reported-Adventurer ) rep-Adventurer ).

      READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
        ENTITY Adventurer ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_adventurers).

      result = VALUE #( FOR adv IN result_adventurers
                        ( %tky   = adv-%tky
                          %param = CORRESPONDING #( adv ) ) ).

    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
