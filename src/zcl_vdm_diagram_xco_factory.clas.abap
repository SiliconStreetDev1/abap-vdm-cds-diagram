"! <p class="shorttext synchronized">VDM XCO Factory</p>
"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! USAGE TERMS:
"! 1. INTERNAL USE: Permission is granted to use this code for internal
"!    business documentation purposes within a single organization at no cost.
"! 2. NON-REDISTRIBUTION: You may NOT redistribute, sell, or include this
"!    source code in any commercial software, package, or library.
"! 3. PAID SERVICES: Use of this code to provide paid consulting or
"!    documentation services requires a Commercial License.
"! 4. MODIFICATIONS: Any modifications remain subject to this license.
"!
"! FOR COMMERCIAL LICENSING INQUIRIES: admin@siliconst.co.nz
class ZCL_VDM_DIAGRAM_XCO_FACTORY definition
  public
  final
  create public .

public section.

    " =========================================================================
    " PUBLIC METHODS
    " =========================================================================
  methods CONSTRUCTOR
    raising
      ZCX_VDM_DIAGRAM_GENERATOR .
  class-methods GET_XCO_ADAPTER
    returning
      value(XCO_ADAPTER) type ref to ZIF_VDM_DIAGRAM_XCO_ADAPTER
    raising
      ZCX_VDM_DIAGRAM_GENERATOR .
protected section.

  data XCO_ADAPTER type ref to ZIF_VDM_DIAGRAM_XCO_ADAPTER .

  class-methods IS_CLOUD
    returning
      value(IS_CLOUD) type ABAP_BOOL .
private section.
ENDCLASS.



CLASS ZCL_VDM_DIAGRAM_XCO_FACTORY IMPLEMENTATION.


  METHOD CONSTRUCTOR.

  ENDMETHOD.


  METHOD GET_XCO_ADAPTER.
    " Dynamic instantiation of the environment-specific adapter to avoid syntax errors
    " if Cloud objects are missing in an On-Premise system.
    DATA(class_name) = COND string(
      WHEN is_cloud( ) = abap_true THEN 'ZCL_VDM_DIAGRAM_XCO_ADP_CP'
      ELSE                               'ZCL_VDM_DIAGRAM_XCO_ADP'
    ).

    TRY.
        CREATE OBJECT xco_adapter TYPE (class_name).
      CATCH cx_sy_create_object_error.
        TRY.
            CREATE OBJECT xco_adapter TYPE ('ZCL_VDM_DIAGRAM_XCO_ADP_CP'). " Fallback to Cloud adapter, even in On-Premise ( Maybe someone deleted it ?).
          CATCH cx_sy_create_object_error.
        ENDTRY.
    ENDTRY.
  ENDMETHOD.


  METHOD IS_CLOUD.
    " We check if the XCO Tenant is 'Empty'.
    " In BTP, this returns the subaccount/tenant details.
    " In On-Premise, it returns an initial/unassigned state.
    DATA(tenant) = xco_cp=>current->tenant( ).
    TRY.
        IF tenant->get_id( ) IS INITIAL.
          is_cloud = abap_false.
        ELSE.
          is_cloud = abap_true.
        ENDIF.
      CATCH cx_root.
        is_cloud = abap_false.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
