@EndUserText.label: 'Accept Quest - Action Parameter'
define abstract entity ZI_RPG_BUY_ITEM_PARAM
{
  //" Value help shows all available quests
  @Consumption.valueHelpDefinition: [{
    entity: {
      name:    'ZC_RPG_MARKETPLACE',
      element: 'ItemID'
    }
  }]
  ItemId : sysuuid_x16;
}
