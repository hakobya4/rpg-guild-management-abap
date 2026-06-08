@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Reward'
@Metadata.allowExtensions: true
define root view entity ZI_RPG_Reward
  as select from zrpg_reward
{
  key reward_uuid as RewardUUID,
      reward_name as RewardName,
      reward_type as RewardType,
      gold_amount as GoldAmount,
      item_rarity as ItemRarity
}
