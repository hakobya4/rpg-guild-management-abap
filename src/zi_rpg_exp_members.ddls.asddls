@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expedition Member (unmanaged)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_RPG_EXP_MEMBERS
  as select from zrpg_exp_members
  association to parent ZI_RPG_EXPEDITION as _Expedition on $projection.ExpeditionId = _Expedition.ExpeditionId
  association [0..1] to ZI_RPG_ADVENTURER as _Adventurer on $projection.AdventurerId = _Adventurer.AdventurerId
{
  key member_id             as MemberId,
      expedition_id         as ExpeditionId,
      adventurer_id         as AdventurerId,
      member_roll           as MemberRoll,
      member_total          as MemberTotal,
      member_passed         as MemberPassed,
      xp_gained             as XpGained,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _Expedition,
      _Adventurer
}
