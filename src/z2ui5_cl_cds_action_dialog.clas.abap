CLASS z2ui5_cl_cds_action_dialog DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    METHODS constructor
      IMPORTING
        val   TYPE data
        title TYPE string OPTIONAL.

    DATA ms_cds TYPE REF TO data.
    DATA mv_title TYPE string.
    DATA ms_entity TYPE z2ui5_cl_cds_util=>ty_s_entity_info.

    DATA mv_vh_field TYPE string.
    DATA mt_vh_data TYPE REF TO data.

    METHODS result
      RETURNING
        VALUE(result) TYPE REF TO data.

    METHODS was_confirmed
      RETURNING
        VALUE(result) TYPE abap_bool.

    DATA mv_confirmed TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_event,
        confirm     TYPE string VALUE `CONFIRM`,
        cancel      TYPE string VALUE `CANCEL`,
        value_help  TYPE string VALUE `VALUE_HELP`,
        vh_confirm  TYPE string VALUE `VH_CONFIRM`,
        vh_cancel   TYPE string VALUE `VH_CANCEL`,
      END OF cs_event.

    METHODS apply_default_values.

    METHODS render_action_dialog
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS render_value_help
      IMPORTING
        client     TYPE REF TO z2ui5_if_client
        field_name TYPE string.

    METHODS handle_value_help_confirm
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS get_control_for_field
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_xml_view
        is_field     TYPE z2ui5_cl_cds_util=>ty_s_field_info
        client       TYPE REF TO z2ui5_if_client.

    METHODS load_dropdown_data
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data.

ENDCLASS.



