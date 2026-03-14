"! <p class="shorttext synchronized">VDM diagram Generator</p>
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
class ZCL_VDM_DIAGRAM_XCO_ADP_CP definition
  public
  final
  create public .

public section.

  interfaces ZIF_VDM_diagram_XCO_ADAPTER .

  aliases GET_ASSOCIATIONS
    for ZIF_VDM_diagram_XCO_ADAPTER~GET_ASSOCIATIONS .
  aliases GET_CARDINALITY
    for ZIF_VDM_diagram_XCO_ADAPTER~GET_CARDINALITY .
  aliases GET_CDS_NAME_BY_DDL
    for ZIF_VDM_diagram_XCO_ADAPTER~GET_CDS_NAME_FROM_DDL .
  aliases GET_CDS_TYPE
    for ZIF_VDM_diagram_XCO_ADAPTER~GET_CDS_TYPE .
  aliases GET_COMPOSITIONS
    for ZIF_VDM_diagram_XCO_ADAPTER~GET_COMPOSITIONS .
  aliases GET_FIELDS
    for ZIF_VDM_diagram_XCO_ADAPTER~GET_FIELDS .
  aliases GET_SOURCES
    for ZIF_VDM_diagram_XCO_ADAPTER~GET_SOURCES .
  PROTECTED SECTION.

  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_VDM_DIAGRAM_XCO_ADP_CP IMPLEMENTATION.


  METHOD GET_ASSOCIATIONS.

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


  METHOD GET_COMPOSITIONS.

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


  METHOD GET_FIELDS.

    "Find the DDL source for the given CDS name and return all fields of the CDS entity
    fields =  xco_cp_cds=>entity( cds_name )->fields->all->get( ).

  ENDMETHOD.


  method ZIF_VDM_diagram_XCO_ADAPTER~GET_CARDINALITY.

   cardinality = currentcardinality.

    IF hasparent = abap_true. "If its a Parent Relationship we only want to show the cardinality on the child side
      cardinality-min = 1.
      cardinality-max = 1.
    ENDIF.

  endmethod.


  METHOD ZIF_VDM_diagram_XCO_ADAPTER~GET_CDS_NAME_FROM_DDL.

    " Sorry on Cloud we can't do much with this. So all CDS will just be upper case
    ddlcds_name = to_upper( cds_name ).

  ENDMETHOD.


  METHOD ZIF_VDM_diagram_XCO_ADAPTER~GET_CDS_TYPE.

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


  METHOD ZIF_VDM_diagram_XCO_ADAPTER~GET_SOURCES.
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
        APPEND 'Unknown (Possible Union)' TO sources.
    ENDTRY.
  ENDMETHOD.


  method ZIF_VDM_DIAGRAM_XCO_ADAPTER~SEARCH_FOR_CDS.

    " 1. Validate input to prevent massive, unconstrained repository reads
    IF cds_search_string IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Normalize the search pattern
    " Convert to uppercase and translate standard SAP wildcards (*) to SQL wildcards (%)
    DATA(lv_pattern) = to_upper( cds_search_string ).
    lv_pattern = replace( val = lv_pattern sub = '*' with = '%' occ = 0 ).

    " 3. Build the XCO Object Name Filter using the pattern constraint
    DATA(lo_name_filter) = xco_cp_abap_repository=>object_name->get_filter(
      xco_cp_abap_sql=>constraint->contains_pattern( lv_pattern )
    ).

    " 4. Query the ABAP repository specifically for DDLs (Data Definition Language objects)
    DATA(lt_ddl_objects) = xco_cp_abap_repository=>objects->ddls->where(
      VALUE #( ( lo_name_filter ) )
    )->in( xco_cp_abap=>repository )->get( ).

    " 5. Extract the names from the returned XCO objects into the flat result table
    cds_names = VALUE #( FOR lo_ddl IN lt_ddl_objects ( lo_ddl->name ) ).

  endmethod.
ENDCLASS.
