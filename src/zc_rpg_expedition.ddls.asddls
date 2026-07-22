@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for ZI_RPG_EXPEDITION'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_RPG_EXPEDITION
  provider contract transactional_query
  as projection on ZI_RPG_EXPEDITION
{
  key ExpeditionId,
      ExpeditionName,
      QuestId,
      Status,
      RequiredStat,
      RequiredLevel,
      DifficultyClass,
      XpReward,
      Successes,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy,
      LocalLastChangedAt,
      /* Associations */
      _Member : redirected to composition child ZC_RPG_EXP_MEMBERS,
      _Quest  : redirected to ZC_RPG_QUEST
}
