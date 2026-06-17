CLASS lhc_Marketplace DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

  CONSTANTS:
      c_status_available TYPE zrpg_quest-status VALUE 'AVAILABLE',
      c_status_sold TYPE zrpg_quest-status VALUE 'SOLD OUT',
      c_default_itemtype TYPE zrpg_marketplace-item_type Value 'WEAPON'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Marketplace RESULT result.


    METHODS setDefaultItemValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Marketplace~setDefaultItemValues.

    METHODS validateItemValues FOR VALIDATE ON SAVE
      IMPORTING keys FOR Marketplace~validateItemValues.
    METHODS buyItem FOR MODIFY
      IMPORTING keys FOR ACTION Marketplace~buyItem RESULT result.

ENDCLASS.

CLASS lhc_Marketplace IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


  METHOD setDefaultItemValues.
   READ ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
       ENTITY Marketplace
       FIELDS ( Status )
       WITH CORRESPONDING #( keys )
       RESULT DATA(market).
     DATA updates TYPE TABLE FOR UPDATE zi_rpg_marketplace\\Marketplace.

    LOOP AT market ASSIGNING FIELD-SYMBOL(<market>).
      CHECK <market>-Status IS INITIAL.
      APPEND VALUE #( %tky = <market>-%tky  Status = c_status_available ) TO updates.
      CHECK <market>-ItemType IS INITIAL.
        APPEND VALUE #(
        %tky            = <market>-%tky
        ItemType = c_default_itemtype
      ) TO updates.
    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace UPDATE FIELDS ( Status ItemType ) WITH updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Marketplace = CORRESPONDING #( BASE ( reported-Marketplace ) rep-Marketplace ).
  ENDMETHOD.

  METHOD validateItemValues.
    READ ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
       ENTITY Marketplace
       FIELDS ( RequiredLevel Price AmountAvailable ItemName )
       WITH CORRESPONDING #( keys )
       RESULT DATA(market).

    LOOP AT market ASSIGNING FIELD-SYMBOL(<market>).

      IF <market>-AmountAvailable < 1.
        APPEND VALUE #( %tky = <market>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                   = <market>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'There must be at least 1 item in the stock.' )
          %element-RequiredLevel = if_abap_behv=>mk-on
        ) TO reported-Marketplace.
      ENDIF.

      IF strlen( replace( val =  <market>-ItemName sub = ` ` with = `` ) ) = 0.
        APPEND VALUE #( %tky = <market>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                   = <market>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Please insert a name for the item.' )
          %element-RequiredLevel = if_abap_behv=>mk-on
        ) TO reported-Marketplace.
      ENDIF.

      IF <market>-RequiredLevel < 1.
        APPEND VALUE #( %tky = <market>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                   = <market>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'The item must have a required level of higher than 0.' )
          %element-RequiredLevel = if_abap_behv=>mk-on
        ) TO reported-Marketplace.

        ENDIF.

       IF <market>-Price < 1.
        APPEND VALUE #( %tky = <market>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                   = <market>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'The item must have a price higher than 0.' )
          %element-RequiredLevel = if_abap_behv=>mk-on
        ) TO reported-Marketplace.

      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD buyItem.
   READ ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        FIELDS ( ItemName Status AdventurerId RequiredLevel Price AmountAvailable )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_marketplace\\Marketplace.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      READ TABLE items ASSIGNING FIELD-SYMBOL(<item>)
        WITH KEY %tky = <key>-%tky.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Item not found. Select a valid item.' )
        ) TO reported-Marketplace.
        CONTINUE.
      ENDIF.

      "  Adventurer from the action parameter
      DATA(lv_adventurer_id) = <key>-%param-AdventurerId.

      IF lv_adventurer_id IS INITIAL.
        APPEND VALUE #( %tky = <item>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                = <item>-%tky
          %action-buyItem = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Please select an adventurer.' )
        ) TO reported-Marketplace.
        CONTINUE.
      ENDIF.

      " Adventurer must exist as a persisted record
      SELECT SINGLE adventurer_name, adventurer_level
        FROM zrpg_adventurer
        WHERE adventurer_id = @lv_adventurer_id
        INTO @DATA(adventurer_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <item>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                = <item>-%tky
          %action-buyItem = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = 'Adventurer does not exist or has not been saved yet.' )
        ) TO reported-Marketplace.
        CONTINUE.
      ENDIF.

      "  Item must be Available
      IF <item>-Status <> c_status_available.
        APPEND VALUE #( %tky = <item>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                = <item>-%tky
          %action-buyItem = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |Item '{ <item>-ItemName }' is not open|
                                          && | (status: { <item>-Status }).| )
        ) TO reported-Marketplace.
        CONTINUE.
      ENDIF.


      "  Level requirement check
      IF adventurer_data-adventurer_level < <item>-RequiredLevel.
        APPEND VALUE #( %tky = <item>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                = <item>-%tky
          %action-buyItem = if_abap_behv=>mk-on
          %msg                = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |You must be level { <item>-RequiredLevel }|
                                          && | to take this quest.|
                                          && | { adventurer_data-adventurer_name }|
                                          && | is currently level|
                                          && | { adventurer_data-adventurer_level }.| )
        ) TO reported-Marketplace.
        CONTINUE.
      ENDIF.
      "Change current count of item available
      DATA(new_amount) = <item>-AmountAvailable - 1.
      MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
        ENTITY Marketplace
          UPDATE FIELDS ( AmountAvailable )
          WITH VALUE #( ( %tky            = <item>-%tky
                          AmountAvailable = new_amount
               ) )
        REPORTED DATA(rep_item)
        FAILED   DATA(fail_item).

      "  Buy item and make it sold
      IF new_amount = 0.
      APPEND VALUE #(
        %tky         = <item>-%tky
        Status       = c_status_sold
      ) TO updates.

      APPEND VALUE #(
        %tky = <item>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |'{ <item>-Itemname }' successfuly bought| )
      ) TO reported-Marketplace.
         ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
        ENTITY Marketplace
          UPDATE FIELDS ( AdventurerId Status )
          WITH updates
        REPORTED DATA(reported_update)
        FAILED   DATA(failed_update).

      reported-Marketplace = CORRESPONDING #(
        BASE ( reported-Marketplace ) reported_update-Marketplace ).
      failed-Marketplace   = CORRESPONDING #(
        BASE ( failed-Marketplace ) failed_update-Marketplace ).
    ENDIF.

    READ ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(result_items).

    result = VALUE #( FOR quest IN result_items
                      ( %tky   = quest-%tky
                        %param = CORRESPONDING #( quest ) ) ).
  ENDMETHOD.

ENDCLASS.
