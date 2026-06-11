@EndUserText.label: 'Join Guild - Abstract Parameter'
define abstract entity ZI_RPG_JOIN_GUILD_PARAM
{
  @Consumption.valueHelpDefinition: [{
    entity: {
      name:    'ZC_RPG_GUILD',
      element: 'GuildId'
    }
  }]
  GuildId : sysuuid_x16;
}
