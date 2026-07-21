CLASS ltc_marketplace DEFINITION FOR TESTING
  DURATION LONG
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.

    METHODS subtype_defaults_for_armor     FOR TESTING.
    METHODS empty_item_name_is_rejected    FOR TESTING.
    METHODS zero_price_is_rejected         FOR TESTING.
    METHODS buy_below_required_level_fails FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS buy_more_than_in_stock_fails   FOR TESTING
      RAISING
        cx_uuid_error.
    METHODS buy_item_reduces_stock         FOR TESTING
      RAISING
        cx_uuid_error.

ENDCLASS.


CLASS ltc_marketplace IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZRPG_MARKETPLACE' ) ( 'ZRPG_MARKET_D' ) ( 'ZI_RPG_MARKETPLACE' )
        ( 'ZRPG_ADVENTURER' ) ( 'ZRPG_DADVENTURER' )
        ( 'ZRPG_GUILD' ) ( 'ZRPG_GUILD_D' ) ( 'ZRPG_INVENTORY' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.

    sql_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD subtype_defaults_for_armor.
    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        CREATE FIELDS ( ItemName ItemType RequiredLevel Price AmountAvailable )
          WITH VALUE #( ( %cid = 'M1' ItemName = 'Shield of Aria' ItemType = 'ARMOR'
                          RequiredLevel = 1 Price = 10 AmountAvailable = 5 ) )
      MAPPED DATA(mapped).

    READ ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        ALL FIELDS WITH VALUE #( ( %pky = mapped-marketplace[ 1 ]-%pky ) )
      RESULT DATA(items).

    cl_abap_unit_assert=>assert_equals(
      act = items[ 1 ]-ItemSubtype exp = 'SHIELD'
      msg = 'ARMOR items must default to the SHIELD subtype' ).
  ENDMETHOD.

  METHOD empty_item_name_is_rejected.
    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        CREATE FIELDS ( ItemName ItemType RequiredLevel Price AmountAvailable )
          WITH VALUE #( ( %cid = 'M1' ItemName = '' ItemType = 'WEAPON'
                          RequiredLevel = 1 Price = 10 AmountAvailable = 5 ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-marketplace[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-marketplace
      msg = 'An item without a name must fail validation' ).
  ENDMETHOD.

  METHOD zero_price_is_rejected.
    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        CREATE FIELDS ( ItemName ItemType RequiredLevel Price AmountAvailable )
          WITH VALUE #( ( %cid = 'M1' ItemName = 'Rusty Dagger' ItemType = 'WEAPON'
                          RequiredLevel = 1 Price = 0 AmountAvailable = 5 ) )
      MAPPED DATA(mapped).

    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        EXECUTE Prepare
          FROM VALUE #( ( %pky = mapped-marketplace[ 1 ]-%pky ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-marketplace
      msg = 'An item with a price below 1 must fail validation' ).
  ENDMETHOD.



  METHOD buy_below_required_level_fails.
    DATA(item_id)        = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id)  = cl_system_uuid=>create_uuid_x16_static( ).

    DATA mkt TYPE STANDARD TABLE OF zrpg_marketplace WITH EMPTY KEY.
    mkt = VALUE #( ( item_id = item_id item_name = 'Dragon Slayer' status = 'AVAILABLE'
                     required_level = 20 price = 5 amount_available = 1 ) ).
    sql_environment->insert_test_data( mkt ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria' adventurer_level = 1 ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        EXECUTE buyItem
          FROM VALUE #( ( ItemId              = item_id
                          %param-AdventurerId = adventurer_id
                          %param-Amount       = 1 ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-marketplace
      msg = 'Buying an item above the adventurer level must fail' ).
  ENDMETHOD.

  METHOD buy_more_than_in_stock_fails.
    DATA(item_id)        = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id)  = cl_system_uuid=>create_uuid_x16_static( ).

    DATA mkt TYPE STANDARD TABLE OF zrpg_marketplace WITH EMPTY KEY.
    mkt = VALUE #( ( item_id = item_id item_name = 'Potion' status = 'AVAILABLE'
                     required_level = 1 price = 5 amount_available = 2 ) ).
    sql_environment->insert_test_data( mkt ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria' adventurer_level = 5 ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        EXECUTE buyItem
          FROM VALUE #( ( ItemId              = item_id
                          %param-AdventurerId = adventurer_id
                          %param-Amount       = 5 ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-marketplace
      msg = 'Buying more units than are in stock must fail' ).
  ENDMETHOD.

  METHOD buy_item_reduces_stock.
    DATA(item_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA mkt TYPE STANDARD TABLE OF zrpg_marketplace WITH EMPTY KEY.
    mkt = VALUE #( ( item_id = item_id item_name = 'Potion' status = 'AVAILABLE'
                     required_level = 1 price = 5 amount_available = 5 ) ).
    sql_environment->insert_test_data( mkt ).

    DATA mkt_views TYPE STANDARD TABLE OF zi_rpg_marketplace WITH EMPTY KEY.
    mkt_views = VALUE #( ( ItemId = item_id ItemName = 'Potion' Status = 'AVAILABLE'
                           RequiredLevel = 1 Price = 5 AmountAvailable = 5 ) ).
    sql_environment->insert_test_data( mkt_views ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria'
                      adventurer_level = 5 created_by = sy-uname ) ).
    sql_environment->insert_test_data( advs ).

    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        EXECUTE buyItem
          FROM VALUE #( ( ItemId              = item_id
                          %param-AdventurerId = adventurer_id
                          %param-Amount       = 2 ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial(
      act = failed-marketplace
      msg = 'Buying an available item within the level gate must succeed' ).

    READ ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace ALL FIELDS WITH VALUE #( ( ItemId = item_id ) )
      RESULT DATA(items).
    cl_abap_unit_assert=>assert_equals(
      act = items[ 1 ]-AmountAvailable exp = 3
      msg = 'The purchase must reduce the stock by the bought amount' ).
  ENDMETHOD.


ENDCLASS.

