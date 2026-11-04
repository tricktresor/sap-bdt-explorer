"! Collects the TBZ* entries behind selected explorer nodes (optionally with
"! everything below them) and writes them as table keys into a customizing request.
CLASS zcl_bdt_explorer_transport DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_node TYPE zif_bdt_explorer_types=>ty_node.
    TYPES tt_e071 TYPE STANDARD TABLE OF e071 WITH DEFAULT KEY.
    TYPES tt_e071k TYPE STANDARD TABLE OF e071k WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING io_model TYPE REF TO zcl_bdt_explorer_model.

    "! @parameter iv_cascade | also collect all entries below the node
    METHODS add_node
      IMPORTING
        is_node    TYPE ty_node
        iv_cascade TYPE abap_bool DEFAULT abap_true.

    METHODS get_conditions
      RETURNING VALUE(rt_cond) TYPE zif_bdt_explorer_types=>tt_tab_cond.

    "! Reads the entries for all collected conditions and builds the table keys
    METHODS get_keys
      RETURNING VALUE(rt_e071k) TYPE tt_e071k.

    METHODS get_log
      RETURNING VALUE(rt_log) TYPE string_table.

    "! Asks for a customizing request and appends the keys to its task
    METHODS write_to_request
      EXPORTING
        ev_order   TYPE trkorr
        ev_message TYPE string.

  PRIVATE SECTION.
    CONSTANTS c_tables_of_object TYPE string
      VALUE `TBZ1 TBZ1T TBZ0A TBZ0B TBZ1F TBZ1H TBZ1C TBZ0Q TBZ0R TBZ0O TBZ3 TBZ3T TBZ3K TBZ3A TBZ3B TBZ3I TBZ3C TBZ3D TBZ3H TBZ3E TBZ3F TBZ3S TBZ3W TBZ3X TBZ3R TBZ4A` ##NO_TEXT.

    DATA mo_model TYPE REF TO zcl_bdt_explorer_model.
    DATA mt_cond TYPE zif_bdt_explorer_types=>tt_tab_cond.
    DATA mt_visited TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA mt_e071k TYPE tt_e071k.
    DATA mt_log TYPE string_table.
    DATA mv_keys_built TYPE abap_bool.

    METHODS node_conditions
      IMPORTING
        is_node    TYPE ty_node
        iv_cascade TYPE abap_bool.

    "! Grouping nodes have no entries of their own: their children are always collected
    METHODS is_grouping
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rv_group) TYPE abap_bool.

    METHODS add_cond
      IMPORTING
        iv_tabname TYPE tabname
        iv_where   TYPE string.

    METHODS build_keys.

    METHODS get_key_fields
      IMPORTING iv_tabname       TYPE tabname
      RETURNING VALUE(rt_fields) TYPE string_table.

    CLASS-METHODS build_tabkey
      IMPORTING
        is_row           TYPE any
        it_key_fields    TYPE string_table
      RETURNING
        VALUE(rv_tabkey) TYPE trobj_name.

    CLASS-METHODS eq
      IMPORTING
        iv_field       TYPE string
        iv_value       TYPE csequence
      RETURNING
        VALUE(rv_cond) TYPE string.
ENDCLASS.



