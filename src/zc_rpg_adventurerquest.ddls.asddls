@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Adventurer Quest Projection'
@Metadata.allowExtensions: true
define root view entity ZC_RPG_AdventurerQuest
  as projection on ZI_RPG_AdventurerQuest
{
  key AdvQuestUUID,
      AdventurerUUID,
      QuestUUID,
      QuestStatus,
      AcceptedAt,
      CompletedAt,
      RewardClaimed,
      XPGranted,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy,
      _Adventurer,
      _Quest
}
