@EndUserText.label: 'CDS Search Value Help for VDM'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_VDM_DIAGRAM_CDS_SEARCH'
@Search.searchable: true
define custom entity ZCE_VDM_DIAGRAM_CDS_SEARCH
{
      @UI.lineItem:       [ { position: 10, label: 'CDS View Name' } ]
      @UI.selectionField: [ { position: 10 } ]
      @EndUserText.label: 'CDS View Name'
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
  key CdsName : sxco_cds_object_name;
}
