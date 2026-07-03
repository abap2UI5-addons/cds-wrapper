CLASS z2ui5_cl_cds_list_report DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_filter,
        name  TYPE string,
        label TYPE string,
        value TYPE string,
      END OF ty_s_filter.

    TYPES ty_t_filter TYPE STANDARD TABLE OF ty_s_filter WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 500.

    DATA mv_cds_view TYPE string.
    DATA mv_title    TYPE string.
    DATA mv_max_rows TYPE i.
    DATA mv_count    TYPE string.
    DATA ms_entity   TYPE z2ui5_cl_cds_util=>ty_s_entity_info.
    DATA mr_data     TYPE REF TO data.
    DATA mt_filter   TYPE ty_t_filter.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_event,
        refresh   TYPE string VALUE `REFRESH`,
        go        TYPE string VALUE `GO`,
        row_press TYPE string VALUE `ROW_PRESS`,
        back      TYPE string VALUE `BACK`,
        create    TYPE string VALUE `CREATE`,
      END OF cs_event.

    DATA mt_row_key TYPE string_table.

    METHODS load_data.

    METHODS get_where_clause
      RETURNING
        VALUE(result) TYPE string.

    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS on_row_press
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS get_line_item_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cds_util=>ty_t_field_info.

    METHODS get_selection_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cds_util=>ty_t_field_info.

    METHODS get_row_key_fields
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS normalize_value
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

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

      "init filter bar from @UI.selectionField
      LOOP AT get_selection_fields( ) INTO DATA(ls_sel).
        APPEND VALUE ty_s_filter(
          name  = ls_sel-name
          label = ls_sel-label ) TO mt_filter.
      ENDLOOP.

      mt_row_key = get_row_key_fields( ).

      load_data( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-refresh )
      OR client->check_on_event( cs_event-go ).
      load_data( ).
      client->view_model_update( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-row_press ).
      on_row_press( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-back ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-create ).
      TRY.
          DATA(lo_descr_cr) = CAST cl_abap_structdescr(
            cl_abap_typedescr=>describe_by_name( mv_cds_view ) ).
          DATA lr_empty TYPE REF TO data.
          CREATE DATA lr_empty TYPE HANDLE lo_descr_cr.
          FIELD-SYMBOLS <ls_empty> TYPE any.
          ASSIGN lr_empty->* TO <ls_empty>.
          client->nav_app_call(
            NEW z2ui5_cl_cds_object_page(
              val       = <ls_empty>
              title     = `Create ` && mv_title
              editable  = abap_true
              is_create = abap_true ) ).
        CATCH cx_root.
          client->message_box_display(
            text = `Cannot create entry for this entity`
            type = `error` ).
      ENDTRY.
      RETURN.
    ENDIF.

    "handle return from Object Page - refresh if data was saved
    IF client->check_on_navigated( ).
      IF client->check_app_prev_stack( ).
        TRY.
            DATA(lo_prev_op) = CAST z2ui5_cl_cds_object_page(
              client->get_app_prev( ) ).
            IF lo_prev_op->was_saved( ).
              load_data( ).
              client->message_toast_display( `Data refreshed` ).
            ENDIF.
          CATCH cx_sy_move_cast_error ##NO_HANDLER.
        ENDTRY.
      ENDIF.
      client->view_model_update( ).
      RETURN.
    ENDIF.

    "fallback: acknowledge any unhandled event / return from sub-app
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
        DATA(lv_where) = get_where_clause( ).
        SELECT * FROM (mv_cds_view)
          WHERE (lv_where)
          INTO TABLE @<lt_data>
          UP TO @mv_max_rows ROWS.
        mv_count = lines( <lt_data> ).
      CATCH cx_root.
        CLEAR mr_data.
        mv_count = `0`.
    ENDTRY.
  ENDMETHOD.


  METHOD get_where_clause.

    LOOP AT mt_filter INTO DATA(ls_filter) WHERE value IS NOT INITIAL.
      DATA(lv_value) = replace( val  = ls_filter-value
                                sub  = `'`
                                with = `''`
                                occ  = 0 ).
      READ TABLE ms_entity-fields INTO DATA(ls_field)
        WITH KEY name = ls_filter-name.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_cond) = ``.
      CASE ls_field-type_kind.
        WHEN `CHAR` OR `STRING`.
          "wildcard search: user pattern via *, otherwise contains
          IF lv_value CS `*`.
            lv_value = replace( val  = lv_value
                                sub  = `*`
                                with = `%`
                                occ  = 0 ).
            lv_cond = |{ ls_filter-name } LIKE '{ lv_value }'|.
          ELSE.
            lv_cond = |{ ls_filter-name } LIKE '%{ lv_value }%'|.
          ENDIF.
        WHEN OTHERS.
          lv_cond = |{ ls_filter-name } = '{ lv_value }'|.
      ENDCASE.

      IF result IS INITIAL.
        result = lv_cond.
      ELSE.
        result = |{ result } AND { lv_cond }|.
      ENDIF.
    ENDLOOP.

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


  METHOD get_row_key_fields.

    "prefer @ObjectModel.semanticKey, fallback to all line item columns
    LOOP AT ms_entity-semantic_key INTO DATA(lv_key).
      IF line_exists( ms_entity-fields[ name = lv_key ] ).
        APPEND lv_key TO result.
      ENDIF.
    ENDLOOP.

    IF result IS INITIAL.
      LOOP AT get_line_item_fields( ) INTO DATA(ls_field).
        APPEND ls_field-name TO result.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD normalize_value.
    "align ABAP and JSON model representations (dates, times, padding)
    result = val.
    REPLACE ALL OCCURRENCES OF `-` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `:` IN result WITH ``.
    CONDENSE result.
  ENDMETHOD.


  METHOD on_row_press.

    IF mr_data IS NOT BOUND OR mt_row_key IS INITIAL.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_match) = abap_true.
      DATA(lv_index) = 0.
      LOOP AT mt_row_key INTO DATA(lv_key).
        lv_index = lv_index + 1.
        ASSIGN COMPONENT lv_key OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_val>).
        IF sy-subrc <> 0
          OR normalize_value( CONV #( <lv_val> ) )
          <> normalize_value( client->get_event_arg( lv_index ) ).
          lv_match = abap_false.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_match = abap_true.
        client->nav_app_call( NEW z2ui5_cl_cds_object_page( val = <ls_row> ) ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_page.

    IF mr_data IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    DATA(lt_columns) = get_line_item_fields( ).

    DATA(lo_view) = z2ui5_cl_xml_view=>factory( ).
    DATA(lo_page) = lo_view->shell( )->page(
      title          = mv_title
      shownavbutton  = client->check_app_prev_stack( )
      navbuttonpress = client->_event( cs_event-back ) ).

    "filter bar (if selection fields exist)
    IF mt_filter IS NOT INITIAL.
      DATA(lo_subheader) = lo_page->sub_header( ).
      DATA(lo_bar) = lo_subheader->overflow_toolbar( ).
      DATA(lo_fbox) = lo_bar->_generic(
        name   = `HBox`
        t_prop = VALUE #( ( n = `items`      v = client->_bind_edit( mt_filter ) )
                          ( n = `alignItems` v = `Center` )
                          ( n = `wrap`       v = `Wrap` ) ) ).
      lo_fbox->input(
        value       = `{VALUE}`
        placeholder = `{LABEL}`
        submit      = client->_event( cs_event-go )
        width       = `12rem`
        class       = `sapUiTinyMarginEnd` ).
      lo_bar->toolbar_spacer( ).
      lo_bar->button(
        text  = `Go`
        type  = `Emphasized`
        press = client->_event( cs_event-go )
        icon  = `sap-icon://search` ).
    ENDIF.

    "table
    DATA(lo_table) = lo_page->table(
      items            = `{path:'` && client->_bind_edit( val = <lt_data> path = abap_true ) && `'}`
      growing          = abap_true
      growingthreshold = `50`
      sticky           = `ColumnHeaders,HeaderToolbar`
      mode             = `None` ).

    "toolbar with title + bound count + create button
    DATA(lo_toolbar) = lo_table->header_toolbar( )->overflow_toolbar( ).
    lo_toolbar->title( text = mv_title && ` (` && client->_bind( mv_count ) && `)` ).
    lo_toolbar->toolbar_spacer( ).
    lo_toolbar->button(
      text  = `Create`
      press = client->_event( cs_event-create )
      type  = `Emphasized`
      icon  = `sap-icon://add` ).
    lo_toolbar->button( icon  = `sap-icon://refresh`
                        press = client->_event( cs_event-refresh ) ).

    "columns - @UI.lineItem importance drives responsive popin behavior
    DATA(lo_columns) = lo_table->columns( ).
    LOOP AT lt_columns INTO DATA(ls_col).
      DATA(lv_col_label) = ls_col-line_item_label.
      IF lv_col_label IS INITIAL.
        lv_col_label = ls_col-label.
      ENDIF.

      IF ls_col-line_item_importance CS `MEDIUM`.
        lo_columns->column( minscreenwidth = `Tablet`
                            demandpopin    = abap_true )->text( lv_col_label ).
      ELSEIF ls_col-line_item_importance CS `LOW`.
        lo_columns->column( minscreenwidth = `Desktop`
                            demandpopin    = abap_true )->text( lv_col_label ).
      ELSE.
        lo_columns->column( )->text( lv_col_label ).
      ENDIF.
    ENDLOOP.

    "items - row press navigates to a generated object page
    DATA(lo_items) = lo_table->items( ).
    DATA lo_row TYPE REF TO z2ui5_cl_xml_view.
    IF mt_row_key IS NOT INITIAL.
      DATA lt_arg TYPE string_table.
      LOOP AT mt_row_key INTO DATA(lv_key).
        APPEND `${` && lv_key && `}` TO lt_arg.
      ENDLOOP.
      lo_row = lo_items->column_list_item(
        type  = `Navigation`
        press = client->_event( val   = cs_event-row_press
                                t_arg = lt_arg ) ).
    ELSE.
      lo_row = lo_items->column_list_item( ).
    ENDIF.
    DATA(lo_cells) = lo_row->cells( ).

    LOOP AT lt_columns INTO ls_col.
      DATA(lv_path) = `{` && ls_col-name && `}`.

      "criticality -> ObjectStatus
      IF ls_col-datapoint_crit_field IS NOT INITIAL
        OR ls_col-line_item_crit_field IS NOT INITIAL.
        DATA(lv_crit_field) = ls_col-line_item_crit_field.
        IF lv_crit_field IS INITIAL.
          lv_crit_field = ls_col-datapoint_crit_field.
        ENDIF.
        lo_cells->object_status(
          text  = lv_path
          state = `{= ${` && lv_crit_field &&
                  `} === 3 ? 'Success' : (${` && lv_crit_field &&
                  `} === 1 ? 'Error' : (${` && lv_crit_field &&
                  `} === 2 ? 'Warning' : 'None')) }` ).

      "amount + currency -> ObjectNumber
      ELSEIF ls_col-is_amount_field = abap_true
        AND ls_col-semantics_currency_code IS NOT INITIAL.
        lo_cells->object_number(
          number = lv_path
          unit   = `{` && to_upper( ls_col-semantics_currency_code ) && `}` ).

      "quantity + unit -> ObjectNumber
      ELSEIF ls_col-is_quantity_field = abap_true
        AND ls_col-semantics_unit_of_measure IS NOT INITIAL.
        lo_cells->object_number(
          number = lv_path
          unit   = `{` && to_upper( ls_col-semantics_unit_of_measure ) && `}` ).

      ELSE.
        lo_cells->text( lv_path ).
      ENDIF.
    ENDLOOP.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
