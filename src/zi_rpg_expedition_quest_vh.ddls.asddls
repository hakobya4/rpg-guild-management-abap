@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expedition Quests - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_RPG_EXPEDITION_QUEST_VH
  as select from zrpg_quest
{
  key quest_id         as QuestId,
      @Search.defaultSearchElement: true
      quest_name       as QuestName,
      status           as Status,
      required_level   as RequiredLevel,
      difficulty_class as DifficultyClass
}
where quest_type_name = 'EXPEDITION'
