CLASS z2ui5_cl_cds_object_page DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    METHODS constructor
      IMPORTING
        val   TYPE data
        title TYPE string OPTIONAL.

    DATA ms_data TYPE REF TO data.
    DATA mv_title TYPE string.
    DATA ms_entity TYPE z2ui5_cl_cds_util=>ty_s_entity_info.

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS get_field_groups
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS render_section_form
      IMPORTING
        io_parent TYPE REF TO z2ui5_cl_xml_view
        iv_group  TYPE string
        client    TYPE REF TO z2ui5_if_client.

    METHODS get_identification_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cds_util=>ty_t_field_info.

    METHODS get_criticality_state
      IMPORTING
        iv_crit_value TYPE i
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.



CLASS z2ui5_cl_cds_object_page IMPLEMENTATION.

  METHOD constructor.
    CREATE DATA ms_data LIKE val.
    ms_data->* = val.
    mv_title = title.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      DATA(lo_datadescr) = cl_abap_datadescr=>describe_by_data( ms_data->* ).
      DATA(lv_entity_name) = lo_datadescr->get_relative_name( ).
      ms_entity = z2ui5_cl_cds_util=>read_entity( lv_entity_name ).

      IF mv_title IS INITIAL.
        IF ms_entity-header_info-type_name IS NOT INITIAL.
          mv_title = ms_entity-header_info-type_name.
        ELSE.
          mv_title = ms_entity-name.
        ENDIF.
      ENDIF.

      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( `BACK` ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

  ENDMETHOD.


  METHOD get_field_groups.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE field_group IS NOT INITIAL.
      IF NOT line_exists( result[ table_line = ls_field-field_group ] ).
        APPEND ls_field-field_group TO result.
      ENDIF.
    ENDLOOP.
    IF result IS INITIAL.
      APPEND `General` TO result.
    ENDIF.
  ENDMETHOD.


  METHOD get_identification_fields.
    "fields with @UI.identification are shown in header
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_hidden = abap_false.
      "for now: use first 3 non-hidden fields if no identification annotation
      APPEND ls_field TO result.
      IF lines( result ) >= 3.
        EXIT.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_criticality_state.
    CASE iv_crit_value.
      WHEN 1. result = `Error`.
      WHEN 2. result = `Warning`.
      WHEN 3. result = `Success`.
      WHEN OTHERS. result = `None`.
    ENDCASE.
  ENDMETHOD.


  METHOD render_page.

    DATA(lo_view) = z2ui5_cl_xml_view=>factory(
      t_ns = VALUE #( ( n = `uxap` v = `sap.uxap` ) ) ).

    DATA(lo_shell) = lo_view->shell( ).
    DATA(lo_page) = lo_shell->page(
      title          = mv_title
      shownavbutton  = client->check_app_prev_stack( )
      navbuttonpress = client->_event( `BACK` ) ).
    DATA(lo_op) = lo_page->object_page_layout(
      uppercaseanchorbar = abap_false ).

    "===== HEADER TITLE =====
    DATA(lo_ht) = lo_op->header_title( )->object_page_dyn_header_title( ).

    "expanded heading - show title
    DATA(lv_title_text) = mv_title.
    IF ms_entity-header_info-title_field IS NOT INITIAL.
      FIELD-SYMBOLS <lv_t> TYPE any.
      ASSIGN COMPONENT ms_entity-header_info-title_field OF STRUCTURE ms_data->* TO <lv_t>.
      IF sy-subrc = 0 AND <lv_t> IS NOT INITIAL.
        lv_title_text = <lv_t>.
      ENDIF.
    ENDIF.
    lo_ht->expanded_heading( )->title( lv_title_text ).

    "snapped heading
    lo_ht->snapped_heading( )->title( lv_title_text ).

    "snapped title on mobile
    lo_ht->snapped_title_on_mobile( )->title( lv_title_text ).

    "expanded content - show subtitle/description
    IF ms_entity-header_info-description_field IS NOT INITIAL.
      FIELD-SYMBOLS <lv_d> TYPE any.
      ASSIGN COMPONENT ms_entity-header_info-description_field OF STRUCTURE ms_data->* TO <lv_d>.
      IF sy-subrc = 0 AND <lv_d> IS NOT INITIAL.
        lo_ht->expanded_content( ns = `uxap` )->label( CONV #( <lv_d> ) ).
        lo_ht->snapped_content( ns = `uxap` )->label( CONV #( <lv_d> ) ).
      ENDIF.
    ENDIF.

    "===== HEADER CONTENT (key attributes) =====
    DATA(lo_hc) = lo_op->header_content( ns = `uxap` ).
    DATA(lo_hbox) = lo_hc->flex_box( wrap = `Wrap` fitcontainer = abap_true ).

    "show identification fields or first few fields as header attributes
    DATA(lt_id_fields) = get_identification_fields( ).
    LOOP AT lt_id_fields INTO DATA(ls_id).
      FIELD-SYMBOLS <lv_id_val> TYPE any.
      ASSIGN COMPONENT ls_id-name OF STRUCTURE ms_data->* TO <lv_id_val>.
      IF sy-subrc = 0.
        DATA(lv_val_str) = CONV string( <lv_id_val> ).
        IF lv_val_str IS NOT INITIAL.
          lo_hbox->vbox( `sapUiSmallMarginEnd sapUiSmallMarginBottom`
            )->label( text = ls_id-label
            )->text( lv_val_str
            )->get_parent( ).
        ENDIF.
      ENDIF.
    ENDLOOP.

    "===== SECTIONS =====
    DATA(lo_sections) = lo_op->sections( ).

    "auto-generate sections from fieldGroup qualifiers
    DATA(lt_groups) = get_field_groups( ).
    LOOP AT lt_groups INTO DATA(lv_group).
      DATA(lo_section) = lo_sections->object_page_section(
        titleuppercase = abap_false
        title          = lv_group ).

      DATA(lo_sub_sections) = lo_section->sub_sections( ).
      DATA(lo_sub) = lo_sub_sections->object_page_sub_section(
        title     = lv_group
        showtitle = abap_false ).
      DATA(lo_blocks) = lo_sub->blocks( ).

      render_section_form(
        io_parent = lo_blocks
        iv_group  = lv_group
        client    = client ).
    ENDLOOP.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_section_form.

    DATA(lo_form) = io_parent->simple_form(
      class     = `sapUxAPObjectPageSubSectionAlignContent`
      editable  = abap_false
      layout    = `ColumnLayout`
      columnsm  = `2`
      columnsl  = `3`
      columnsxl = `4` ).

    "collect and sort fields for this group
    DATA lt_sorted TYPE z2ui5_cl_cds_util=>ty_t_field_info.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_hidden = abap_false AND field_group = iv_group.
      APPEND ls_field TO lt_sorted.
    ENDLOOP.
    SORT lt_sorted BY field_group_pos.

    "render each field
    LOOP AT lt_sorted INTO ls_field.
      FIELD-SYMBOLS <field> TYPE any.
      ASSIGN COMPONENT ls_field-name OF STRUCTURE ms_data->* TO <field>.
      CHECK sy-subrc = 0.

      lo_form->label( ls_field-label ).

      DATA(lv_display_val) = CONV string( <field> ).

      IF ls_field-is_multiline = abap_true.
        lo_form->text( lv_display_val ).
      ELSEIF ls_field-type_kind = `DATS` AND lv_display_val IS NOT INITIAL.
        lo_form->text( lv_display_val ).
      ELSE.
        lo_form->text( lv_display_val ).
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
