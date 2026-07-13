CLASS zcl_rpg_combat DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " Picks the right combat strategy for an adventurer class.
    CLASS-METHODS create_strategy
      IMPORTING iv_adventurer_class TYPE zrpg_adventurer-adventurer_class
      RETURNING VALUE(ro_strategy) TYPE REF TO zif_rpg_quest_resolution.

ENDCLASS.



CLASS zcl_rpg_combat IMPLEMENTATION.

  METHOD create_strategy.
    CASE iv_adventurer_class.
      WHEN 'WIZARD' OR 'SORCERER' OR 'WARLOCK' OR 'DRUID' OR 'CLERIC' OR 'BARD'.
        ro_strategy = NEW zcl_rpg_combat_caster( ).
      WHEN OTHERS.
        ro_strategy = NEW zcl_rpg_combat_martial( ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.

