# cds-wrapper

Display CDS Artefacts with abap2UI5

### CDS Popup

##### Popup Definition 
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

##### abap2UI5 Popup Call
```abap
  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).

      DATA(lo_popup) = NEW z2ui5_cl_cds_popup( value z2ui5_cds_test_popup(
        SearchCountry = `USA`
      ) ).
      client->nav_app_call( CAST #( lo_popup ) ).
      RETURN.

    ENDIF.

    lo_popup = CAST #( client->get_app_prev( ) ).
    data(ls_cds_result) = lo_popup->result( )->*.

  ENDMETHOD.
```

### CDS Value Help

##### Value Help Definition 

##### abap2UI5 Value Help Call

### CDS List Report

Renders a Fiori-Elements-style list report for any CDS view, driven entirely by its annotations:
- Columns from `@UI.lineItem` (position, label, importance-based responsive popin)
- Filter bar from `@UI.selectionField` (contains-search for text fields, `*` wildcards supported)
- Criticality columns from `@UI.lineItem.criticality` / `@UI.dataPoint.criticality`
- Amount/quantity columns from `@Semantics.amount.currencyCode` / `@Semantics.quantity.unitOfMeasure`
- Title from `@UI.headerInfo.typeNamePlural`, live row count
- Row navigation to a generated object page (row matched via `@ObjectModel.semanticKey`)

##### abap2UI5 List Report Call
```abap
client->nav_app_call( NEW z2ui5_cl_cds_list_report(
  cds_view_name = `I_COUNTRY`
  title         = `Countries`
  max_rows      = 500 ) ).
```

### CDS Object Page

Renders an object page for a single record of a CDS entity:
- Header title/description from `@UI.headerInfo`
- Header attributes from `@UI.identification` (fallback: first visible fields)
- Status attributes with criticality from `@UI.dataPoint`
- Sections from `@UI.facet` fieldGroup references (order + labels), fallback to `@UI.fieldGroup` qualifiers
- User-format dates/times, Yes/No booleans, amounts/quantities with unit via `@Semantics`

##### abap2UI5 Object Page Call
```abap
"val: any structure typed after the CDS entity
client->nav_app_call( NEW z2ui5_cl_cds_object_page( val = ls_row ) ).
```
