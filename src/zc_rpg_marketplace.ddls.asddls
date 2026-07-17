@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for ZI_RPG_MARKETPLACE'
@Metadata.allowExtensions: true
define root view entity ZC_RPG_MARKETPLACE
  provider contract transactional_query
  as projection on ZI_RPG_MARKETPLACE
{

  key ItemId,
      AdventurerId,
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
      Price,
      AmountAvailable,
      Status,


      _Adventurer : redirected to ZC_RPG_ADVENTURER
}
