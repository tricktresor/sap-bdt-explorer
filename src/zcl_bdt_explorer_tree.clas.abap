"! ALV tree for the BDT explorer: lazy loading, navigation, search and transport
CLASS zcl_bdt_explorer_tree DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_node TYPE zif_bdt_explorer_types=>ty_node.
    TYPES tt_node TYPE zif_bdt_explorer_types=>tt_node.

    TYPES:
      BEGIN OF ty_line,
        text TYPE c LENGTH 80,
        info TYPE c LENGTH 120,
      END OF ty_line,
      tt_line TYPE STANDARD TABLE OF ty_line WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING io_container TYPE REF TO cl_gui_container.

    METHODS display
      IMPORTING io_model TYPE REF TO zcl_bdt_explorer_model.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_function,
        search    TYPE salv_de_function VALUE 'ZSEARCH',
        transport TYPE salv_de_function VALUE 'ZTRANSP',
        expand    TYPE salv_de_function VALUE 'ZEXPAND',
      END OF c_function.

    TYPES:
      BEGIN OF ty_map,
        node_key TYPE salv_de_node_key,
        node     TYPE ty_node,
        loaded   TYPE abap_bool,
      END OF ty_map.

    TYPES tt_key TYPE STANDARD TABLE OF salv_de_node_key WITH EMPTY KEY.
    TYPES tt_sellist TYPE STANDARD TABLE OF vimsellist WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_preview,
        objname TYPE trobj_name,
        tabkey  TYPE trobj_name,
      END OF ty_preview,
      tt_preview TYPE STANDARD TABLE OF ty_preview WITH DEFAULT KEY.

    DATA mo_tree TYPE REF TO cl_salv_tree.
    DATA mo_model TYPE REF TO zcl_bdt_explorer_model.
    DATA mt_outtab TYPE tt_line.
    DATA mt_map TYPE HASHED TABLE OF ty_map WITH UNIQUE KEY node_key.
    "! Root node and search result roots
    DATA mt_top TYPE tt_key.
    DATA mv_displayed TYPE abap_bool.

    METHODS setup_columns.
    METHODS setup_functions.

    METHODS add_node
      IMPORTING
        iv_parent     TYPE salv_de_node_key OPTIONAL
        is_node       TYPE ty_node
        iv_loaded     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_key) TYPE salv_de_node_key.

    METHODS add_nodes
      IMPORTING
        iv_parent      TYPE salv_de_node_key
        it_nodes       TYPE tt_node
      RETURNING
        VALUE(rt_keys) TYPE tt_key.

    "! Loads all levels below a node that were not read yet
    METHODS load_subtree
      IMPORTING iv_key TYPE salv_de_node_key.

    METHODS expand_all.

    METHODS expand_node
      IMPORTING iv_key TYPE salv_de_node_key.

    METHODS search.
    METHODS transport.
    METHODS navigate
      IMPORTING is_node TYPE ty_node.

    "! Opens the BDT maintenance (as transactions BUS1..BUS23 do) positioned on the node
    METHODS navigate_customizing
      IMPORTING is_node TYPE ty_node.

    "! @parameter rv_unknown_field | the maintenance does not know a field of the selection
    METHODS call_maintenance
      IMPORTING
        iv_cluster              TYPE vcldir-vclname OPTIONAL
        iv_start                TYPE vclstruc-object OPTIONAL
        iv_view                 TYPE dd02v-tabname OPTIONAL
        it_sellist              TYPE tt_sellist
      RETURNING
        VALUE(rv_unknown_field) TYPE abap_bool.

    METHODS on_expand_empty_folder FOR EVENT expand_empty_folder OF cl_salv_events_tree
      IMPORTING node_key.
    METHODS on_double_click FOR EVENT double_click OF cl_salv_events_tree
      IMPORTING node_key.
    METHODS on_link_click FOR EVENT link_click OF cl_salv_events_tree
      IMPORTING node_key.
    METHODS on_added_function FOR EVENT added_function OF cl_salv_events_tree
      IMPORTING e_salv_function.
