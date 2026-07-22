@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for ZI_RPG_EXP_MEMBERS'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_RPG_EXP_MEMBERS
  as projection on ZI_RPG_EXP_MEMBERS
{
    key MemberId,
    ExpeditionId,
    AdventurerId,
    MemberRoll,
    MemberTotal,
    MemberPassed,
    XpGained,
    LocalLastChangedAt,
    /* Associations */
      _Expedition : redirected to parent ZC_RPG_EXPEDITION,
      _Adventurer : redirected to ZC_RPG_ADVENTURER
}
