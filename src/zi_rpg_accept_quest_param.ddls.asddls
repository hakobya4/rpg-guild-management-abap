@EndUserText.label: 'Accept Quest - Action Parameter'
define abstract entity ZI_RPG_ACCEPT_QUEST_PARAM
{
  //" Value help shows all available quests
  @Consumption.valueHelpDefinition: [{
    entity: {
      name:    'ZC_RPG_QUEST',
      element: 'QuestId'
    }
  }]
  QuestId : sysuuid_x16;
}
