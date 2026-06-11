@EndUserText.label: 'Assign Adventurer - Action Parameter'
define abstract entity ZI_RPG_ASSIGN_ADV_PARAM
{
  //" Value help shows all adventurers
  @Consumption.valueHelpDefinition: [{
    entity: {
      name:    'ZC_RPG_ADVENTURER',
      element: 'AdventurerId'
    }
  }]
  AdventurerId : sysuuid_x16;
}
