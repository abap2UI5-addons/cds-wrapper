CLASS z2ui5_cl_cds_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "======= FIELD-LEVEL TYPES =======

    TYPES:
      BEGIN OF ty_s_additional_binding,
        element       TYPE string,
        local_element TYPE string,
        usage         TYPE string,
      END OF ty_s_additional_binding.

    TYPES ty_t_additional_binding TYPE STANDARD TABLE OF ty_s_additional_binding WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_value_help,
        entity_name        TYPE string,
        element            TYPE string,
        is_dropdown        TYPE abap_bool,
        additional_binding TYPE ty_t_additional_binding,
      END OF ty_s_value_help.

    TYPES:
      BEGIN OF ty_s_field_info,
        "identification
        name               TYPE string,
        label              TYPE string,
        tooltip            TYPE string,
        is_key             TYPE abap_bool,

        "ABAP type info
        type_kind          TYPE string,
        abap_type          TYPE string,
        data_element       TYPE string,
        length             TYPE i,
        decimals           TYPE i,
        is_boolean         TYPE abap_bool,

        "UI annotations
        is_hidden          TYPE abap_bool,
        is_mandatory       TYPE abap_bool,
        is_multiline       TYPE abap_bool,
        is_visible         TYPE abap_bool,
        is_searchable      TYPE abap_bool,
        is_high_importance TYPE abap_bool,
        default_value      TYPE string,
        text_element       TYPE string,

        "fieldGroup
        field_group        TYPE string,
        field_group_pos    TYPE i,

        "lineItem
        line_item_pos      TYPE i,
        line_item_importance TYPE string,
        line_item_crit_field TYPE string,
        line_item_label    TYPE string,

        "selectionField
        selection_field_pos TYPE i,
        is_selection_field  TYPE abap_bool,

        "identification
        identification_pos TYPE i,
        is_identification  TYPE abap_bool,

        "dataPoint
        datapoint_qualifier  TYPE string,
        datapoint_crit_field TYPE string,

        "semantics
        semantics_currency_code TYPE string,
        semantics_unit_of_measure TYPE string,
        is_currency_field  TYPE abap_bool,
        is_unit_field      TYPE abap_bool,
        is_amount_field    TYPE abap_bool,
        is_quantity_field   TYPE abap_bool,

        "value help
        value_help         TYPE ty_s_value_help,
      END OF ty_s_field_info.

    TYPES ty_t_field_info TYPE STANDARD TABLE OF ty_s_field_info WITH DEFAULT KEY.

    "======= ENTITY-LEVEL TYPES =======

    TYPES:
      BEGIN OF ty_s_facet,
        id               TYPE string,
        parent_id        TYPE string,
        type             TYPE string,
        label            TYPE string,
        target_qualifier TYPE string,
        position         TYPE i,
        purpose          TYPE string,
      END OF ty_s_facet.

    TYPES ty_t_facet TYPE STANDARD TABLE OF ty_s_facet WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_header_info,
        type_name        TYPE string,
        type_name_plural TYPE string,
        title_field      TYPE string,
        description_field TYPE string,
        image_field      TYPE string,
      END OF ty_s_header_info.

    TYPES:
      BEGIN OF ty_s_annotation,
        key   TYPE string,
        value TYPE string,
      END OF ty_s_annotation.

    TYPES ty_t_annotation TYPE STANDARD TABLE OF ty_s_annotation WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_entity_info,
        "identification
        name            TYPE string,
        description     TYPE string,
        entity_type     TYPE string,

        "key metadata
        is_dropdown     TYPE abap_bool,
        is_searchable   TYPE abap_bool,
        semantic_key    TYPE string_table,

        "structure
        fields          TYPE ty_t_field_info,
        facets          TYPE ty_t_facet,
        header_info     TYPE ty_s_header_info,

        "raw annotations (entity-level)
        entity_annotations TYPE ty_t_annotation,
      END OF ty_s_entity_info.

    "======= PUBLIC METHODS =======

    "! Read full metadata for a CDS entity (abstract entity, view entity, etc.)
    CLASS-METHODS read_entity
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_entity_info.

    "! Read entity-level annotations only (no field details)
    CLASS-METHODS read_entity_annotations
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_entity_info.

    "! Read annotations for a single field
    CLASS-METHODS read_field_annotations
      IMPORTING
        entity_name   TYPE clike
        field_name    TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_annotation.

    "! Check if a CDS entity has sizeCategory #XS
    CLASS-METHODS is_size_category_xs
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Get list of key fields for an entity
    CLASS-METHODS get_key_fields
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE string_table.

    "! Get all annotations for an entity (raw key-value pairs)
    CLASS-METHODS get_all_annotations
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_annotation.

  PRIVATE SECTION.

    CLASS-METHODS strip_quotes
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS detect_boolean
      IMPORTING
        io_elem       TYPE REF TO cl_abap_elemdescr
        field_name    TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS parse_field_annotations
      IMPORTING
        it_annos      TYPE cl_dd_ddl_annotation_service=>ty_t_anno_value
      CHANGING
        cs_field      TYPE ty_s_field_info.

