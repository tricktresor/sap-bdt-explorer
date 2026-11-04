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
        refresh   TYPE salv_de_function VALUE 'ZREFRESH',
      END OF c_function.

    TYPES:
      BEGIN OF ty_map,
        node_key TYPE salv_de_node_key,
        node     TYPE ty_node,
      END OF ty_map.

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
    DATA mv_displayed TYPE abap_bool.

    METHODS setup_columns.
    METHODS setup_functions.

    METHODS add_node
      IMPORTING
        iv_parent     TYPE salv_de_node_key OPTIONAL
        is_node       TYPE ty_node
      RETURNING
        VALUE(rv_key) TYPE salv_de_node_key.

    METHODS add_nodes
      IMPORTING
        iv_parent TYPE salv_de_node_key
        it_nodes  TYPE tt_node.

    METHODS expand_node
      IMPORTING iv_key TYPE salv_de_node_key.

    METHODS search.
    METHODS transport.
    METHODS navigate
      IMPORTING is_node TYPE ty_node.

    METHODS on_expand_empty_folder FOR EVENT expand_empty_folder OF cl_salv_events_tree
      IMPORTING node_key.
    METHODS on_double_click FOR EVENT double_click OF cl_salv_events_tree
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
        lo_functions->add_function( name     = c_function-refresh
                                    icon     = CONV #( icon_refresh )
                                    text     = ''
                                    tooltip  = 'Reload'
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
    CLEAR mt_map.

    DATA(ls_root) = mo_model->get_root( ).
    DATA(lv_root) = add_node( is_node = ls_root ).
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
      ELSE |{ zcl_bdt_explorer_model=>get_type_text( is_node-type ) } { is_node-key_text }| ).
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

    rv_key = lo_node->get_key( ).
    INSERT VALUE #( node_key = rv_key node = is_node ) INTO TABLE mt_map.
  ENDMETHOD.


  METHOD add_nodes.
    LOOP AT it_nodes INTO DATA(ls_node).
      add_node( iv_parent = iv_parent is_node = ls_node ).
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

    DATA(lt_nodes) = mo_model->expand( ls_map-node ).
    IF lt_nodes IS INITIAL.
      MESSAGE 'No entries found' TYPE 'S'.
      RETURN.
    ENDIF.
    add_nodes( iv_parent = node_key it_nodes = lt_nodes ).
    expand_node( node_key ).
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
      WHEN c_function-refresh.
        display( mo_model ).
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

    DATA(lv_key) = add_node( is_node = VALUE #( type     = zif_bdt_explorer_types=>c_type-search
                                                objap    = mo_model->get_objap( )
                                                key_text = |Where-used: { lv_criteria }|
                                                info     = |{ lines( lt_hits ) } hits| ) ).
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
