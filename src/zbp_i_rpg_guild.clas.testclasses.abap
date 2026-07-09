
CLASS ltc_guild DEFINITION FOR TESTING
  DURATION LONG
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.

    METHODS empty_name_is_rejected         FOR TESTING.
    METHODS short_name_is_rejected         FOR TESTING.
    METHODS duplicate_name_is_rejected     FOR TESTING
              RAISING
                cx_uuid_error.
    METHODS delete_blocked_with_members    FOR TESTING
              RAISING
                cx_uuid_error.


ENDCLASS.


CLASS ltc_guild IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZRPG_GUILD' ) ( 'ZRPG_GUILD_D' ) ( 'ZRPG_ADVENTURER' ) ( 'ZRPG_DADVENTURER' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD teardown.
      ROLLBACK ENTITIES.

    " Start every test with empty doubles so tests can't leak into each other.
    sql_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD empty_name_is_rejected.
    MODIFY ENTITIES OF zi_rpg_guild IN LOCAL MODE
      ENTITY Guild
        CREATE FIELDS ( GuildName )
          WITH VALUE #( ( %cid = 'G1' GuildName = '' ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_guild IN LOCAL MODE
      ENTITY Guild
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-guild[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-guild
      msg = 'An empty guild name must fail validation' ).
  ENDMETHOD.

  METHOD short_name_is_rejected.
    MODIFY ENTITIES OF zi_rpg_guild IN LOCAL MODE
      ENTITY Guild
        CREATE FIELDS ( GuildName )
          WITH VALUE #( ( %cid = 'G1' GuildName = 'Ab' ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_guild IN LOCAL MODE
      ENTITY Guild
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-guild[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-guild
      msg = 'A name with fewer than 3 letters must fail validation' ).
  ENDMETHOD.

  METHOD duplicate_name_is_rejected.
    " An already-persisted guild with the same name in a different case.
    DATA guilds TYPE STANDARD TABLE OF zrpg_guild WITH EMPTY KEY.
    guilds = VALUE #( ( guild_id   = cl_system_uuid=>create_uuid_x16_static( )
                        guild_name = 'Silver Hand' ) ).
    sql_environment->insert_test_data( guilds ).

    MODIFY ENTITIES OF zi_rpg_guild IN LOCAL MODE
      ENTITY Guild
        CREATE FIELDS ( GuildName )
          WITH VALUE #( ( %cid = 'G1' GuildName = 'silver hand' ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_guild IN LOCAL MODE
      ENTITY Guild
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-guild[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-guild
      msg = 'A duplicate guild name (case-insensitive) must fail validation' ).
  ENDMETHOD.


  METHOD delete_blocked_with_members.
    DATA(guild_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA guilds TYPE STANDARD TABLE OF zrpg_guild WITH EMPTY KEY.
    guilds = VALUE #( ( guild_id = guild_id guild_name = 'Silver Hand' ) ).
    sql_environment->insert_test_data( guilds ).

    DATA adventurers TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    adventurers = VALUE #( ( adventurer_id   = cl_system_uuid=>create_uuid_x16_static( )
                             guild_id        = guild_id
                             adventurer_name = 'Aria' ) ).
    sql_environment->insert_test_data( adventurers ).

    MODIFY ENTITIES OF zi_rpg_guild IN LOCAL MODE
      ENTITY Guild
        DELETE FROM VALUE #( ( GuildId = guild_id ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-guild
      msg = 'Deleting a guild that still has members must be blocked' ).
  ENDMETHOD.

ENDCLASS.

