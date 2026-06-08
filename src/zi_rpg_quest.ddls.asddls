@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Quest'
@Metadata.allowExtensions: true
define root view entity ZI_RPG_Quest
  as select from zrpg_quest
  association [0..1] to ZI_RPG_Reward as _Reward
    on $projection.RewardUUID = _Reward.RewardUUID
{
  key quest_uuid   as QuestUUID,
      quest_name   as QuestName,
      description  as Description,
      min_level    as MinLevel,
      xp_reward    as XPReward,
      reward_uuid  as RewardUUID,
      active_status as ActiveStatus,
      _Reward
}
