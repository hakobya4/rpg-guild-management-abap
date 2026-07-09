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

ENDCLASS.


CLASS ltc_adventurer IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZRPG_ADVENTURER' ) ( 'ZRPG_DADVENTURER' ) ( 'ZI_RPG_ADVENTURER' )

               ( 'ZRPG_GUILD' ) ( 'ZRPG_GUILD_D' )
               ( 'ZRPG_INVENTORY' )
               ( 'ZRPG_MARKETPLACE' ) ( 'ZRPG_MARKET_D' )
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


ENDCLASS.

