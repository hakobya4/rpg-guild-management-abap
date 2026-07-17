@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Quest Loot Entry - Projection View'
@Metadata.allowExtensions: true

define root view entity ZC_RPG_QUEST_LOOT
  provider contract transactional_query
  as projection on ZI_RPG_QUEST_LOOT
{
  key LootId,
      QuestId,
      ItemId,

      _Quest : redirected to ZC_RPG_QUEST
}
