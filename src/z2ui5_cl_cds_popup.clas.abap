CLASS z2ui5_cl_cds_popup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.
    METHODS constructor
      IMPORTING
        val TYPE data.

    DATA ms_cds TYPE REF TO data.

    METHODS result
      RETURNING
        VALUE(result) TYPE REF TO data.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_cds_popup IMPLEMENTATION.

  METHOD constructor.
    ms_cds = REF #( val ).
  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    DATA(lo_cds) = xco_cds=>view( `Z2UI5_CDS_TEST_POPUP` ).

    IF lo_cds->exists( ).
      DATA(es_content) = lo_cds->content( )->get( ).
      DATA(et_fields) = lo_cds->fields->all->get( ).

      DATA(lo_field) = et_fields[ 1 ].
      DATA(lo_field_content) = lo_field->content( ).

    ENDIF.


    DATA(lo_view_entity_field) = xco_cp_cds=>view_entity( 'Z2UI5_CDS_TEST_POPUP'
      )->field( 'SearchCountry' ).

    DATA(lt_anno) = xco_cp_cds=>annotations->direct->of( lo_view_entity_field )->get( ).
    DATA(lo_anno) = lt_anno[ 1 ].
    DATA(lo_prop) =  lo_anno->get_property( ).
    DATA(lo_val) = lo_anno->get_value( ).
    DATA lv_val TYPE string.
    lo_val->write_to( ia_value = REF #( lv_val ) ).


*    lo_cds->
*    DATA(lo_anno) = xco_cds=>annotations( `Z2UI5_CDS_TEST_POPUP` ).

  ENDMETHOD.

  METHOD result.
    result = ms_cds.
  ENDMETHOD.

ENDCLASS.
