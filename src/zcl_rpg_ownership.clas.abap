CLASS zcl_rpg_ownership DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " does the current user own this record
    CLASS-METHODS is_owner
      IMPORTING iv_created_by   TYPE syuname
      RETURNING VALUE(rv_owner) TYPE abap_bool.

ENDCLASS.



CLASS zcl_rpg_ownership IMPLEMENTATION.

  METHOD is_owner.
    " unowned records are not locked out
    rv_owner = xsdbool( iv_created_by = sy-uname OR iv_created_by IS INITIAL ).
  ENDMETHOD.

ENDCLASS.

