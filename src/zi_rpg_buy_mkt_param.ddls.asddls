@EndUserText.label: 'Marketplace Buy - Action Parameter'
define abstract entity ZI_RPG_BUY_MKT_PARAM
{
  AdventurerId : sysuuid_x16;
  // How many units to buy
  Amount       : abap.int4;
}
