@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Adventurer - Interface View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_RPG_ADVENTURER
  as select from    zrpg_adventurer

  //  " Join guild table to get the guild name directly
  left outer join zrpg_guild on zrpg_adventurer.guild_id = zrpg_guild.guild_id

  association [0..1] to ZI_RPG_GUILD as _Guild          on $projection.GuildId = _Guild.GuildId

  association [0..*] to ZI_RPG_QUEST as _Quest          on $projection.AdventurerId = _Quest.AdventurerId

  //  " All OPEN quests available to take
  association [0..*] to ZI_RPG_QUEST as _AvailableQuest on _AvailableQuest.Status = 'OPEN'
{
  key zrpg_adventurer.adventurer_id         as AdventurerId,
      zrpg_adventurer.guild_id              as GuildId,

      //      " Guild name pulled directly from the joined table
      zrpg_guild.guild_name                 as GuildName,

      zrpg_adventurer.adventurer_name       as AdventurerName,
      zrpg_adventurer.adventurer_class      as AdventurerClass,
      zrpg_adventurer.adventurer_level      as AdventurerLevel,
      zrpg_adventurer.adventurer_xp         as AdventurerXp,
      zrpg_adventurer.adventurer_gold       as AdventurerGold,

      @Semantics.systemDateTime.createdAt: true
      zrpg_adventurer.created_at            as CreatedAt,
      @Semantics.user.createdBy: true
      zrpg_adventurer.created_by            as CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      zrpg_adventurer.last_changed_at       as LastChangedAt,
      @Semantics.user.lastChangedBy: true
      zrpg_adventurer.last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      zrpg_adventurer.local_last_changed_at as LocalLastChangedAt,

      _Guild,
      _Quest,
      _AvailableQuest
}
