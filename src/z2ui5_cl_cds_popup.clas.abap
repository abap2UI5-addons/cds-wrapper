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

    CREATE DATA ms_cds LIKE val.
    ms_cds->* = val.

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    DATA(lo_datadescr) = cl_abap_datadescr=>describe_by_data( ms_cds->* ).
    DATA(lv_name3) = lo_datadescr->get_relative_name( ).

    DATA(lo_cds) = xco_cds=>view( conv #( lv_name3 ) ).
    DATA(et_fields) = lo_cds->fields->all->get( ).

    DATA(lo_view_entity) = xco_cp_cds=>view_entity( conv #( lv_name3 ) ).

    LOOP AT et_fields INTO DATA(lo_field).

      DATA(lv_name) = lo_field->name.
      DATA(lo_view_entity_field) = lo_view_entity->field( lv_name ).

      DATA(lt_anno) = xco_cp_cds=>annotations->direct->of( lo_view_entity_field )->get( ).
      LOOP AT lt_anno INTO DATA(lo_anno).

        DATA(lv_prop) = lo_anno->get_property( ).
        CASE lv_prop.

          WHEN `ENDUSERTEXT.LABEL`.

            DATA(lo_val) = lo_anno->get_value( ).
            DATA lv_val TYPE string.
            lo_val->write_to( REF #( lv_val ) ).

        ENDCASE.

      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD result.
    result = ms_cds.
  ENDMETHOD.

ENDCLASS.
