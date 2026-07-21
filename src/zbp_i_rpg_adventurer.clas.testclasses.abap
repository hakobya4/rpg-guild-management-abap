CLASS ltc_adventurer DEFINITION FOR TESTING
  DURATION LONG
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.

    METHODS new_adventurer_starts_at_lvl1   FOR TESTING.
    METHODS empty_class_is_rejected         FOR TESTING.
    METHODS empty_name_is_rejected          FOR TESTING.
    METHODS name_with_digits_is_rejected    FOR TESTING.
    METHODS duplicate_name_is_rejected      FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS join_nonexistent_guild_fails    FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS join_same_guild_twice_fails     FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS quit_without_a_guild_fails      FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS join_guild_succeeds             FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS buy_updates_gold_and_stock      FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS roll_stats_fills_stats          FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS delete_blocked_for_non_owner    FOR TESTING
      RAISING
        cx_uuid_error.
ENDCLASS.


CLASS ltc_adventurer IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZRPG_ADVENTURER' ) ( 'ZRPG_DADVENTURER' ) ( 'ZI_RPG_ADVENTURER' )

               ( 'ZRPG_GUILD' ) ( 'ZRPG_GUILD_D' )
               ( 'ZRPG_INVENTORY' )
               ( 'ZRPG_MARKETPLACE' ) ( 'ZRPG_MARKET_D' ) ( 'ZI_RPG_MARKETPLACE' )
               ( 'ZRPG_QUEST' ) ( 'ZRPG_QUEST_D' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.

    sql_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD new_adventurer_starts_at_lvl1.

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        CREATE FIELDS ( AdventurerName AdventurerClass )
          WITH VALUE #( ( %cid = 'A1' AdventurerName = 'Aria' AdventurerClass = 'FIGHTER' ) )
      MAPPED DATA(mapped).

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        ALL FIELDS WITH VALUE #( ( %pky = mapped-adventurer[ 1 ]-%pky ) )
      RESULT DATA(advs).

    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdventurerLevel exp = 1
      msg = 'A brand-new adventurer must start at level 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = advs[ 1 ]-AdventurerXp exp = 0
      msg = 'A brand-new adventurer must start with 0 XP' ).
  ENDMETHOD.

  METHOD empty_class_is_rejected.
    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        CREATE FIELDS ( AdventurerName AdventurerClass )
          WITH VALUE #( ( %cid = 'A1' AdventurerName = 'Aria' AdventurerClass = '' ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-adventurer[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-adventurer
      msg = 'An adventurer without a class must fail validation' ).
  ENDMETHOD.

  METHOD empty_name_is_rejected.
    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        CREATE FIELDS ( AdventurerName AdventurerClass )
          WITH VALUE #( ( %cid = 'A1' AdventurerName = '' AdventurerClass = 'FIGHTER' ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-adventurer[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-adventurer
      msg = 'An adventurer without a name must fail validation' ).
  ENDMETHOD.

  METHOD name_with_digits_is_rejected.
    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        CREATE FIELDS ( AdventurerName AdventurerClass )
          WITH VALUE #( ( %cid = 'A1' AdventurerName = 'Aria123' AdventurerClass = 'FIGHTER' ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-adventurer[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-adventurer
      msg = 'A name containing digits must fail validation' ).
  ENDMETHOD.

  METHOD duplicate_name_is_rejected.
    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id   = cl_system_uuid=>create_uuid_x16_static( )
                      adventurer_name = 'Aria' ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        CREATE FIELDS ( AdventurerName AdventurerClass )
          WITH VALUE #( ( %cid = 'A1' AdventurerName = 'aria' AdventurerClass = 'FIGHTER' ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-adventurer[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-adventurer
      msg = 'A duplicate adventurer name (case-insensitive) must fail validation' ).
  ENDMETHOD.



  METHOD join_nonexistent_guild_fails.
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria' adventurer_class = 'FIGHTER' ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE joinGuild
          FROM VALUE #( ( AdventurerId = adventurer_id
                          %param-GuildId = cl_system_uuid=>create_uuid_x16_static( ) ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-adventurer
      msg = 'Joining a guild that does not exist must fail' ).
  ENDMETHOD.

  METHOD join_same_guild_twice_fails.
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(guild_id)       = cl_system_uuid=>create_uuid_x16_static( ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id   = adventurer_id
                      adventurer_name = 'Aria'
                      adventurer_class = 'FIGHTER'
                      guild_id        = guild_id ) ).
    sql_environment->insert_test_data( advs ).

    DATA guilds TYPE STANDARD TABLE OF zrpg_guild WITH EMPTY KEY.
    guilds = VALUE #( ( guild_id = guild_id guild_name = 'Silver Hand' ) ).
    sql_environment->insert_test_data( guilds ).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE joinGuild
          FROM VALUE #( ( AdventurerId = adventurer_id %param-GuildId = guild_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-adventurer
      msg = 'Joining a guild the adventurer already belongs to must fail' ).
  ENDMETHOD.

  METHOD quit_without_a_guild_fails.
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria' adventurer_class = 'FIGHTER' ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE quitGuild
          FROM VALUE #( ( AdventurerId = adventurer_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-adventurer
      msg = 'An adventurer with no guild cannot quit one' ).
  ENDMETHOD.

  METHOD join_guild_succeeds.
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(guild_id)      = cl_system_uuid=>create_uuid_x16_static( ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                      adventurer_class = 'FIGHTER' created_by = sy-uname ) ).
    sql_environment->insert_test_data( advs ).

    DATA adv_views TYPE STANDARD TABLE OF zi_rpg_adventurer WITH EMPTY KEY.
    adv_views = VALUE #( ( AdventurerId = adventurer_id AdventurerName = 'Aria'
                           AdventurerClass = 'FIGHTER' CreatedBy = sy-uname ) ).
    sql_environment->insert_test_data( adv_views ).

    DATA guilds TYPE STANDARD TABLE OF zrpg_guild WITH EMPTY KEY.
    guilds = VALUE #( ( guild_id = guild_id guild_name = 'Silver Hand' ) ).
    sql_environment->insert_test_data( guilds ).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE joinGuild
          FROM VALUE #( ( AdventurerId = adventurer_id %param-GuildId = guild_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-adventurer
      msg = 'Joining an existing guild as the owner must succeed' ).

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(advs_read).
    cl_abap_unit_assert=>assert_equals(
      act = advs_read[ 1 ]-GuildId exp = guild_id
      msg = 'The adventurer must be linked to the joined guild' ).
  ENDMETHOD.

  METHOD buy_updates_gold_and_stock.
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(item_id)       = cl_system_uuid=>create_uuid_x16_static( ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                      adventurer_class = 'FIGHTER' adventurer_level = 5
                      adventurer_gold = 100
                      adv_str = 10 adv_dex = 10 adv_con = 10
                      adv_int = 10 adv_wis = 10 adv_cha = 10
                      created_by = sy-uname ) ).
    sql_environment->insert_test_data( advs ).

    DATA adv_views TYPE STANDARD TABLE OF zi_rpg_adventurer WITH EMPTY KEY.
    adv_views = VALUE #( ( AdventurerId = adventurer_id AdventurerName = 'Aria'
                           AdventurerClass = 'FIGHTER' AdventurerLevel = 5
                           AdventurerGold = 100
                           AdvStr = 10 AdvDex = 10 AdvCon = 10
                           AdvInt = 10 AdvWis = 10 AdvCha = 10
                           CreatedBy = sy-uname ) ).
    sql_environment->insert_test_data( adv_views ).

    DATA mkt TYPE STANDARD TABLE OF zrpg_marketplace WITH EMPTY KEY.
    mkt = VALUE #( ( item_id = item_id item_name = 'Potion' status = 'AVAILABLE'
                     required_level = 1 price = 10 amount_available = 5 ) ).
    sql_environment->insert_test_data( mkt ).

    DATA mkt_views TYPE STANDARD TABLE OF zi_rpg_marketplace WITH EMPTY KEY.
    mkt_views = VALUE #( ( ItemId = item_id ItemName = 'Potion' Status = 'AVAILABLE'
                           RequiredLevel = 1 Price = 10 AmountAvailable = 5 ) ).
    sql_environment->insert_test_data( mkt_views ).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE buyItem
          FROM VALUE #( ( AdventurerId  = adventurer_id
                          %param-ItemId = item_id
                          %param-Amount = 2 ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-adventurer
      msg = 'Buying an affordable, in-stock item must succeed' ).

    " 2 x 10 gold spent out of 100
    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(advs_read).
    cl_abap_unit_assert=>assert_equals(
      act = advs_read[ 1 ]-AdventurerGold exp = 80
      msg = 'The purchase must deduct the total cost from the gold' ).

    " Stock reduced from 5 to 3
    READ ENTITIES OF zi_rpg_marketplace
      ENTITY Marketplace ALL FIELDS WITH VALUE #( ( ItemId = item_id ) )
      RESULT DATA(items).
    cl_abap_unit_assert=>assert_equals(
      act = items[ 1 ]-AmountAvailable exp = 3
      msg = 'The purchase must reduce the marketplace stock' ).
  ENDMETHOD.

  METHOD roll_stats_fills_stats.
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                      adventurer_class = 'FIGHTER' created_by = sy-uname ) ).
    sql_environment->insert_test_data( advs ).

    DATA adv_views TYPE STANDARD TABLE OF zi_rpg_adventurer WITH EMPTY KEY.
    adv_views = VALUE #( ( AdventurerId = adventurer_id AdventurerName = 'Aria'
                           AdventurerClass = 'FIGHTER' CreatedBy = sy-uname ) ).
    sql_environment->insert_test_data( adv_views ).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        EXECUTE rollStats
          FROM VALUE #( ( AdventurerId = adventurer_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-adventurer
      msg = 'Rolling stats for an owned adventurer must succeed' ).

    READ ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer ALL FIELDS WITH VALUE #( ( AdventurerId = adventurer_id ) )
      RESULT DATA(advs_read).

    " 4d6-drop-lowest is always between 3 and 18
    cl_abap_unit_assert=>assert_number_between(
      lower = 3 upper = 18 number = advs_read[ 1 ]-AdvStr
      msg = 'STR must be a valid 4d6-drop-lowest roll' ).
    cl_abap_unit_assert=>assert_number_between(
      lower = 3 upper = 18 number = advs_read[ 1 ]-AdvDex
      msg = 'DEX must be a valid 4d6-drop-lowest roll' ).
    cl_abap_unit_assert=>assert_number_between(
      lower = 3 upper = 18 number = advs_read[ 1 ]-AdvCon
      msg = 'CON must be a valid 4d6-drop-lowest roll' ).
    cl_abap_unit_assert=>assert_number_between(
      lower = 3 upper = 18 number = advs_read[ 1 ]-AdvInt
      msg = 'INT must be a valid 4d6-drop-lowest roll' ).
    cl_abap_unit_assert=>assert_number_between(
      lower = 3 upper = 18 number = advs_read[ 1 ]-AdvWis
      msg = 'WIS must be a valid 4d6-drop-lowest roll' ).
    cl_abap_unit_assert=>assert_number_between(
      lower = 3 upper = 18 number = advs_read[ 1 ]-AdvCha
      msg = 'CHA must be a valid 4d6-drop-lowest roll' ).
  ENDMETHOD.

  METHOD delete_blocked_for_non_owner.
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).

    " Created by a different user - the current user must not delete it
    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                      adventurer_class = 'FIGHTER' created_by = 'SOMEONE_ELSE' ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_adventurer IN LOCAL MODE
      ENTITY Adventurer
        DELETE FROM VALUE #( ( AdventurerId = adventurer_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-adventurer
      msg = 'Deleting another player''s adventurer must be blocked' ).
  ENDMETHOD.
ENDCLASS.

