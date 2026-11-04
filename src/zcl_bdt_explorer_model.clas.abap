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

    "! With an application filter: a section or view that belongs to other applications only.
    "! Below a relevant screen it is shown, but transported only as assignment.
    METHODS is_foreign
      IMPORTING is_node           TYPE ty_node
      RETURNING VALUE(rv_foreign) TYPE abap_bool.

    "! Node label: like GET_TYPE_TEXT, object parts named as the application object calls them
    METHODS get_label
      IMPORTING is_node        TYPE ty_node
      RETURNING VALUE(rv_text) TYPE string.

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

    " With an application filter only these sequences, screens and data sets lead to a
    " view of the selected applications. Below a relevant screen everything is shown.
    DATA mt_rel_varnr TYPE HASHED TABLE OF bu_varnr WITH UNIQUE KEY table_line.
    DATA mt_rel_dynid TYPE HASHED TABLE OF bu_dynid WITH UNIQUE KEY table_line.
    DATA mt_rel_absnr TYPE HASHED TABLE OF bu_absnr WITH UNIQUE KEY table_line.
    DATA mt_rel_setid TYPE HASHED TABLE OF bu_setid WITH UNIQUE KEY table_line.

    " Name of an object part as the application object calls it (BUPA: BP View / BP Views)
    DATA mv_part_singular TYPE string VALUE `Object part`.
    DATA mv_part_plural TYPE string VALUE `Object parts`.

    METHODS determine_relevance.
    METHODS determine_part_names.

    "! Expander only for nodes that really have children (one select per node type)
    METHODS mark_expandable
      CHANGING ct_nodes TYPE tt_node.

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
    METHODS object_parts
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS object_part_folders
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS object_part_data_sets
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS object_part_applications
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS object_part_sequences
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS object_part_views
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rt_nodes) TYPE tt_node.
    METHODS object_part_subheaders
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
    IF mt_appli IS NOT INITIAL.
      determine_relevance( ).
    ENDIF.
    determine_part_names( ).
  ENDMETHOD.


  METHOD determine_part_names.
    " Singular: label of the reference field TBZ1-RLTTB/RLTFL, plural: TBZ1T-RLTPL
    SELECT SINGLE rlttb, rltfl FROM tbz1 INTO @DATA(ls_reference)
      WHERE objap = @mv_objap.
    IF sy-subrc = 0 AND ls_reference-rlttb IS NOT INITIAL.
      SELECT SINGLE rollname FROM dd03l INTO @DATA(lv_rollname)
        WHERE tabname   = @ls_reference-rlttb
          AND fieldname = @ls_reference-rltfl
          AND as4local  = 'A'.
      SELECT SINGLE scrtext_m FROM dd04t INTO @DATA(lv_singular)
        WHERE rollname   = @lv_rollname
          AND ddlanguage = @mv_langu
          AND as4local   = 'A'.
      IF lv_singular IS INITIAL.
        SELECT SINGLE scrtext_m FROM dd04t INTO @lv_singular
          WHERE rollname   = @lv_rollname
            AND ddlanguage = 'E'
            AND as4local   = 'A'.
      ENDIF.
      IF lv_singular IS NOT INITIAL.
        mv_part_singular = lv_singular.
      ENDIF.
    ENDIF.

    SELECT SINGLE rltpl FROM tbz1t INTO @DATA(lv_plural)
      WHERE spras = @mv_langu
        AND objap = @mv_objap.
    IF lv_plural IS INITIAL.
      SELECT SINGLE rltpl FROM tbz1t INTO @lv_plural
        WHERE spras = 'E'
          AND objap = @mv_objap.
    ENDIF.
    IF lv_plural IS NOT INITIAL.
      mv_part_plural = lv_plural.
    ENDIF.
  ENDMETHOD.


  METHOD get_label.
    rv_text = COND #( WHEN is_node-type = zif_bdt_explorer_types=>c_type-object_part THEN mv_part_singular
                      ELSE get_type_text( is_node-type ) ).
  ENDMETHOD.


  METHOD determine_relevance.
    SELECT DISTINCT h~absnr
      FROM tbz3h AS h
      INNER JOIN tbz3e AS e ON e~objap = h~objap AND e~sicht = h~sicht
      INTO TABLE @mt_rel_absnr
      WHERE h~objap = @mv_objap
        AND e~appli IN @mt_appli.

    SELECT DISTINCT i~dynid
      FROM tbz3i AS i
      INNER JOIN tbz3h AS h ON h~objap = i~objap AND h~absnr = i~absnr
      INNER JOIN tbz3e AS e ON e~objap = h~objap AND e~sicht = h~sicht
      INTO TABLE @mt_rel_dynid
      WHERE i~objap = @mv_objap
        AND e~appli IN @mt_appli.

    SELECT DISTINCT k~varnr
      FROM tbz3k AS k
      INNER JOIN tbz3i AS i ON i~objap = k~objap AND i~dynid = k~dynid
      INNER JOIN tbz3h AS h ON h~objap = i~objap AND h~absnr = i~absnr
      INNER JOIN tbz3e AS e ON e~objap = h~objap AND e~sicht = h~sicht
      INTO TABLE @mt_rel_varnr
      WHERE k~objap = @mv_objap
        AND e~appli IN @mt_appli.

    SELECT DISTINCT setid FROM tbz3e
      INTO TABLE @mt_rel_setid
      WHERE objap = @mv_objap
        AND appli IN @mt_appli
        AND setid <> @space.
  ENDMETHOD.


  METHOD is_foreign.
    IF mt_appli IS INITIAL.
      RETURN.
    ENDIF.
    CASE is_node-type.
      WHEN zif_bdt_explorer_types=>c_type-section.
        rv_foreign = xsdbool( NOT line_exists( mt_rel_absnr[ table_line = is_node-absnr ] ) ).
      WHEN zif_bdt_explorer_types=>c_type-view.
        rv_foreign = xsdbool( is_node-appli NOT IN mt_appli ).
      WHEN zif_bdt_explorer_types=>c_type-sequence.
        " Screen sequence (category) of an object part: not specific to the application
        rv_foreign = xsdbool( is_node-folder = zif_bdt_explorer_types=>c_folder-op_sequences ).
    ENDCASE.
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
          WHEN zif_bdt_explorer_types=>c_folder-object_parts.
            rt_nodes = object_parts( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-op_data_sets.
            rt_nodes = object_part_data_sets( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-op_appls.
            rt_nodes = object_part_applications( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-op_sequences.
            rt_nodes = object_part_sequences( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-op_views.
            rt_nodes = object_part_views( is_node ).
          WHEN zif_bdt_explorer_types=>c_folder-op_subheader.
            rt_nodes = object_part_subheaders( is_node ).
        ENDCASE.
      WHEN zif_bdt_explorer_types=>c_type-object_part.
        rt_nodes = object_part_folders( is_node ).
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
    mark_expandable( CHANGING ct_nodes = rt_nodes ).
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
    mark_expandable( CHANGING ct_nodes = rt_nodes ).
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
    mark_expandable( CHANGING ct_nodes = rt_nodes ).
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
        OR zif_bdt_explorer_types=>c_type-subheader
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
      ( |{ zif_bdt_explorer_types=>c_folder-object_parts }{ mv_part_plural }| )
      ( |{ zif_bdt_explorer_types=>c_folder-activities }Activities (field modification)| ) ).

    LOOP AT lt_folders INTO DATA(lv_folder).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-folder ).
      ls_node-folder   = lv_folder(4).
      ls_node-key_text = substring( val = lv_folder off = 4 ).

      " Tables and activities have no application reference
      IF mt_appli IS NOT INITIAL
         AND ( ls_node-folder = zif_bdt_explorer_types=>c_folder-tables
            OR ls_node-folder = zif_bdt_explorer_types=>c_folder-activities ).
        CONTINUE.
      ENDIF.
      " No empty folders
      IF get_children( ls_node ) IS INITIAL.
        CONTINUE.
      ENDIF.
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

    SELECT e~sicht, e~prgnm, e~dynnr, e~appli, t~bez50
      FROM tbz3e AS e
      LEFT OUTER JOIN tbz3f AS t ON t~objap = e~objap AND t~sicht = e~sicht AND t~spras = @mv_langu
      INTO CORRESPONDING FIELDS OF TABLE @lt_views
      WHERE e~objap = @mv_objap
        AND e~appli = @is_node-appli
      ORDER BY e~sicht.
    rt_nodes = views_to_nodes( is_from = is_node it_views = lt_views iv_up = abap_false ).
  ENDMETHOD.


  METHOD sequences.
    SELECT s~varnr, s~xvrst, t~txt50
      FROM tbz3 AS s
      LEFT OUTER JOIN tbz3t AS t ON t~objap = s~objap AND t~varnr = s~varnr AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_seq)
      WHERE s~objap = @mv_objap
      ORDER BY s~varnr.

    LOOP AT lt_seq INTO DATA(ls_seq).
      IF mt_appli IS NOT INITIAL AND NOT line_exists( mt_rel_varnr[ table_line = ls_seq-varnr ] ).
        CONTINUE.
      ENDIF.
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
      IF mt_appli IS NOT INITIAL AND NOT line_exists( mt_rel_dynid[ table_line = ls_scr-dynid ] ).
        CONTINUE.
      ENDIF.
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
      IF mt_appli IS NOT INITIAL AND NOT line_exists( mt_rel_setid[ table_line = ls_set-setid ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-data_set ).
      ls_node-setid    = ls_set-setid.
      ls_node-key_text = ls_set-setid.
      ls_node-text     = ls_set-title.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD object_parts.
    DATA lt_relevant TYPE HASHED TABLE OF bu_rltyp WITH UNIQUE KEY table_line.

    SELECT p~rltyp, t~bez50
      FROM tbz0 AS p
      LEFT OUTER JOIN tbz0t AS t ON t~objap = p~objap AND t~rltyp = p~rltyp AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_parts)
      WHERE p~objap = @mv_objap
      ORDER BY p~rltyp.

    " With an application filter only object parts calling the application (TBZ0C)
    IF mt_appli IS NOT INITIAL.
      SELECT DISTINCT rltyp FROM tbz0c INTO TABLE @lt_relevant
        WHERE objap = @mv_objap
          AND appli IN @mt_appli.
    ENDIF.

    LOOP AT lt_parts INTO DATA(ls_part).
      IF mt_appli IS NOT INITIAL AND NOT line_exists( lt_relevant[ table_line = ls_part-rltyp ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-object_part ).
      ls_node-rltyp    = ls_part-rltyp.
      ls_node-key_text = ls_part-rltyp.
      ls_node-text     = ls_part-bez50.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD object_part_folders.
    " Same structure as view cluster BUPA_TBZ0
    DATA(lt_folders) = VALUE string_table(
      ( |{ zif_bdt_explorer_types=>c_folder-op_data_sets }Data Sets| )
      ( |{ zif_bdt_explorer_types=>c_folder-op_appls }Calling Applications| )
      ( |{ zif_bdt_explorer_types=>c_folder-op_sequences }Screen Sequences| )
      ( |{ zif_bdt_explorer_types=>c_folder-op_views }Views| )
      ( |{ zif_bdt_explorer_types=>c_folder-op_subheader }Subheader ID| ) ).

    LOOP AT lt_folders INTO DATA(lv_folder).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-folder ).
      ls_node-folder   = lv_folder(4).
      ls_node-key_text = substring( val = lv_folder off = 4 ).
      IF get_children( ls_node ) IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD object_part_data_sets.
    SELECT s~setid, t~title
      FROM tbz0s AS s
      LEFT OUTER JOIN tbz0r AS t ON t~objap = s~objap AND t~setid = s~setid AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_sets)
      WHERE s~objap = @mv_objap
        AND s~rltyp = @is_node-rltyp
      ORDER BY s~setid.

    LOOP AT lt_sets INTO DATA(ls_set).
      IF mt_appli IS NOT INITIAL AND NOT line_exists( mt_rel_setid[ table_line = ls_set-setid ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-data_set ).
      ls_node-folder   = zif_bdt_explorer_types=>c_folder-op_data_sets.
      ls_node-setid    = ls_set-setid.
      ls_node-key_text = ls_set-setid.
      ls_node-text     = ls_set-title.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD object_part_applications.
    SELECT c~appli, t~bez30
      FROM tbz0c AS c
      LEFT OUTER JOIN tbz0b AS t ON t~objap = c~objap AND t~appli = c~appli AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_app)
      WHERE c~objap = @mv_objap
        AND c~rltyp = @is_node-rltyp
        AND c~appli IN @mt_appli
      ORDER BY c~appli.

    LOOP AT lt_app INTO DATA(ls_app).
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-application ).
      ls_node-folder   = zif_bdt_explorer_types=>c_folder-op_appls.
      ls_node-appli    = ls_app-appli.
      ls_node-key_text = ls_app-appli.
      ls_node-text     = ls_app-bez30.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD object_part_sequences.
    SELECT u~vartp, u~varnr, t~txt50
      FROM tbz0u AS u
      LEFT OUTER JOIN tbz3t AS t ON t~objap = u~objap AND t~varnr = u~varnr AND t~spras = @mv_langu
      INTO TABLE @DATA(lt_seq)
      WHERE u~objap = @mv_objap
        AND u~rltyp = @is_node-rltyp
      ORDER BY u~vartp.

    LOOP AT lt_seq INTO DATA(ls_seq).
      IF mt_appli IS NOT INITIAL AND NOT line_exists( mt_rel_varnr[ table_line = ls_seq-varnr ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-sequence ).
      ls_node-folder   = zif_bdt_explorer_types=>c_folder-op_sequences.
      ls_node-vartp    = ls_seq-vartp.
      ls_node-varnr    = ls_seq-varnr.
      ls_node-key_text = ls_seq-varnr.
      ls_node-text     = ls_seq-txt50.
      ls_node-info     = |Screen sequence category { ls_seq-vartp }|.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD object_part_views.
    DATA lt_views TYPE tt_view_row.

    SELECT e~sicht, e~prgnm, e~dynnr, e~appli, t~bez50
      FROM tbz0f AS f
      INNER JOIN tbz3e AS e ON e~objap = f~objap AND e~sicht = f~sicht
      LEFT OUTER JOIN tbz3f AS t ON t~objap = e~objap AND t~sicht = e~sicht AND t~spras = @mv_langu
      INTO CORRESPONDING FIELDS OF TABLE @lt_views
      WHERE f~objap = @mv_objap
        AND f~rltyp = @is_node-rltyp
        AND e~appli IN @mt_appli
      ORDER BY e~sicht.

    rt_nodes = views_to_nodes( is_from = is_node it_views = lt_views iv_up = abap_false ).
    LOOP AT rt_nodes ASSIGNING FIELD-SYMBOL(<ls_node>).
      <ls_node>-folder = zif_bdt_explorer_types=>c_folder-op_views.
    ENDLOOP.
  ENDMETHOD.


  METHOD object_part_subheaders.
    " TBZJ2 has no application object: the object part is the role
    SELECT j~sub_header_id, h~application, t~text
      FROM tbzj2 AS j
      LEFT OUTER JOIN tbzj1 AS h ON h~sub_header_id = j~sub_header_id
      LEFT OUTER JOIN tbzj1t AS t ON t~sub_header_id = j~sub_header_id AND t~language = @mv_langu
      INTO TABLE @DATA(lt_shid)
      WHERE j~role = @is_node-rltyp
      ORDER BY j~sub_header_id.

    LOOP AT lt_shid INTO DATA(ls_shid).
      IF mt_appli IS NOT INITIAL AND ls_shid-application NOT IN mt_appli.
        CONTINUE.
      ENDIF.
      DATA(ls_node) = derive( is_from = is_node iv_type = zif_bdt_explorer_types=>c_type-subheader ).
      ls_node-folder   = zif_bdt_explorer_types=>c_folder-op_subheader.
      ls_node-shid     = ls_shid-sub_header_id.
      ls_node-key_text = ls_shid-sub_header_id.
      ls_node-text     = ls_shid-text.
      ls_node-info     = COND #( WHEN ls_shid-application IS NOT INITIAL THEN |Appl. { ls_shid-application }| ).
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


  METHOD mark_expandable.
    DATA lt_appli TYPE STANDARD TABLE OF bu_appli WITH EMPTY KEY.
    DATA lt_rltyp TYPE STANDARD TABLE OF bu_rltyp WITH EMPTY KEY.
    DATA lt_varnr TYPE STANDARD TABLE OF bu_varnr WITH EMPTY KEY.
    DATA lt_dynid TYPE STANDARD TABLE OF bu_dynid WITH EMPTY KEY.
    DATA lt_dynid_up TYPE STANDARD TABLE OF bu_dynid WITH EMPTY KEY.
    DATA lt_absnr TYPE STANDARD TABLE OF bu_absnr WITH EMPTY KEY.
    DATA lt_absnr_up TYPE STANDARD TABLE OF bu_absnr WITH EMPTY KEY.
    DATA lt_sicht TYPE STANDARD TABLE OF bu_sicht WITH EMPTY KEY.
    DATA lt_sicht_up TYPE STANDARD TABLE OF bu_sicht WITH EMPTY KEY.
    DATA lt_fldgr TYPE STANDARD TABLE OF bu_fldgr WITH EMPTY KEY.
    DATA lt_fldgr_up TYPE STANDARD TABLE OF bu_fldgr WITH EMPTY KEY.
    DATA lv_has_status TYPE abap_bool.

    DATA(lt_app) = VALUE tt_node( FOR n IN ct_nodes WHERE ( type = zif_bdt_explorer_types=>c_type-application ) ( n ) ).
    IF lt_app IS NOT INITIAL.
      " views of the application (TBZ3E)
      SELECT appli FROM tbz3e INTO TABLE @lt_appli
        FOR ALL ENTRIES IN @lt_app
        WHERE objap = @mv_objap
          AND appli = @lt_app-appli.
    ENDIF.

    DATA(lt_part) = VALUE tt_node( FOR n IN ct_nodes WHERE ( type = zif_bdt_explorer_types=>c_type-object_part ) ( n ) ).
    IF lt_part IS NOT INITIAL.
      " any assignment of the object part (view cluster BUPA_TBZ0)
      SELECT rltyp FROM tbz0s INTO TABLE @lt_rltyp
        FOR ALL ENTRIES IN @lt_part
        WHERE objap = @mv_objap
          AND rltyp = @lt_part-rltyp.
      SELECT rltyp FROM tbz0c APPENDING TABLE @lt_rltyp
        FOR ALL ENTRIES IN @lt_part
        WHERE objap = @mv_objap
          AND rltyp = @lt_part-rltyp.
      SELECT rltyp FROM tbz0u APPENDING TABLE @lt_rltyp
        FOR ALL ENTRIES IN @lt_part
        WHERE objap = @mv_objap
          AND rltyp = @lt_part-rltyp.
      SELECT rltyp FROM tbz0f APPENDING TABLE @lt_rltyp
        FOR ALL ENTRIES IN @lt_part
        WHERE objap = @mv_objap
          AND rltyp = @lt_part-rltyp.
      SELECT role FROM tbzj2 APPENDING TABLE @lt_rltyp
        FOR ALL ENTRIES IN @lt_part
        WHERE role = @lt_part-rltyp.
    ENDIF.

    DATA(lt_seq) = VALUE tt_node( FOR n IN ct_nodes WHERE ( type = zif_bdt_explorer_types=>c_type-sequence ) ( n ) ).
    IF lt_seq IS NOT INITIAL.
      " screens of the sequence (TBZ3K)
      SELECT varnr FROM tbz3k INTO TABLE @lt_varnr
        FOR ALL ENTRIES IN @lt_seq
        WHERE objap = @mv_objap
          AND varnr = @lt_seq-varnr.
    ENDIF.

    DATA(lt_scr) = VALUE tt_node( FOR n IN ct_nodes WHERE ( type = zif_bdt_explorer_types=>c_type-screen ) ( n ) ).
    IF lt_scr IS NOT INITIAL.
      " down: sections of the screen (TBZ3I), up: sequences using the screen (TBZ3K)
      SELECT dynid FROM tbz3i INTO TABLE @lt_dynid
        FOR ALL ENTRIES IN @lt_scr
        WHERE objap = @mv_objap
          AND dynid = @lt_scr-dynid.
      SELECT dynid FROM tbz3k INTO TABLE @lt_dynid_up
        FOR ALL ENTRIES IN @lt_scr
        WHERE objap = @mv_objap
          AND dynid = @lt_scr-dynid.
    ENDIF.

    DATA(lt_sec) = VALUE tt_node( FOR n IN ct_nodes WHERE ( type = zif_bdt_explorer_types=>c_type-section ) ( n ) ).
    IF lt_sec IS NOT INITIAL.
      " down: views of the section (TBZ3H), up: screens using the section (TBZ3I)
      SELECT absnr FROM tbz3h INTO TABLE @lt_absnr
        FOR ALL ENTRIES IN @lt_sec
        WHERE objap = @mv_objap
          AND absnr = @lt_sec-absnr.
      SELECT absnr FROM tbz3i INTO TABLE @lt_absnr_up
        FOR ALL ENTRIES IN @lt_sec
        WHERE objap = @mv_objap
          AND absnr = @lt_sec-absnr.
    ENDIF.

    DATA(lt_view) = VALUE tt_node( FOR n IN ct_nodes WHERE ( type = zif_bdt_explorer_types=>c_type-view ) ( n ) ).
    IF lt_view IS NOT INITIAL.
      " down: field groups of the view (TBZ3S), up: sections using the view (TBZ3H)
      SELECT sicht FROM tbz3s INTO TABLE @lt_sicht
        FOR ALL ENTRIES IN @lt_view
        WHERE objap = @mv_objap
          AND sicht = @lt_view-sicht.
      SELECT sicht FROM tbz3h INTO TABLE @lt_sicht_up
        FOR ALL ENTRIES IN @lt_view
        WHERE objap = @mv_objap
          AND sicht = @lt_view-sicht.
    ENDIF.

    DATA(lt_fg) = VALUE tt_node( FOR n IN ct_nodes WHERE ( type = zif_bdt_explorer_types=>c_type-field_group ) ( n ) ).
    IF lt_fg IS NOT INITIAL.
      " down: fields (TBZ3R) or field status per activity (TBZ0O), up: views using the field group (TBZ3S)
      SELECT fldgr FROM tbz3r INTO TABLE @lt_fldgr
        FOR ALL ENTRIES IN @lt_fg
        WHERE objap = @mv_objap
          AND fldgr = @lt_fg-fldgr.
      SELECT fldgr FROM tbz3s INTO TABLE @lt_fldgr_up
        FOR ALL ENTRIES IN @lt_fg
        WHERE objap = @mv_objap
          AND fldgr = @lt_fg-fldgr.
      SELECT COUNT( * ) FROM tbz0o
        WHERE objap = @mv_objap.
      lv_has_status = xsdbool( sy-dbcnt > 0 ).
    ENDIF.

    LOOP AT ct_nodes ASSIGNING FIELD-SYMBOL(<ls_node>) WHERE expandable = abap_true.
      CASE <ls_node>-type.
        WHEN zif_bdt_explorer_types=>c_type-application.
          <ls_node>-expandable = xsdbool( line_exists( lt_appli[ table_line = <ls_node>-appli ] ) ).
        WHEN zif_bdt_explorer_types=>c_type-object_part.
          <ls_node>-expandable = xsdbool( line_exists( lt_rltyp[ table_line = <ls_node>-rltyp ] ) ).
        WHEN zif_bdt_explorer_types=>c_type-sequence.
          <ls_node>-expandable = xsdbool( <ls_node>-up = abap_false
                                      AND line_exists( lt_varnr[ table_line = <ls_node>-varnr ] ) ).
        WHEN zif_bdt_explorer_types=>c_type-screen.
          IF <ls_node>-up = abap_true.
            <ls_node>-expandable = xsdbool( line_exists( lt_dynid_up[ table_line = <ls_node>-dynid ] ) ).
          ELSE.
            <ls_node>-expandable = xsdbool( line_exists( lt_dynid[ table_line = <ls_node>-dynid ] ) ).
          ENDIF.
        WHEN zif_bdt_explorer_types=>c_type-section.
          IF <ls_node>-up = abap_true.
            <ls_node>-expandable = xsdbool( line_exists( lt_absnr_up[ table_line = <ls_node>-absnr ] ) ).
          ELSE.
            <ls_node>-expandable = xsdbool( line_exists( lt_absnr[ table_line = <ls_node>-absnr ] ) ).
          ENDIF.
        WHEN zif_bdt_explorer_types=>c_type-view.
          IF <ls_node>-up = abap_true.
            <ls_node>-expandable = xsdbool( line_exists( lt_sicht_up[ table_line = <ls_node>-sicht ] ) ).
          ELSE.
            <ls_node>-expandable = xsdbool( line_exists( lt_sicht[ table_line = <ls_node>-sicht ] ) ).
          ENDIF.
        WHEN zif_bdt_explorer_types=>c_type-field_group.
          IF <ls_node>-up = abap_true.
            <ls_node>-expandable = xsdbool( line_exists( lt_fldgr_up[ table_line = <ls_node>-fldgr ] ) ).
          ELSE.
            <ls_node>-expandable = xsdbool( lv_has_status = abap_true
                                         OR line_exists( lt_fldgr[ table_line = <ls_node>-fldgr ] ) ).
          ENDIF.
      ENDCASE.
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
      WHEN zif_bdt_explorer_types=>c_type-object_part  THEN `Object part`
      WHEN zif_bdt_explorer_types=>c_type-subheader    THEN `Subheader ID`
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
      WHEN 0.
        rv_status = is_tbz0o-feldstlst1+lv_offset(1).
      WHEN 1.
        rv_status = is_tbz0o-feldstlst2+lv_offset(1).
      WHEN 2.
        rv_status = is_tbz0o-feldstlst3+lv_offset(1).
      WHEN 3.
        rv_status = is_tbz0o-feldstlst4+lv_offset(1).
      WHEN 4.
        rv_status = is_tbz0o-feldstlst5+lv_offset(1).
      WHEN 5.
        rv_status = is_tbz0o-feldstlst6+lv_offset(1).
      WHEN 6.
        rv_status = is_tbz0o-feldstlst7+lv_offset(1).
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
