CLASS z2ui5_cl_cds_overview_page DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_card,
        cds_view_name TYPE string,
        title         TYPE string,
        card_type     TYPE string,
        max_rows      TYPE i,
      END OF ty_s_card.

    TYPES ty_t_card TYPE STANDARD TABLE OF ty_s_card WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING
        title TYPE string OPTIONAL
        cards TYPE ty_t_card.

    DATA mv_title TYPE string.
    DATA mt_cards TYPE ty_t_card.

    TYPES:
      BEGIN OF ty_s_card_data,
        entity   TYPE z2ui5_cl_cds_util=>ty_s_entity_info,
        data_ref TYPE REF TO data,
        title    TYPE string,
        count    TYPE i,
      END OF ty_s_card_data.

    TYPES ty_t_card_data TYPE STANDARD TABLE OF ty_s_card_data WITH DEFAULT KEY.

    DATA mt_card_data TYPE ty_t_card_data.

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS load_all_cards.

    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS render_table_card
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_xml_view
        is_card      TYPE ty_s_card_data
        client       TYPE REF TO z2ui5_if_client.

    METHODS render_kpi_card
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_xml_view
        is_card      TYPE ty_s_card_data
        client       TYPE REF TO z2ui5_if_client.

ENDCLASS.



CLASS z2ui5_cl_cds_overview_page IMPLEMENTATION.

  METHOD constructor.
    mv_title = title.
    mt_cards = cards.
    IF mv_title IS INITIAL.
      mv_title = `Overview`.
    ENDIF.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      load_all_cards( ).
      render_page( client ).
      "clear generic refs to allow serialization
      LOOP AT mt_card_data ASSIGNING FIELD-SYMBOL(<ls_cd>).
        CLEAR <ls_cd>-data_ref.
      ENDLOOP.
      RETURN.
    ENDIF.

    IF client->check_on_event( `BACK` ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

  ENDMETHOD.


  METHOD load_all_cards.

    LOOP AT mt_cards INTO DATA(ls_card).
      DATA(ls_cd) = VALUE ty_s_card_data( ).
      DATA(lv_view) = to_upper( ls_card-cds_view_name ).

      ls_cd-entity = z2ui5_cl_cds_util=>read_entity( lv_view ).
      ls_cd-title = ls_card-title.
      IF ls_cd-title IS INITIAL.
        IF ls_cd-entity-header_info-type_name_plural IS NOT INITIAL.
          ls_cd-title = ls_cd-entity-header_info-type_name_plural.
        ELSE.
          ls_cd-title = lv_view.
        ENDIF.
      ENDIF.

      DATA(lv_max) = ls_card-max_rows.
      IF lv_max <= 0.
        lv_max = 5.
      ENDIF.

      TRY.
          DATA(lo_descr) = CAST cl_abap_structdescr(
            cl_abap_typedescr=>describe_by_name( lv_view ) ).
          DATA(lo_table_type) = cl_abap_tabledescr=>create( lo_descr ).
          CREATE DATA ls_cd-data_ref TYPE HANDLE lo_table_type.
          FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
          ASSIGN ls_cd-data_ref->* TO <lt_data>.
          SELECT * FROM (lv_view) INTO TABLE @<lt_data>
            UP TO @lv_max ROWS.
          ls_cd-count = lines( <lt_data> ).
        CATCH cx_root.
          CLEAR ls_cd-data_ref.
      ENDTRY.

      APPEND ls_cd TO mt_card_data.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_page.

    DATA(lo_view) = z2ui5_cl_xml_view=>factory( ).
    DATA(lo_page) = lo_view->shell( )->page(
      title          = mv_title
      shownavbutton  = client->check_app_prev_stack( )
      navbuttonpress = client->_event( `BACK` ) ).

    "grid layout for cards
    DATA(lo_grid) = lo_page->grid(
      default_span = `L6 M12 S12` ).

    LOOP AT mt_card_data INTO DATA(ls_cd).
      DATA(lv_card_idx) = sy-tabix.
      READ TABLE mt_cards INDEX lv_card_idx INTO DATA(ls_card_cfg).

      DATA(lv_type) = `TABLE`.
      IF ls_card_cfg-card_type IS NOT INITIAL.
        lv_type = to_upper( ls_card_cfg-card_type ).
      ENDIF.

      CASE lv_type.
        WHEN `KPI` OR `NUMERIC`.
          render_kpi_card(
            io_container = lo_grid
            is_card      = ls_cd
            client       = client ).
        WHEN OTHERS.
          render_table_card(
            io_container = lo_grid
            is_card      = ls_cd
            client       = client ).
      ENDCASE.
    ENDLOOP.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_table_card.

    IF is_card-data_ref IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN is_card-data_ref->* TO <lt_data>.

    "get lineItem fields or all visible
    DATA lt_columns TYPE z2ui5_cl_cds_util=>ty_t_field_info.
    LOOP AT is_card-entity-fields INTO DATA(ls_field)
      WHERE line_item_pos > 0 AND is_hidden = abap_false.
      APPEND ls_field TO lt_columns.
    ENDLOOP.
    SORT lt_columns BY line_item_pos.
    IF lt_columns IS INITIAL.
      LOOP AT is_card-entity-fields INTO ls_field
        WHERE is_hidden = abap_false.
        APPEND ls_field TO lt_columns.
        IF lines( lt_columns ) >= 5.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    "panel as card container
    DATA(lo_panel) = io_container->panel(
      headertext = |{ is_card-title } ({ is_card-count })| ).

    "table inside panel
    DATA(lo_table) = lo_panel->table(
      items = `{path:'` && client->_bind_edit( val = <lt_data> path = abap_true ) && `'}`
      mode  = `None` ).

    DATA(lo_columns) = lo_table->columns( ).
    LOOP AT lt_columns INTO ls_field.
      DATA(lv_label) = ls_field-line_item_label.
      IF lv_label IS INITIAL.
        lv_label = ls_field-label.
      ENDIF.
      lo_columns->column( )->text( lv_label ).
    ENDLOOP.

    DATA(lo_items) = lo_table->items( ).
    DATA(lo_row) = lo_items->column_list_item( ).
    DATA(lo_cells) = lo_row->cells( ).
    LOOP AT lt_columns INTO ls_field.
      DATA(lv_path) = `{` && ls_field-name && `}`.
      lo_cells->text( lv_path ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_kpi_card.

    IF is_card-data_ref IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN is_card-data_ref->* TO <lt_data>.

    "find dataPoint fields for KPI
    DATA lv_kpi_value TYPE string.
    DATA lv_kpi_unit TYPE string.
    LOOP AT is_card-entity-fields INTO DATA(ls_field)
      WHERE datapoint_qualifier IS NOT INITIAL.
      FIELD-SYMBOLS <lv_val> TYPE any.
      READ TABLE <lt_data> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF sy-subrc = 0.
        ASSIGN COMPONENT ls_field-name OF STRUCTURE <ls_row> TO <lv_val>.
        IF sy-subrc = 0.
          lv_kpi_value = <lv_val>.
        ENDIF.
      ENDIF.
      EXIT.
    ENDLOOP.

    IF lv_kpi_value IS INITIAL.
      lv_kpi_value = CONV string( is_card-count ).
    ENDIF.

    "render as GenericTile with NumericContent
    io_container->generic_tile(
      header    = is_card-title
      subheader = |{ is_card-count } items|
      frameType = `OneByOne`
    )->tile_content(
      )->numeric_content(
        value = lv_kpi_value
        scale = lv_kpi_unit ).

  ENDMETHOD.

ENDCLASS.
