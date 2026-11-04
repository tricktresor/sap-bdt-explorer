*&---------------------------------------------------------------------*
*& Report ZBDT_EXPLORER
*&---------------------------------------------------------------------*
*& SAP Business Data Toolset (BDT) Explorer
*& https://github.com/tricktresor/sap-bdt-explorer
*&
*& Shows the BDT customizing of an application object as a tree:
*& applications, screen sequences > screens > sections > views >
*& field groups > fields, events with function modules, tables,
*& data sets and field modification per activity.
*& Toolbar: where-used search and transport of the selected entries.
*&---------------------------------------------------------------------*
REPORT zbdt_explorer.

TABLES sscrfields.

DATA gv_appli TYPE bu_appli.

PARAMETERS p_objap TYPE bu_objap OBLIGATORY DEFAULT 'BUPA'.
SELECT-OPTIONS s_appli FOR gv_appli.
PARAMETERS p_langu TYPE sy-langu DEFAULT sy-langu.

CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS pbo.
    CLASS-METHODS pai
      IMPORTING iv_ucomm TYPE sy-ucomm.

  PRIVATE SECTION.
    CLASS-DATA go_docking TYPE REF TO cl_gui_docking_container.
    CLASS-DATA go_tree TYPE REF TO zcl_bdt_explorer_tree.
    CLASS-DATA gv_loaded_for TYPE string.
    CLASS-DATA gv_reload TYPE abap_bool.

    CLASS-METHODS get_selection
      RETURNING VALUE(rv_selection) TYPE string.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD pai.
    " F8 always reloads; Enter (and any other PAI) when the selection changed,
    " so control events of the tree do not reset it. Nothing is read before the first Enter/F8.
    DATA(lv_selection) = get_selection( ).
    IF iv_ucomm = 'ONLI' OR lv_selection <> gv_loaded_for.
      gv_loaded_for = lv_selection.
      gv_reload = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD pbo.
    IF gv_reload = abap_false.
      RETURN.
    ENDIF.
    gv_reload = abap_false.

    " A displayed SALV tree is not rebuilt reliably: create container and tree anew
    IF go_docking IS BOUND.
      go_docking->free( ).
      CLEAR: go_docking, go_tree.
    ENDIF.

    go_docking = NEW #( repid = sy-repid
                        dynnr = sy-dynnr
                        side  = cl_gui_docking_container=>dock_at_bottom
                        ratio = 80 ).
    go_tree = NEW #( go_docking ).
    go_tree->display( NEW zcl_bdt_explorer_model( iv_objap = p_objap
                                                  iv_langu = p_langu
                                                  it_appli = s_appli[] ) ).
  ENDMETHOD.

  METHOD get_selection.
    rv_selection = |{ p_objap }/{ p_langu }|.
    LOOP AT s_appli INTO DATA(ls_appli).
      rv_selection = |{ rv_selection }/{ ls_appli-sign }{ ls_appli-option }{ ls_appli-low }{ ls_appli-high }|.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

AT SELECTION-SCREEN OUTPUT.
  lcl_app=>pbo( ).

AT SELECTION-SCREEN.
  lcl_app=>pai( sscrfields-ucomm ).

START-OF-SELECTION.
  " The tree lives on the selection screen; nothing to do here.
