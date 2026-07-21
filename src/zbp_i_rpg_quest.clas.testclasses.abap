CLASS ltd_scripted_dice DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_rpg_dice_roller.
    DATA mv_d20     TYPE i VALUE 10.                              " fixed d20 result
    DATA mt_percent TYPE STANDARD TABLE OF i WITH EMPTY KEY.      " d100 results, in call order
    DATA mv_between TYPE i VALUE 1.                               " fixed pick result
  PRIVATE SECTION.
    DATA mv_percent_calls TYPE i.
ENDCLASS.

CLASS ltd_scripted_dice IMPLEMENTATION.
  METHOD zif_rpg_dice_roller~roll_dtwenty.
    rv_roll = mv_d20.
  ENDMETHOD.
  METHOD zif_rpg_dice_roller~roll_stats.
    rv_roll = 10.
  ENDMETHOD.
  METHOD zif_rpg_dice_roller~roll_percentage.
    mv_percent_calls += 1.
    rv_roll = COND #( WHEN line_exists( mt_percent[ mv_percent_calls ] )
                      THEN mt_percent[ mv_percent_calls ]
                      ELSE 100 ).
  ENDMETHOD.
  METHOD zif_rpg_dice_roller~roll_between.
    rv_roll = COND #( WHEN mv_between BETWEEN iv_min AND iv_max
                      THEN mv_between
                      ELSE iv_min ).
  ENDMETHOD.
ENDCLASS.

CLASS ltc_quest DEFINITION FOR TESTING
  DURATION LONG
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.

    " Seeds one IN_PROGRESS quest + its adventurer; returns both ids
    METHODS seed_quest_and_adventurer
      IMPORTING iv_difficulty    TYPE i DEFAULT 5
      EXPORTING ev_quest_id      TYPE sysuuid_x16
                ev_adventurer_id TYPE sysuuid_x16
      RAISING   cx_uuid_error.


    METHODS new_quest_starts_open          FOR TESTING.
    METHODS zero_xp_reward_is_rejected     FOR TESTING.
    METHODS accept_taken_quest_fails       FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS accept_below_level_fails       FOR TESTING
      RAISING
        cx_uuid_error.


    METHODS complete_not_in_progress_fails FOR TESTING RAISING cx_static_check.
    METHODS complete_success_pays_rewards  FOR TESTING RAISING cx_uuid_error.
    METHODS complete_failure_no_rewards    FOR TESTING RAISING cx_uuid_error.
    METHODS loot_drop_grants_stat_bonus    FOR TESTING RAISING cx_uuid_error.
    METHODS loot_blocked_by_level          FOR TESTING RAISING cx_uuid_error.

ENDCLASS.


