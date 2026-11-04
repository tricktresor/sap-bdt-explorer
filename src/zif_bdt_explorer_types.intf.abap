INTERFACE zif_bdt_explorer_types
  PUBLIC.

  TYPES ty_node_type TYPE c LENGTH 4.
  TYPES ty_folder TYPE c LENGTH 4.

  "! Node types of the BDT hierarchy
  CONSTANTS:
    BEGIN OF c_type,
      object       TYPE ty_node_type VALUE 'OBJ',  " TBZ1  application object
      folder       TYPE ty_node_type VALUE 'FOLD', " grouping node
      application  TYPE ty_node_type VALUE 'APP',  " TBZ0A application
      sequence     TYPE ty_node_type VALUE 'SEQ',  " TBZ3  screen sequence
      screen       TYPE ty_node_type VALUE 'SCR',  " TBZ3A screen
      section      TYPE ty_node_type VALUE 'SEC',  " TBZ3C section
      view         TYPE ty_node_type VALUE 'VIEW', " TBZ3E view
      field_group  TYPE ty_node_type VALUE 'FG',   " TBZ3W field group
      field        TYPE ty_node_type VALUE 'FLD',  " TBZ3R field
      field_status TYPE ty_node_type VALUE 'FST',  " TBZ0O field status per activity
      event        TYPE ty_node_type VALUE 'EVT',  " TBZ1F event
      event_fm     TYPE ty_node_type VALUE 'EFM',  " TBZ1F function module of an event
      table        TYPE ty_node_type VALUE 'TAB',  " TBZ1H table
      data_set     TYPE ty_node_type VALUE 'SET',  " TBZ0Q data set
      object_part  TYPE ty_node_type VALUE 'OBP',  " TBZ0  object part (e.g. BP role category)
      activity     TYPE ty_node_type VALUE 'ACT',  " TBZ0O activity
      search       TYPE ty_node_type VALUE 'SRCH', " search result root
    END OF c_type.

  CONSTANTS:
    BEGIN OF c_folder,
      applications TYPE ty_folder VALUE 'APPS',
      sequences    TYPE ty_folder VALUE 'SEQS',
      events       TYPE ty_folder VALUE 'EVTS',
      tables       TYPE ty_folder VALUE 'TABS',
      data_sets    TYPE ty_folder VALUE 'SETS',
      activities   TYPE ty_folder VALUE 'ACTS',
    END OF c_folder.

  "! A node carries its own key plus the key of the neighbour it was reached from.
  "! Going down the hierarchy the parent keys are filled, going up (where-used)
  "! the child keys are filled. The transport uses the neighbour key to include
  "! the assignment entry (TBZ3K, TBZ3I, TBZ3H, TBZ3S) between both nodes.
  TYPES:
    BEGIN OF ty_node,
      type       TYPE ty_node_type,
      folder     TYPE ty_folder,
      up         TYPE abap_bool,
      expandable TYPE abap_bool,
      objap      TYPE bu_objap,
      appli      TYPE bu_appli,
      varnr      TYPE bu_varnr,
      dynid      TYPE bu_dynid,
      absnr      TYPE bu_absnr,
      sicht      TYPE bu_sicht,
      fldgr      TYPE bu_fldgr,
      tabnm      TYPE tabname,
      fldnm      TYPE fieldname,
      ztpkt      TYPE bu_ztpkt,
      fname      TYPE rs38l_fnam,
      action     TYPE bu_action_tbz0m,
      setid      TYPE bu_setid,
      rltyp      TYPE bu_rltyp,
      prgnm      TYPE progname,
      dynnr      TYPE dynnr,
      key_text   TYPE string,
      text       TYPE string,
      info       TYPE string,
    END OF ty_node,
    tt_node TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY.

  TYPES ty_appli_range TYPE RANGE OF bu_appli.

ENDINTERFACE.
