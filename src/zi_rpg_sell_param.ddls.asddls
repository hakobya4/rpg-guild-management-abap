@EndUserText.label: 'Sell Item - Action Parameter'
define abstract entity ZI_RPG_SELL_PARAM
{
  //" Value help shows items the adventurer owns
  @Consumption.valueHelpDefinition: [{
    entity: {
      name:    'ZI_RPG_INV_VH',
      element: 'ItemId'
    }
  }]
  ItemId : sysuuid_x16;
  // How many units to sell
  Amount : abap.int4;
}
