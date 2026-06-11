@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Guild - Interface View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_RPG_GUILD
  as select from zrpg_guild
  association [0..*] to ZI_RPG_ADVENTURER as _Adventurer on $projection.GuildId = _Adventurer.GuildId
{
  key guild_id              as GuildId,
      guild_name            as GuildName,
      description           as Description,

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
