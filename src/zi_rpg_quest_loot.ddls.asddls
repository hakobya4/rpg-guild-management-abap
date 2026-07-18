@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Quest Loot Entry - Interface View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_RPG_QUEST_LOOT
  as select from zrpg_quest_loot
  association [1..1] to ZI_RPG_QUEST as _Quest on $projection.QuestId = _Quest.QuestId
  
{
  key loot_id              as LootId,
      quest_id              as QuestId,
      item_id               as ItemId,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Quest
}
