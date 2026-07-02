CLASS z2ui5_cl_cds_list_report DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 500.

    DATA mv_cds_view  TYPE string.
    DATA mv_title     TYPE string.
    DATA mv_max_rows  TYPE i.
    DATA ms_entity    TYPE z2ui5_cl_cds_util=>ty_s_entity_info.
    DATA mr_data         TYPE REF TO data.
    DATA mt_filter       TYPE z2ui5_cl_cds_util=>ty_t_field_info.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_event,
        refresh TYPE string VALUE `REFRESH`,
        back    TYPE string VALUE `BACK`,
      END OF cs_event.

    METHODS load_data.

    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS get_line_item_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cds_util=>ty_t_field_info.

    METHODS get_selection_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cds_util=>ty_t_field_info.

ENDCLASS.



CLASS z2ui5_cl_cds_list_report IMPLEMENTATION.

  METHOD constructor.
    mv_cds_view = to_upper( cds_view_name ).
    mv_title = title.
    mv_max_rows = max_rows.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      ms_entity = z2ui5_cl_cds_util=>read_entity( mv_cds_view ).
      IF mv_title IS INITIAL.
        IF ms_entity-header_info-type_name_plural IS NOT INITIAL.
          mv_title = ms_entity-header_info-type_name_plural.
        ELSE.
          mv_title = mv_cds_view.
        ENDIF.
      ENDIF.
      load_data( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-refresh ).
      load_data( ).
      client->view_model_update( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-back ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    "fallback: acknowledge any unhandled event
    client->view_model_update( ).

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


  METHOD get_line_item_fields.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE line_item_pos > 0 AND is_hidden = abap_false.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result BY line_item_pos.

    "fallback: if no lineItem annotations, show all visible fields
    IF result IS INITIAL.
      LOOP AT ms_entity-fields INTO ls_field
        WHERE is_hidden = abap_false.
        APPEND ls_field TO result.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_selection_fields.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_selection_field = abap_true.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result BY selection_field_pos.
  ENDMETHOD.


  METHOD render_page.

    IF mr_data IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    DATA(lt_columns) = get_line_item_fields( ).
    DATA(lt_filters) = get_selection_fields( ).

    DATA(lo_view) = z2ui5_cl_xml_view=>factory( ).
    DATA(lo_page) = lo_view->shell( )->page(
      title          = mv_title
      shownavbutton  = client->check_app_prev_stack( )
      navbuttonpress = client->_event( `BACK` ) ).

    "filter bar (if selection fields exist)
    IF lt_filters IS NOT INITIAL.
      DATA(lo_subheader) = lo_page->sub_header( ).
      DATA(lo_bar) = lo_subheader->overflow_toolbar( ).
      LOOP AT lt_filters INTO DATA(ls_filter).
        lo_bar->input(
          placeholder = ls_filter-label
          width       = `12rem` ).
      ENDLOOP.
      lo_bar->toolbar_spacer( ).
      lo_bar->button(
        text  = `Go`
        type  = `Emphasized`
        press = client->_event( cs_event-refresh )
        icon  = `sap-icon://search` ).
    ENDIF.

    "table
    DATA(lv_count) = CONV string( lines( <lt_data> ) ).
    DATA(lo_table) = lo_page->table(
      items            = `{path:'` && client->_bind_edit( val = <lt_data> path = abap_true ) && `'}`
      growing          = abap_true
      growingthreshold = `50`
      sticky           = `ColumnHeaders,HeaderToolbar`
      mode             = `None` ).

    "toolbar with title + count
    DATA(lo_toolbar) = lo_table->header_toolbar( )->overflow_toolbar( ).
    lo_toolbar->title( text = |{ mv_title } ({ lv_count })| ).
    lo_toolbar->toolbar_spacer( ).
    lo_toolbar->button( icon  = `sap-icon://refresh`
                        press = client->_event( cs_event-refresh ) ).

    "columns
    DATA(lo_columns) = lo_table->columns( ).
    LOOP AT lt_columns INTO DATA(ls_col).
      DATA(lv_col_label) = ls_col-line_item_label.
      IF lv_col_label IS INITIAL.
        lv_col_label = ls_col-label.
      ENDIF.
      lo_columns->column( )->text( lv_col_label ).
    ENDLOOP.

    "items
    DATA(lo_items) = lo_table->items( ).
    DATA(lo_row) = lo_items->column_list_item( ).
    DATA(lo_cells) = lo_row->cells( ).

    LOOP AT lt_columns INTO ls_col.
      DATA(lv_path) = `{` && ls_col-name && `}`.

      "if field has criticality, render as ObjectStatus
      IF ls_col-datapoint_crit_field IS NOT INITIAL
        OR ls_col-line_item_crit_field IS NOT INITIAL.
        DATA(lv_crit_field) = ls_col-line_item_crit_field.
        IF lv_crit_field IS INITIAL.
          lv_crit_field = ls_col-datapoint_crit_field.
        ENDIF.
        lo_cells->object_status(
          text  = lv_path
          state = `{= $` && lv_crit_field &&
                  ` === 3 ? 'Success' : ($` && lv_crit_field &&
                  ` === 1 ? 'Error' : ($` && lv_crit_field &&
                  ` === 2 ? 'Warning' : 'None')) }` ).
      ELSE.
        lo_cells->text( lv_path ).
      ENDIF.
    ENDLOOP.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
