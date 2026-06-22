@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inventory Item - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel.dataCategory: #VALUE_HELP
// Value help for selling: only items currently held in inventory.
define view entity ZI_RPG_INV_VH
  as select from zrpg_inventory
{
      @Search.defaultSearchElement: true
  key inventory_id as InventoryId,
      item_id      as ItemId,
      item_name    as ItemName,
      item_type    as ItemType,
      item_subtype as ItemSubtype,
      amount       as Amount,
      adventurerid as AdventurerId
}
where amount > 0 
