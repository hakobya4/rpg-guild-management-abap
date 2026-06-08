@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Guild'
@Metadata.allowExtensions: true
define root view entity ZI_RPG_Guild
  as select from zrpg_guild
{
  key guild_uuid      as GuildUUID,
      guild_name      as GuildName,
      home_city       as HomeCity,
      reputation      as Reputation,
      created_at      as CreatedAt,
      created_by      as CreatedBy,
      last_changed_at as LastChangedAt,
      last_changed_by as LastChangedBy
}