ENDCLASS.



CLASS zcl_bdt_explorer_tree IMPLEMENTATION.

  METHOD constructor.
    TRY.
        cl_salv_tree=>factory(
          EXPORTING r_container = io_container
          IMPORTING r_salv_tree = mo_tree
          CHANGING  t_table     = mt_outtab ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'E'.
    ENDTRY.

    DATA(lo_settings) = mo_tree->get_tree_settings( ).
    lo_settings->set_hierarchy_header( 'BDT customizing' ).
    lo_settings->set_hierarchy_size( 50 ).

    setup_columns( ).
    setup_functions( ).

    DATA(lo_events) = mo_tree->get_event( ).
    SET HANDLER on_expand_empty_folder
                on_double_click
                on_link_click
                on_added_function FOR lo_events.
  ENDMETHOD.


  METHOD setup_columns.
    DATA(lo_columns) = mo_tree->get_columns( ).
    lo_columns->set_optimize( abap_true ).
    TRY.
        DATA(lo_column) = lo_columns->get_column( 'TEXT' ).
        lo_column->set_short_text( 'Text' ).
        lo_column->set_medium_text( 'Description' ).
        lo_column->set_long_text( 'Description' ).
        lo_column = lo_columns->get_column( 'INFO' ).
        lo_column->set_short_text( 'Info' ).
        lo_column->set_medium_text( 'Details' ).
        lo_column->set_long_text( 'Details' ).
      CATCH cx_salv_not_found ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.


  METHOD setup_functions.
    DATA(lo_functions) = mo_tree->get_functions( ).
    lo_functions->set_all( abap_true ).
    TRY.
        lo_functions->add_function( name     = c_function-expand
                                    icon     = CONV #( icon_expand_all )
                                    text     = 'Expand all'
                                    tooltip  = 'Load and expand everything below the selected nodes (all without selection)'
                                    position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_functions->add_function( name     = c_function-search
                                    icon     = CONV #( icon_search )
                                    text     = 'Where-used'
                                    tooltip  = 'Search field, function module, screen or field group'
                                    position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_functions->add_function( name     = c_function-transport
                                    icon     = CONV #( icon_import_transport_request )
                                    text     = 'Transport'
                                    tooltip  = 'Write selected entries into a customizing request'
                                    position = if_salv_c_function_position=>right_of_salv_functions ).
      CATCH cx_salv_existing cx_salv_wrong_call INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD display.
    mo_model = io_model.

    TRY.
        mo_tree->get_nodes( )->delete_all( ).
      CATCH cx_salv_error ##NO_HANDLER.
    ENDTRY.
    CLEAR: mt_map, mt_top.

    DATA(ls_root) = mo_model->get_root( ).
    DATA(lv_root) = add_node( is_node = ls_root iv_loaded = abap_true ).
    APPEND lv_root TO mt_top.
    add_nodes( iv_parent = lv_root it_nodes = mo_model->expand( ls_root ) ).
    expand_node( lv_root ).

    IF mv_displayed = abap_false.
      mo_tree->display( ).
      mv_displayed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD add_node.
    DATA(lv_text) = SWITCH string( is_node-type
      WHEN zif_bdt_explorer_types=>c_type-folder
        OR zif_bdt_explorer_types=>c_type-search THEN is_node-key_text
      ELSE |{ mo_model->get_label( is_node ) } { is_node-key_text }| ).
    IF is_node-up = abap_true.
      lv_text = |<- { lv_text }|.
    ENDIF.

    DATA(ls_line) = VALUE ty_line( text = is_node-text info = is_node-info ).

    TRY.
        DATA(lo_node) = mo_tree->get_nodes( )->add_node(
          related_node   = iv_parent
          relationship   = cl_gui_column_tree=>relat_last_child
          data_row       = ls_line
          text           = CONV lvc_value( lv_text )
          expander       = is_node-expandable
          folder         = xsdbool( is_node-expandable = abap_true
                                 OR is_node-type = zif_bdt_explorer_types=>c_type-search ) ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    " Hotspot: a click on the node text opens the customizing
    IF is_node-type <> zif_bdt_explorer_types=>c_type-search.
      lo_node->get_hierarchy_item( )->set_type( if_salv_c_item_type=>link ).
    ENDIF.

    rv_key = lo_node->get_key( ).
    INSERT VALUE #( node_key = rv_key node = is_node loaded = iv_loaded ) INTO TABLE mt_map.
  ENDMETHOD.


  METHOD add_nodes.
    LOOP AT it_nodes INTO DATA(ls_node).
      DATA(lv_key) = add_node( iv_parent = iv_parent is_node = ls_node ).
      IF lv_key IS NOT INITIAL.
        APPEND lv_key TO rt_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_subtree.
    DATA lt_keys TYPE tt_key.

    READ TABLE mt_map INTO DATA(ls_map) WITH TABLE KEY node_key = iv_key.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF ls_map-loaded = abap_false AND ls_map-node-expandable = abap_true.
      mt_map[ node_key = iv_key ]-loaded = abap_true.
      lt_keys = add_nodes( iv_parent = iv_key it_nodes = mo_model->expand( ls_map-node ) ).
    ELSE.
      TRY.
          DATA(lt_children) = mo_tree->get_nodes( )->get_node( iv_key )->get_children( ).
        CATCH cx_salv_msg.
          RETURN.
      ENDTRY.
      lt_keys = VALUE #( FOR ls_child IN lt_children ( ls_child-key ) ).
    ENDIF.

    LOOP AT lt_keys INTO DATA(lv_key).
      load_subtree( lv_key ).
    ENDLOOP.
  ENDMETHOD.


  METHOD expand_all.
    DATA(lt_keys) = VALUE tt_key( FOR ls_selected IN mo_tree->get_selections( )->get_selected_nodes( )
                                  ( ls_selected-key ) ).
    IF lt_keys IS INITIAL.
      lt_keys = mt_top.
    ENDIF.

    LOOP AT lt_keys INTO DATA(lv_key).
      load_subtree( lv_key ).
      TRY.
          mo_tree->get_nodes( )->get_node( lv_key )->expand( complete_subtree = abap_true ).
        CATCH cx_salv_msg ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD expand_node.
    TRY.
        mo_tree->get_nodes( )->get_node( iv_key )->expand( ).
      CATCH cx_salv_msg ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.


  METHOD on_expand_empty_folder.
    READ TABLE mt_map INTO DATA(ls_map) WITH TABLE KEY node_key = node_key.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    mt_map[ node_key = node_key ]-loaded = abap_true.
    DATA(lt_nodes) = mo_model->expand( ls_map-node ).
    IF lt_nodes IS INITIAL.
      MESSAGE 'No entries found' TYPE 'S'.
      RETURN.
    ENDIF.
    add_nodes( iv_parent = node_key it_nodes = lt_nodes ).
    expand_node( node_key ).
  ENDMETHOD.


  METHOD on_link_click.
    READ TABLE mt_map INTO DATA(ls_map) WITH TABLE KEY node_key = node_key.
    IF sy-subrc = 0.
      navigate_customizing( ls_map-node ).
    ENDIF.
  ENDMETHOD.


  METHOD on_double_click.
    READ TABLE mt_map INTO DATA(ls_map) WITH TABLE KEY node_key = node_key.
    IF sy-subrc = 0.
      navigate( ls_map-node ).
    ENDIF.
  ENDMETHOD.


  METHOD on_added_function.
    CASE e_salv_function.
      WHEN c_function-search.
        search( ).
      WHEN c_function-transport.
        transport( ).
      WHEN c_function-expand.
        expand_all( ).
    ENDCASE.
  ENDMETHOD.


  METHOD navigate.
    DATA lv_name TYPE eu_lname.
    DATA lv_type TYPE seu_obj.

    CASE is_node-type.
      WHEN zif_bdt_explorer_types=>c_type-event_fm.
        lv_name = is_node-fname.
        lv_type = 'FUNC'.
      WHEN zif_bdt_explorer_types=>c_type-view.
        lv_name = is_node-prgnm.
        lv_type = 'PROG'.
      WHEN zif_bdt_explorer_types=>c_type-table
        OR zif_bdt_explorer_types=>c_type-field.
        lv_name = is_node-tabnm.
        lv_type = 'TABL'.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'RS_TOOL_ACCESS'
      EXPORTING
        operation   = 'SHOW'
        object_name = lv_name
        object_type = lv_type
      EXCEPTIONS
        OTHERS      = 1.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.


  METHOD navigate_customizing.
    DATA lv_cluster TYPE vcldir-vclname.
    DATA lv_view TYPE dd02v-tabname.
    DATA lt_keys TYPE tt_sellist.
    DATA lv_objap TYPE bu_objap.

    DATA(lt_base) = VALUE tt_sellist( ( viewfield = 'OBJAP' operator = 'EQ' value = is_node-objap ) ).

    " Object parts and everything listed below them: view cluster BUPA_TBZ0 at the matching object
    IF is_node-type = zif_bdt_explorer_types=>c_type-object_part
       OR is_node-folder = zif_bdt_explorer_types=>c_folder-object_parts
       OR is_node-folder = zif_bdt_explorer_types=>c_folder-op_data_sets
       OR is_node-folder = zif_bdt_explorer_types=>c_folder-op_appls
       OR is_node-folder = zif_bdt_explorer_types=>c_folder-op_sequences
       OR is_node-folder = zif_bdt_explorer_types=>c_folder-op_views
       OR is_node-folder = zif_bdt_explorer_types=>c_folder-op_subheader.
      DATA(lv_start) = SWITCH vclstruc-object( is_node-folder
        WHEN zif_bdt_explorer_types=>c_folder-op_data_sets THEN 'V_TBZ0S'
        WHEN zif_bdt_explorer_types=>c_folder-op_appls     THEN 'V_TBZ0C'
        WHEN zif_bdt_explorer_types=>c_folder-op_sequences THEN 'V_TBZ0U'
        WHEN zif_bdt_explorer_types=>c_folder-op_views     THEN 'V_TBZ0F'
        WHEN zif_bdt_explorer_types=>c_folder-op_subheader THEN 'V_TBZJ2' ).
      IF is_node-rltyp IS NOT INITIAL.
        lt_keys = VALUE #( ( viewfield = 'RLTYP' operator = 'EQ' value = is_node-rltyp ) ).
      ENDIF.
      IF call_maintenance( iv_cluster = 'BUPA_TBZ0'
                           iv_start   = lv_start
                           it_sellist = VALUE #( BASE lt_base ( LINES OF lt_keys ) ) ) = abap_true
         AND lt_keys IS NOT INITIAL.
        call_maintenance( iv_cluster = 'BUPA_TBZ0'
                          iv_start   = lv_start
                          it_sellist = lt_base ).
      ENDIF.
      RETURN.
    ENDIF.

    " Target per node type, as report BUSVIEWS maps the transactions BUS1..BUS23
    DATA(lv_type) = COND zif_bdt_explorer_types=>ty_node_type(
      WHEN is_node-type <> zif_bdt_explorer_types=>c_type-folder THEN is_node-type
      ELSE SWITCH #( is_node-folder
             WHEN zif_bdt_explorer_types=>c_folder-applications THEN zif_bdt_explorer_types=>c_type-application
             WHEN zif_bdt_explorer_types=>c_folder-sequences    THEN zif_bdt_explorer_types=>c_type-sequence
             WHEN zif_bdt_explorer_types=>c_folder-events       THEN zif_bdt_explorer_types=>c_type-event
             WHEN zif_bdt_explorer_types=>c_folder-tables       THEN zif_bdt_explorer_types=>c_type-table
             WHEN zif_bdt_explorer_types=>c_folder-data_sets    THEN zif_bdt_explorer_types=>c_type-data_set
             WHEN zif_bdt_explorer_types=>c_folder-activities   THEN zif_bdt_explorer_types=>c_type-activity ) ).
    DATA(lv_positioned) = xsdbool( is_node-type <> zif_bdt_explorer_types=>c_type-folder ).

    CASE lv_type.
      WHEN zif_bdt_explorer_types=>c_type-object.
        lv_cluster = 'BUPA_TBZ1'.
      WHEN zif_bdt_explorer_types=>c_type-application.
        lv_view = 'V_TBZ0A'.
        lt_keys = VALUE #( ( viewfield = 'APPLI' operator = 'EQ' value = is_node-appli ) ).
      WHEN zif_bdt_explorer_types=>c_type-sequence.
        lv_cluster = 'BUPA_TBZ3'.
        lt_keys = VALUE #( ( viewfield = 'VARNR' operator = 'EQ' value = is_node-varnr ) ).
      WHEN zif_bdt_explorer_types=>c_type-screen.
        lv_cluster = 'BUPATBZ3A'.
        lt_keys = VALUE #( ( viewfield = 'DYNID' operator = 'EQ' value = is_node-dynid ) ).
      WHEN zif_bdt_explorer_types=>c_type-section.
        lv_cluster = 'BUPA_TBZ3C'.
        lt_keys = VALUE #( ( viewfield = 'ABSNR' operator = 'EQ' value = is_node-absnr ) ).
      WHEN zif_bdt_explorer_types=>c_type-view.
        lv_cluster = 'BUPA_TBZ3E'.
        lt_keys = VALUE #( ( viewfield = 'SICHT' operator = 'EQ' value = is_node-sicht ) ).
      WHEN zif_bdt_explorer_types=>c_type-field_group
        OR zif_bdt_explorer_types=>c_type-field.
        lv_cluster = 'BUPAFLDMOD'.
        lt_keys = VALUE #( ( viewfield = 'FLDGR' operator = 'EQ' value = is_node-fldgr ) ).
      WHEN zif_bdt_explorer_types=>c_type-event
        OR zif_bdt_explorer_types=>c_type-event_fm.
        " Like BUSVIEWS: selection by OBJCN, the application object is passed via memory
        lv_cluster = 'BUPATBZ1AR'.
        lt_base = COND #( WHEN is_node-objap = 'BUPR'
                          THEN VALUE #( ( viewfield = 'OBJCN' operator = 'NE' value = 'BUPA' ) )
                          ELSE VALUE #( ( viewfield = 'OBJCN' operator = 'EQ' value = 'BUSS' ) ) ).
        lv_objap = is_node-objap.
        EXPORT lv_objap = lv_objap TO MEMORY ID 'BUPA_TBZ1F_OBJAP'.
        lt_keys = VALUE #( ( viewfield = 'ZTPKT' operator = 'EQ' value = is_node-ztpkt ) ).
      WHEN zif_bdt_explorer_types=>c_type-table.
        lv_view = 'V_TBZ1H'.
        lt_keys = VALUE #( ( viewfield = 'TABNM' operator = 'EQ' value = is_node-tabnm ) ).
      WHEN zif_bdt_explorer_types=>c_type-data_set.
        lv_view = 'V_TBZ0Q'.
        lt_keys = VALUE #( ( viewfield = 'SETID' operator = 'EQ' value = is_node-setid ) ).
      WHEN zif_bdt_explorer_types=>c_type-activity
        OR zif_bdt_explorer_types=>c_type-field_status.
        lv_view = 'V_TBZ0O_2'.
        lt_keys = VALUE #( ( viewfield = 'ACTION' operator = 'EQ' value = is_node-action ) ).
      WHEN OTHERS.
        RETURN.
    ENDCASE.

    IF lv_positioned = abap_false.
      CLEAR lt_keys.
    ENDIF.

    " The view field names are not known for every maintenance: fall back to OBJAP/OBJCN only
    IF call_maintenance( iv_cluster = lv_cluster
                         iv_view    = lv_view
                         it_sellist = VALUE #( BASE lt_base ( LINES OF lt_keys ) ) ) = abap_true
       AND lt_keys IS NOT INITIAL.
      call_maintenance( iv_cluster = lv_cluster
                        iv_view    = lv_view
                        it_sellist = lt_base ).
    ENDIF.
  ENDMETHOD.


  METHOD call_maintenance.
    DATA(lt_sellist) = it_sellist.
    LOOP AT lt_sellist ASSIGNING FIELD-SYMBOL(<ls_sel>).
      IF sy-tabix < lines( lt_sellist ).
        <ls_sel>-and_or = 'AND'.
      ENDIF.
    ENDLOOP.

    IF iv_cluster IS NOT INITIAL.
      CALL FUNCTION 'VIEWCLUSTER_MAINTENANCE_CALL'
        EXPORTING
          viewcluster_name             = iv_cluster
          start_object                 = iv_start
          maintenance_action           = 'U'
          no_warning_for_clientindep   = abap_true
        TABLES
          dba_sellist                  = lt_sellist
        EXCEPTIONS
          unknown_field_in_dba_sellist = 1
          OTHERS                       = 2.
    ELSE.
      CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
        EXPORTING
          action                       = 'U'
          view_name                    = iv_view
        TABLES
          dba_sellist                  = lt_sellist
        EXCEPTIONS
          unknown_field_in_dba_sellist = 1
          OTHERS                       = 2.
    ENDIF.

    CASE sy-subrc.
      WHEN 0.
      WHEN 1.
        rv_unknown_field = abap_true.
      WHEN OTHERS.
        IF sy-msgid IS NOT INITIAL.
          MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE 'E'.
        ELSE.
          MESSAGE |Maintenance { iv_cluster }{ iv_view } could not be opened| TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD search.
    DATA lt_fields TYPE STANDARD TABLE OF sval.
    DATA lv_returncode TYPE c LENGTH 1.

    lt_fields = VALUE #(
      ( tabname = 'TBZ3R' fieldname = 'FLDNM' fieldtext = 'Field name' )
      ( tabname = 'TBZ3R' fieldname = 'TABNM' fieldtext = 'Structure (screen)' )
      ( tabname = 'TBZ1F' fieldname = 'FNAME' fieldtext = 'Function module' )
      ( tabname = 'TBZ3E' fieldname = 'PRGNM' fieldtext = 'Program' )
      ( tabname = 'TBZ3E' fieldname = 'DYNNR' fieldtext = 'Screen number' )
      ( tabname = 'TBZ3W' fieldname = 'FLDGR' fieldtext = 'Field group' ) ).

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title     = 'BDT where-used search (* = wildcard)'
      IMPORTING
        returncode      = lv_returncode
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    IF sy-subrc <> 0 OR lv_returncode = 'A'.
      RETURN.
    ENDIF.

    DATA(lv_field)    = CONV string( lt_fields[ fieldname = 'FLDNM' ]-value ).
    DATA(lv_struc)    = CONV string( lt_fields[ fieldname = 'TABNM' ]-value ).
    DATA(lv_function) = CONV string( lt_fields[ fieldname = 'FNAME' ]-value ).
    DATA(lv_program)  = CONV string( lt_fields[ fieldname = 'PRGNM' ]-value ).
    DATA(lv_dynnr)    = CONV string( lt_fields[ fieldname = 'DYNNR' ]-value ).
    DATA(lv_fldgr)    = CONV bu_fldgr( lt_fields[ fieldname = 'FLDGR' ]-value ).

    DATA(lv_criteria) = condense( |{ lv_struc }{ COND #( WHEN lv_struc IS NOT INITIAL THEN `-` ) }{ lv_field } | &&
                                  |{ lv_function } { lv_program } { lv_dynnr } | &&
                                  |{ COND #( WHEN lv_fldgr IS NOT INITIAL THEN |FG { lv_fldgr }| ) }| ).
    IF lv_criteria IS INITIAL.
      MESSAGE 'Enter at least one search criterion' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(lt_hits) = mo_model->search( iv_field     = lv_field
                                      iv_structure = lv_struc
                                      iv_function  = lv_function
                                      iv_program   = lv_program
                                      iv_dynnr     = lv_dynnr
                                      iv_fldgr     = lv_fldgr ).

    DATA(lv_key) = add_node( is_node   = VALUE #( type     = zif_bdt_explorer_types=>c_type-search
                                                  objap    = mo_model->get_objap( )
                                                  key_text = |Where-used: { lv_criteria }|
                                                  info     = |{ lines( lt_hits ) } hits| )
                             iv_loaded = abap_true ).
    APPEND lv_key TO mt_top.
    add_nodes( iv_parent = lv_key it_nodes = lt_hits ).
    expand_node( lv_key ).
  ENDMETHOD.


  METHOD transport.
    DATA lv_answer TYPE c LENGTH 1.
    DATA lt_preview TYPE tt_preview.

    DATA(lt_selected) = mo_tree->get_selections( )->get_selected_nodes( ).
    IF lt_selected IS INITIAL.
      MESSAGE 'Select one or more nodes first' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Transport BDT entries'
        text_question         = 'Include all dependent entries below the selected nodes?'
        text_button_1         = 'With dependents'
        text_button_2         = 'Selected only'
        display_cancel_button = abap_true
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        OTHERS                = 1.
    IF sy-subrc <> 0 OR lv_answer = 'A'.
      RETURN.
    ENDIF.

    DATA(lo_transport) = NEW zcl_bdt_explorer_transport( mo_model ).
    DATA(lv_cascade) = xsdbool( lv_answer = '1' ).

    LOOP AT lt_selected INTO DATA(ls_selected).
      READ TABLE mt_map INTO DATA(ls_map) WITH TABLE KEY node_key = ls_selected-key.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF ls_map-node-type = zif_bdt_explorer_types=>c_type-search.
        " A search result stands for all of its hits
        TRY.
            DATA(lt_children) = ls_selected-node->get_children( ).
          CATCH cx_salv_msg.
            CLEAR lt_children.
        ENDTRY.
        LOOP AT lt_children INTO DATA(ls_child).
          READ TABLE mt_map INTO DATA(ls_child_map) WITH TABLE KEY node_key = ls_child-key.
          IF sy-subrc = 0.
            lo_transport->add_node( is_node = ls_child_map-node iv_cascade = lv_cascade ).
          ENDIF.
        ENDLOOP.
      ELSE.
        lo_transport->add_node( is_node = ls_map-node iv_cascade = lv_cascade ).
      ENDIF.
    ENDLOOP.

    DATA(lt_keys) = lo_transport->get_keys( ).
    IF lt_keys IS INITIAL.
      MESSAGE 'No table entries found for the selection' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " Preview of the collected keys
    lt_preview = VALUE #( FOR ls_key IN lt_keys ( objname = ls_key-objname tabkey = ls_key-tabkey ) ).
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_preview)
                                CHANGING  t_table      = lt_preview ).
        lo_preview->set_screen_popup( start_column = 10 end_column = 140 start_line = 3 end_line = 25 ).
        lo_preview->get_columns( )->set_optimize( abap_true ).
        lo_preview->get_display_settings( )->set_list_header( |{ lines( lt_preview ) } table keys collected| ).
        lo_preview->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Transport BDT entries'
        text_question         = |Write { lines( lt_keys ) } table keys into a customizing request?|
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        OTHERS                = 1.
    IF sy-subrc <> 0 OR lv_answer <> '1'.
      RETURN.
    ENDIF.

    lo_transport->write_to_request( IMPORTING ev_order   = DATA(lv_order)
                                              ev_message = DATA(lv_message) ).
    IF lv_order IS INITIAL.
      MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE lv_message TYPE 'S'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
