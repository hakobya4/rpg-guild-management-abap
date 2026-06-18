@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Marketplace Item - Value Help'
@Search.searchable: true
define view entity ZI_RPG_ITEM_VH
  as select from zrpg_marketplace
{
      @Search.defaultSearchElement: true
  key item_id          as ItemId,
      item_name        as ItemName,
      item_type        as ItemType,
      item_subtype     as ItemSubtype,
      price            as Price,
      required_level   as RequiredLevel,
      amount_available as AmountAvailable,
      status           as Status
}
where status = 'AVAILABLE' and amount_available > 0
