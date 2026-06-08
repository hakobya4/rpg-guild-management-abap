@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Adventurer'
@Metadata.allowExtensions: true
define root view entity ZI_RPG_Adventurer
  as select from zrpg_adventurer
  association [0..1] to ZI_RPG_Guild as _Guild
    on $projection.GuildUUID = _Guild.GuildUUID
  association [0..*] to ZI_RPG_AdventurerQuest as _QuestLog
    on $projection.AdventurerUUID = _QuestLog.AdventurerUUID
{
  key adventurer_uuid  as AdventurerUUID,
      guild_uuid       as GuildUUID,
      adventurer_name  as AdventurerName,
      adventurer_class as AdventurerClass,
      level_value      as LevelValue,
      xp_total         as XPTotal,
      active_status    as ActiveStatus,
      created_at       as CreatedAt,
      created_by       as CreatedBy,
      last_changed_at  as LastChangedAt,
      last_changed_by  as LastChangedBy,
      _Guild,
      _QuestLog
}