CLASS z2ui5_cl_cds_action_dialog IMPLEMENTATION.

  METHOD constructor.
    CREATE DATA ms_cds LIKE val.
    ms_cds->* = val.
    mv_title = title.
    mv_confirmed = abap_false.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      DATA(lo_datadescr) = cl_abap_datadescr=>describe_by_data( ms_cds->* ).
      DATA(lv_entity_name) = lo_datadescr->get_relative_name( ).
      ms_entity = z2ui5_cl_cds_util=>read_entity( lv_entity_name ).
      IF mv_title IS INITIAL.
        mv_title = ms_entity-name.
      ENDIF.
      apply_default_values( ).
      render_action_dialog( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-confirm ).
      mv_confirmed = abap_true.
      client->popup_destroy( ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-cancel ).
      mv_confirmed = abap_false.
      client->popup_destroy( ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-value_help ).
      DATA(lv_vh_field) = client->get_event_arg( ).
      render_value_help( client = client field_name = lv_vh_field ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-vh_confirm ).
      handle_value_help_confirm( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-vh_cancel ).
      client->popup_destroy( ).
      render_action_dialog( client ).
      RETURN.
    ENDIF.

  ENDMETHOD.


  METHOD apply_default_values.
    LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE default_value IS NOT INITIAL.
      FIELD-SYMBOLS <fld> TYPE any.
      ASSIGN COMPONENT ls_field-name OF STRUCTURE ms_cds->* TO <fld>.
      IF sy-subrc = 0 AND <fld> IS INITIAL.
        <fld> = ls_field-default_value.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_dropdown_data.
    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( entity_name ) ).
        DATA(lo_table_type) = cl_abap_tabledescr=>create( lo_descr ).
        CREATE DATA result TYPE HANDLE lo_table_type.
        FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
        ASSIGN result->* TO <lt_data>.
        SELECT * FROM (entity_name) INTO TABLE @<lt_data> UP TO 500 ROWS.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.


  METHOD render_action_dialog.

    DATA(lo_popup) = z2ui5_cl_xml_view=>factory_popup( ).
    DATA(lo_dialog) = lo_popup->dialog(
      title        = mv_title
      contentwidth = `450px`
      draggable    = abap_true
      resizable    = abap_true ).

    DATA(lo_content) = lo_dialog->content( ).
    DATA(lo_form) = lo_content->simple_form(
      editable = abap_true
      layout   = `ResponsiveGridLayout` )->content( `form` ).

    LOOP AT ms_entity-fields INTO DATA(ls_field).
      IF ls_field-is_hidden = abap_true.
        CONTINUE.
      ENDIF.
      IF ls_field-is_mandatory = abap_true.
        lo_form->label( text = ls_field-label required = abap_true ).
      ELSE.
        lo_form->label( ls_field-label ).
      ENDIF.
      get_control_for_field(
        io_container = lo_form
        is_field     = ls_field
        client       = client ).
    ENDLOOP.

    lo_dialog->begin_button( )->button(
      text  = `OK`
      press = client->_event( cs_event-confirm )
      type  = `Emphasized` ).

    lo_dialog->end_button( )->button(
      text  = `Cancel`
      press = client->_event( cs_event-cancel ) ).

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD get_control_for_field.

    FIELD-SYMBOLS <field> TYPE any.
    ASSIGN COMPONENT is_field-name OF STRUCTURE ms_cds->* TO <field>.

    IF is_field-is_boolean = abap_true.
      io_container->checkbox(
        selected = client->_bind_edit( val = <field> view = z2ui5_if_client=>cs_view-popup )
        text     = `` ).
      RETURN.
    ENDIF.

    IF is_field-type_kind = `DATS`.
      io_container->date_picker(
        value = client->_bind_edit( val = <field> view = z2ui5_if_client=>cs_view-popup ) ).
      RETURN.
    ENDIF.

    IF is_field-type_kind = `TIMS`.
      io_container->time_picker(
        value = client->_bind_edit( val = <field> view = z2ui5_if_client=>cs_view-popup ) ).
      RETURN.
    ENDIF.

    IF is_field-is_multiline = abap_true OR is_field-type_kind = `STRING`.
      io_container->text_area(
        value = client->_bind_edit( val = <field> view = z2ui5_if_client=>cs_view-popup )
        rows  = `3`
        width = `100%` ).
      RETURN.
    ENDIF.

    IF is_field-value_help-is_dropdown = abap_true.
      DATA(lr_dd_data) = load_dropdown_data( is_field-value_help-entity_name ).
      IF lr_dd_data IS BOUND.
        FIELD-SYMBOLS <lt_dd> TYPE STANDARD TABLE.
        ASSIGN lr_dd_data->* TO <lt_dd>.
        DATA(lv_elem_path) = is_field-value_help-element.
        DATA(lv_key_path) = `{` && lv_elem_path && `}`.
        io_container->combobox(
          selectedkey = client->_bind_edit( val = <field> view = z2ui5_if_client=>cs_view-popup )
          items       = client->_bind( <lt_dd> )
        )->item(
          key  = lv_key_path
          text = lv_key_path ).
      ELSE.
        io_container->input( value = client->_bind_edit( val = <field> view = z2ui5_if_client=>cs_view-popup ) ).
      ENDIF.
      RETURN.
    ENDIF.

    IF is_field-value_help-entity_name IS NOT INITIAL.
      io_container->input(
        value           = client->_bind_edit( val = <field> view = z2ui5_if_client=>cs_view-popup )
        showvaluehelp   = abap_true
        valuehelprequest = client->_event(
          val   = cs_event-value_help
          t_arg = VALUE #( ( is_field-name ) ) ) ).
      RETURN.
    ENDIF.

    io_container->input( value = client->_bind_edit( val = <field> view = z2ui5_if_client=>cs_view-popup ) ).

  ENDMETHOD.


  METHOD render_value_help.

    mv_vh_field = field_name.

    READ TABLE ms_entity-fields INTO DATA(ls_field)
      WITH KEY name = field_name.
    IF sy-subrc <> 0 OR ls_field-value_help-entity_name IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_entity) = ls_field-value_help-entity_name.

    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( lv_entity ) ).
        DATA(lo_table_type) = cl_abap_tabledescr=>create( lo_descr ).
        DATA lt_result TYPE REF TO data.
        CREATE DATA lt_result TYPE HANDLE lo_table_type.
        FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
        ASSIGN lt_result->* TO <lt_data>.
        SELECT * FROM (lv_entity) INTO TABLE @<lt_data> UP TO 200 ROWS.
      CATCH cx_root.
        client->message_toast_display( |Could not load value help data| ).
        RETURN.
    ENDTRY.

    mt_vh_data = lt_result.

    "read VH entity metadata for column labels
    DATA(ls_vh_meta) = z2ui5_cl_cds_util=>read_entity( lv_entity ).

    DATA(lo_popup) = z2ui5_cl_xml_view=>factory_popup( ).
    DATA(lo_dialog) = lo_popup->table_select_dialog(
      title   = ls_field-label
      confirm = client->_event( cs_event-vh_confirm )
      cancel  = client->_event( cs_event-vh_cancel )
      items   = `{path:'` && client->_bind_edit( val = <lt_data> path = abap_true ) && `'}` ).

    "use visible fields from VH metadata
    DATA(lo_columns) = lo_dialog->columns( ).
    DATA(lo_items) = lo_dialog->items( ).
    DATA(lo_row) = lo_items->column_list_item( ).
    DATA(lo_cells) = lo_row->cells( ).

    LOOP AT ls_vh_meta-fields INTO DATA(ls_vh_field)
      WHERE is_visible = abap_true AND is_hidden = abap_false.
      lo_columns->column( )->text( ls_vh_field-label ).
      DATA(lv_path) = `{` && ls_vh_field-name && `}`.
      lo_cells->text( lv_path ).
    ENDLOOP.

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD handle_value_help_confirm.

    DATA(lv_index_str) = client->get_event_arg( ).

    IF mt_vh_data IS BOUND AND mv_vh_field IS NOT INITIAL.
      FIELD-SYMBOLS <lt_vh_data> TYPE STANDARD TABLE.
      ASSIGN mt_vh_data->* TO <lt_vh_data>.

      DATA(lv_index) = CONV i( lv_index_str ).
      IF lv_index > 0 AND lv_index <= lines( <lt_vh_data> ).
        READ TABLE ms_entity-fields INTO DATA(ls_field)
          WITH KEY name = mv_vh_field.
        IF sy-subrc = 0.
          FIELD-SYMBOLS <ls_row> TYPE any.
          READ TABLE <lt_vh_data> INDEX lv_index ASSIGNING <ls_row>.
          IF sy-subrc = 0.
            IF ls_field-value_help-element IS NOT INITIAL.
              FIELD-SYMBOLS <lv_vh_value> TYPE any.
              FIELD-SYMBOLS <lv_target> TYPE any.
              ASSIGN COMPONENT ls_field-value_help-element
                OF STRUCTURE <ls_row> TO <lv_vh_value>.
              ASSIGN COMPONENT mv_vh_field
                OF STRUCTURE ms_cds->* TO <lv_target>.
              IF <lv_vh_value> IS ASSIGNED AND <lv_target> IS ASSIGNED.
                <lv_target> = <lv_vh_value>.
              ENDIF.
            ENDIF.

            LOOP AT ls_field-value_help-additional_binding INTO DATA(ls_bind)
              WHERE usage CS `RESULT`.
              IF ls_bind-element IS NOT INITIAL AND ls_bind-local_element IS NOT INITIAL.
                FIELD-SYMBOLS <lv_src> TYPE any.
                FIELD-SYMBOLS <lv_tgt> TYPE any.
                ASSIGN COMPONENT ls_bind-element OF STRUCTURE <ls_row> TO <lv_src>.
                ASSIGN COMPONENT ls_bind-local_element OF STRUCTURE ms_cds->* TO <lv_tgt>.
                IF <lv_src> IS ASSIGNED AND <lv_tgt> IS ASSIGNED.
                  <lv_tgt> = <lv_src>.
                ENDIF.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    client->popup_destroy( ).
    render_action_dialog( client ).

  ENDMETHOD.


  METHOD result.
    result = ms_cds.
  ENDMETHOD.


  METHOD was_confirmed.
    result = mv_confirmed.
  ENDMETHOD.

ENDCLASS.
