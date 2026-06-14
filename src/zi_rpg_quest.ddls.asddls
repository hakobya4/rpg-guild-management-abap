@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Quest - Interface View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_RPG_QUEST
  as select from zrpg_quest

  //  " Shows which adventurer owns this quest
  association [0..1] to ZI_RPG_ADVENTURER as _Adventurer on $projection.AdventurerId = _Adventurer.AdventurerId
{
  key quest_id              as QuestId,
      quest_name            as QuestName,
      description           as Description,
      required_level        as RequiredLevel,
      xp_reward             as XpReward,
      gold_reward           as GoldReward,
      status                as Status,
      adventurer_id         as AdventurerId,

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

      _Adventurer
}