CLASS ltc_quest IMPLEMENTATION.

  METHOD class_setup.
    " Draft tables must be doubled alongside their active counterparts, or a
    " real (empty) draft table gets mixed with the fake active one and reads
    " come back empty even for otherwise-valid requests.
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZRPG_QUEST' ) ( 'ZRPG_QUEST_D' ) ( 'ZI_RPG_QUEST' )
        ( 'ZRPG_ADVENTURER' ) ( 'ZRPG_DADVENTURER' ) ( 'ZI_RPG_ADVENTURER' )
        ( 'ZRPG_GUILD' ) ( 'ZRPG_GUILD_D' )
        ( 'ZRPG_QUEST_LOOT' ) ( 'ZRPG_LOOT_ITEMS' )
        ( 'ZRPG_INVENTORY' ) ) ).

  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD teardown.
    " Discard any CREATE/UPDATE still buffered in RAP's transactional
    " session from this test, or it leaks into the next test's reads.
    ROLLBACK ENTITIES.
    sql_environment->clear_doubles( ).
    " Reset the dice roller seam so a stub injected by one test can't
    " leak into the next one and fake a deterministic result there too.
    CLEAR lhc_quest=>go_dice_roller.
  ENDMETHOD.

  METHOD seed_quest_and_adventurer.
    ev_quest_id      = cl_system_uuid=>create_uuid_x16_static( ).
    ev_adventurer_id = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = ev_quest_id quest_name = 'Slay the dragon'
                        quest_type_name = 'COMBAT' status = 'IN_PROGRESS'
                        adventurer_id = ev_adventurer_id
                        required_level = 1 required_stat = 'STR'
                        difficulty_class = iv_difficulty
                        xp_reward = 25 gold_reward = 50 ) ).
    sql_environment->insert_test_data( quests ).

    " created_by = current user so the ownership check passes
    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = ev_adventurer_id adventurer_name = 'Aria'
                      adventurer_level = 1 adventurer_xp = 8 adventurer_gold = 0
                      adv_str = 10 adv_dex = 10 adv_con = 10
                      adv_int = 10 adv_wis = 10 adv_cha = 10
                      created_by = sy-uname ) ).
    sql_environment->insert_test_data( advs ).
    DATA quest_views TYPE STANDARD TABLE OF zi_rpg_quest WITH EMPTY KEY.
    quest_views = VALUE #( ( QuestId = ev_quest_id QuestName = 'Slay the dragon'
                             QuestTypeName = 'COMBAT' Status = 'IN_PROGRESS'
                             AdventurerId = ev_adventurer_id
                             RequiredLevel = 1 RequiredStat = 'STR'
                             DifficultyClass = iv_difficulty
                             XpReward = 25 GoldReward = 50 ) ).
    sql_environment->insert_test_data( quest_views ).

    DATA adv_views TYPE STANDARD TABLE OF zi_rpg_adventurer WITH EMPTY KEY.
    adv_views = VALUE #( ( AdventurerId = ev_adventurer_id AdventurerName = 'Aria'
                           AdventurerLevel = 1 AdventurerXp = 8 AdventurerGold = 0
                           AdvStr = 10 AdvDex = 10 AdvCon = 10
                           AdvInt = 10 AdvWis = 10 AdvCha = 10
                           CreatedBy = sy-uname ) ).
    sql_environment->insert_test_data( adv_views ).
  ENDMETHOD.


  METHOD new_quest_starts_open.
    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        CREATE FIELDS ( QuestName QuestTypeName RequiredLevel XpReward GoldReward )
          WITH VALUE #( ( %cid = 'Q1' QuestName = 'Slay the dragon' QuestTypeName = 'COMBAT'
                          RequiredLevel = 5 XpReward = 20 GoldReward = 50 ) )
      MAPPED DATA(mapped).

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        ALL FIELDS WITH VALUE #( ( %pky = mapped-quest[ 1 ]-%pky ) )
      RESULT DATA(quests).

    cl_abap_unit_assert=>assert_equals(
      act = quests[ 1 ]-Status exp = 'OPEN'
      msg = 'A newly created quest must default to OPEN' ).
  ENDMETHOD.

  METHOD zero_xp_reward_is_rejected.
    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        CREATE FIELDS ( QuestName QuestTypeName RequiredLevel XpReward GoldReward )
          WITH VALUE #( ( %cid = 'Q1' QuestName = 'Slay the dragon' QuestTypeName = 'COMBAT'
                          RequiredLevel = 5 XpReward = 0 GoldReward = 50 ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-quest[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-quest
      msg = 'A quest with no XP reward must fail validation' ).
  ENDMETHOD.



  METHOD accept_taken_quest_fails.
    DATA(quest_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id)  = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon' quest_type_name = 'COMBAT'
                        status = 'IN_PROGRESS' required_level = 1 xp_reward = 10 gold_reward = 5 ) ).
    sql_environment->insert_test_data( quests ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                  adventurer_level = 5 created_by = sy-uname ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE acceptQuest
          FROM VALUE #( ( QuestId = quest_id %param-AdventurerId = adventurer_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-quest
      msg = 'A quest that is already in progress cannot be accepted again' ).
  ENDMETHOD.

  METHOD accept_below_level_fails.
    DATA(quest_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id)  = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon' quest_type_name = 'COMBAT'
                        status = 'OPEN' required_level = 10 xp_reward = 10 gold_reward = 5 ) ).
    sql_environment->insert_test_data( quests ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                       adventurer_level = 1 created_by = sy-uname ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE acceptQuest
          FROM VALUE #( ( QuestId = quest_id %param-AdventurerId = adventurer_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-quest
      msg = 'An adventurer below the required level cannot accept the quest' ).
  ENDMETHOD.




  METHOD complete_not_in_progress_fails.
    DATA(quest_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon' quest_type_name = 'COMBAT'
                        status = 'OPEN' required_level = 1 xp_reward = 5 gold_reward = 5 ) ).
    sql_environment->insert_test_data( quests ).

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE completeQuest
          FROM VALUE #( ( QuestId = quest_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-quest
      msg = 'A quest that is still OPEN cannot be completed' ).
  ENDMETHOD.

  METHOD complete_success_pays_rewards.
    seed_quest_and_adventurer( IMPORTING ev_quest_id      = DATA(quest_id)
                                         ev_adventurer_id = DATA(adventurer_id) ).

    " Natural 20 passes DC 5; loot gate roll of 99 means no drop
    DATA(dice) = NEW ltd_scripted_dice( ).
    dice->mv_d20     = 20.
    dice->mt_percent = VALUE #( ( 99 ) ).
    lhc_quest=>go_dice_roller = dice.

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE completeQuest
          FROM VALUE #( ( QuestId = quest_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-quest
      msg = 'A passed check must not fail the action' ).

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest ALL FIELDS WITH VALUE #( ( QuestId = quest_id ) )
      RESULT DATA(quests).
    cl_abap_unit_assert=>assert_equals(
      act = quests[ 1 ]-Status exp = 'COMPLETED'
      msg = 'A passed check must set the quest to COMPLETED' ).

    " XP 8 + reward 25 = 33 -> 3 level-ups (10 XP each), 3 XP remainder
    READ ENTITIES OF zi_rpg_adventurer
      ENTITY Adventurer ALL FIELDS WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(advs).
    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdventurerGold exp = 50
      msg = 'Gold reward must be paid out' ).
    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdventurerLevel exp = 4
      msg = '33 total XP at 10 per level must level 1 -> 4' ).
    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdventurerXp exp = 3
      msg = 'The XP remainder after leveling must be kept' ).
  ENDMETHOD.

  METHOD complete_failure_no_rewards.
    seed_quest_and_adventurer( EXPORTING iv_difficulty    = 25
                               IMPORTING ev_quest_id      = DATA(quest_id)
                                         ev_adventurer_id = DATA(adventurer_id) ).

    " Roll of 1 with +0 modifier cannot beat DC 25
    DATA(dice) = NEW ltd_scripted_dice( ).
    dice->mv_d20 = 1.
    lhc_quest=>go_dice_roller = dice.

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE completeQuest
          FROM VALUE #( ( QuestId = quest_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest ALL FIELDS WITH VALUE #( ( QuestId = quest_id ) )
      RESULT DATA(quests).
    cl_abap_unit_assert=>assert_equals(
      act = quests[ 1 ]-Status exp = 'FAILED'
      msg = 'A failed check must set the quest to FAILED' ).

    READ ENTITIES OF zi_rpg_adventurer
      ENTITY Adventurer ALL FIELDS WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(advs).
    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdventurerGold exp = 0
      msg = 'A failed quest must not pay out gold' ).
    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdventurerLevel exp = 1
      msg = 'A failed quest must not grant levels' ).
  ENDMETHOD.

  METHOD loot_drop_grants_stat_bonus.
    seed_quest_and_adventurer( IMPORTING ev_quest_id      = DATA(quest_id)
                                         ev_adventurer_id = DATA(adventurer_id) ).

    " A COMMON item the level-1 adventurer is eligible for, linked to the quest
    DATA(item_id) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA loot TYPE STANDARD TABLE OF zrpg_loot_items WITH EMPTY KEY.
    loot = VALUE #( ( item_id = item_id item_name = 'Rusty Longsword'
                      item_type = 'WEAPON' item_rarity = 'COMMON'
                      required_level = 1 price = 15 str_bonus = 1 ) ).
    sql_environment->insert_test_data( loot ).

    DATA links TYPE STANDARD TABLE OF zrpg_quest_loot WITH EMPTY KEY.
    links = VALUE #( ( loot_id = cl_system_uuid=>create_uuid_x16_static( )
                       quest_id = quest_id item_id = item_id ) ).
    sql_environment->insert_test_data( links ).

    " d20 = 20 passes; drop roll 10 <= 30 lands; rarity roll 50 -> COMMON
    DATA(dice) = NEW ltd_scripted_dice( ).
    dice->mv_d20     = 20.
    dice->mt_percent = VALUE #( ( 10 ) ( 50 ) ).
    lhc_quest=>go_dice_roller = dice.

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE completeQuest
          FROM VALUE #( ( QuestId = quest_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-quest
      msg = 'A successful quest with a valid loot drop must not fail' ).

    " First copy of the won item must apply its stat bonus
    READ ENTITIES OF zi_rpg_adventurer
      ENTITY Adventurer ALL FIELDS WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(advs).
    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdvStr exp = 11
      msg = 'The won item''s STR bonus must be applied to the adventurer' ).
  ENDMETHOD.

  METHOD loot_blocked_by_level.
    seed_quest_and_adventurer( IMPORTING ev_quest_id      = DATA(quest_id)
                                         ev_adventurer_id = DATA(adventurer_id) ).

    " The only linked item requires level 10 - the level-1 adventurer
    " must not receive it even though the drop and rarity rolls land.
    DATA(item_id) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA loot TYPE STANDARD TABLE OF zrpg_loot_items WITH EMPTY KEY.
    loot = VALUE #( ( item_id = item_id item_name = 'Dragonscale Plate'
                      item_type = 'ARMOR' item_rarity = 'COMMON'
                      required_level = 10 price = 240 con_bonus = 4 ) ).
    sql_environment->insert_test_data( loot ).

    DATA links TYPE STANDARD TABLE OF zrpg_quest_loot WITH EMPTY KEY.
    links = VALUE #( ( loot_id = cl_system_uuid=>create_uuid_x16_static( )
                       quest_id = quest_id item_id = item_id ) ).
    sql_environment->insert_test_data( links ).

    DATA(dice) = NEW ltd_scripted_dice( ).
    dice->mv_d20     = 20.
    dice->mt_percent = VALUE #( ( 10 ) ( 50 ) ).
    lhc_quest=>go_dice_roller = dice.

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE completeQuest
          FROM VALUE #( ( QuestId = quest_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    READ ENTITIES OF zi_rpg_adventurer
      ENTITY Adventurer ALL FIELDS WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(advs).
    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdvCon exp = 10
      msg = 'An item above the adventurer''s level must not grant its bonus' ).
  ENDMETHOD.

ENDCLASS.

