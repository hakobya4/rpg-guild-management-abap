@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Quest Projection'
@Metadata.allowExtensions: true
define root view entity ZC_RPG_Quest
  as projection on ZI_RPG_Quest
{
  key QuestUUID,
      QuestName,
      Description,
      MinLevel,
      XPReward,
      RewardUUID,
      ActiveStatus
}
