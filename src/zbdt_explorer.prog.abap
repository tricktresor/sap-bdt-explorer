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
DATA go_docking TYPE REF TO cl_gui_docking_container.
DATA go_tree TYPE REF TO zcl_bdt_explorer_tree.
DATA gv_loaded_for TYPE string.

PARAMETERS p_objap TYPE bu_objap OBLIGATORY DEFAULT 'BUPA'.
SELECT-OPTIONS s_appli FOR gv_appli.
PARAMETERS p_langu TYPE sy-langu DEFAULT sy-langu.

AT SELECTION-SCREEN OUTPUT.
  IF go_docking IS INITIAL.
    go_docking = NEW #( repid = sy-repid
                        dynnr = sy-dynnr
                        side  = cl_gui_docking_container=>dock_at_bottom
                        ratio = 80 ).
    go_tree = NEW #( go_docking ).
    PERFORM load USING abap_true.
  ENDIF.

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'ONLI'.
      PERFORM load USING abap_true.
    WHEN space.
      " Enter: reload only when the selection changed, keep the expanded tree otherwise
      PERFORM load USING abap_false.
  ENDCASE.

START-OF-SELECTION.
  " The tree lives on the selection screen; nothing to do here.

FORM load USING iv_force TYPE abap_bool.
  CHECK go_tree IS BOUND.

  DATA(lv_selection) = |{ p_objap }/{ p_langu }|.
  LOOP AT s_appli INTO DATA(ls_appli).
    lv_selection = |{ lv_selection }/{ ls_appli-sign }{ ls_appli-option }{ ls_appli-low }{ ls_appli-high }|.
  ENDLOOP.
  IF iv_force = abap_false AND lv_selection = gv_loaded_for.
    RETURN.
  ENDIF.
  gv_loaded_for = lv_selection.

  go_tree->display( NEW zcl_bdt_explorer_model( iv_objap = p_objap
                                                iv_langu = p_langu
                                                it_appli = s_appli[] ) ).
ENDFORM.
