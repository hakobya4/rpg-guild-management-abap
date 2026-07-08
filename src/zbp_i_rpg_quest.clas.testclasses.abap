CLASS ltc_quest DEFINITION FOR TESTING
  DURATION LONG
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.

    METHODS new_quest_starts_open          FOR TESTING.
    METHODS zero_xp_reward_is_rejected     FOR TESTING.
    METHODS accept_open_quest_succeeds     FOR TESTING
              RAISING
                cx_uuid_error.
    METHODS accept_taken_quest_fails       FOR TESTING
              RAISING
                cx_uuid_error.
    METHODS accept_below_level_fails       FOR TESTING
              RAISING
                cx_uuid_error.
    METHODS complete_grants_xp_and_gold    FOR TESTING
              RAISING
                cx_uuid_error.
    METHODS complete_can_level_up          FOR TESTING
              RAISING
                cx_uuid_error.
    METHODS complete_not_in_progress_fails FOR TESTING
              RAISING
                cx_uuid_error.

ENDCLASS.


CLASS ltc_quest IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZRPG_QUEST' ) ( 'ZRPG_QUEST_D' )
        ( 'ZRPG_ADVENTURER' ) ( 'ZRPG_DADVENTURER' )
        ( 'ZRPG_GUILD' ) ( 'ZRPG_GUILD_D' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD teardown.
    sql_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD new_quest_starts_open.
    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        CREATE FIELDS ( QuestName RequiredLevel XpReward GoldReward )
          WITH VALUE #( ( %cid = 'Q1' QuestName = 'Slay the dragon'
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
        CREATE FIELDS ( QuestName RequiredLevel XpReward GoldReward )
          WITH VALUE #( ( %cid = 'Q1' QuestName = 'Slay the dragon'
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

  METHOD accept_open_quest_succeeds.
    DATA(quest_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id)  = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon'
                        status = 'OPEN' required_level = 1 xp_reward = 10 gold_reward = 5 ) ).
    sql_environment->insert_test_data( quests ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria' adventurer_level = 5 ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE acceptQuest
          FROM VALUE #( ( QuestId = quest_id %param-AdventurerId = adventurer_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-quest
      msg = 'Accepting an open quest that matches the level should succeed' ).

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest FIELDS ( Status AdventurerId ) WITH VALUE #( ( QuestId = quest_id ) )
      RESULT DATA(result).

    cl_abap_unit_assert=>assert_equals(
      act = result[ 1 ]-Status exp = 'IN_PROGRESS'
      msg = 'An accepted quest must switch to IN_PROGRESS' ).
  ENDMETHOD.

  METHOD accept_taken_quest_fails.
    DATA(quest_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id)  = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon'
                        status = 'IN_PROGRESS' required_level = 1 xp_reward = 10 gold_reward = 5 ) ).
    sql_environment->insert_test_data( quests ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria' adventurer_level = 5 ) ).
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
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon'
                        status = 'OPEN' required_level = 10 xp_reward = 10 gold_reward = 5 ) ).
    sql_environment->insert_test_data( quests ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria' adventurer_level = 1 ) ).
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

  METHOD complete_grants_xp_and_gold.
    DATA(quest_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id)  = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon'
                        status = 'IN_PROGRESS' adventurer_id = adventurer_id
                        required_level = 1 xp_reward = 5 gold_reward = 20 ) ).
    sql_environment->insert_test_data( quests ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                      adventurer_level = 3 adventurer_xp = 2 adventurer_gold = 10 ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE completeQuest
          FROM VALUE #( ( QuestId = quest_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-quest
      msg = 'Completing an in-progress quest with a valid adventurer should succeed' ).

    READ ENTITIES OF zi_rpg_adventurer
      ENTITY Adventurer FIELDS ( AdventurerXp AdventurerGold AdventurerLevel )
        WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(result).

    cl_abap_unit_assert=>assert_equals(
      act = result[ 1 ]-AdventurerXp exp = 7
      msg = '2 existing XP + 5 reward XP = 7, below the level-up threshold' ).
    cl_abap_unit_assert=>assert_equals(
      act = result[ 1 ]-AdventurerGold exp = 30
      msg = '10 existing gold + 20 reward gold = 30' ).
    cl_abap_unit_assert=>assert_equals(
      act = result[ 1 ]-AdventurerLevel exp = 3
      msg = 'No level threshold was crossed, so the level stays the same' ).
  ENDMETHOD.

  METHOD complete_can_level_up.
    DATA(quest_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id)  = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon'
                        status = 'IN_PROGRESS' adventurer_id = adventurer_id
                        required_level = 1 xp_reward = 15 gold_reward = 0 ) ).
    sql_environment->insert_test_data( quests ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                      adventurer_level = 1 adventurer_xp = 8 adventurer_gold = 0 ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        EXECUTE completeQuest
          FROM VALUE #( ( QuestId = quest_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    READ ENTITIES OF zi_rpg_adventurer
      ENTITY Adventurer FIELDS ( AdventurerXp AdventurerLevel )
        WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(result).

    " 8 existing XP + 15 reward = 23 -> 2 levels gained (23 DIV 10), 3 XP left over (23 MOD 10).
    cl_abap_unit_assert=>assert_equals(
      act = result[ 1 ]-AdventurerLevel exp = 3
      msg = 'Crossing 2 full 10-XP thresholds must grant 2 levels' ).
    cl_abap_unit_assert=>assert_equals(
      act = result[ 1 ]-AdventurerXp exp = 3
      msg = 'The remainder after leveling up must be kept as XP' ).
  ENDMETHOD.

  METHOD complete_not_in_progress_fails.
    DATA(quest_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA quests TYPE STANDARD TABLE OF zrpg_quest WITH EMPTY KEY.
    quests = VALUE #( ( quest_id = quest_id quest_name = 'Slay the dragon'
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

ENDCLASS.

