@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Quest - Projection View'
@Metadata.allowExtensions: true

define root view entity ZC_RPG_QUEST
  provider contract transactional_query
  as projection on ZI_RPG_QUEST
{
  key QuestId,
      QuestName,
      QuestTypeName,
      Description,
      RequiredLevel,
      DifficultyClass,
      RequiredStat,
      XpReward,
      GoldReward,
      Status,
      AdventurerId,

      _Adventurer : redirected to ZC_RPG_ADVENTURER,
      _Loot       : redirected to ZC_RPG_QUEST_LOOT
}
