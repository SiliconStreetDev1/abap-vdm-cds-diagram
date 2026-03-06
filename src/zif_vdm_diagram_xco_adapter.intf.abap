interface ZIF_VDM_DIAGRAM_XCO_ADAPTER
  public .


  methods GET_CDS_TYPE
    importing
      !CDS_NAME type SXCO_CDS_OBJECT_NAME
    returning
      value(TYPE) type ZVDM_DIAGRAM_CDS_TYPE .
  methods GET_FIELDS
    importing
      !CDS_NAME type SXCO_CDS_OBJECT_NAME
    returning
      value(FIELDS) type SXCO_T_CDS_FIELDS .
  methods GET_ASSOCIATIONS
    importing
      !CDS_NAME type SXCO_CDS_OBJECT_NAME
    returning
      value(ASSOCIATIONS) type SXCO_T_CDS_ASSOCIATIONS .
  methods GET_COMPOSITIONS
    importing
      !CDS_NAME type SXCO_CDS_OBJECT_NAME
    returning
      value(COMPOSITIONS) type SXCO_T_CDS_COMPOSITIONS .
  methods GET_SOURCES
    importing
      !CDS_NAME type SXCO_CDS_OBJECT_NAME
    returning
      value(SOURCES) type SXCO_T_CDS_OBJECT_NAMES .
  methods GET_CDS_NAME_FROM_DDL
    importing
      !CDS_NAME type SXCO_CDS_OBJECT_NAME
    returning
      value(DDLCDS_NAME) type SXCO_CDS_OBJECT_NAME .
  methods GET_CARDINALITY
    importing
      !CDS_NAME type SXCO_CDS_OBJECT_NAME
      !ASSOCNAME type STRING
      !HASPARENT type ABAP_BOOL default ABAP_FALSE
      !CURRENTCARDINALITY type IF_XCO_CDS_ASSOCIATION_CONTENT=>TS_CARDINALITY
    returning
      value(CARDINALITY) type IF_XCO_CDS_ASSOCIATION_CONTENT=>TS_CARDINALITY .
endinterface.
