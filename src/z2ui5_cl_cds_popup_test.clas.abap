CLASS z2ui5_cl_cds_popup_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.
    DATA ls_cds TYPE z2ui5_cds_test_popup.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_cds_popup_test IMPLEMENTATION.




  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).

      ls_cds-SearchCountry = `USA`.
      DATA(lo_popup) = NEW z2ui5_cl_cds_popup( ls_cds ).
      client->nav_app_call( CAST #( lo_popup ) ).
      RETURN.

    ENDIF.

    "read result
    lo_popup = CAST #( client->get_app_prev( ) ).
    DATA(lr_result) = lo_popup->result( ).
    ls_cds = lr_result->*.

  ENDMETHOD.

ENDCLASS.
