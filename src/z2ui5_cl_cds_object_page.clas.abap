CLASS z2ui5_cl_cds_object_page DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    METHODS constructor
      IMPORTING
        val       TYPE data
        title     TYPE string OPTIONAL
        editable  TYPE abap_bool DEFAULT abap_false
        is_create TYPE abap_bool DEFAULT abap_false.

    "! Check if user saved (for caller to detect on return)
    METHODS was_saved
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Get the saved data reference
    METHODS result
      RETURNING
        VALUE(result) TYPE REF TO data.

    DATA ms_data TYPE REF TO data.
    DATA mv_title TYPE string.
    DATA ms_entity TYPE z2ui5_cl_cds_util=>ty_s_entity_info.
    DATA mv_editable TYPE abap_bool.
    DATA mv_is_create TYPE abap_bool.
    DATA mv_saved TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_section,
        title       TYPE string,
        field_group TYPE string,
      END OF ty_s_section.

    TYPES ty_t_section TYPE STANDARD TABLE OF ty_s_section WITH DEFAULT KEY.

    CONSTANTS:
      BEGIN OF cs_event,
        back   TYPE string VALUE `BACK`,
        edit   TYPE string VALUE `EDIT`,
        save   TYPE string VALUE `SAVE`,
        cancel TYPE string VALUE `CANCEL`,
        delete TYPE string VALUE `DELETE`,
      END OF cs_event.

    DATA ms_data_backup TYPE REF TO data.
    DATA mv_entity_name TYPE string.

    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS get_sections
      RETURNING
        VALUE(result) TYPE ty_t_section.

    METHODS render_section_form
      IMPORTING
        io_parent TYPE REF TO z2ui5_cl_xml_view
        iv_group  TYPE string
        client    TYPE REF TO z2ui5_if_client.

    METHODS get_identification_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cds_util=>ty_t_field_info.

    METHODS get_datapoint_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cds_util=>ty_t_field_info.

    METHODS get_criticality_state
      IMPORTING
        iv_crit_value TYPE i
      RETURNING
        VALUE(result) TYPE string.

    METHODS get_crit_value
      IMPORTING
        iv_field      TYPE string
      RETURNING
        VALUE(result) TYPE i.

    METHODS get_field_value
      IMPORTING
        is_field      TYPE z2ui5_cl_cds_util=>ty_s_field_info
      RETURNING
        VALUE(result) TYPE string.

    METHODS format_value
      IMPORTING
        is_field      TYPE z2ui5_cl_cds_util=>ty_s_field_info
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    METHODS save_data
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS delete_data
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

ENDCLASS.



