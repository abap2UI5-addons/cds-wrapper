CLASS z2ui5_cl_cds_value_help DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        element       TYPE clike OPTIONAL
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 200.

    METHODS result
      RETURNING
        VALUE(result) TYPE REF TO data.

    METHODS result_value
      RETURNING
        VALUE(result) TYPE string.

    METHODS was_confirmed
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS is_dropdown
      RETURNING
        VALUE(result) TYPE abap_bool.

    DATA mv_cds_view   TYPE string.
    DATA mv_element    TYPE string.
    DATA mv_title      TYPE string.
    DATA mv_max_rows   TYPE i.
    DATA mv_confirmed  TYPE abap_bool.
    DATA ms_entity     TYPE z2ui5_cl_cds_util=>ty_s_entity_info.
    DATA mr_selected   TYPE REF TO data.
    DATA mv_result_val TYPE string.
    DATA mr_data       TYPE REF TO data.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_event,
        confirm TYPE string VALUE `VH_CONFIRM`,
        cancel  TYPE string VALUE `VH_CANCEL`,
      END OF cs_event.

    METHODS load_data.

    METHODS render_dialog
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

ENDCLASS.



CLASS z2ui5_cl_cds_value_help IMPLEMENTATION.

  METHOD constructor.
    mv_cds_view = to_upper( cds_view_name ).
    mv_element = to_upper( element ).
    mv_title = title.
    mv_max_rows = max_rows.
    mv_confirmed = abap_false.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      ms_entity = z2ui5_cl_cds_util=>read_entity( mv_cds_view ).
      IF mv_title IS INITIAL.
        mv_title = ms_entity-name.
      ENDIF.
      IF mv_element IS INITIAL AND lines( ms_entity-fields ) > 0.
        mv_element = ms_entity-fields[ 1 ]-name.
      ENDIF.
      load_data( ).
      render_dialog( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-confirm ).
      mv_confirmed = abap_true.

      DATA(lv_index_str) = client->get_event_arg( ).
      DATA(lv_index) = CONV i( lv_index_str ).

      IF mr_data IS BOUND AND lv_index > 0.
        FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
        ASSIGN mr_data->* TO <lt_data>.

        IF lv_index <= lines( <lt_data> ).
          FIELD-SYMBOLS <ls_row> TYPE any.
          READ TABLE <lt_data> INDEX lv_index ASSIGNING <ls_row>.
          IF sy-subrc = 0.
            CREATE DATA mr_selected LIKE <ls_row>.
            mr_selected->* = <ls_row>.

            IF mv_element IS NOT INITIAL.
              FIELD-SYMBOLS <lv_val> TYPE any.
              ASSIGN COMPONENT mv_element OF STRUCTURE <ls_row> TO <lv_val>.
              IF sy-subrc = 0.
                mv_result_val = <lv_val>.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-cancel ).
      mv_confirmed = abap_false.
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

  ENDMETHOD.


  METHOD load_data.
    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( mv_cds_view ) ).
        DATA(lo_table_type) = cl_abap_tabledescr=>create( lo_descr ).
        CREATE DATA mr_data TYPE HANDLE lo_table_type.
        FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
        ASSIGN mr_data->* TO <lt_data>.
        SELECT * FROM (mv_cds_view) INTO TABLE @<lt_data>
          UP TO @mv_max_rows ROWS.
      CATCH cx_root.
        CLEAR mr_data.
    ENDTRY.
  ENDMETHOD.


  METHOD render_dialog.

    IF mr_data IS NOT BOUND.
      client->message_box_display(
        text = |Could not load data from { mv_cds_view }|
        type = `error` ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    DATA(lo_popup) = z2ui5_cl_xml_view=>factory_popup( ).
    DATA(lo_dialog) = lo_popup->table_select_dialog(
      title   = mv_title
      confirm = client->_event( cs_event-confirm )
      cancel  = client->_event( cs_event-cancel )
      items   = `{path:'` && client->_bind_edit( val = <lt_data> path = abap_true ) && `'}` ).

    DATA(lo_columns) = lo_dialog->columns( ).
    DATA(lo_items) = lo_dialog->items( ).
    DATA(lo_row) = lo_items->column_list_item( ).
    DATA(lo_cells) = lo_row->cells( ).

    "render only visible, non-hidden fields
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_visible = abap_true AND is_hidden = abap_false.
      lo_columns->column( )->text( ls_field-label ).
      DATA(lv_path) = `{` && ls_field-name && `}`.
      lo_cells->text( lv_path ).

      "if text element exists, add description column
      IF ls_field-text_element IS NOT INITIAL.
        lo_columns->column( )->text( ls_field-text_element ).
        DATA(lv_text_path) = `{` && ls_field-text_element && `}`.
        lo_cells->text( lv_text_path ).
      ENDIF.
    ENDLOOP.

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD result.
    result = mr_selected.
  ENDMETHOD.


  METHOD result_value.
    result = mv_result_val.
  ENDMETHOD.


  METHOD was_confirmed.
    result = mv_confirmed.
  ENDMETHOD.


  METHOD is_dropdown.
    result = ms_entity-is_dropdown.
  ENDMETHOD.

ENDCLASS.
