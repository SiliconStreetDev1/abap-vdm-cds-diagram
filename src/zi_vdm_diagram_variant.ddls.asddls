@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VDM Diagram Variant Base View'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_VDM_Diagram_Variant
  as select from zvdm_diag_var
{
  key variant_id as VariantId,
  variant_name as VariantName,
  cds_name as CdsName,
  @Semantics.user.createdBy: true
  created_by as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at as CreatedAt,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at as LastChangedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at as LocalLastChangedAt,
  is_global as IsGlobal,
    is_unlisted as  isUnlisted,
  configuration as Configuration
}