CLASS z2ui5_cl_cds_object_page IMPLEMENTATION.

  METHOD constructor.
    CREATE DATA ms_data LIKE val.
    ms_data->* = val.
    mv_title = title.
    mv_editable = editable.
    mv_is_create = is_create.
  ENDMETHOD.


  METHOD was_saved.
    result = mv_saved.
  ENDMETHOD.


  METHOD result.
    result = ms_data.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      DATA(lo_datadescr) = cl_abap_datadescr=>describe_by_data( ms_data->* ).
      mv_entity_name = lo_datadescr->get_relative_name( ).
      ms_entity = z2ui5_cl_cds_util=>read_entity( mv_entity_name ).

      "backup original data for cancel
      CREATE DATA ms_data_backup LIKE ms_data->*.
      ms_data_backup->* = ms_data->*.

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

    IF client->check_on_event( cs_event-back ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-edit ).
      mv_editable = abap_true.
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-cancel ).
      ms_data->* = ms_data_backup->*.
      mv_editable = abap_false.
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-save ).
      IF save_data( client ).
        mv_saved = abap_true.
        mv_editable = abap_false.
        "update backup to new saved state
        ms_data_backup->* = ms_data->*.
        render_page( client ).
        client->message_toast_display( `Data saved successfully` ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-delete ).
      IF delete_data( client ).
        mv_saved = abap_true.
        client->message_toast_display( `Data deleted successfully` ).
        client->nav_app_leave( ).
      ENDIF.
      RETURN.
    ENDIF.

  ENDMETHOD.


  METHOD save_data.

    FIELD-SYMBOLS <ls_data> TYPE any.
    ASSIGN ms_data->* TO <ls_data>.

    TRY.
        MODIFY (mv_entity_name) FROM @<ls_data>.
        IF sy-subrc = 0.
          result = abap_true.
        ELSE.
          client->message_box_display(
            text = `Save failed (sy-subrc <> 0)`
            type = `error` ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_err).
        client->message_box_display(
          text = lx_err->get_text( )
          type = `error` ).
    ENDTRY.

  ENDMETHOD.


  METHOD delete_data.

    FIELD-SYMBOLS <ls_data> TYPE any.
    ASSIGN ms_data->* TO <ls_data>.

    TRY.
        DELETE (mv_entity_name) FROM @<ls_data>.
        IF sy-subrc = 0.
          result = abap_true.
        ELSE.
          client->message_box_display(
            text = `Delete failed (sy-subrc <> 0)`
            type = `error` ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_err).
        client->message_box_display(
          text = lx_err->get_text( )
          type = `error` ).
    ENDTRY.

  ENDMETHOD.


  METHOD get_sections.

    "facet-driven: @UI.facet fieldGroup references define order and labels
    DATA lt_facets TYPE z2ui5_cl_cds_util=>ty_t_facet.
    LOOP AT ms_entity-facets INTO DATA(ls_facet)
      WHERE target_qualifier IS NOT INITIAL.
      IF ls_facet-type IS INITIAL OR ls_facet-type CS `FIELDGROUP`.
        APPEND ls_facet TO lt_facets.
      ENDIF.
    ENDLOOP.
    SORT lt_facets BY position.

    LOOP AT lt_facets INTO ls_facet.
      IF NOT line_exists( ms_entity-fields[ field_group = ls_facet-target_qualifier ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_title) = ls_facet-label.
      IF lv_title IS INITIAL.
        lv_title = ls_facet-target_qualifier.
      ENDIF.
      APPEND VALUE ty_s_section(
        title       = lv_title
        field_group = ls_facet-target_qualifier ) TO result.
    ENDLOOP.

    "field groups not covered by facets, in order of appearance
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE field_group IS NOT INITIAL AND is_hidden = abap_false.
      IF NOT line_exists( result[ field_group = ls_field-field_group ] ).
        APPEND VALUE ty_s_section(
          title       = ls_field-field_group
          field_group = ls_field-field_group ) TO result.
      ENDIF.
    ENDLOOP.

    "no field groups at all -> single section with all visible fields
    IF result IS INITIAL.
      APPEND VALUE ty_s_section( title = `General` ) TO result.
    ENDIF.

  ENDMETHOD.


  METHOD get_identification_fields.

    "fields annotated with @UI.identification, ordered by position
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_identification = abap_true AND is_hidden = abap_false.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result BY identification_pos.

    "fallback: first 3 visible fields (dataPoints are rendered separately)
    IF result IS INITIAL.
      LOOP AT ms_entity-fields INTO ls_field
        WHERE is_hidden = abap_false AND datapoint_qualifier IS INITIAL.
        APPEND ls_field TO result.
        IF lines( result ) >= 3.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD get_datapoint_fields.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE datapoint_qualifier IS NOT INITIAL AND is_hidden = abap_false.
      APPEND ls_field TO result.
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


  METHOD get_crit_value.
    FIELD-SYMBOLS <lv_crit> TYPE any.
    ASSIGN COMPONENT iv_field OF STRUCTURE ms_data->* TO <lv_crit>.
    IF sy-subrc = 0.
      TRY.
          result = <lv_crit>.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD get_field_value.
    FIELD-SYMBOLS <lv_val> TYPE any.
    ASSIGN COMPONENT is_field-name OF STRUCTURE ms_data->* TO <lv_val>.
    IF sy-subrc = 0.
      result = format_value( is_field = is_field
                             val      = <lv_val> ).
    ENDIF.
  ENDMETHOD.


  METHOD format_value.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.

    IF is_field-is_boolean = abap_true.
      result = COND #( WHEN val = abap_true THEN `Yes` ELSE `No` ).
      RETURN.
    ENDIF.

    TRY.
        CASE is_field-type_kind.
          WHEN `DATS`.
            lv_date = val.
            IF lv_date IS NOT INITIAL.
              result = |{ lv_date DATE = USER }|.
            ENDIF.
          WHEN `TIMS`.
            lv_time = val.
            IF lv_time IS NOT INITIAL.
              result = |{ lv_time TIME = USER }|.
            ENDIF.
          WHEN OTHERS.
            result = |{ val }|.
        ENDCASE.
      CATCH cx_root.
        result = |{ val }|.
    ENDTRY.

  ENDMETHOD.


  METHOD render_page.

    DATA(lo_view) = z2ui5_cl_xml_view=>factory(
      t_ns = VALUE #( ( n = `uxap` v = `sap.uxap` ) ) ).

    DATA(lo_shell) = lo_view->shell( ).
    DATA(lo_page) = lo_shell->page(
      title          = mv_title
      shownavbutton  = client->check_app_prev_stack( )
      navbuttonpress = client->_event( cs_event-back ) ).
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

    "actions - Edit / Save / Cancel / Delete buttons
    DATA(lo_actions) = lo_ht->actions( ns = `uxap` ).
    IF mv_editable = abap_false.
      lo_actions->button(
        text  = `Edit`
        press = client->_event( cs_event-edit )
        type  = `Emphasized`
        icon  = `sap-icon://edit` ).
      lo_actions->button(
        text  = `Delete`
        press = client->_event( cs_event-delete )
        type  = `Reject`
        icon  = `sap-icon://delete` ).
    ELSE.
      lo_actions->button(
        text  = `Save`
        press = client->_event( cs_event-save )
        type  = `Emphasized`
        icon  = `sap-icon://save` ).
      lo_actions->button(
        text  = `Cancel`
        press = client->_event( cs_event-cancel )
        icon  = `sap-icon://decline` ).
    ENDIF.

    "expanded content - show subtitle/description
    IF ms_entity-header_info-description_field IS NOT INITIAL.
      FIELD-SYMBOLS <lv_d> TYPE any.
      ASSIGN COMPONENT ms_entity-header_info-description_field OF STRUCTURE ms_data->* TO <lv_d>.
      IF sy-subrc = 0 AND <lv_d> IS NOT INITIAL.
        lo_ht->expanded_content( ns = `uxap` )->label( CONV #( <lv_d> ) ).
        lo_ht->snapped_content( ns = `uxap` )->label( CONV #( <lv_d> ) ).
      ENDIF.
    ENDIF.

    "===== HEADER CONTENT (key attributes + data points) =====
    DATA(lo_hc) = lo_op->header_content( ns = `uxap` ).
    DATA(lo_hbox) = lo_hc->flex_box( wrap = `Wrap` fitcontainer = abap_true ).

    "identification fields as header attributes
    LOOP AT get_identification_fields( ) INTO DATA(ls_id).
      DATA(lv_val_str) = get_field_value( ls_id ).
      IF lv_val_str IS NOT INITIAL.
        lo_hbox->vbox( `sapUiSmallMarginEnd sapUiSmallMarginBottom`
          )->label( text = ls_id-label
          )->text( lv_val_str
          )->get_parent( ).
      ENDIF.
    ENDLOOP.

    "@UI.dataPoint fields as status attributes with criticality
    LOOP AT get_datapoint_fields( ) INTO DATA(ls_dp).
      lv_val_str = get_field_value( ls_dp ).
      IF lv_val_str IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_state) = `None`.
      IF ls_dp-datapoint_crit_field IS NOT INITIAL.
        lv_state = get_criticality_state( get_crit_value( ls_dp-datapoint_crit_field ) ).
      ENDIF.
      lo_hbox->vbox( `sapUiSmallMarginEnd sapUiSmallMarginBottom`
        )->label( text = ls_dp-label
        )->object_status(
            text  = lv_val_str
            state = lv_state
        )->get_parent( ).
    ENDLOOP.

    "===== SECTIONS =====
    DATA(lo_sections) = lo_op->sections( ).

    LOOP AT get_sections( ) INTO DATA(ls_section).
      DATA(lo_section) = lo_sections->object_page_section(
        titleuppercase = abap_false
        title          = ls_section-title ).

      DATA(lo_sub_sections) = lo_section->sub_sections( ).
      DATA(lo_sub) = lo_sub_sections->object_page_sub_section(
        title     = ls_section-title
        showtitle = abap_false ).
      DATA(lo_blocks) = lo_sub->blocks( ).

      render_section_form(
        io_parent = lo_blocks
        iv_group  = ls_section-field_group
        client    = client ).
    ENDLOOP.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_section_form.

    DATA(lo_form) = io_parent->simple_form(
      class     = `sapUxAPObjectPageSubSectionAlignContent`
      editable  = mv_editable
      layout    = `ColumnLayout`
      columnsm  = `2`
      columnsl  = `3`
      columnsxl = `4` ).

    "collect and sort fields for this group
    "(empty group = fields without any fieldGroup annotation)
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

      "=== EDIT MODE: render input controls ===
      IF mv_editable = abap_true.

        IF ls_field-is_boolean = abap_true.
          lo_form->checkbox(
            selected = client->_bind_edit( <field> )
            text     = `` ).
        ELSEIF ls_field-type_kind = `DATS`.
          lo_form->date_picker(
            value = client->_bind_edit( <field> ) ).
        ELSEIF ls_field-is_multiline = abap_true.
          lo_form->text_area(
            value = client->_bind_edit( <field> )
            rows  = `4`
            width = `100%` ).
        ELSE.
          lo_form->input(
            value = client->_bind_edit( <field> ) ).
        ENDIF.

      "=== DISPLAY MODE: render read-only controls ===
      ELSE.

        DATA(lv_display_val) = format_value( is_field = ls_field
                                             val      = <field> ).

        "criticality -> ObjectStatus
        IF ls_field-datapoint_crit_field IS NOT INITIAL.
          lo_form->object_status(
            text  = lv_display_val
            state = get_criticality_state( get_crit_value( ls_field-datapoint_crit_field ) ) ).

        "amount + currency -> ObjectNumber
        ELSEIF ls_field-is_amount_field = abap_true
          AND ls_field-semantics_currency_code IS NOT INITIAL.
          DATA(ls_currency) = VALUE z2ui5_cl_cds_util=>ty_s_field_info(
            name = ls_field-semantics_currency_code ).
          lo_form->object_number(
            number     = lv_display_val
            unit       = get_field_value( ls_currency )
            emphasized = abap_false ).

        "quantity + unit -> ObjectNumber
        ELSEIF ls_field-is_quantity_field = abap_true
          AND ls_field-semantics_unit_of_measure IS NOT INITIAL.
          DATA(ls_unit) = VALUE z2ui5_cl_cds_util=>ty_s_field_info(
            name = ls_field-semantics_unit_of_measure ).
          lo_form->object_number(
            number     = lv_display_val
            unit       = get_field_value( ls_unit )
            emphasized = abap_false ).

        ELSE.
          lo_form->text( lv_display_val ).
        ENDIF.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
