@EndUserText.label: 'Entity for popup'
define abstract entity z2ui5_cds_test_popup
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Country', element: 'Country' } }]
  @EndUserText.label: 'Country'
  @EndUserText.quickInfo: 'Select a country from the list'
  SearchCountry : land1;

  @EndUserText.label: 'Valid To'
  @UI.defaultValue: '99991231'
  NewDate       : abap.dats;

  @EndUserText.label: 'Message Type'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_MessageSeverity', element: 'Severity' } }]
  MessageType   : abap.int4;

  @EndUserText.label: 'Update data'
  FlagUpdate    : abap.char(1);

  @EndUserText.label: 'Show Messages'
  FlagMessage   : abap_boolean;

  @EndUserText.label: 'Description'
  @UI.multiLineText: true
  Description   : abap.string(256);

  @UI.hidden: true
  InternalKey   : sysuuid_x16;
}
