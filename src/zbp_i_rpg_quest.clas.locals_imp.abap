*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type declarations

CLASS lhc_Quest DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS:
      c_status_open        TYPE zrpg_quest-status VALUE 'OPEN',
      c_status_in_progress TYPE zrpg_quest-status VALUE 'IN_PROGRESS',
      c_status_completed   TYPE zrpg_quest-status VALUE 'COMPLETED'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Quest RESULT result.


    METHODS validateQuestValues FOR VALIDATE ON SAVE
      IMPORTING keys FOR Quest~validateQuestValues.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Quest~setInitialStatus.

ENDCLASS.

CLASS lhc_Quest IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Empty — BTP trial permits all operations by default
  ENDMETHOD.

  METHOD validateQuestValues.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest
        FIELDS ( RequiredLevel XpReward )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests).


    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).

      IF <quest>-RequiredLevel < 1.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky                   = <quest>-%tky
          %msg                   = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Level requirement must be at least 1.' )
          %element-RequiredLevel = if_abap_behv=>mk-on
        ) TO reported-Quest.
      ENDIF.

      IF <quest>-XpReward < 1 or <quest>-GoldReward.
        APPEND VALUE #( %tky = <quest>-%tky ) TO failed-Quest.
        APPEND VALUE #(
          %tky              = <quest>-%tky
          %msg              = new_message_with_text(
                                severity = if_abap_behv_message=>severity-error
                                text     = 'XP or Gold reward must be at least 1.' )
          %element-XpReward = if_abap_behv=>mk-on
        ) TO reported-Quest.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD setInitialStatus.

    READ ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(quests).

    DATA updates TYPE TABLE FOR UPDATE zi_rpg_quest\\Quest.

    LOOP AT quests ASSIGNING FIELD-SYMBOL(<quest>).
      CHECK <quest>-Status IS INITIAL.
      APPEND VALUE #( %tky = <quest>-%tky  Status = c_status_open ) TO updates.
    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zi_rpg_quest IN LOCAL MODE
      ENTITY Quest UPDATE FIELDS ( Status ) WITH updates
      REPORTED DATA(rep)
      FAILED   DATA(fail).

    reported-Quest = CORRESPONDING #( BASE ( reported-Quest ) rep-Quest ).

  ENDMETHOD.


ENDCLASS.


