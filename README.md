# cds-wrapper

Display CDS Artefacts with abap2UI5


#### CDS Popup
```cds
@EndUserText.label: 'Entity for popup'
define abstract entity z2ui5_cds_test_popup
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZBS_C_CountryVH', element: 'Country' } }]
  @EndUserText.label: 'Search Country'
  SearchCountry : land1;
  @EndUserText.label: 'New date'
  NewDate       : abap.dats;
  @EndUserText.label: 'Message type'
  MessageType   : abap.int4;
  @EndUserText.label: 'Update data'
  FlagUpdate    : abap.char(1);
  @EndUserText.label: 'Show Messages'
  FlagMessage   : abap_boolean;
}
```

#### abap2UI5 Popup Call
```abap
  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).

      data(ls_cds) = value z2ui5_cds_test_popup( SearchCountry = `USA` ).
      DATA(lo_popup) = NEW z2ui5_cl_cds_popup( ls_cds ).
      client->nav_app_call( CAST #( lo_popup ) ).
      RETURN.

    ENDIF.

    lo_popup = CAST #( client->get_app_prev( ) ).
    data(ls_cds_result) = lo_popup->result( )->*.

  ENDMETHOD.
```
