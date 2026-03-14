@EndUserText.label: 'VDM Diagrammer Custom Entity'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_VDM_DIAGRAM_QUERY'
define custom entity ZCE_VDM_DIAGRAM
{
      // Strict ABAP Cloud type ensures Fiori Search inputs are validated automatically
  key CdsName         : sxco_cds_object_name;
  key RendererEngine  : abap.char(20);

      //=== NEW ADVANCED CONFIGURATION PARAMETERS ===
      MaxLevel        : abap.int4;
      ShowBase        : abap_boolean;
      ShowKeys        : abap_boolean;
      ShowFields      : abap_boolean;
      ShowAssocFields : abap_boolean;
      CustomDevOnly   : abap_boolean;
      LineAssoc       : abap_boolean;
      LineComp        : abap_boolean;
      LineInherit     : abap_boolean;

      //Comma-separated strings for the whitelists/blacklists
      IncludeCds      : abap.string(0);
      ExcludeCds      : abap.string(0);

      // Outputs
      FileExtension   : abap.char(10);
      DiagramPayload  : abap.string(0);
}
