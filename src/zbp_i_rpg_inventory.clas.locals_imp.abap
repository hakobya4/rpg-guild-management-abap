CLASS lhc_Inventory DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Inventory RESULT result.
    METHODS sellItem FOR MODIFY
      IMPORTING keys FOR ACTION Inventory~sellItem.

ENDCLASS.

CLASS lhc_Inventory IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

METHOD sellItem.


    DATA inv_updates TYPE TABLE FOR UPDATE zi_rpg_inventory\\Inventory.
    DATA inv_deletes TYPE TABLE FOR DELETE zi_rpg_inventory\\Inventory.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      SELECT SINGLE item_id, item_name, adventurerid, price, amount
        FROM zrpg_inventory
        WHERE inventory_id = @<key>-InventoryId
        INTO @DATA(item_data).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Inventory.
        APPEND VALUE #(
          %tky             = <key>-%tky
          %action-sellItem = if_abap_behv=>mk-on
          %msg             = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Inventory item not found.' )
        ) TO reported-Inventory.
        CONTINUE.
      ENDIF.

      " ── Amount to sell (default 1) ──
      DATA(lv_sell) = <key>-%param-Amount.
      IF lv_sell < 1.
        lv_sell = 1.
      ENDIF.

      IF lv_sell > item_data-amount.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-Inventory.
        APPEND VALUE #(
          %tky             = <key>-%tky
          %action-sellItem = if_abap_behv=>mk-on
          %msg             = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |You only own { item_data-amount } of '{ item_data-item_name }'.| )
        ) TO reported-Inventory.
        CONTINUE.
      ENDIF.

      DATA(lv_refund) = lv_sell * item_data-price.

      " ── 1) Refund gold to the owning adventurer (cross-BO) ──
      SELECT SINGLE adventurer_gold
        FROM zrpg_adventurer
        WHERE adventurer_id = @item_data-adventurerid
        INTO @DATA(lv_gold).

      IF sy-subrc = 0.
        MODIFY ENTITIES OF zi_rpg_adventurer
          ENTITY Adventurer
            UPDATE FIELDS ( AdventurerGold )
            WITH VALUE #( ( AdventurerId   = item_data-adventurerid
                            AdventurerGold = lv_gold + lv_refund ) )
          REPORTED DATA(rep_adv)
          FAILED   DATA(fail_adv).
      ENDIF.

      MODIFY ENTITIES OF zi_rpg_marketplace
        ENTITY Marketplace
          EXECUTE restock
          FROM VALUE #( ( ItemId        = item_data-item_id
                          %param-Amount = lv_sell ) )
        REPORTED DATA(rep_mkt)
        FAILED   DATA(fail_mkt).

      " ── 3) Reduce or remove the inventory stack (own BO, local mode) ──
      IF lv_sell = item_data-amount.
        APPEND VALUE #( %tky = <key>-%tky ) TO inv_deletes.
      ELSE.
        APPEND VALUE #( %tky    = <key>-%tky
                        Amount  = item_data-amount - lv_sell ) TO inv_updates.
      ENDIF.

      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |Sold { lv_sell }x '{ item_data-item_name }' for { lv_refund } gold.| )
      ) TO reported-Inventory.

    ENDLOOP.

    IF inv_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rpg_inventory IN LOCAL MODE
        ENTITY Inventory
          UPDATE FIELDS ( Amount ) WITH inv_updates
        REPORTED DATA(rep_u) FAILED DATA(fail_u).
      reported-Inventory = CORRESPONDING #( BASE ( reported-Inventory ) rep_u-Inventory ).
      failed-Inventory   = CORRESPONDING #( BASE ( failed-Inventory ) fail_u-Inventory ).
    ENDIF.

    IF inv_deletes IS NOT INITIAL.
      MODIFY ENTITIES OF zi_rpg_inventory IN LOCAL MODE
        ENTITY Inventory
          DELETE FROM inv_deletes
        REPORTED DATA(rep_d) FAILED DATA(fail_d).
      reported-Inventory = CORRESPONDING #( BASE ( reported-Inventory ) rep_d-Inventory ).
      failed-Inventory   = CORRESPONDING #( BASE ( failed-Inventory ) fail_d-Inventory ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
