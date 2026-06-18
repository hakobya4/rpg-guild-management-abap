@EndUserText.label: 'Buy Item - Action Parameter'
define abstract entity ZI_RPG_BUY_ITEM_PARAM
{
  //" Value help shows all available items
  @Consumption.valueHelpDefinition: [{
    entity: {
      name:    'ZI_RPG_ITEM_VH',
      element: 'ItemId'
    }
  }]
  ItemId : sysuuid_x16;
}
