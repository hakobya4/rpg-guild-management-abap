@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Loot Item Catalog - Projection View'
@Metadata.allowExtensions: true

define root view entity ZC_RPG_LOOT_ITEMS
  provider contract transactional_query
  as projection on ZI_RPG_LOOT_ITEMS
{
  key ItemId,
      ItemName,
      ItemType,
      ItemSubtype,
      ItemRarity,
      Description,
      RequiredLevel,
      StrBonus,
      DexBonus,
      ConBonus,
      IntBonus,
      WisBonus,
      ChaBonus,
      Price
}
