@EndUserText.label: 'Loot Odds - Action Result'

define abstract entity ZI_RPG_LOOT_ODDS
{
      @UI.lineItem: [{ position: 10, label: 'Category' }]
    key  Category       : abap.char(20);
      @UI.lineItem: [{ position: 20, label: 'Detail' }]
     key  Detail         : abap.char(30);
      @UI.lineItem: [{ position: 30, label: 'Probability %' }]
      ProbabilityPct : abap.int4;
}
