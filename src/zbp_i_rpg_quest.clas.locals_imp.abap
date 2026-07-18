*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

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
      " COMMON 60% / UNCOMMON 25% / RARE 10% / LEGENDARY 5%.
      c_pct_any_drop       TYPE i VALUE 30,
      c_pct_common         TYPE i VALUE 60,
      c_pct_uncommon       TYPE i VALUE 25,
      c_pct_rare           TYPE i VALUE 10,
      c_pct_legendary      TYPE i VALUE 5.


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
    METHODS previewLootOdds FOR MODIFY
      IMPORTING keys FOR ACTION Quest~previewLootOdds RESULT result.
    METHODS linkAllLootItems FOR DETERMINE ON SAVE
      IMPORTING keys FOR Quest~linkAllLootItems.

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
      SELECT SINGLE adventurer_name, adventurer_level
        FROM zrpg_adventurer
        WHERE adventurer_id = @lv_adventurer_id
        INTO @DATA(adventurer_data).

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
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      SELECT SINGLE status, adventurer_id, xp_reward, quest_name, required_level, gold_reward, quest_type_name, difficulty_class, required_stat, quest_id
        FROM zrpg_quest
        WHERE quest_id = @<key>-QuestId
        INTO @DATA(quest_data).
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
      IF quest_data-adventurer_id IS INITIAL.
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

      "update adventurer values

      SELECT SINGLE adventurer_id, adventurer_gold, adventurer_xp, adventurer_level, adventurer_class,
      adv_str, adv_dex, adv_con, adv_int, adv_wis, adv_cha
        FROM zrpg_adventurer
        WHERE adventurer_id = @quest_data-adventurer_id
        INTO @DATA(lv_adv_stats).

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

      DATA(lv_modifier) = NEW zcl_rpg_stat_check( )->zif_rpg_quest_resolution~get_check_modifier(
                             iv_quest_stat       = quest_data-required_stat
                             iv_adventurer_level = lv_adv_stats-adventurer_level
                             iv_required_level   = quest_data-required_level
                             iv_adventurer_str   = lv_adv_stats-adv_str
                             iv_adventurer_dex   = lv_adv_stats-adv_dex
                             iv_adventurer_con   = lv_adv_stats-adv_con
                             iv_adventurer_int   = lv_adv_stats-adv_int
                             iv_adventurer_wis   = lv_adv_stats-adv_wis
                             iv_adventurer_cha   = lv_adv_stats-adv_cha ).

      IF go_dice_roller IS INITIAL.
        go_dice_roller = NEW zcl_rpg_roll_dice( ).
      ENDIF.
      DATA(lv_roll) = go_dice_roller->roll_dtwenty( ).

      IF lv_roll + lv_modifier >= quest_data-difficulty_class.
        "  Success: mark quest completed and pay out rewards
        APPEND VALUE #(
          %tky   = <key>-%tky
          Status = c_status_completed
        ) TO quest_updates.

        DATA(total_xp)      = lv_adv_stats-adventurer_xp + quest_data-xp_reward.
        DATA(levels_gained) = total_xp DIV c_xp_per_level.
        DATA(new_level)     = lv_adv_stats-adventurer_level + levels_gained.
        DATA(new_xp)        = total_xp MOD c_xp_per_level.
        DATA(new_gold)      = lv_adv_stats-adventurer_gold + quest_data-gold_reward.

        MODIFY ENTITIES OF zi_rpg_adventurer
          ENTITY Adventurer
          UPDATE FIELDS ( AdventurerGold AdventurerXP AdventurerLevel  )
            WITH VALUE #( ( AdventurerId   = quest_data-adventurer_id
                       AdventurerGold = new_gold
                       AdventurerXp = new_xp
                       AdventurerLevel = new_level  ) )
          REPORTED DATA(rep_adv)
          FAILED   DATA(fail_adv).

        APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |Completed! (rolled { lv_roll } { COND #( WHEN lv_modifier >= 0 THEN '+' ELSE '' ) }{ lv_modifier } | &&
                            |= { lv_roll + lv_modifier } vs DC { quest_data-difficulty_class })| )         ) TO reported-Quest.

        " ── Loot roll: 30% chance of any drop at all ──
        DATA(lv_loot_roll) = go_dice_roller->roll_percentage( ).

        IF lv_loot_roll <= c_pct_any_drop.

          " rarity odds (COMMON 60 / UNCOMMON 25 / RARE 10 / LEGENDARY 5).
          DATA(lv_rarity_roll) = go_dice_roller->roll_percentage( ).
          DATA(lv_rolled_rarity) = COND zrpg_loot_items-item_rarity(
            WHEN lv_rarity_roll <= c_pct_common                                     THEN 'COMMON'
            WHEN lv_rarity_roll <= c_pct_common + c_pct_uncommon                     THEN 'UNCOMMON'
            WHEN lv_rarity_roll <= c_pct_common + c_pct_uncommon + c_pct_rare        THEN 'RARE'
            ELSE                                                                          'LEGENDARY' ).

          " Eligible items, this quest's loot pool, filtered to the
          " rolled rarity.
          SELECT li~item_id, li~item_name, li~item_type, li~item_subtype,
                li~description, li~required_level, li~price, li~str_bonus,
                 li~dex_bonus, li~con_bonus, li~int_bonus, li~wis_bonus, li~cha_bonus
                     FROM zrpg_quest_loot AS ql
                     INNER JOIN zrpg_loot_items AS li ON ql~item_id = li~item_id
            WHERE ql~quest_id       = @quest_data-quest_id
              AND li~item_rarity         = @lv_rolled_rarity
              AND li~required_level <= @lv_adv_stats-adventurer_level
                     INTO TABLE @DATA(lt_eligible_items).

          IF lt_eligible_items IS INITIAL.
            APPEND VALUE #(
              %tky = <key>-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-information
                       text     = |Loot roll unsuccessful due to level.| )
            ) TO reported-Quest.
          ELSE.
            " Pick one at random among the eligible items of that rarity.
            DATA(lv_pick_index) = go_dice_roller->roll_percentage( ) MOD lines( lt_eligible_items ) + 1.
            DATA(ls_won_item) = lt_eligible_items[ lv_pick_index ].

            SELECT SINGLE inventory_id, amount
              FROM zrpg_inventory
              WHERE adventurerid = @quest_data-adventurer_id
                AND item_id       = @ls_won_item-item_id
              INTO @DATA(ls_existing_loot_inv).

            IF sy-subrc = 0.
              " Already own it - just add another one, no repeated bonus.
              MODIFY ENTITIES OF zi_rpg_inventory
                ENTITY Inventory
                  UPDATE FIELDS ( Amount )
                  WITH VALUE #( ( InventoryId = ls_existing_loot_inv-inventory_id
                                  Amount      = ls_existing_loot_inv-amount + 1 ) )
                REPORTED DATA(rep_loot_inv_u)
                FAILED   DATA(fail_loot_inv_u).
            ELSE.
              " First time owning this loot item - create the it
              MODIFY ENTITIES OF zi_rpg_inventory
                ENTITY Inventory
                  CREATE FIELDS ( AdventurerId ItemId ItemName ItemType ItemSubtype ItemRarity
                                  Description RequiredLevel Price Amount
                                  StrBonus DexBonus ConBonus IntBonus WisBonus ChaBonus )
                    WITH VALUE #( ( %cid          = |LOOT_{ ls_won_item-item_id }|
                                    AdventurerId  = quest_data-adventurer_id
                                    ItemId        = ls_won_item-item_id
                                    ItemName      = ls_won_item-item_name
                                    ItemType      = ls_won_item-item_type
                                    ItemSubtype   = ls_won_item-item_subtype
                                    ItemRarity        = lv_rolled_rarity
                                    Description   = ls_won_item-description
                                    RequiredLevel = ls_won_item-required_level
                                    Price         = ls_won_item-price
                                    Amount        = 1
                                    StrBonus      = ls_won_item-str_bonus
                                    DexBonus      = ls_won_item-dex_bonus
                                    ConBonus      = ls_won_item-con_bonus
                                    IntBonus      = ls_won_item-int_bonus
                                    WisBonus      = ls_won_item-wis_bonus
                                    ChaBonus      = ls_won_item-cha_bonus ) )
                REPORTED DATA(rep_loot_inv_c)
                FAILED   DATA(fail_loot_inv_c).

              MODIFY ENTITIES OF zi_rpg_adventurer
                ENTITY Adventurer
                  UPDATE FIELDS ( AdvStr AdvDex AdvCon AdvInt AdvWis AdvCha )
                  WITH VALUE #( ( AdventurerId = quest_data-adventurer_id
                                  AdvStr = lv_adv_stats-adv_str + ls_won_item-str_bonus
                                  AdvDex = lv_adv_stats-adv_dex + ls_won_item-dex_bonus
                                  AdvCon = lv_adv_stats-adv_con + ls_won_item-con_bonus
                                  AdvInt = lv_adv_stats-adv_int + ls_won_item-int_bonus
                                  AdvWis = lv_adv_stats-adv_wis + ls_won_item-wis_bonus
                                  AdvCha = lv_adv_stats-adv_cha + ls_won_item-cha_bonus ) )
                REPORTED DATA(rep_loot_stat)
                FAILED   DATA(fail_loot_stat).
            ENDIF.

            APPEND VALUE #(
              %tky = <key>-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-success
                       text     = |Loot! You received a { lv_rolled_rarity } item: '{ ls_won_item-item_name }'.| )
            ) TO reported-Quest.
          ENDIF.
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
                 text     = |Failed! (rolled { lv_roll } { COND #( WHEN lv_modifier >= 0 THEN '+' ELSE '' ) }{ lv_modifier } | &&
                            |= { lv_roll + lv_modifier } vs DC { quest_data-difficulty_class })| )
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

  METHOD linkAllLootItems.

    SELECT item_id
      FROM zrpg_loot_items
      INTO TABLE @DATA(lt_loot_items).

    CHECK lt_loot_items IS NOT INITIAL.

    DATA lt_loot_create TYPE TABLE FOR CREATE zi_rpg_quest_loot\\QuestLoot.
    DATA lv_cid_counter TYPE i.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      " Don't duplicate links if this determination somehow runs twice
      SELECT SINGLE @abap_true
        FROM zrpg_quest_loot
        WHERE quest_id = @<key>-QuestId
        INTO @DATA(lv_already_linked).

      CHECK lv_already_linked <> abap_true.

      LOOP AT lt_loot_items INTO DATA(ls_item).
        lv_cid_counter += 1.
        APPEND VALUE #(
          %cid    = |QLOOT_{ lv_cid_counter }|
          QuestId = <key>-QuestId
          ItemId  = ls_item-item_id
        ) TO lt_loot_create.
      ENDLOOP.

    ENDLOOP.

    CHECK lt_loot_create IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_quest_loot
      ENTITY QuestLoot
        CREATE FIELDS ( QuestId ItemId )
        WITH lt_loot_create
      REPORTED DATA(rep_loot)
      FAILED   DATA(fail_loot).

  ENDMETHOD.


ENDCLASS.




