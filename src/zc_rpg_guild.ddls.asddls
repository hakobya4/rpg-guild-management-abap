@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Guild - Projection View'
@Metadata.allowExtensions: true

define root view entity ZC_RPG_GUILD
  provider contract transactional_query
  as projection on ZI_RPG_GUILD
{
  key GuildId,
      GuildName,
      Description,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy,
      LocalLastChangedAt,
      _Adventurer : redirected to ZC_RPG_ADVENTURER
}
