CLASS lhc_Marketplace DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS:
      c_status_available    TYPE zrpg_quest-status VALUE 'AVAILABLE',
      c_status_sold         TYPE zrpg_quest-status VALUE 'SOLD OUT',
      c_default_itemtype    TYPE zrpg_marketplace-item_type VALUE 'WEAPON',
      c_default_itemsubtype TYPE zrpg_marketplace-item_subtype VALUE 'LONGSWORD'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Marketplace RESULT result.


    METHODS setDefaultItemValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Marketplace~setDefaultItemValues.

    METHODS setDefaultSubtype FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Marketplace~setDefaultSubtype.

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
        FIELDS ( Status ItemType ItemSubtype )
        WITH CORRESPONDING #( keys )
        RESULT DATA(market_stat).
    DATA stat_updates TYPE TABLE FOR UPDATE zi_rpg_marketplace\\Marketplace.

    LOOP AT market_stat ASSIGNING FIELD-SYMBOL(<market_stat>).
      CHECK <market_stat>-Status IS INITIAL.
      APPEND VALUE #(
       %tky = <market_stat>-%tky
       Status = c_status_available
       ItemType = c_default_itemtype
       ItemSubtype = c_default_itemsubtype
       ) TO stat_updates.
    ENDLOOP.

    CHECK stat_updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace UPDATE FIELDS ( Status ItemType ItemSubtype ) WITH stat_updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Marketplace = CORRESPONDING #( BASE ( reported-Marketplace ) rep-Marketplace ).
  ENDMETHOD.
  METHOD setDefaultSubtype.
    " When the item type changes, reset the subtype to that type's default
    " so the (type, subtype) pair always stays consistent.
    READ ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace
        FIELDS ( ItemType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_marketplace\\Marketplace.

    LOOP AT items ASSIGNING FIELD-SYMBOL(<item>).

      DATA(lv_subtype) = SWITCH zrpg_marketplace-item_subtype( <item>-ItemType
        WHEN 'WEAPON'        THEN 'LONGSWORD'
        WHEN 'ARMOR'         THEN 'SHIELD'
        WHEN 'CONSUMABLE'    THEN 'POTION'
        WHEN 'MAGIC ITEM'    THEN 'WAND'
        WHEN 'MISCELLANEOUS' THEN 'ROPE'
        ELSE '' ).

      CHECK lv_subtype IS NOT INITIAL.

      APPEND VALUE #(
        %tky        = <item>-%tky
        ItemSubtype = lv_subtype
      ) TO updates.

    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
      ENTITY Marketplace UPDATE FIELDS ( ItemSubtype ) WITH updates
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
        ) TO reported-Marketplace.
      ENDIF.

      IF strlen(  <market>-ItemName  ) = 0.
        APPEND VALUE #( %tky = <market>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                   = <market>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Please insert a name for the item.' )
        ) TO reported-Marketplace.
      ENDIF.

      IF <market>-RequiredLevel < 1.
        APPEND VALUE #( %tky = <market>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                   = <market>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'The item must have a required level of higher than 0.' )
        ) TO reported-Marketplace.

      ENDIF.

      IF <market>-Price < 1.
        APPEND VALUE #( %tky = <market>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky                   = <market>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'The item must have a price higher than 0.' )
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
                                          && | to take this quest.| )
        ) TO reported-Marketplace.
        CONTINUE.
      ENDIF.
      "  Requested quantity from the action parameter (default 1)
      DATA(lv_amount) = <key>-%param-Amount.
      IF lv_amount < 1.
        lv_amount = 1.
      ENDIF.

      "  Not enough stock for the requested quantity
      IF lv_amount > <item>-AmountAvailable.
        APPEND VALUE #( %tky = <item>-%tky ) TO failed-Marketplace.
        APPEND VALUE #(
          %tky            = <item>-%tky
          %action-buyItem = if_abap_behv=>mk-on
          %msg            = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = |Only { <item>-AmountAvailable } of|
                                      && | '{ <item>-ItemName }' in stock|
                                      && | (requested { lv_amount }).| )
        ) TO reported-Marketplace.
        CONTINUE.
      ENDIF.

      "  Reduce stock by the bought quantity and assign the item to the buyer
      DATA(new_amount) = <item>-AmountAvailable - lv_amount..

      MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
        ENTITY Marketplace
          UPDATE FIELDS ( AmountAvailable AdventurerId )
          WITH VALUE #( ( %tky            = <item>-%tky
                          AmountAvailable = new_amount
                          AdventurerId    = lv_adventurer_id
               ) )
        REPORTED DATA(rep_item)
        FAILED   DATA(fail_item).

      "  When the last unit is bought, mark the listing SOLD OUT
      IF new_amount = 0.
        APPEND VALUE #(
          %tky         = <item>-%tky
          Status       = c_status_sold
        ) TO updates.
      ENDIF.
      APPEND VALUE #(
      %tky = <item>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |{ lv_amount }x '{ <item>-ItemName }' successfully bought.| )
      ) TO reported-Marketplace.
    ENDLOOP.


    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rpg_marketplace IN LOCAL MODE
        ENTITY Marketplace
          UPDATE FIELDS ( Status )
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
