"! <p class="shorttext synchronized">VDM PlantUML Generator</p>
"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! USAGE TERMS:
"! 1. INTERNAL USE: Permission is granted to use this code for internal
"!    business documentation purposes within a single organization at no cost.
"! 2. NON-REDISTRIBUTION: You may NOT redistribute, sell, or include this
"!    source code (or derivatives thereof) in any commercial software or library.
"! 3. PAID SERVICES: Use of this code to provide paid consulting or
"!    documentation services to third parties requires a Commercial License.
"! 4. MODIFICATIONS: Any modifications remain subject to this license.
"!
"! DISCLAIMER: THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
"! IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"! LIABILITY ARISING FROM THE USE OF THE SOFTWARE.
"!
"! FOR COMMERCIAL LICENSING INQUIRIES: admin@siliconst.co.nz

CLASS zcl_vdm_plantuml_xco_adp_cp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.


    INTERFACES zif_vdm_plantuml_xco_adapter .

    ALIASES:
     get_CDS_Type FOR zif_vdm_plantuml_xco_adapter~get_cds_type,
     get_associations FOR zif_vdm_plantuml_xco_adapter~get_associations,
     get_compositions FOR zif_vdm_plantuml_xco_adapter~get_compositions,
     get_fields FOR zif_vdm_plantuml_xco_adapter~get_fields,
     get_Sources FOR zif_vdm_plantuml_xco_adapter~get_sources,
     get_CDS_Name_By_DDL FOR zif_vdm_plantuml_xco_adapter~get_cds_name_from_ddl,
     get_Cardinality  FOR zif_vdm_plantuml_xco_adapter~get_cardinality.

  PROTECTED SECTION.

  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_VDM_PLANTUML_XCO_ADP_CP IMPLEMENTATION.


  METHOD zif_vdm_plantuml_xco_adapter~get_cds_type.

    "Find the DDL source for the given CDS name and return the type of the CDS entity (e.g. CDS Entity , CDS Projection etc.)
    DATA(objectNameFilter) = xco_cp_abap_repository=>object_name->get_filter(
                                 xco_cp_abap_sql=>constraint->equal( cds_name ) ).
    DATA(typeDefinitions) = xco_cp_abap_repository=>objects->ddls->where( VALUE #( ( objectnamefilter ) ) )->in(
        xco_cp_abap=>repository )->get( ).

    "If there is exactly one DDL source found, return its type
    "There should only ever be one DDL source for a given CDS name, but we check this just to be sure
    IF lines( typedefinitions  ) = 1.
      type = typedefinitions[ 1 ]->get_type( )->value.
    ENDIF.
  ENDMETHOD.


  METHOD get_associations.

    "Find the DDL source for the given CDS name and return all associations of the CDS entity
    CASE me->get_CDS_Type( cds_name ).
      WHEN 'V'. "CDS View (OLD)
        associations = xco_cp_cds=>view( cds_name )->associations->all->get( ).
      WHEN 'W'. "CDS View Entity (NEW)
        associations = xco_cp_cds=>view_entity( cds_name )->associations->all->get( ).
      WHEN OTHERS. " Other views don't have associations, so we return an empty table
        CLEAR associations.
    ENDCASE.

  ENDMETHOD.


  METHOD get_compositions.

    "Find the DDL source for the given CDS name and return all Compositions of the CDS entity
    CASE me->get_CDS_Type( cds_name ).
      WHEN 'V'. "CDS View (OLD)
        compositions = xco_cp_cds=>view( cds_name )->compositions->all->get( ).
      WHEN 'W'. "CDS View Entity (NEW)
        compositions = xco_cp_cds=>view_entity( cds_name )->compositions->all->get( ).
      WHEN OTHERS. " Other views don't have compositions, so we return an empty table
        CLEAR compositions.
    ENDCASE.

  ENDMETHOD.


  METHOD get_fields.

    "Find the DDL source for the given CDS name and return all fields of the CDS entity
    fields =  xco_cp_cds=>entity( cds_name )->fields->all->get( ).

  ENDMETHOD.


  METHOD zif_vdm_plantuml_xco_adapter~get_sources.
    TRY.

        " Find the DDL source for the given CDS name and return all Compositions of the CDS entity
        CASE me->get_CDS_Type( cds_name ).
          WHEN 'V'. " CDS View (OLD)
            APPEND xco_cp_cds=>view( cds_name )->content( )->get_data_source( )-entity TO sources.
          WHEN 'W'. " CDS View Entity (NEW)
            APPEND xco_cp_cds=>view_entity( cds_name )->content( )->get_data_source( )-view_entity TO sources.
            WHEN 'P'. " CDS View Entity (NEW)
            APPEND XCO_cp_cds=>projection_view( cds_name )->content( )->get_data_source( )-view_entity TO sources.
          WHEN OTHERS. " Other views don't have compositions, so we return an empty table
            CLEAR sources.
        ENDCASE.

      CATCH cx_xco_runtime_exception INTO DATA(exception).
        " If we get here it most likely means we are missing Union Support for CDS Views, which means we can't determine the source of the CDS View,
        " so we return an empty table
        " this is a known issue in the XCO CLOUD API and there is currently no workaround for it, other than returning an empty table.
        " It is supported for on Premise ( With a few cheats) , but not for cloud, which is why we catch the exception and return an empty table in this case
        CLEAR sources.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_vdm_plantuml_xco_adapter~get_cds_name_from_ddl.

    " Sorry on Cloud we can't do much with this. So all CDS will just be upper case
    ddlcds_name = to_upper( cds_name ).

  ENDMETHOD.


  method ZIF_VDM_PLANTUML_XCO_ADAPTER~get_cardinality.

   cardinality = currentcardinality.

    IF hasparent = abap_true. "If its a Parent Relationship we only want to show the cardinality on the child side
      cardinality-min = 1.
      cardinality-max = 1.
    ENDIF.

  endmethod.
ENDCLASS.
