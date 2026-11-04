"! Reads the BDT customizing (TBZ* tables) of one application object
"! and returns it as nodes: downwards (hierarchy) or upwards (where-used).
CLASS zcl_bdt_explorer_model DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_node TYPE zif_bdt_explorer_types=>ty_node.
    TYPES tt_node TYPE zif_bdt_explorer_types=>tt_node.

    METHODS constructor
      IMPORTING
        iv_objap TYPE bu_objap
        iv_langu TYPE sy-langu DEFAULT sy-langu
        it_appli TYPE zif_bdt_explorer_types=>ty_appli_range OPTIONAL.

    METHODS get_objap
      RETURNING VALUE(rv_objap) TYPE bu_objap.

    METHODS get_appli_filter
      RETURNING VALUE(rt_appli) TYPE zif_bdt_explorer_types=>ty_appli_range.

    METHODS get_root
      RETURNING VALUE(rs_node) TYPE ty_node.

    "! Children for a downward node, parents for an upward (where-used) node
    METHODS expand
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.

    METHODS get_children
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.

    METHODS get_parents
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.

    "! Where-used search. Patterns support * and + as wildcards.
    METHODS search
      IMPORTING
        iv_field          TYPE csequence OPTIONAL
        iv_structure      TYPE csequence OPTIONAL
        iv_function       TYPE csequence OPTIONAL
        iv_program        TYPE csequence OPTIONAL
        iv_dynnr          TYPE csequence OPTIONAL
        iv_fldgr          TYPE bu_fldgr OPTIONAL
      RETURNING
        VALUE(rt_nodes)   TYPE tt_node.

    CLASS-METHODS get_type_text
      IMPORTING iv_type        TYPE zif_bdt_explorer_types=>ty_node_type
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS get_field_status
      IMPORTING
        is_tbz0o         TYPE tbz0o
        iv_fldgr         TYPE bu_fldgr
      RETURNING
        VALUE(rv_status) TYPE char1.

  PRIVATE SECTION.
    CONSTANTS c_max_hits TYPE i VALUE 500.
    "! Length of each TBZ0O-FELDSTLST1..7 (one status character per field group)
    CONSTANTS c_status_length TYPE i VALUE 250.

    TYPES:
      BEGIN OF ty_view_row,
        sicht TYPE bu_sicht,
        prgnm TYPE progname,
        dynnr TYPE dynnr,
        appli TYPE bu_appli,
        bez50 TYPE bu_bez50,
      END OF ty_view_row,
      tt_view_row TYPE STANDARD TABLE OF ty_view_row WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_efm_row,
        ztpkt TYPE bu_ztpkt,
        posnr TYPE bu_posnr,
        fname TYPE rs38l_fnam,
        appli TYPE bu_appli,
        xaktv TYPE bu_xaktvfn,
      END OF ty_efm_row,
      tt_efm_row TYPE STANDARD TABLE OF ty_efm_row WITH DEFAULT KEY.

    DATA mv_objap TYPE bu_objap.
    DATA mv_langu TYPE sy-langu.
    DATA mt_appli TYPE zif_bdt_explorer_types=>ty_appli_range.

    METHODS derive
      IMPORTING
        is_from        TYPE ty_node
        iv_type        TYPE zif_bdt_explorer_types=>ty_node_type
        iv_up          TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_node) TYPE ty_node.

    METHODS folders
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS applications
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS application_content
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS sequences
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS sequence_screens
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS screen_sections
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS section_views
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS view_field_groups
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS field_group_content
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS events
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS event_function_modules
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS tables
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS data_sets
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS activities
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.

    METHODS views_to_nodes
      IMPORTING
        is_from         TYPE ty_node
        it_views        TYPE tt_view_row
        iv_up           TYPE abap_bool
      RETURNING
        VALUE(rt_nodes) TYPE tt_node.
    METHODS fms_to_nodes
      IMPORTING
        is_from         TYPE ty_node
        it_fms          TYPE tt_efm_row
      RETURNING
        VALUE(rt_nodes) TYPE tt_node.
    METHODS field_group_text
      IMPORTING iv_fldgr       TYPE bu_fldgr
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS to_like
      IMPORTING iv_pattern     TYPE csequence
      RETURNING VALUE(rv_like) TYPE string.
    CLASS-METHODS field_status_text
      IMPORTING iv_status      TYPE char1
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS zcl_bdt_explorer_model IMPLEMENTATION.

  METHOD constructor.
    mv_objap = iv_objap.
    mv_langu = iv_langu.
    mt_appli = it_appli.
  ENDMETHOD.


  METHOD get_objap.
    rv_objap = mv_objap.
  ENDMETHOD.


  METHOD get_appli_filter.
    rt_appli = mt_appli.
  ENDMETHOD.


  METHOD get_root.
    SELECT SINGLE bez50 FROM tbz1t INTO @DATA(lv_text)
      WHERE spras = @mv_langu
        AND objap = @mv_objap.

    rs_node = VALUE #( type       = zif_bdt_explorer_types=>c_type-object
                       objap      = mv_objap
                       expandable = abap_true
                       key_text   = mv_objap
                       text       = lv_text ).
  ENDMETHOD.


  METHOD expand.
    IF is_node-up = abap_true.
      rt_nodes = get_parents( is_node ).
    ELSE.
      rt_nodes = get_children( is_node ).
    ENDIF.
  ENDMETHOD.


  METHOD get_children.
    CASE is_node-type.
      WHEN zif_bdt_explorer_types=>c_type-object.
        rt_nodes = folders( is_node ).
      WHEN zif_bdt_explorer_types=>c_type-folder.
        CASE is_node-folder.
          WHEN zif_bdt_explorer_types=>c_folder-applications.
            rt_nodes = applications( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-sequences.
            rt_nodes = sequences( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-events.
            rt_nodes = events( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-tables.
            rt_nodes = tables( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-data_sets.
            rt_nodes = data_sets( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-activities.
            rt_nodes = activities( is_node ).
        ENDCASE.
      WHEN zif_bdt_explorer_types=>c_type-application.
        rt_nodes = application_content( is_node ).
      WHEN zif_bdt_explorer_types=>c_type-sequence.
        rt_nodes = sequence_screens( is_node ).
      WHEN zif_bdt_explorer_types=>c_type-screen.
        rt_nodes = screen_sections( is_node ).
      WHEN zif_bdt_explorer_types=>c_type-section.
        rt_nodes = section_views( is_node ).
      WHEN zif_bdt_explorer_types=>c_type-view.
        rt_nodes = view_field_groups( is_node ).
      WHEN zif_bdt_explorer_types=>c_type-field_group.
        rt_nodes = field_group_content( is_node ).
      WHEN zif_bdt_explorer_types=>c_type-event.
        rt_nodes = event_function_modules( is_node ).
    ENDCASE.
  ENDMETHOD.


  METHOD get_parents.
    DATA lt_views TYPE tt_view_row.

    CASE is_node-type.
      WHEN zif_bdt_explorer_types=>c_type-field_group.
        SELECT e~sicht, e~prgnm, e~dynnr, e~appli, t~bez50
          FROM tbz3s AS s
          INNER JOIN tbz3e AS e ON e~objap = s~objap AND e~sicht = s~sicht
          LEFT OUTER JOIN tbz3f AS t ON t~objap = e~objap AND t~sicht = e~sicht AND t~spras = @mv_langu
          INTO CORRESPONDING FIELDS OF TABLE @lt_views
          WHERE s~objap = @mv_objap
            AND s~fldgr = @is_node-fldgr
            AND e~appli IN @mt_appli
          ORDER BY e~sicht.
        rt_nodes = views_to_nodes( is_from = is_node it_views = lt_views iv_up = abap_true ).

      WHEN zif_bdt_explorer_types=>c_type-view.
        SELECT h~absnr, t~bez50
          FROM tbz3h AS h
          LEFT OUTER JOIN tbz3d AS t ON t~objap = h~objap AND t~absnr = h~absnr AND t~spras = @mv_langu
          INTO TABLE @DATA(lt_sec)
          WHERE h~objap = @mv_objap
            AND h~sicht = @is_node-sicht
          ORDER BY h~absnr.
        LOOP AT lt_sec INTO DATA(ls_sec).
          DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-section iv_up = abap_true ).
          ls_node-absnr    = ls_sec-absnr.
          ls_node-key_text = ls_sec-absnr.
          ls_node-text     = ls_sec-bez50.
          APPEND ls_node TO rt_nodes.
        ENDLOOP.

      WHEN zif_bdt_explorer_types=>c_type-section.
        SELECT i~dynid, t~dtx50
          FROM tbz3i AS i
          LEFT OUTER JOIN tbz3b AS t ON t~objap = i~objap AND t~dynid = i~dynid AND t~spras = @mv_langu
          INTO TABLE @DATA(lt_scr)
          WHERE i~objap = @mv_objap
            AND i~absnr = @is_node-absnr
          ORDER BY i~dynid.
        LOOP AT lt_scr INTO DATA(ls_scr).
          ls_node = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-screen iv_up = abap_true ).
          ls_node-dynid    = ls_scr-dynid.
          ls_node-key_text = ls_scr-dynid.
          ls_node-text     = ls_scr-dtx50.
          APPEND ls_node TO rt_nodes.
        ENDLOOP.

      WHEN zif_bdt_explorer_types=>c_type-screen.
        SELECT k~varnr, k~posnr, t~txt50
          FROM tbz3k AS k
          LEFT OUTER JOIN tbz3t AS t ON t~objap = k~objap AND t~varnr = k~varnr AND t~spras = @mv_langu
          INTO TABLE @DATA(lt_seq)
          WHERE k~objap = @mv_objap
            AND k~dynid = @is_node-dynid
          ORDER BY k~varnr.
        LOOP AT lt_seq INTO DATA(ls_seq).
          ls_node = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-sequence iv_up = abap_true ).
          ls_node-varnr      = ls_seq-varnr.
          ls_node-key_text   = ls_seq-varnr.
          ls_node-text       = ls_seq-txt50.
          ls_node-info       = |Position { ls_seq-posnr }|.
          ls_node-expandable = abap_false.
          APPEND ls_node TO rt_nodes.
        ENDLOOP.
    ENDCASE.
  ENDMETHOD.


  METHOD search.
    DATA lt_views TYPE tt_view_row.
    DATA lt_fms TYPE tt_efm_row.
    DATA ls_node TYPE ty_node.
    DATA(ls_from) = VALUE ty_node( objap = mv_objap ).

    IF iv_field IS NOT INITIAL OR iv_structure IS NOT INITIAL.
      DATA(lv_field) = to_like( iv_field ).
      DATA(lv_struc) = to_like( iv_structure ).
      SELECT tabnm, fldnm, fldgr FROM tbz3r
        INTO TABLE @DATA(lt_fields)
        UP TO @c_max_hits ROWS
        WHERE objap = @mv_objap
          AND fldnm LIKE @lv_field
          AND tabnm LIKE @lv_struc
        ORDER BY fldgr, tabnm, fldnm.
      LOOP AT lt_fields INTO DATA(ls_field).
        ls_node = derive( is_from = ls_from iv_type = zif_bdt_explorer_types=>c_type-field_group iv_up = abap_true ).
        ls_node-fldgr    = ls_field-fldgr.
        ls_node-tabnm    = ls_field-tabnm.
        ls_node-fldnm    = ls_field-fldnm.
        ls_node-key_text = ls_field-fldgr.
        ls_node-text     = field_group_text( ls_field-fldgr ).
        ls_node-info     = |Field { ls_field-tabnm }-{ ls_field-fldnm }|.
        APPEND ls_node TO rt_nodes.
      ENDLOOP.
    ENDIF.

    IF iv_fldgr IS NOT INITIAL.
      ls_node = derive( is_from = ls_from iv_type = zif_bdt_explorer_types=>c_type-field_group iv_up = abap_true ).
      ls_node-fldgr    = iv_fldgr.
      ls_node-key_text = iv_fldgr.
      ls_node-text     = field_group_text( iv_fldgr ).
      APPEND ls_node TO rt_nodes.
    ENDIF.

    IF iv_function IS NOT INITIAL.
      DATA(lv_fm) = to_like( iv_function ).

      " Event function modules
      SELECT ztpkt, posnr, fname, appli, xaktv FROM tbz1f
        INTO CORRESPONDING FIELDS OF TABLE @lt_fms
        UP TO @c_max_hits ROWS
        WHERE objap = @mv_objap
          AND fname LIKE @lv_fm
          AND appli IN @mt_appli
        ORDER BY ztpkt, posnr.
      APPEND LINES OF fms_to_nodes( is_from = ls_from it_fms = lt_fms ) TO rt_nodes.

      " View function modules (PBC, PBO, PAI, text transfer)
      SELECT e~sicht, e~prgnm, e~dynnr, e~appli, t~bez50
        FROM tbz3e AS e
        LEFT OUTER JOIN tbz3f AS t ON t~objap = e~objap AND t~sicht = e~sicht AND t~spras = @mv_langu
        INTO CORRESPONDING FIELDS OF TABLE @lt_views
        UP TO @c_max_hits ROWS
        WHERE e~objap = @mv_objap
          AND e~appli IN @mt_appli
          AND ( e~fnpbc LIKE @lv_fm OR e~fnpbo LIKE @lv_fm OR e~fnpai LIKE @lv_fm OR e~fntxt LIKE @lv_fm )
        ORDER BY e~sicht.
      APPEND LINES OF views_to_nodes( is_from = ls_from it_views = lt_views iv_up = abap_true ) TO rt_nodes.

      " Programmed field grouping
      SELECT fldgr, fname FROM tbz3w
        INTO TABLE @DATA(lt_fg)
        WHERE objap = @mv_objap
          AND fname LIKE @lv_fm
        ORDER BY fldgr.
      LOOP AT lt_fg INTO DATA(ls_fg).
        ls_node = derive( is_from = ls_from iv_type = zif_bdt_explorer_types=>c_type-field_group iv_up = abap_true ).
        ls_node-fldgr    = ls_fg-fldgr.
        ls_node-key_text = ls_fg-fldgr.
        ls_node-text     = field_group_text( ls_fg-fldgr ).
        ls_node-info     = |Field grouping FM { ls_fg-fname }|.
        APPEND ls_node TO rt_nodes.
      ENDLOOP.

      " Screens of external function groups
      SELECT a~dynid, a~fname, t~dtx50
        FROM tbz3a AS a
        LEFT OUTER JOIN tbz3b AS t ON t~objap = a~objap AND t~dynid = a~dynid AND t~spras = @mv_langu
        INTO TABLE @DATA(lt_scr)
        WHERE a~objap = @mv_objap
          AND a~fname LIKE @lv_fm
        ORDER BY a~dynid.
      LOOP AT lt_scr INTO DATA(ls_scr).
        ls_node = derive( is_from = ls_from iv_type = zif_bdt_explorer_types=>c_type-screen iv_up = abap_true ).
        ls_node-dynid    = ls_scr-dynid.
        ls_node-key_text = ls_scr-dynid.
        ls_node-text     = ls_scr-dtx50.
        ls_node-info     = |Screen FM { ls_scr-fname }|.
        APPEND ls_node TO rt_nodes.
      ENDLOOP.

      " Read/collect function modules of tables
      SELECT tabnm, fncrd, fncwr FROM tbz1h
        INTO TABLE @DATA(lt_tab)
        WHERE objap = @mv_objap
          AND ( fncrd LIKE @lv_fm OR fncwr LIKE @lv_fm )
        ORDER BY tabnm.
      LOOP AT lt_tab INTO DATA(ls_tab).
        ls_node = derive( is_from = ls_from iv_type = zif_bdt_explorer_types=>c_type-table ).
        ls_node-tabnm    = ls_tab-tabnm.
        ls_node-key_text = ls_tab-tabnm.
        ls_node-info     = |Read { ls_tab-fncrd } / Collect { ls_tab-fncwr }|.
        APPEND ls_node TO rt_nodes.
      ENDLOOP.
    ENDIF.

    IF iv_program IS NOT INITIAL OR iv_dynnr IS NOT INITIAL.
      DATA(lv_prog) = to_like( iv_program ).
      DATA(lv_dynnr) = to_like( iv_dynnr ).
      SELECT e~sicht, e~prgnm, e~dynnr, e~appli, t~bez50
        FROM tbz3e AS e
        LEFT OUTER JOIN tbz3f AS t ON t~objap = e~objap AND t~sicht = e~sicht AND t~spras = @mv_langu
        INTO CORRESPONDING FIELDS OF TABLE @lt_views
        UP TO @c_max_hits ROWS
        WHERE e~objap = @mv_objap
          AND e~appli IN @mt_appli
          AND e~prgnm LIKE @lv_prog
          AND e~dynnr LIKE @lv_dynnr
        ORDER BY e~sicht.
      APPEND LINES OF views_to_nodes( is_from = ls_from it_views = lt_views iv_up = abap_true ) TO rt_nodes.
    ENDIF.
  ENDMETHOD.


  METHOD derive.
    rs_node = VALUE #( BASE is_from
                       type       = iv_type
                       up         = iv_up
                       folder     = space
                       key_text   = ``
                       text       = ``
                       info       = `` ).
    CASE iv_type.
      WHEN zif_bdt_explorer_types=>c_type-field
        OR zif_bdt_explorer_types=>c_type-field_status
        OR zif_bdt_explorer_types=>c_type-event_fm
        OR zif_bdt_explorer_types=>c_type-table
        OR zif_bdt_explorer_types=>c_type-data_set
        OR zif_bdt_explorer_types=>c_type-activity.
        rs_node-expandable = abap_false.
      WHEN OTHERS.
        rs_node-expandable = abap_true.
    ENDCASE.
  ENDMETHOD.


  METHOD folders.
    DATA(lt_folders) = VALUE string_table(
      ( |{ zif_bdt_explorer_types=>c_folder-applications }Applications| )
      ( |{ zif_bdt_explorer_types=>c_folder-sequences }Screen sequences| )
      ( |{ zif_bdt_explorer_types=>c_folder-events }Events| )
      ( |{ zif_bdt_explorer_types=>c_folder-tables }Tables| )
      ( |{ zif_bdt_explorer_types=>c_folder-data_sets }Data sets| )
      ( |{ zif_bdt_explorer_types=>c_folder-activities }Activities (field modification)| ) ).

    LOOP AT lt_folders INTO DATA(lv_folder).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-folder ).
      ls_node-folder   = lv_folder(4).
      ls_node-key_text = substring( val = lv_folder off = 4 ).
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD applications.
    SELECT a~appli, a~xaktv, t~bez30
      FROM tbz0a AS a
      LEFT OUTER JOIN tbz0b AS t ON t~objap = a~objap AND t~appli = a~appli AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_app)
      WHERE a~objap = @mv_objap
        AND a~appli IN @mt_appli
      ORDER BY a~appli.

    LOOP AT lt_app INTO DATA(ls_app).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-application ).
      ls_node-appli    = ls_app-appli.
      ls_node-key_text = ls_app-appli.
      ls_node-text     = ls_app-bez30.
      ls_node-info     = COND #( WHEN ls_app-xaktv = abap_true THEN `active` ELSE `inactive` ).
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD application_content.
    DATA lt_views TYPE tt_view_row.
    DATA lt_fms TYPE tt_efm_row.

    SELECT e~sicht, e~prgnm, e~dynnr, e~appli, t~bez50
      FROM tbz3e AS e
      LEFT OUTER JOIN tbz3f AS t ON t~objap = e~objap AND t~sicht = e~sicht AND t~spras = @mv_langu
      INTO CORRESPONDING FIELDS OF TABLE @lt_views
      WHERE e~objap = @mv_objap
        AND e~appli = @is_node-appli
      ORDER BY e~sicht.
    rt_nodes = views_to_nodes( is_from = is_node it_views = lt_views iv_up = abap_false ).

    SELECT ztpkt, posnr, fname, appli, xaktv FROM tbz1f
      INTO CORRESPONDING FIELDS OF TABLE @lt_fms
      WHERE objap = @mv_objap
        AND appli = @is_node-appli
      ORDER BY ztpkt, posnr.
    APPEND LINES OF fms_to_nodes( is_from = is_node it_fms = lt_fms ) TO rt_nodes.
  ENDMETHOD.


  METHOD sequences.
    SELECT s~varnr, s~xvrst, t~txt50
      FROM tbz3 AS s
      LEFT OUTER JOIN tbz3t AS t ON t~objap = s~objap AND t~varnr = s~varnr AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_seq)
      WHERE s~objap = @mv_objap
      ORDER BY s~varnr.

    LOOP AT lt_seq INTO DATA(ls_seq).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-sequence ).
      ls_node-varnr    = ls_seq-varnr.
      ls_node-key_text = ls_seq-varnr.
      ls_node-text     = ls_seq-txt50.
      ls_node-info     = COND #( WHEN ls_seq-xvrst = abap_true THEN `standard` ).
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD sequence_screens.
    SELECT k~posnr, k~dynid, t~dtx50
      FROM tbz3k AS k
      LEFT OUTER JOIN tbz3b AS t ON t~objap = k~objap AND t~dynid = k~dynid AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_scr)
      WHERE k~objap = @mv_objap
        AND k~varnr = @is_node-varnr
      ORDER BY k~posnr.

    LOOP AT lt_scr INTO DATA(ls_scr).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-screen ).
      ls_node-dynid    = ls_scr-dynid.
      ls_node-key_text = ls_scr-dynid.
      ls_node-text     = ls_scr-dtx50.
      ls_node-info     = |Position { ls_scr-posnr }|.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD screen_sections.
    SELECT i~posnr, i~absnr, t~bez50
      FROM tbz3i AS i
      LEFT OUTER JOIN tbz3d AS t ON t~objap = i~objap AND t~absnr = i~absnr AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_sec)
      WHERE i~objap = @mv_objap
        AND i~dynid = @is_node-dynid
      ORDER BY i~posnr.

    LOOP AT lt_sec INTO DATA(ls_sec).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-section ).
      ls_node-absnr    = ls_sec-absnr.
      ls_node-key_text = ls_sec-absnr.
      ls_node-text     = ls_sec-bez50.
      ls_node-info     = |Position { ls_sec-posnr }|.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD section_views.
    DATA lt_views TYPE tt_view_row.

    SELECT e~sicht, e~prgnm, e~dynnr, e~appli, t~bez50
      FROM tbz3h AS h
      INNER JOIN tbz3e AS e ON e~objap = h~objap AND e~sicht = h~sicht
      LEFT OUTER JOIN tbz3f AS t ON t~objap = e~objap AND t~sicht = e~sicht AND t~spras = @mv_langu
      INTO CORRESPONDING FIELDS OF TABLE @lt_views
      WHERE h~objap = @mv_objap
        AND h~absnr = @is_node-absnr
        AND e~appli IN @mt_appli
      ORDER BY h~posnr.

    rt_nodes = views_to_nodes( is_from = is_node it_views = lt_views iv_up = abap_false ).
  ENDMETHOD.


  METHOD view_field_groups.
    SELECT s~fldgr, w~fname, t~bez50
      FROM tbz3s AS s
      LEFT OUTER JOIN tbz3w AS w ON w~objap = s~objap AND w~fldgr = s~fldgr
      LEFT OUTER JOIN tbz3x AS t ON t~objap = s~objap AND t~fldgr = s~fldgr AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_fg)
      WHERE s~objap = @mv_objap
        AND s~sicht = @is_node-sicht
      ORDER BY s~fldgr.

    LOOP AT lt_fg INTO DATA(ls_fg).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-field_group ).
      ls_node-fldgr    = ls_fg-fldgr.
      ls_node-key_text = ls_fg-fldgr.
      ls_node-text     = ls_fg-bez50.
      ls_node-info     = COND #( WHEN ls_fg-fname IS NOT INITIAL THEN |Field grouping FM { ls_fg-fname }| ).
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD field_group_content.
    SELECT tabnm, fldnm, xinpt FROM tbz3r
      INTO TABLE @DATA(lt_fields)
      WHERE objap = @mv_objap
        AND fldgr = @is_node-fldgr
      ORDER BY tabnm, fldnm.

    LOOP AT lt_fields INTO DATA(ls_field).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-field ).
      ls_node-tabnm    = ls_field-tabnm.
      ls_node-fldnm    = ls_field-fldnm.
      ls_node-key_text = |{ ls_field-tabnm }-{ ls_field-fldnm }|.
      ls_node-info     = COND #( WHEN ls_field-xinpt = abap_true THEN `input field` ).
      APPEND ls_node TO rt_nodes.
    ENDLOOP.

    " Field status of this field group per activity (field modification)
    SELECT * FROM tbz0o INTO TABLE @DATA(lt_tbz0o)
      WHERE objap = @mv_objap
      ORDER BY action.
    LOOP AT lt_tbz0o INTO DATA(ls_tbz0o).
      ls_node = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-field_status ).
      ls_node-action   = ls_tbz0o-action.
      ls_node-key_text = |Activity { ls_tbz0o-action }|.
      ls_node-text     = field_status_text( get_field_status( is_tbz0o = ls_tbz0o iv_fldgr = is_node-fldgr ) ).
      ls_node-info     = `Transport moves the whole TBZ0O entry (all field groups)`.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD events.
    DATA lt_events TYPE STANDARD TABLE OF bu_ztpkt WITH EMPTY KEY.

    SELECT DISTINCT ztpkt FROM tbz1f
      INTO TABLE @lt_events
      WHERE objap = @mv_objap
        AND appli IN @mt_appli
      ORDER BY ztpkt.

    LOOP AT lt_events INTO DATA(lv_ztpkt).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-event ).
      ls_node-ztpkt    = lv_ztpkt.
      ls_node-key_text = lv_ztpkt.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD event_function_modules.
    DATA lt_fms TYPE tt_efm_row.

    SELECT ztpkt, posnr, fname, appli, xaktv FROM tbz1f
      INTO CORRESPONDING FIELDS OF TABLE @lt_fms
      WHERE objap = @mv_objap
        AND ztpkt = @is_node-ztpkt
        AND appli IN @mt_appli
      ORDER BY posnr.

    rt_nodes = fms_to_nodes( is_from = is_node it_fms = lt_fms ).
  ENDMETHOD.


  METHOD tables.
    SELECT tabnm, fncrd, fncwr FROM tbz1h
      INTO TABLE @DATA(lt_tab)
      WHERE objap = @mv_objap
      ORDER BY tabnm.

    LOOP AT lt_tab INTO DATA(ls_tab).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-table ).
      ls_node-tabnm    = ls_tab-tabnm.
      ls_node-key_text = ls_tab-tabnm.
      ls_node-info     = |Read { ls_tab-fncrd } / Collect { ls_tab-fncwr }|.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD data_sets.
    SELECT q~setid, t~title
      FROM tbz0q AS q
      LEFT OUTER JOIN tbz0r AS t ON t~objap = q~objap AND t~setid = q~setid AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_sets)
      WHERE q~objap = @mv_objap
      ORDER BY q~setid.

    LOOP AT lt_sets INTO DATA(ls_set).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-data_set ).
      ls_node-setid    = ls_set-setid.
      ls_node-key_text = ls_set-setid.
      ls_node-text     = ls_set-title.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD activities.
    DATA lt_act TYPE STANDARD TABLE OF bu_action_tbz0m WITH EMPTY KEY.

    SELECT action FROM tbz0o
      INTO TABLE @lt_act
      WHERE objap = @mv_objap
      ORDER BY action.

    LOOP AT lt_act INTO DATA(lv_action).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-activity ).
      ls_node-action   = lv_action.
      ls_node-key_text = lv_action.
      ls_node-info     = `Field status of all field groups`.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD views_to_nodes.
    LOOP AT it_views INTO DATA(ls_view).
      DATA(ls_node) = derive( is_from = is_from iv_type = zif_bdt_explorer_types=>c_type-view iv_up = iv_up ).
      ls_node-sicht    = ls_view-sicht.
      ls_node-appli    = ls_view-appli.
      ls_node-prgnm    = ls_view-prgnm.
      ls_node-dynnr    = ls_view-dynnr.
      ls_node-key_text = ls_view-sicht.
      ls_node-text     = ls_view-bez50.
      ls_node-info     = |{ ls_view-prgnm } { ls_view-dynnr } (Appl. { ls_view-appli })|.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD fms_to_nodes.
    LOOP AT it_fms INTO DATA(ls_fm).
      DATA(ls_node) = derive( is_from = is_from iv_type = zif_bdt_explorer_types=>c_type-event_fm ).
      ls_node-ztpkt    = ls_fm-ztpkt.
      ls_node-fname    = ls_fm-fname.
      ls_node-appli    = ls_fm-appli.
      ls_node-key_text = |{ ls_fm-ztpkt } { ls_fm-posnr }|.
      ls_node-text     = ls_fm-fname.
      ls_node-info     = |Appl. { ls_fm-appli }{ COND #( WHEN ls_fm-xaktv = abap_false THEN ` (inactive)` ) }|.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD field_group_text.
    SELECT SINGLE bez50 FROM tbz3x INTO @DATA(lv_text)
      WHERE spras = @mv_langu
        AND objap = @mv_objap
        AND fldgr = @iv_fldgr.
    rv_text = lv_text.
  ENDMETHOD.


  METHOD get_type_text.
    rv_text = SWITCH #( iv_type
      WHEN zif_bdt_explorer_types=>c_type-object       THEN `Object`
      WHEN zif_bdt_explorer_types=>c_type-application  THEN `Application`
      WHEN zif_bdt_explorer_types=>c_type-sequence     THEN `Screen sequence`
      WHEN zif_bdt_explorer_types=>c_type-screen       THEN `Screen`
      WHEN zif_bdt_explorer_types=>c_type-section      THEN `Section`
      WHEN zif_bdt_explorer_types=>c_type-view         THEN `View`
      WHEN zif_bdt_explorer_types=>c_type-field_group  THEN `Field group`
      WHEN zif_bdt_explorer_types=>c_type-field        THEN `Field`
      WHEN zif_bdt_explorer_types=>c_type-field_status THEN `Field status`
      WHEN zif_bdt_explorer_types=>c_type-event        THEN `Event`
      WHEN zif_bdt_explorer_types=>c_type-event_fm     THEN `Event FM`
      WHEN zif_bdt_explorer_types=>c_type-table        THEN `Table`
      WHEN zif_bdt_explorer_types=>c_type-data_set     THEN `Data set`
      WHEN zif_bdt_explorer_types=>c_type-activity     THEN `Activity`
      WHEN zif_bdt_explorer_types=>c_type-search       THEN `Search`
      ELSE `` ).
  ENDMETHOD.


  METHOD get_field_status.
    " TBZ0O-FELDSTLST1..7 form one long string with one status character per field group number
    DATA(lv_index) = CONV i( iv_fldgr ) - 1.
    IF lv_index < 0.
      RETURN.
    ENDIF.
    DATA(lv_offset) = lv_index MOD c_status_length.

    CASE lv_index DIV c_status_length.
      WHEN 0. rv_status = is_tbz0o-feldstlst1+lv_offset(1).
      WHEN 1. rv_status = is_tbz0o-feldstlst2+lv_offset(1).
      WHEN 2. rv_status = is_tbz0o-feldstlst3+lv_offset(1).
      WHEN 3. rv_status = is_tbz0o-feldstlst4+lv_offset(1).
      WHEN 4. rv_status = is_tbz0o-feldstlst5+lv_offset(1).
      WHEN 5. rv_status = is_tbz0o-feldstlst6+lv_offset(1).
      WHEN 6. rv_status = is_tbz0o-feldstlst7+lv_offset(1).
    ENDCASE.
  ENDMETHOD.


  METHOD field_status_text.
    rv_text = SWITCH #( iv_status
      WHEN '+' THEN `+ Required entry`
      WHEN '.' THEN `. Optional entry`
      WHEN '*' THEN `* Display only`
      WHEN '-' THEN `- Hidden`
      ELSE `  Not specified` ).
  ENDMETHOD.


  METHOD to_like.
    IF iv_pattern IS INITIAL.
      rv_like = `%`.
      RETURN.
    ENDIF.
    rv_like = to_upper( condense( iv_pattern ) ).
    REPLACE ALL OCCURRENCES OF `*` IN rv_like WITH `%`.
    REPLACE ALL OCCURRENCES OF `+` IN rv_like WITH `_`.
  ENDMETHOD.

ENDCLASS.
