@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Reward Projection'
@Metadata.allowExtensions: true
define root view entity ZC_RPG_Reward
  as projection on ZI_RPG_Reward
{
  key RewardUUID,
      RewardName,
      RewardType,
      GoldAmount,
      ItemRarity
}
