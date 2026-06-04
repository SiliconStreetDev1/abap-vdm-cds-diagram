@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VDM Diagram Variant Transactional Root'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZR_VDM_Diagram_Variant_TP
  as select from ZI_VDM_Diagram_Variant
{
  key VariantId,
  VariantName,
  CdsName,
  CreatedBy,
  CreatedAt,
  LastChangedAt,
  LocalLastChangedAt,
  IsGlobal,
  Configuration
}
