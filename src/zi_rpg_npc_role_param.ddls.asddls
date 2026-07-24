
@EndUserText.label: 'Abstract Entity NPC role'

define abstract entity ZI_RPG_NPC_ROLE_PARAM
{
  @Consumption.valueHelpDefinition: [{
    entity: {
      name:    'ZI_RPG_NPCROLE_VH',
      element: 'NpcRole'
    }
  }]
  NpcRole : abap.char( 30 );
   @Consumption.valueHelpDefinition: [{
    entity: {
      name:    'ZI_RPG_NPC_RACE_VH',
      element: 'NpcRace'
    }
  }]
  NpcRace : abap.char( 30 );
}
