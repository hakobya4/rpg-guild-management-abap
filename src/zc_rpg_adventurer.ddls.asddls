@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Adventurer - Projection View'
@Metadata.allowExtensions: true

define root view entity ZC_RPG_ADVENTURER
  provider contract transactional_query
  as projection on ZI_RPG_ADVENTURER
{
  key AdventurerId,

      @ObjectModel.text.association: '_Guild'
      GuildId,
      GuildName,
      AdventurerName,
      AdventurerClass,
      AdventurerLevel,
      AdventurerXp,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy,
      LocalLastChangedAt,

      _Guild          : redirected to ZC_RPG_GUILD,
      _Quest          : redirected to ZC_RPG_QUEST,
      _AvailableQuest : redirected to ZC_RPG_QUEST

}
