
CLASS ltc_inventory DEFINITION FOR TESTING
  DURATION LONG
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.

    METHODS sell_removes_the_row  FOR TESTING RAISING cx_uuid_error.
    METHODS selling_more_than_owned_fails     FOR TESTING RAISING cx_uuid_error.

ENDCLASS.


CLASS ltc_inventory IMPLEMENTATION.

  METHOD class_setup.
    " ZRPG_GUILD is doubled too because the ZI_RPG_ADVENTURER CDS view
    " always left-joins to it - reading zi_rpg_adventurer without doubling
    " the guild table mixes a fake table with a real one and returns no rows.
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZRPG_INVENTORY' )
        ( 'ZRPG_ADVENTURER' ) ( 'ZRPG_DADVENTURER' )
        ( 'ZRPG_MARKETPLACE' ) ( 'ZRPG_MARKET_D' )
        ( 'ZRPG_GUILD' ) ( 'ZRPG_GUILD_D' ) ) ).
    ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD teardown.
      ROLLBACK ENTITIES.

    sql_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD sell_removes_the_row.
    DATA(inventory_id)  = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(item_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA inv TYPE STANDARD TABLE OF zrpg_inventory WITH EMPTY KEY.
    inv = VALUE #( ( inventory_id = inventory_id adventurerid = adventurer_id
                     item_id = item_id item_name = 'Potion' price = 5 amount = 2 ) ).
    sql_environment->insert_test_data( inv ).

    DATA advs TYPE STANDARD TABLE OF zrpg_adventurer WITH EMPTY KEY.
    advs = VALUE #( ( adventurer_id = adventurer_id adventurer_name = 'Aria' adventurer_gold = 0 ) ).
    sql_environment->insert_test_data( advs ).

    DATA mkt TYPE STANDARD TABLE OF zrpg_marketplace WITH EMPTY KEY.
    mkt = VALUE #( ( item_id = item_id item_name = 'Potion' amount_available = 0 status = 'SOLD OUT' ) ).
    sql_environment->insert_test_data( mkt ).

    MODIFY ENTITIES OF zi_rpg_inventory IN LOCAL MODE
      ENTITY Inventory
        EXECUTE sellItem
          FROM VALUE #( ( InventoryId = inventory_id %param-Amount = 2 ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    READ ENTITIES OF zi_rpg_inventory IN LOCAL MODE
      ENTITY Inventory FIELDS ( Amount ) WITH VALUE #( ( InventoryId = inventory_id ) )
      RESULT DATA(items)
      FAILED DATA(read_failed).

    cl_abap_unit_assert=>assert_initial(
      act = items
      msg = 'Selling the entire stack must remove the inventory row' ).
  ENDMETHOD.

  METHOD selling_more_than_owned_fails.
    DATA(inventory_id)  = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(item_id)       = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(adventurer_id) = cl_system_uuid=>create_uuid_x16_static( ).

    DATA inv TYPE STANDARD TABLE OF zrpg_inventory WITH EMPTY KEY.
    inv = VALUE #( ( inventory_id = inventory_id adventurerid = adventurer_id
                     item_id = item_id item_name = 'Potion' price = 5 amount = 1 ) ).
    sql_environment->insert_test_data( inv ).

    MODIFY ENTITIES OF zi_rpg_inventory IN LOCAL MODE
      ENTITY Inventory
        EXECUTE sellItem
          FROM VALUE #( ( InventoryId = inventory_id %param-Amount = 5 ) )
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = failed-inventory
      msg = 'Selling more units than are owned must fail' ).
  ENDMETHOD.

ENDCLASS.

