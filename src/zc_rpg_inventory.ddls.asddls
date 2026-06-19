@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inventory - Projection View'
@Metadata.allowExtensions: true
define root view entity ZC_RPG_INVENTORY
  provider contract transactional_query
  as projection on ZI_RPG_INVENTORY
{
  key InventoryId,
      Adventurerid,
      ItemId,
      ItemName,
      ItemType,
      ItemSubtype,
      Description,
      Amount,
      Price,
      RequiredLevel,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy,
      LocalLastChangedAt,
      _Adventurer : redirected to ZC_RPG_ADVENTURER
}