ENDCLASS.



CLASS z2ui5_cl_cds_util IMPLEMENTATION.

  METHOD read_entity.

    DATA(lv_name) = to_upper( entity_name ).
    result-name = lv_name.

    DATA(lv_entity) = CONV ddstrucobjname( lv_name ).

    "======= ENTITY-LEVEL ANNOTATIONS =======
    TRY.
        cl_dd_ddl_annotation_service=>get_direct_annos_4_entity(
          EXPORTING entityname = lv_entity
          IMPORTING annos      = DATA(lt_entity_annos) ).

        LOOP AT lt_entity_annos INTO DATA(ls_ea).
          DATA(lv_ea_key) = CONV string( ls_ea-annoname ).
          DATA(lv_ea_val) = CONV string( ls_ea-value ).

          "store raw annotation
          APPEND VALUE ty_s_annotation( key = lv_ea_key value = lv_ea_val )
            TO result-entity_annotations.

          "sizeCategory
          IF lv_ea_key CS `OBJECTMODEL.RESULTSET.SIZECATEGORY` AND lv_ea_val CS `XS`.
            result-is_dropdown = abap_true.
          ENDIF.

          "searchable
          IF lv_ea_key = `SEARCH.SEARCHABLE` AND lv_ea_val = `true`.
            result-is_searchable = abap_true.
          ENDIF.

          "description
          IF lv_ea_key = `ENDUSERTEXT.LABEL`.
            result-description = lv_ea_val.
          ENDIF.

          "@UI.headerInfo
          IF lv_ea_key = `UI.HEADERINFO.TYPENAME`.
            result-header_info-type_name = lv_ea_val.
          ENDIF.
          IF lv_ea_key = `UI.HEADERINFO.TYPENAMEPLURAL`.
            result-header_info-type_name_plural = lv_ea_val.
          ENDIF.
          IF lv_ea_key = `UI.HEADERINFO.TITLE.VALUE`.
            result-header_info-title_field = strip_quotes( lv_ea_val ).
          ENDIF.
          IF lv_ea_key = `UI.HEADERINFO.DESCRIPTION.VALUE`.
            result-header_info-description_field = strip_quotes( lv_ea_val ).
          ENDIF.
          IF lv_ea_key = `UI.HEADERINFO.IMAGEURL.VALUE`.
            result-header_info-image_field = strip_quotes( lv_ea_val ).
          ENDIF.

          "@ObjectModel.semanticKey
          IF lv_ea_key CS `OBJECTMODEL.SEMANTICKEY`.
            APPEND strip_quotes( lv_ea_val ) TO result-semantic_key.
          ENDIF.

          "@UI.facet
          IF lv_ea_key CS `UI.FACET$`.
            DATA(lv_facet_idx) = 0.
            DATA(lv_after_facet) = lv_ea_key.
            REPLACE `UI.FACET$` IN lv_after_facet WITH ``.
            DATA(lv_dollar_pos) = find( val = lv_after_facet sub = `$` ).
            IF lv_dollar_pos > 0.
              lv_facet_idx = CONV i( lv_after_facet(lv_dollar_pos) ).
            ENDIF.

            IF lv_facet_idx > 0.
              WHILE lines( result-facets ) < lv_facet_idx.
                APPEND INITIAL LINE TO result-facets.
              ENDWHILE.
              IF lv_ea_key CS `.ID`.
                result-facets[ lv_facet_idx ]-id = strip_quotes( lv_ea_val ).
              ENDIF.
              IF lv_ea_key CS `.PARENTID`.
                result-facets[ lv_facet_idx ]-parent_id = strip_quotes( lv_ea_val ).
              ENDIF.
              IF lv_ea_key CS `.TYPE`.
                result-facets[ lv_facet_idx ]-type = strip_quotes( lv_ea_val ).
              ENDIF.
              IF lv_ea_key CS `.LABEL`.
                result-facets[ lv_facet_idx ]-label = lv_ea_val.
              ENDIF.
              IF lv_ea_key CS `.TARGETQUALIFIER`.
                result-facets[ lv_facet_idx ]-target_qualifier = strip_quotes( lv_ea_val ).
              ENDIF.
              IF lv_ea_key CS `.POSITION`.
                result-facets[ lv_facet_idx ]-position = CONV i( lv_ea_val ).
              ENDIF.
              IF lv_ea_key CS `.PURPOSE`.
                result-facets[ lv_facet_idx ]-purpose = strip_quotes( lv_ea_val ).
              ENDIF.
            ENDIF.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.

    "======= FIELD-LEVEL METADATA =======
    DATA lv_has_display_anno TYPE abap_bool.

    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( lv_name ) ).
        DATA(lt_comps) = lo_descr->get_components( ).

        "detect entity type from type descriptor
        DATA(lv_abs_name) = lo_descr->absolute_name.
        IF lv_abs_name CS `\TYPE=`.
          result-entity_type = `STRUCTURE`.
        ELSE.
          result-entity_type = `VIEW`.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    "get key fields from DDIC
    DATA(lt_keys) = get_key_fields( lv_name ).

    LOOP AT lt_comps INTO DATA(ls_comp).
      DATA(ls_field) = VALUE ty_s_field_info(
        name       = ls_comp-name
        is_visible = abap_true ).

      "check if key field
      IF line_exists( lt_keys[ table_line = ls_comp-name ] ).
        ls_field-is_key = abap_true.
      ENDIF.

      "RTTI type analysis
      IF ls_comp-type->kind = cl_abap_typedescr=>kind_elem.
        DATA(lo_elem) = CAST cl_abap_elemdescr( ls_comp-type ).
        CASE lo_elem->type_kind.
          WHEN cl_abap_typedescr=>typekind_date.
            ls_field-type_kind = `DATS`.
          WHEN cl_abap_typedescr=>typekind_time.
            ls_field-type_kind = `TIMS`.
          WHEN cl_abap_typedescr=>typekind_int
            OR cl_abap_typedescr=>typekind_int1
            OR cl_abap_typedescr=>typekind_int2
            OR cl_abap_typedescr=>typekind_int8.
            ls_field-type_kind = `INT`.
          WHEN cl_abap_typedescr=>typekind_packed
            OR cl_abap_typedescr=>typekind_decfloat16
            OR cl_abap_typedescr=>typekind_decfloat34.
            ls_field-type_kind = `DEC`.
          WHEN cl_abap_typedescr=>typekind_string.
            ls_field-type_kind = `STRING`.
          WHEN OTHERS.
            ls_field-type_kind = `CHAR`.
        ENDCASE.
        ls_field-length = lo_elem->output_length.
        ls_field-decimals = lo_elem->decimals.
        ls_field-is_boolean = detect_boolean( io_elem = lo_elem field_name = ls_comp-name ).

        "data element name
        DATA(lv_abs) = lo_elem->absolute_name.
        IF lv_abs CS `\TYPE=`.
          ls_field-data_element = lv_abs+6.
        ENDIF.

        "abap type descriptor
        ls_field-abap_type = lo_elem->get_relative_name( ).
      ENDIF.

      "read field annotations
      DATA(lv_fieldname) = CONV ddfieldname_l( ls_comp-name ).
      cl_dd_ddl_annotation_service=>get_direct_annos_4_element(
        EXPORTING
          entityname  = lv_entity
          elementname = lv_fieldname
        IMPORTING
          annos       = DATA(lt_annos) ).

      parse_field_annotations( EXPORTING it_annos = lt_annos
                               CHANGING  cs_field = ls_field ).

      "check display annotation flag
      LOOP AT lt_annos INTO DATA(ls_check)
        WHERE annoname = `CONSUMPTION.VALUEHELPDEFAULT.DISPLAY`.
        lv_has_display_anno = abap_true.
      ENDLOOP.

      "check VH entity for dropdown
      IF ls_field-value_help-entity_name IS NOT INITIAL.
        ls_field-value_help-is_dropdown = is_size_category_xs( ls_field-value_help-entity_name ).
      ENDIF.

      IF ls_field-label IS INITIAL.
        ls_field-label = ls_field-name.
      ENDIF.

      APPEND ls_field TO result-fields.
    ENDLOOP.

    "if no display annotations found, all fields are visible
    IF lv_has_display_anno = abap_false.
      LOOP AT result-fields ASSIGNING FIELD-SYMBOL(<ls_f>).
        <ls_f>-is_visible = abap_true.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD parse_field_annotations.

    LOOP AT it_annos INTO DATA(ls_anno).
      DATA(lv_key) = CONV string( ls_anno-annoname ).
      DATA(lv_val) = CONV string( ls_anno-value ).

      "@EndUserText.label
      IF lv_key = `ENDUSERTEXT.LABEL`.
        cs_field-label = lv_val.
      ENDIF.

      "@EndUserText.quickInfo
      IF lv_key = `ENDUSERTEXT.QUICKINFO`.
        cs_field-tooltip = lv_val.
      ENDIF.

      "@UI.hidden
      IF lv_key = `UI.HIDDEN` AND lv_val = `true`.
        cs_field-is_hidden = abap_true.
      ENDIF.

      "@UI.multiLineText
      IF lv_key = `UI.MULTILINETEXT` AND lv_val = `true`.
        cs_field-is_multiline = abap_true.
      ENDIF.

      "@UI.defaultValue
      IF lv_key = `UI.DEFAULTVALUE`.
        cs_field-default_value = strip_quotes( lv_val ).
      ENDIF.

      "@ObjectModel.mandatory
      IF lv_key = `OBJECTMODEL.MANDATORY` AND lv_val = `true`.
        cs_field-is_mandatory = abap_true.
      ENDIF.

      "@Consumption.valueHelpDefault.display
      IF lv_key = `CONSUMPTION.VALUEHELPDEFAULT.DISPLAY`.
        cs_field-is_visible = xsdbool( lv_val = `true` ).
      ENDIF.

      "@Search.defaultSearchElement
      IF lv_key = `SEARCH.DEFAULTSEARCHELEMENT` AND lv_val = `true`.
        cs_field-is_searchable = abap_true.
      ENDIF.

      "@UI.lineItem importance
      IF lv_key CS `UI.LINEITEM` AND lv_key CS `.IMPORTANCE`.
        IF lv_val CS `HIGH`.
          cs_field-is_high_importance = abap_true.
        ENDIF.
        cs_field-line_item_importance = strip_quotes( lv_val ).
      ENDIF.

      "@ObjectModel.text.element
      IF lv_key = `OBJECTMODEL.TEXT.ELEMENT`.
        cs_field-text_element = lv_val.
      ENDIF.

      "@UI.fieldGroup
      IF lv_key CS `UI.FIELDGROUP` AND lv_key CS `.QUALIFIER`.
        cs_field-field_group = strip_quotes( lv_val ).
      ENDIF.
      IF lv_key CS `UI.FIELDGROUP` AND lv_key CS `.POSITION`.
        cs_field-field_group_pos = CONV i( lv_val ).
      ENDIF.

      "@UI.lineItem
      IF lv_key CS `UI.LINEITEM` AND lv_key CS `.POSITION`.
        cs_field-line_item_pos = CONV i( lv_val ).
      ENDIF.
      IF lv_key CS `UI.LINEITEM` AND lv_key CS `.CRITICALITY`.
        cs_field-line_item_crit_field = strip_quotes( lv_val ).
      ENDIF.
      IF lv_key CS `UI.LINEITEM` AND lv_key CS `.LABEL`.
        cs_field-line_item_label = lv_val.
      ENDIF.

      "@UI.selectionField
      IF lv_key CS `UI.SELECTIONFIELD` AND lv_key CS `.POSITION`.
        cs_field-is_selection_field = abap_true.
        cs_field-selection_field_pos = CONV i( lv_val ).
      ENDIF.

      "@UI.identification
      IF lv_key CS `UI.IDENTIFICATION` AND lv_key CS `.POSITION`.
        cs_field-is_identification = abap_true.
        cs_field-identification_pos = CONV i( lv_val ).
      ENDIF.

      "@UI.dataPoint
      IF lv_key CS `UI.DATAPOINT` AND lv_key CS `.QUALIFIER`.
        cs_field-datapoint_qualifier = strip_quotes( lv_val ).
      ENDIF.
      IF lv_key CS `UI.DATAPOINT` AND lv_key CS `.CRITICALITY`.
        cs_field-datapoint_crit_field = strip_quotes( lv_val ).
      ENDIF.

      "@Semantics.amount.currencyCode
      IF lv_key = `SEMANTICS.AMOUNT.CURRENCYCODE`.
        cs_field-semantics_currency_code = strip_quotes( lv_val ).
        cs_field-is_amount_field = abap_true.
      ENDIF.

      "@Semantics.quantity.unitOfMeasure
      IF lv_key = `SEMANTICS.QUANTITY.UNITOFMEASURE`.
        cs_field-semantics_unit_of_measure = strip_quotes( lv_val ).
        cs_field-is_quantity_field = abap_true.
      ENDIF.

      "@Semantics.currencyCode
      IF lv_key = `SEMANTICS.CURRENCYCODE` AND lv_val = `true`.
        cs_field-is_currency_field = abap_true.
      ENDIF.

      "@Semantics.unitOfMeasure
      IF lv_key = `SEMANTICS.UNITOFMEASURE` AND lv_val = `true`.
        cs_field-is_unit_field = abap_true.
      ENDIF.

      "@Consumption.valueHelpDefinition - entity
      IF lv_key CS `CONSUMPTION.VALUEHELPDEFINITION`
        AND lv_key CS `.ENTITY.NAME`.
        cs_field-value_help-entity_name = strip_quotes( lv_val ).
      ENDIF.
      IF lv_key CS `CONSUMPTION.VALUEHELPDEFINITION`
        AND lv_key CS `.ENTITY.ELEMENT`.
        cs_field-value_help-element = strip_quotes( lv_val ).
      ENDIF.

      "@Consumption.valueHelpDefinition - additionalBinding
      IF lv_key CS `CONSUMPTION.VALUEHELPDEFINITION`
        AND lv_key CS `.ADDITIONALBINDING`
        AND lv_key CS `.ELEMENT`
        AND NOT ( lv_key CS `.LOCALELEMENT` ).
        DATA(ls_binding) = VALUE ty_s_additional_binding( ).
        ls_binding-element = strip_quotes( lv_val ).
        APPEND ls_binding TO cs_field-value_help-additional_binding.
      ENDIF.
      IF lv_key CS `CONSUMPTION.VALUEHELPDEFINITION`
        AND lv_key CS `.ADDITIONALBINDING`
        AND lv_key CS `.LOCALELEMENT`.
        IF lines( cs_field-value_help-additional_binding ) > 0.
          DATA(lv_last_idx) = lines( cs_field-value_help-additional_binding ).
          cs_field-value_help-additional_binding[ lv_last_idx ]-local_element = strip_quotes( lv_val ).
        ENDIF.
      ENDIF.
      IF lv_key CS `CONSUMPTION.VALUEHELPDEFINITION`
        AND lv_key CS `.ADDITIONALBINDING`
        AND lv_key CS `.USAGE`.
        IF lines( cs_field-value_help-additional_binding ) > 0.
          lv_last_idx = lines( cs_field-value_help-additional_binding ).
          cs_field-value_help-additional_binding[ lv_last_idx ]-usage = strip_quotes( lv_val ).
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD read_entity_annotations.
    DATA(lv_name) = to_upper( entity_name ).
    result-name = lv_name.
    TRY.
        cl_dd_ddl_annotation_service=>get_direct_annos_4_entity(
          EXPORTING entityname = CONV #( lv_name )
          IMPORTING annos      = DATA(lt_annos) ).
        LOOP AT lt_annos INTO DATA(ls_anno).
          APPEND VALUE ty_s_annotation(
            key = CONV string( ls_anno-annoname )
            value = CONV string( ls_anno-value ) ) TO result-entity_annotations.
          IF ls_anno-annoname CS `OBJECTMODEL.RESULTSET.SIZECATEGORY`.
            DATA(lv_val) = CONV string( ls_anno-value ).
            IF lv_val CS `XS`.
              result-is_dropdown = abap_true.
            ENDIF.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD read_field_annotations.
    TRY.
        cl_dd_ddl_annotation_service=>get_direct_annos_4_element(
          EXPORTING
            entityname  = CONV #( to_upper( entity_name ) )
            elementname = CONV #( to_upper( field_name ) )
          IMPORTING
            annos       = DATA(lt_annos) ).
        LOOP AT lt_annos INTO DATA(ls_anno).
          APPEND VALUE ty_s_annotation(
            key   = CONV string( ls_anno-annoname )
            value = CONV string( ls_anno-value ) ) TO result.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD get_key_fields.
    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( to_upper( entity_name ) ) ).
        "key fields: first components that form the key (from DDIC)
        DATA(lt_comps) = lo_descr->get_components( ).
        "try reading keys from DD annotation
        DATA(lv_entity) = CONV ddstrucobjname( to_upper( entity_name ) ).
        cl_dd_ddl_annotation_service=>get_direct_annos_4_entity(
          EXPORTING entityname = lv_entity
          IMPORTING annos      = DATA(lt_annos) ).
        LOOP AT lt_annos INTO DATA(ls_anno)
          WHERE annoname CS `OBJECTMODEL.SEMANTICKEY`.
          APPEND strip_quotes( CONV string( ls_anno-value ) ) TO result.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD get_all_annotations.
    "read entity-level
    TRY.
        cl_dd_ddl_annotation_service=>get_direct_annos_4_entity(
          EXPORTING entityname = CONV #( to_upper( entity_name ) )
          IMPORTING annos      = DATA(lt_ea) ).
        LOOP AT lt_ea INTO DATA(ls_ea).
          APPEND VALUE ty_s_annotation(
            key   = |ENTITY.{ ls_ea-annoname }|
            value = CONV string( ls_ea-value ) ) TO result.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.

    "read field-level
    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( to_upper( entity_name ) ) ).
        LOOP AT lo_descr->get_components( ) INTO DATA(ls_comp).
          cl_dd_ddl_annotation_service=>get_direct_annos_4_element(
            EXPORTING
              entityname  = CONV #( to_upper( entity_name ) )
              elementname = CONV #( ls_comp-name )
            IMPORTING
              annos       = DATA(lt_fa) ).
          LOOP AT lt_fa INTO DATA(ls_fa).
            APPEND VALUE ty_s_annotation(
              key   = |{ ls_comp-name }.{ ls_fa-annoname }|
              value = CONV string( ls_fa-value ) ) TO result.
          ENDLOOP.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD is_size_category_xs.
    TRY.
        cl_dd_ddl_annotation_service=>get_direct_annos_4_entity(
          EXPORTING entityname = CONV #( to_upper( entity_name ) )
          IMPORTING annos      = DATA(lt_annos) ).
        LOOP AT lt_annos INTO DATA(ls_anno).
          IF ls_anno-annoname CS `OBJECTMODEL.RESULTSET.SIZECATEGORY`.
            DATA(lv_val) = CONV string( ls_anno-value ).
            IF lv_val CS `XS`.
              result = abap_true.
              RETURN.
            ENDIF.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD strip_quotes.
    result = val.
    CONDENSE result.
    IF result IS NOT INITIAL.
      IF result(1) = `'`.
        result = result+1.
      ENDIF.
      DATA(lv_len) = strlen( result ) - 1.
      IF lv_len >= 0 AND result+lv_len(1) = `'`.
        result = result(lv_len).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD detect_boolean.
    DATA(lv_rel_name) = io_elem->get_relative_name( ).
    IF lv_rel_name = `ABAP_BOOLEAN` OR lv_rel_name = `XSDBOOLEAN`
      OR lv_rel_name = `BOOLE_D` OR lv_rel_name = `XFELD`
      OR lv_rel_name = `ABAP_BOOL` OR lv_rel_name = `FLAG`.
      result = abap_true.
      RETURN.
    ENDIF.
    result = abap_false.
  ENDMETHOD.

ENDCLASS.
