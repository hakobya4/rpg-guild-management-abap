@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'NPC - Projection View'
@Metadata.allowExtensions: true
define root view entity ZC_RPG_NPC
  provider contract transactional_query
  as projection on ZI_RPG_NPC
{
  key NpcId,
      NpcName,
      NpcRace,
      NpcRole,
      FlavorText,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy,
      LocalLastChangedAt
}
