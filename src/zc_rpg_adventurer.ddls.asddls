@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Adventurer Projection'
@Metadata.allowExtensions: true
define root view entity ZC_RPG_Adventurer
  as projection on ZI_RPG_Adventurer
{
  key AdventurerUUID,
      GuildUUID,
      AdventurerName,
      AdventurerClass,
      LevelValue,
      XPTotal,
      ActiveStatus,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy
}
