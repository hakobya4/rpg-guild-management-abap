@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Guild Projection'
@Metadata.allowExtensions: true
define root view entity ZC_RPG_Guild
  as projection on ZI_RPG_Guild
{
  key GuildUUID,
      GuildName,
      HomeCity,
      Reputation,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy
}