CLASS zcl_bdt_explorer_transport IMPLEMENTATION.

  METHOD constructor.
    mo_model = io_model.
  ENDMETHOD.


  METHOD add_node.
    DATA(lv_id) = |{ is_node-type }/{ is_node-folder }/{ is_node-up }/{ is_node-objap }/{ is_node-appli }/{ is_node-varnr }/| &&
                  |{ is_node-dynid }/{ is_node-absnr }/{ is_node-sicht }/{ is_node-fldgr }/{ is_node-tabnm }/| &&
                  |{ is_node-fldnm }/{ is_node-ztpkt }/{ is_node-fname }/{ is_node-action }/{ is_node-setid }/{ iv_cascade }|.
    INSERT lv_id INTO TABLE mt_visited.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    mv_keys_built = abap_false.

    node_conditions( is_node = is_node iv_cascade = iv_cascade ).

    " The whole object without application filter is collected by OBJAP directly
    IF is_node-type = zif_bdt_explorer_types=>c_type-object AND mo_model->get_appli_filter( ) IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_cascade = abap_true OR is_grouping( is_node ) = abap_true.
      DATA(ls_down) = is_node.
      ls_down-up = abap_false.
      LOOP AT mo_model->get_children( ls_down ) INTO DATA(ls_child).
        " Field status lives in one TBZ0O entry for all field groups: only on explicit selection
        IF ls_child-type = zif_bdt_explorer_types=>c_type-field_status.
          CONTINUE.
        ENDIF.
        add_node( is_node = ls_child iv_cascade = iv_cascade ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD is_grouping.
    rv_group = xsdbool( is_node-type = zif_bdt_explorer_types=>c_type-folder
                     OR is_node-type = zif_bdt_explorer_types=>c_type-event ).
  ENDMETHOD.


  METHOD node_conditions.
    DATA(lv_objap) = eq( iv_field = `OBJAP` iv_value = is_node-objap ).

    CASE is_node-type.
      WHEN zif_bdt_explorer_types=>c_type-object.
        IF iv_cascade = abap_true AND mo_model->get_appli_filter( ) IS INITIAL.
          SPLIT c_tables_of_object AT space INTO TABLE DATA(lt_tables).
          LOOP AT lt_tables INTO DATA(lv_table).
            add_cond( iv_tabname = CONV #( lv_table ) iv_where = lv_objap ).
          ENDLOOP.
        ELSE.
          add_cond( iv_tabname = 'TBZ1'  iv_where = lv_objap ).
          add_cond( iv_tabname = 'TBZ1T' iv_where = lv_objap ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-application.
        DATA(lv_appli) = |{ lv_objap } AND { eq( iv_field = `APPLI` iv_value = is_node-appli ) }|.
        add_cond( iv_tabname = 'TBZ0A' iv_where = lv_appli ).
        add_cond( iv_tabname = 'TBZ0B' iv_where = lv_appli ).

      WHEN zif_bdt_explorer_types=>c_type-sequence.
        DATA(lv_varnr) = |{ lv_objap } AND { eq( iv_field = `VARNR` iv_value = is_node-varnr ) }|.
        add_cond( iv_tabname = 'TBZ3'  iv_where = lv_varnr ).
        add_cond( iv_tabname = 'TBZ3T' iv_where = lv_varnr ).
        IF is_node-dynid IS NOT INITIAL.
          add_cond( iv_tabname = 'TBZ3K'
                    iv_where   = |{ lv_varnr } AND { eq( iv_field = `DYNID` iv_value = is_node-dynid ) }| ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-screen.
        DATA(lv_dynid) = |{ lv_objap } AND { eq( iv_field = `DYNID` iv_value = is_node-dynid ) }|.
        add_cond( iv_tabname = 'TBZ3A' iv_where = lv_dynid ).
        add_cond( iv_tabname = 'TBZ3B' iv_where = lv_dynid ).
        IF is_node-varnr IS NOT INITIAL.
          add_cond( iv_tabname = 'TBZ3K'
                    iv_where   = |{ lv_dynid } AND { eq( iv_field = `VARNR` iv_value = is_node-varnr ) }| ).
        ENDIF.
        IF is_node-absnr IS NOT INITIAL.
          add_cond( iv_tabname = 'TBZ3I'
                    iv_where   = |{ lv_dynid } AND { eq( iv_field = `ABSNR` iv_value = is_node-absnr ) }| ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-section.
        DATA(lv_absnr) = |{ lv_objap } AND { eq( iv_field = `ABSNR` iv_value = is_node-absnr ) }|.
        add_cond( iv_tabname = 'TBZ3C' iv_where = lv_absnr ).
        add_cond( iv_tabname = 'TBZ3D' iv_where = lv_absnr ).
        IF is_node-dynid IS NOT INITIAL.
          add_cond( iv_tabname = 'TBZ3I'
                    iv_where   = |{ lv_absnr } AND { eq( iv_field = `DYNID` iv_value = is_node-dynid ) }| ).
        ENDIF.
        IF is_node-sicht IS NOT INITIAL.
          add_cond( iv_tabname = 'TBZ3H'
                    iv_where   = |{ lv_absnr } AND { eq( iv_field = `SICHT` iv_value = is_node-sicht ) }| ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-view.
        DATA(lv_sicht) = |{ lv_objap } AND { eq( iv_field = `SICHT` iv_value = is_node-sicht ) }|.
        add_cond( iv_tabname = 'TBZ3E' iv_where = lv_sicht ).
        add_cond( iv_tabname = 'TBZ3F' iv_where = lv_sicht ).
        add_cond( iv_tabname = 'TBZ4A' iv_where = lv_sicht ).
        IF is_node-absnr IS NOT INITIAL.
          add_cond( iv_tabname = 'TBZ3H'
                    iv_where   = |{ lv_sicht } AND { eq( iv_field = `ABSNR` iv_value = is_node-absnr ) }| ).
        ENDIF.
        IF is_node-fldgr IS NOT INITIAL.
          add_cond( iv_tabname = 'TBZ3S'
                    iv_where   = |{ lv_sicht } AND { eq( iv_field = `FLDGR` iv_value = is_node-fldgr ) }| ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-field_group.
        DATA(lv_fldgr) = |{ lv_objap } AND { eq( iv_field = `FLDGR` iv_value = is_node-fldgr ) }|.
        add_cond( iv_tabname = 'TBZ3W' iv_where = lv_fldgr ).
        add_cond( iv_tabname = 'TBZ3X' iv_where = lv_fldgr ).
        IF is_node-sicht IS NOT INITIAL.
          add_cond( iv_tabname = 'TBZ3S'
                    iv_where   = |{ lv_fldgr } AND { eq( iv_field = `SICHT` iv_value = is_node-sicht ) }| ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-field.
        add_cond( iv_tabname = 'TBZ3R'
                  iv_where   = |{ lv_objap } AND { eq( iv_field = `FLDGR` iv_value = is_node-fldgr ) }| &&
                               | AND { eq( iv_field = `TABNM` iv_value = is_node-tabnm ) }| &&
                               | AND { eq( iv_field = `FLDNM` iv_value = is_node-fldnm ) }| ).
        add_cond( iv_tabname = 'TBZ1C'
                  iv_where   = |{ lv_objap } AND { eq( iv_field = `DYNPTABNM` iv_value = is_node-tabnm ) }| &&
                               | AND { eq( iv_field = `DYNPFLDNM` iv_value = is_node-fldnm ) }| ).

      WHEN zif_bdt_explorer_types=>c_type-field_status
        OR zif_bdt_explorer_types=>c_type-activity.
        add_cond( iv_tabname = 'TBZ0O'
                  iv_where   = |{ lv_objap } AND { eq( iv_field = `ACTION` iv_value = is_node-action ) }| ).

      WHEN zif_bdt_explorer_types=>c_type-event_fm.
        add_cond( iv_tabname = 'TBZ1F'
                  iv_where   = |{ lv_objap } AND { eq( iv_field = `ZTPKT` iv_value = is_node-ztpkt ) }| &&
                               | AND { eq( iv_field = `FNAME` iv_value = is_node-fname ) }| &&
                               | AND { eq( iv_field = `APPLI` iv_value = is_node-appli ) }| ).

      WHEN zif_bdt_explorer_types=>c_type-table.
        add_cond( iv_tabname = 'TBZ1H'
                  iv_where   = |{ lv_objap } AND { eq( iv_field = `TABNM` iv_value = is_node-tabnm ) }| ).

      WHEN zif_bdt_explorer_types=>c_type-data_set.
        DATA(lv_setid) = |{ lv_objap } AND { eq( iv_field = `SETID` iv_value = is_node-setid ) }|.
        add_cond( iv_tabname = 'TBZ0Q' iv_where = lv_setid ).
        add_cond( iv_tabname = 'TBZ0R' iv_where = lv_setid ).
    ENDCASE.
  ENDMETHOD.


  METHOD add_cond.
    READ TABLE mt_cond TRANSPORTING NO FIELDS WITH KEY tabname = iv_tabname sql_where = iv_where.
    IF sy-subrc <> 0.
      APPEND VALUE #( tabname = iv_tabname sql_where = iv_where ) TO mt_cond.
    ENDIF.
  ENDMETHOD.


  METHOD get_conditions.
    rt_cond = mt_cond.
  ENDMETHOD.


  METHOD get_keys.
    build_keys( ).
    rt_e071k = mt_e071k.
  ENDMETHOD.


  METHOD get_log.
    build_keys( ).
    rt_log = mt_log.
  ENDMETHOD.


  METHOD build_keys.
    DATA lr_table TYPE REF TO data.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    IF mv_keys_built = abap_true.
      RETURN.
    ENDIF.
    CLEAR: mt_e071k, mt_log.

    LOOP AT mt_cond INTO DATA(ls_cond).
      CREATE DATA lr_table TYPE STANDARD TABLE OF (ls_cond-tabname).
      ASSIGN lr_table->* TO <lt_rows>.

      TRY.
          SELECT * FROM (ls_cond-tabname)
            INTO TABLE @<lt_rows>
            WHERE (ls_cond-sql_where).
        CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
          APPEND |{ ls_cond-tabname }: { lx_sql->get_text( ) }| TO mt_log.
          CONTINUE.
      ENDTRY.

      APPEND |{ ls_cond-tabname } { ls_cond-sql_where }: { lines( <lt_rows> ) } entries| TO mt_log.
      DATA(lt_key_fields) = get_key_fields( ls_cond-tabname ).

      LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
        APPEND VALUE #( pgmid      = 'R3TR'
                        object     = 'TABU'
                        objname    = ls_cond-tabname
                        mastertype = 'TABU'
                        mastername = ls_cond-tabname
                        tabkey     = build_tabkey( is_row = <ls_row> it_key_fields = lt_key_fields ) )
          TO mt_e071k.
      ENDLOOP.
    ENDLOOP.

    SORT mt_e071k BY objname tabkey.
    DELETE ADJACENT DUPLICATES FROM mt_e071k COMPARING objname tabkey.
    mv_keys_built = abap_true.
  ENDMETHOD.


  METHOD get_key_fields.
    DATA lt_fields TYPE STANDARD TABLE OF fieldname WITH EMPTY KEY.

    SELECT fieldname FROM dd03l
      INTO TABLE @lt_fields
      WHERE tabname  = @iv_tabname
        AND as4local = 'A'
        AND keyflag  = @abap_true
        AND fieldname NOT LIKE '.%'
      ORDER BY position.
    rt_fields = VALUE #( FOR lv_field IN lt_fields ( CONV #( lv_field ) ) ).
  ENDMETHOD.


  METHOD build_tabkey.
    DATA lv_length TYPE i.
    DATA lv_offset TYPE i.

    LOOP AT it_key_fields INTO DATA(lv_field).
      ASSIGN COMPONENT lv_field OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_value>).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      DESCRIBE FIELD <lv_value> LENGTH lv_length IN CHARACTER MODE.
      IF lv_offset + lv_length > 120.
        " Key longer than E071K-TABKEY: transport generically from here on
        rv_tabkey+lv_offset = '*'.
        RETURN.
      ENDIF.
      rv_tabkey+lv_offset(lv_length) = <lv_value>.
      lv_offset = lv_offset + lv_length.
    ENDLOOP.
  ENDMETHOD.


  METHOD write_to_request.
    DATA lt_e071 TYPE tt_e071.
    DATA lv_task TYPE trkorr.

    CLEAR: ev_order, ev_message.
    DATA(lt_e071k) = get_keys( ).
    IF lt_e071k IS INITIAL.
      ev_message = `No entries collected`.
      RETURN.
    ENDIF.

    LOOP AT lt_e071k INTO DATA(ls_e071k).
      READ TABLE lt_e071 TRANSPORTING NO FIELDS WITH KEY obj_name = ls_e071k-objname.
      IF sy-subrc <> 0.
        APPEND VALUE #( pgmid    = 'R3TR'
                        object   = 'TABU'
                        obj_name = ls_e071k-objname
                        objfunc  = 'K' ) TO lt_e071.
      ENDIF.
    ENDLOOP.

    CALL FUNCTION 'TR_ORDER_CHOICE_CORRECTION'
      EXPORTING
        iv_category            = 'CUST'
      IMPORTING
        ev_order               = ev_order
        ev_task                = lv_task
      EXCEPTIONS
        invalid_category       = 1
        no_correction_selected = 2
        OTHERS                 = 3.
    IF sy-subrc <> 0.
      CLEAR ev_order.
      ev_message = `No request selected`.
      RETURN.
    ENDIF.

    CALL FUNCTION 'TR_APPEND_TO_COMM_OBJS_KEYS'
      EXPORTING
        wi_trkorr = lv_task
      TABLES
        wt_e071   = lt_e071
        wt_e071k  = lt_e071k
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ev_message.
      CLEAR ev_order.
      RETURN.
    ENDIF.

    ev_message = |{ lines( lt_e071k ) } keys of { lines( lt_e071 ) } tables written to { ev_order }/{ lv_task }|.
  ENDMETHOD.


  METHOD eq.
    rv_cond = |{ iv_field } = { cl_abap_dyn_prg=>quote( condense( iv_value ) ) }|.
  ENDMETHOD.

ENDCLASS.
