"! Collects the TBZ* entries behind selected explorer nodes (optionally with
"! everything below them) and writes them as table keys into a customizing request.
"! Only the key columns are selected; their flat character-like row is the TABKEY.
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

    TYPES ty_value TYPE c LENGTH 40.
    TYPES ty_range TYPE RANGE OF ty_value.

    "! Restriction for the key selection; an empty range means all values
    TYPES:
      BEGIN OF ty_filter,
        objap  TYPE bu_objap,
        appli  TYPE ty_range,
        varnr  TYPE ty_range,
        dynid  TYPE ty_range,
        absnr  TYPE ty_range,
        sicht  TYPE ty_range,
        fldgr  TYPE ty_range,
        tabnm  TYPE ty_range,
        fldnm  TYPE ty_range,
        ztpkt  TYPE ty_range,
        fname  TYPE ty_range,
        action TYPE ty_range,
        setid  TYPE ty_range,
      END OF ty_filter.

    DATA mo_model TYPE REF TO zcl_bdt_explorer_model.
    DATA mt_visited TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA mt_e071k TYPE tt_e071k.
    DATA mt_log TYPE string_table.

    METHODS collect
      IMPORTING
        is_node    TYPE ty_node
        iv_cascade TYPE abap_bool.

    "! Grouping nodes have no entries of their own: their children are always collected
    METHODS is_grouping
      IMPORTING is_node         TYPE ty_node
      RETURNING VALUE(rv_group) TYPE abap_bool.

    "! @parameter iv_tables | space separated table names
    METHODS read_keys
      IMPORTING
        iv_tables TYPE string
        is_filter TYPE ty_filter.

    METHODS add_keys
      IMPORTING
        iv_tabname TYPE tabname
        it_keys    TYPE ANY TABLE.

    CLASS-METHODS eq
      IMPORTING iv_value        TYPE clike
      RETURNING VALUE(rt_range) TYPE ty_range.
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

    collect( is_node = is_node iv_cascade = iv_cascade ).

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


  METHOD collect.
    DATA(lv_objap) = is_node-objap.

    CASE is_node-type.
      WHEN zif_bdt_explorer_types=>c_type-object.
        IF iv_cascade = abap_true AND mo_model->get_appli_filter( ) IS INITIAL.
          read_keys( iv_tables = c_tables_of_object
                     is_filter = VALUE #( objap = lv_objap ) ).
        ELSE.
          read_keys( iv_tables = `TBZ1 TBZ1T`
                     is_filter = VALUE #( objap = lv_objap ) ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-application.
        read_keys( iv_tables = `TBZ0A TBZ0B`
                   is_filter = VALUE #( objap = lv_objap appli = eq( is_node-appli ) ) ).

      WHEN zif_bdt_explorer_types=>c_type-sequence.
        read_keys( iv_tables = `TBZ3 TBZ3T`
                   is_filter = VALUE #( objap = lv_objap varnr = eq( is_node-varnr ) ) ).
        IF is_node-dynid IS NOT INITIAL.
          read_keys( iv_tables = `TBZ3K`
                     is_filter = VALUE #( objap = lv_objap varnr = eq( is_node-varnr ) dynid = eq( is_node-dynid ) ) ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-screen.
        read_keys( iv_tables = `TBZ3A TBZ3B`
                   is_filter = VALUE #( objap = lv_objap dynid = eq( is_node-dynid ) ) ).
        IF is_node-varnr IS NOT INITIAL.
          read_keys( iv_tables = `TBZ3K`
                     is_filter = VALUE #( objap = lv_objap dynid = eq( is_node-dynid ) varnr = eq( is_node-varnr ) ) ).
        ENDIF.
        IF is_node-absnr IS NOT INITIAL.
          read_keys( iv_tables = `TBZ3I`
                     is_filter = VALUE #( objap = lv_objap dynid = eq( is_node-dynid ) absnr = eq( is_node-absnr ) ) ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-section.
        read_keys( iv_tables = `TBZ3C TBZ3D`
                   is_filter = VALUE #( objap = lv_objap absnr = eq( is_node-absnr ) ) ).
        IF is_node-dynid IS NOT INITIAL.
          read_keys( iv_tables = `TBZ3I`
                     is_filter = VALUE #( objap = lv_objap absnr = eq( is_node-absnr ) dynid = eq( is_node-dynid ) ) ).
        ENDIF.
        IF is_node-sicht IS NOT INITIAL.
          read_keys( iv_tables = `TBZ3H`
                     is_filter = VALUE #( objap = lv_objap absnr = eq( is_node-absnr ) sicht = eq( is_node-sicht ) ) ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-view.
        read_keys( iv_tables = `TBZ3E TBZ3F TBZ4A`
                   is_filter = VALUE #( objap = lv_objap sicht = eq( is_node-sicht ) ) ).
        IF is_node-absnr IS NOT INITIAL.
          read_keys( iv_tables = `TBZ3H`
                     is_filter = VALUE #( objap = lv_objap sicht = eq( is_node-sicht ) absnr = eq( is_node-absnr ) ) ).
        ENDIF.
        IF is_node-fldgr IS NOT INITIAL.
          read_keys( iv_tables = `TBZ3S`
                     is_filter = VALUE #( objap = lv_objap sicht = eq( is_node-sicht ) fldgr = eq( is_node-fldgr ) ) ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-field_group.
        read_keys( iv_tables = `TBZ3W TBZ3X`
                   is_filter = VALUE #( objap = lv_objap fldgr = eq( is_node-fldgr ) ) ).
        IF is_node-sicht IS NOT INITIAL.
          read_keys( iv_tables = `TBZ3S`
                     is_filter = VALUE #( objap = lv_objap fldgr = eq( is_node-fldgr ) sicht = eq( is_node-sicht ) ) ).
        ENDIF.

      WHEN zif_bdt_explorer_types=>c_type-field.
        read_keys( iv_tables = `TBZ3R`
                   is_filter = VALUE #( objap = lv_objap
                                        fldgr = eq( is_node-fldgr )
                                        tabnm = eq( is_node-tabnm )
                                        fldnm = eq( is_node-fldnm ) ) ).
        read_keys( iv_tables = `TBZ1C`
                   is_filter = VALUE #( objap = lv_objap
                                        tabnm = eq( is_node-tabnm )
                                        fldnm = eq( is_node-fldnm ) ) ).

      WHEN zif_bdt_explorer_types=>c_type-field_status
        OR zif_bdt_explorer_types=>c_type-activity.
        read_keys( iv_tables = `TBZ0O`
                   is_filter = VALUE #( objap = lv_objap action = eq( is_node-action ) ) ).

      WHEN zif_bdt_explorer_types=>c_type-event_fm.
        read_keys( iv_tables = `TBZ1F`
                   is_filter = VALUE #( objap = lv_objap
                                        ztpkt = eq( is_node-ztpkt )
                                        fname = eq( is_node-fname )
                                        appli = eq( is_node-appli ) ) ).

      WHEN zif_bdt_explorer_types=>c_type-table.
        read_keys( iv_tables = `TBZ1H`
                   is_filter = VALUE #( objap = lv_objap tabnm = eq( is_node-tabnm ) ) ).

      WHEN zif_bdt_explorer_types=>c_type-data_set.
        read_keys( iv_tables = `TBZ0Q TBZ0R`
                   is_filter = VALUE #( objap = lv_objap setid = eq( is_node-setid ) ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD read_keys.
    SPLIT iv_tables AT space INTO TABLE DATA(lt_tables).

    LOOP AT lt_tables INTO DATA(lv_table).
      CASE lv_table.
        WHEN `TBZ1`.
          SELECT client, objap FROM tbz1 INTO TABLE @DATA(lt_tbz1)
            WHERE objap = @is_filter-objap.
          add_keys( iv_tabname = 'TBZ1' it_keys = lt_tbz1 ).

        WHEN `TBZ1T`.
          SELECT client, spras, objap FROM tbz1t INTO TABLE @DATA(lt_tbz1t)
            WHERE objap = @is_filter-objap.
          add_keys( iv_tabname = 'TBZ1T' it_keys = lt_tbz1t ).

        WHEN `TBZ0A`.
          SELECT client, objap, appli FROM tbz0a INTO TABLE @DATA(lt_tbz0a)
            WHERE objap = @is_filter-objap
              AND appli IN @is_filter-appli.
          add_keys( iv_tabname = 'TBZ0A' it_keys = lt_tbz0a ).

        WHEN `TBZ0B`.
          SELECT client, spras, objap, appli FROM tbz0b INTO TABLE @DATA(lt_tbz0b)
            WHERE objap = @is_filter-objap
              AND appli IN @is_filter-appli.
          add_keys( iv_tabname = 'TBZ0B' it_keys = lt_tbz0b ).

        WHEN `TBZ1F`.
          SELECT client, objcn, ztpkt, objap, posnr FROM tbz1f INTO TABLE @DATA(lt_tbz1f)
            WHERE objap = @is_filter-objap
              AND ztpkt IN @is_filter-ztpkt
              AND fname IN @is_filter-fname
              AND appli IN @is_filter-appli.
          add_keys( iv_tabname = 'TBZ1F' it_keys = lt_tbz1f ).

        WHEN `TBZ1H`.
          SELECT client, objap, tabnm FROM tbz1h INTO TABLE @DATA(lt_tbz1h)
            WHERE objap = @is_filter-objap
              AND tabnm IN @is_filter-tabnm.
          add_keys( iv_tabname = 'TBZ1H' it_keys = lt_tbz1h ).

        WHEN `TBZ1C`.
          SELECT client, objap, dynptabnm, dynpfldnm FROM tbz1c INTO TABLE @DATA(lt_tbz1c)
            WHERE objap = @is_filter-objap
              AND dynptabnm IN @is_filter-tabnm
              AND dynpfldnm IN @is_filter-fldnm.
          add_keys( iv_tabname = 'TBZ1C' it_keys = lt_tbz1c ).

        WHEN `TBZ0Q`.
          SELECT client, objap, setid FROM tbz0q INTO TABLE @DATA(lt_tbz0q)
            WHERE objap = @is_filter-objap
              AND setid IN @is_filter-setid.
          add_keys( iv_tabname = 'TBZ0Q' it_keys = lt_tbz0q ).

        WHEN `TBZ0R`.
          SELECT client, spras, objap, setid FROM tbz0r INTO TABLE @DATA(lt_tbz0r)
            WHERE objap = @is_filter-objap
              AND setid IN @is_filter-setid.
          add_keys( iv_tabname = 'TBZ0R' it_keys = lt_tbz0r ).

        WHEN `TBZ0O`.
          SELECT client, objap, action FROM tbz0o INTO TABLE @DATA(lt_tbz0o)
            WHERE objap = @is_filter-objap
              AND action IN @is_filter-action.
          add_keys( iv_tabname = 'TBZ0O' it_keys = lt_tbz0o ).

        WHEN `TBZ3`.
          SELECT client, objap, varnr FROM tbz3 INTO TABLE @DATA(lt_tbz3)
            WHERE objap = @is_filter-objap
              AND varnr IN @is_filter-varnr.
          add_keys( iv_tabname = 'TBZ3' it_keys = lt_tbz3 ).

        WHEN `TBZ3T`.
          SELECT client, spras, objap, varnr FROM tbz3t INTO TABLE @DATA(lt_tbz3t)
            WHERE objap = @is_filter-objap
              AND varnr IN @is_filter-varnr.
          add_keys( iv_tabname = 'TBZ3T' it_keys = lt_tbz3t ).

        WHEN `TBZ3K`.
          SELECT client, objap, varnr, posnr FROM tbz3k INTO TABLE @DATA(lt_tbz3k)
            WHERE objap = @is_filter-objap
              AND varnr IN @is_filter-varnr
              AND dynid IN @is_filter-dynid.
          add_keys( iv_tabname = 'TBZ3K' it_keys = lt_tbz3k ).

        WHEN `TBZ3A`.
          SELECT client, objap, dynid FROM tbz3a INTO TABLE @DATA(lt_tbz3a)
            WHERE objap = @is_filter-objap
              AND dynid IN @is_filter-dynid.
          add_keys( iv_tabname = 'TBZ3A' it_keys = lt_tbz3a ).

        WHEN `TBZ3B`.
          SELECT client, spras, objap, dynid FROM tbz3b INTO TABLE @DATA(lt_tbz3b)
            WHERE objap = @is_filter-objap
              AND dynid IN @is_filter-dynid.
          add_keys( iv_tabname = 'TBZ3B' it_keys = lt_tbz3b ).

        WHEN `TBZ3I`.
          SELECT client, objap, dynid, posnr, absnr FROM tbz3i INTO TABLE @DATA(lt_tbz3i)
            WHERE objap = @is_filter-objap
              AND dynid IN @is_filter-dynid
              AND absnr IN @is_filter-absnr.
          add_keys( iv_tabname = 'TBZ3I' it_keys = lt_tbz3i ).

        WHEN `TBZ3C`.
          SELECT client, objap, absnr FROM tbz3c INTO TABLE @DATA(lt_tbz3c)
            WHERE objap = @is_filter-objap
              AND absnr IN @is_filter-absnr.
          add_keys( iv_tabname = 'TBZ3C' it_keys = lt_tbz3c ).

        WHEN `TBZ3D`.
          SELECT client, spras, objap, absnr FROM tbz3d INTO TABLE @DATA(lt_tbz3d)
            WHERE objap = @is_filter-objap
              AND absnr IN @is_filter-absnr.
          add_keys( iv_tabname = 'TBZ3D' it_keys = lt_tbz3d ).

        WHEN `TBZ3H`.
          SELECT client, objap, absnr, posnr FROM tbz3h INTO TABLE @DATA(lt_tbz3h)
            WHERE objap = @is_filter-objap
              AND absnr IN @is_filter-absnr
              AND sicht IN @is_filter-sicht.
          add_keys( iv_tabname = 'TBZ3H' it_keys = lt_tbz3h ).

        WHEN `TBZ3E`.
          SELECT client, objap, sicht FROM tbz3e INTO TABLE @DATA(lt_tbz3e)
            WHERE objap = @is_filter-objap
              AND sicht IN @is_filter-sicht.
          add_keys( iv_tabname = 'TBZ3E' it_keys = lt_tbz3e ).

        WHEN `TBZ3F`.
          SELECT client, spras, objap, sicht FROM tbz3f INTO TABLE @DATA(lt_tbz3f)
            WHERE objap = @is_filter-objap
              AND sicht IN @is_filter-sicht.
          add_keys( iv_tabname = 'TBZ3F' it_keys = lt_tbz3f ).

        WHEN `TBZ3S`.
          SELECT client, objap, sicht, fldgr FROM tbz3s INTO TABLE @DATA(lt_tbz3s)
            WHERE objap = @is_filter-objap
              AND sicht IN @is_filter-sicht
              AND fldgr IN @is_filter-fldgr.
          add_keys( iv_tabname = 'TBZ3S' it_keys = lt_tbz3s ).

        WHEN `TBZ3W`.
          SELECT client, objap, fldgr FROM tbz3w INTO TABLE @DATA(lt_tbz3w)
            WHERE objap = @is_filter-objap
              AND fldgr IN @is_filter-fldgr.
          add_keys( iv_tabname = 'TBZ3W' it_keys = lt_tbz3w ).

        WHEN `TBZ3X`.
          SELECT client, spras, objap, fldgr FROM tbz3x INTO TABLE @DATA(lt_tbz3x)
            WHERE objap = @is_filter-objap
              AND fldgr IN @is_filter-fldgr.
          add_keys( iv_tabname = 'TBZ3X' it_keys = lt_tbz3x ).

        WHEN `TBZ3R`.
          SELECT client, objap, tabnm, fldnm, fldgr FROM tbz3r INTO TABLE @DATA(lt_tbz3r)
            WHERE objap = @is_filter-objap
              AND tabnm IN @is_filter-tabnm
              AND fldnm IN @is_filter-fldnm
              AND fldgr IN @is_filter-fldgr.
          add_keys( iv_tabname = 'TBZ3R' it_keys = lt_tbz3r ).

        WHEN `TBZ4A`.
          SELECT client, objap, fcode, sicht FROM tbz4a INTO TABLE @DATA(lt_tbz4a)
            WHERE objap = @is_filter-objap
              AND sicht IN @is_filter-sicht.
          add_keys( iv_tabname = 'TBZ4A' it_keys = lt_tbz4a ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_keys.
    DATA lv_tabkey TYPE trobj_name.

    APPEND |{ iv_tabname }: { lines( it_keys ) } entries| TO mt_log.

    " Key columns are leading and character-like: the selected row is the table key
    LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      lv_tabkey = <ls_key>.
      APPEND VALUE #( pgmid      = 'R3TR'
                      object     = 'TABU'
                      objname    = iv_tabname
                      mastertype = 'TABU'
                      mastername = iv_tabname
                      tabkey     = lv_tabkey ) TO mt_e071k.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_keys.
    SORT mt_e071k BY objname tabkey.
    DELETE ADJACENT DUPLICATES FROM mt_e071k COMPARING objname tabkey.
    rt_e071k = mt_e071k.
  ENDMETHOD.


  METHOD get_log.
    rt_log = mt_log.
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
    IF iv_value IS NOT INITIAL.
      rt_range = VALUE #( ( sign = 'I' option = 'EQ' low = iv_value ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
