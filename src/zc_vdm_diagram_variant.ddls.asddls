@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VDM Diagram Variant Projection'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZC_VDM_Diagram_Variant
  provider contract transactional_query
  as projection on ZR_VDM_Diagram_Variant_TP
{
  key VariantId,
      VariantName,
      CdsName,
      CreatedBy,
      CreatedAt,
      LastChangedAt,
      LocalLastChangedAt,
      IsGlobal,
      
      @UI.hidden: true
      Configuration
}
