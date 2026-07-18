@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Loot Item - Value Help'
@Search.searchable: true
define view entity ZI_RPG_LOOT_ITEM_VH
  as select from zrpg_loot_items
{
      @Search.defaultSearchElement: true
  key item_id   as ItemId,
      item_name as ItemName,
      item_type as ItemType,
      item_rarity    as ItemRarity
}
