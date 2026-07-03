@EndUserText.label: 'Object Page Test Entity'
@UI.headerInfo: { typeName: 'Purchase Order',
                  typeNamePlural: 'Purchase Orders',
                  title: { value: 'OrderId' },
                  description: { value: 'CustomerName' } }
define abstract entity z2ui5_cds_test_op
{
  @UI.fieldGroup:[{ qualifier: 'General', position: 10 }]
  @UI.identification: [{ position: 10 }]
  @EndUserText.label: 'Order ID'
  OrderId      : abap.char(10);

  @UI.fieldGroup:[{ qualifier: 'General', position: 20 }]
  @UI.identification: [{ position: 20 }]
  @EndUserText.label: 'Customer'
  CustomerName : abap.char(40);

  @UI.fieldGroup:[{ qualifier: 'General', position: 30 }]
  @EndUserText.label: 'Priority'
  @UI.dataPoint: { qualifier: 'Priority', criticality: 'PriorityCrit' }
  Priority     : abap.char(10);

  @UI.hidden   : true
  PriorityCrit : abap.int4;

  @UI.fieldGroup:[{ qualifier: 'General', position: 40 }]
  @EndUserText.label: 'Status'
  @UI.dataPoint: { qualifier: 'Status', criticality: 'StatusCrit' }
  Status       : abap.char(20);

  @UI.hidden   : true
  StatusCrit   : abap.int4;

  @UI.fieldGroup:[{ qualifier: 'Dates', position: 10 }]
  @EndUserText.label: 'Order Date'
  OrderDate    : abap.dats;

  @UI.fieldGroup:[{ qualifier: 'Dates', position: 20 }]
  @EndUserText.label: 'Delivery Date'
  DeliveryDate : abap.dats;

  @UI.fieldGroup:[{ qualifier: 'Dates', position: 30 }]
  @EndUserText.label: 'Changed On'
  ChangedOn    : abap.dats;

  @UI.fieldGroup:[{ qualifier: 'Amounts', position: 10 }]
  @EndUserText.label: 'Net Amount'
  @Semantics.amount.currencyCode: 'Currency'
  NetAmount    : abap.dec(15,2);

  @UI.fieldGroup:[{ qualifier: 'Amounts', position: 20 }]
  @EndUserText.label: 'Tax Amount'
  @Semantics.amount.currencyCode: 'Currency'
  TaxAmount    : abap.dec(15,2);

  @UI.fieldGroup:[{ qualifier: 'Amounts', position: 30 }]
  @EndUserText.label: 'Gross Amount'
  @Semantics.amount.currencyCode: 'Currency'
  GrossAmount  : abap.dec(15,2);

  @UI.fieldGroup:[{ qualifier: 'Amounts', position: 40 }]
  @EndUserText.label: 'Currency'
  @Semantics.currencyCode: true
  Currency     : abap.cuky;

  @UI.fieldGroup:[{ qualifier: 'Admin', position: 10 }]
  @EndUserText.label: 'Created By'
  CreatedBy    : abap.char(12);

  @UI.fieldGroup:[{ qualifier: 'Admin', position: 20 }]
  @EndUserText.label: 'Created On'
  CreatedOn    : abap.dats;

  @UI.fieldGroup:[{ qualifier: 'Admin', position: 30 }]
  @EndUserText.label: 'Changed By'
  ChangedBy    : abap.char(12);

  @UI.fieldGroup:[{ qualifier: 'Notes', position: 10 }]
  @EndUserText.label: 'Notes'
  @UI.multiLineText: true
  Notes        : abap.string(1000);

  @UI.hidden   : true
  InternalGuid : sysuuid_x16;
}
