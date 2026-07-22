@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expedition - Interface View (unmanaged)'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_RPG_EXPEDITION
  as select from zrpg_expedition
  composition [0..*] of ZI_RPG_EXP_MEMBERS as _Member
  association [0..1] to ZI_RPG_QUEST as _Quest on $projection.QuestId = _Quest.QuestId
{
  key expedition_id         as ExpeditionId,
      expedition_name       as ExpeditionName,
      quest_id              as QuestId,
      status                as Status,
      required_stat         as RequiredStat,
      required_level        as RequiredLevel,
      difficulty_class      as DifficultyClass,
      xp_reward             as XpReward,
      successes             as Successes,
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
      _Member,
      _Quest
}
