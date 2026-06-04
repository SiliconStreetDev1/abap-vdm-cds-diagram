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
CLASS zcl_vdm_diagram_xco_adp_cp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_vdm_diagram_xco_adapter .

    ALIASES get_associations
      FOR zif_vdm_diagram_xco_adapter~get_associations .
    ALIASES get_cardinality
      FOR zif_vdm_diagram_xco_adapter~get_cardinality .
    ALIASES get_cds_name_by_ddl
      FOR zif_vdm_diagram_xco_adapter~get_cds_name_from_ddl .
    ALIASES get_cds_type
      FOR zif_vdm_diagram_xco_adapter~get_cds_type .
    ALIASES get_compositions
      FOR zif_vdm_diagram_xco_adapter~get_compositions .
    ALIASES get_fields
      FOR zif_vdm_diagram_xco_adapter~get_fields .
    ALIASES get_sources
      FOR zif_vdm_diagram_xco_adapter~get_sources .

  PROTECTED SECTION.

  PRIVATE SECTION.
    " PERFORMANCE FIX: Cache structure to prevent redundant ABAP Repository hits
    " Since GET_CDS_TYPE is called by associations, compositions, and sources,
    " caching it here provides a massive O(1) speedup for deep VDM hierarchies.
    TYPES: BEGIN OF ty_type_cache,
             cds_name TYPE sxco_cds_object_name,
             type     TYPE zvdm_diagram_cds_type,
           END OF ty_type_cache.

    DATA type_cache TYPE HASHED TABLE OF ty_type_cache WITH UNIQUE KEY cds_name.
ENDCLASS.



CLASS ZCL_VDM_DIAGRAM_XCO_ADP_CP IMPLEMENTATION.


  METHOD zif_vdm_diagram_xco_adapter~get_cardinality.

    cardinality = currentcardinality.

    IF hasparent = abap_true. "If its a Parent Relationship we only want to show the cardinality on the child side
      cardinality-min = 1.
      cardinality-max = 1.
    ENDIF.

  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_cds_name_from_ddl.

    " Sorry on Cloud we can't do much with this. So all CDS will just be upper case
    ddlcds_name = to_upper( cds_name ).

  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_cds_type.
    DATA(normalized_cds_name) = to_upper( cds_name ).

    " PERFORMANCE FIX: Check the hashed memory cache first to avoid redundant database reads
    ASSIGN type_cache[ cds_name = normalized_cds_name ] TO FIELD-SYMBOL(<cache_entry>).
    IF sy-subrc = 0.
      type = <cache_entry>-type.
      RETURN.
    ENDIF.

    " Find the DDL source for the given CDS name and return the type of the CDS entity
    " (e.g. CDS Entity, CDS Projection etc.)
    DATA(object_name_filter) = xco_cp_abap_repository=>object_name->get_filter(
                                 xco_cp_abap_sql=>constraint->equal( normalized_cds_name ) ).

    DATA(type_definitions) = xco_cp_abap_repository=>objects->ddls->where(
                                 VALUE #( ( object_name_filter ) ) )->in( xco_cp_abap=>repository )->get( ).

    " If there is exactly one DDL source found, return its type
    " There should only ever be one DDL source for a given CDS name, but we check this just to be sure
    IF lines( type_definitions ) = 1.
      type = type_definitions[ 1 ]->get_type( )->value.
    ENDIF.

    " Store the result in the cache for future O(1) lookups
    INSERT VALUE #( cds_name = normalized_cds_name type = type ) INTO TABLE type_cache.
  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_sources.
    TRY.

        " Find the DDL source for the given CDS name and return all Compositions of the CDS entity
        CASE me->get_cds_type( cds_name ).
          WHEN 'V'. " CDS View (OLD)
            APPEND xco_cp_cds=>view( cds_name )->content( )->get_data_source( )-entity TO sources.
          WHEN 'W'. " CDS View Entity (NEW)
            APPEND xco_cp_cds=>view_entity( cds_name )->content( )->get_data_source( )-view_entity TO sources.
          WHEN 'P'. " CDS Projection View (NEW)
            APPEND xco_cp_cds=>projection_view( cds_name )->content( )->get_data_source( )-view_entity TO sources.
          WHEN OTHERS. " Other views don't have compositions, so we return an empty table
            CLEAR sources.
        ENDCASE.

      CATCH cx_xco_runtime_exception INTO DATA(exception).
        " If we get here it most likely means we are missing Union Support for CDS Views,
        " which means we can't determine the source of the CDS View, so we return an empty table.
        " This is a known issue in the XCO CLOUD API and there is currently no workaround for it,
        " other than returning an empty table. It is supported for on Premise (With a few cheats),
        " but not for cloud, which is why we catch the exception and return an empty table in this case.
        APPEND 'Unknown (Possible Union)' TO sources.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~search_for_cds.

    " 1. Validate input to prevent massive, unconstrained repository reads
    IF cds_search_string IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Normalize the search pattern
    " Convert to uppercase and translate standard SAP wildcards (*) to SQL wildcards (%)
    DATA(search_pattern) = to_upper( cds_search_string ).
    search_pattern = replace( val = search_pattern sub = '*' with = '%' occ = 0 ).

    " 3. Build the XCO Object Name Filter using the pattern constraint
    DATA(name_filter) = xco_cp_abap_repository=>object_name->get_filter(
      xco_cp_abap_sql=>constraint->contains_pattern( search_pattern )
    ).

    " 4. Query the ABAP repository specifically for DDLs (Data Definition Language objects)
    DATA(ddl_objects) = xco_cp_abap_repository=>objects->ddls->where(
      VALUE #( ( name_filter ) )
    )->in( xco_cp_abap=>repository )->get( ).

    " 5. Extract the names from the returned XCO objects into the flat result table
    cds_names = VALUE #( FOR ddl_object IN ddl_objects ( ddl_object->name ) ).

  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_associations.

    " Find the DDL source for the given CDS name and return all associations of the CDS entity
    CASE me->get_cds_type( cds_name ).
      WHEN 'V'. "CDS View (OLD)
        associations = xco_cp_cds=>view( cds_name )->associations->all->get( ).
      WHEN 'W'. "CDS View Entity (NEW)
        associations = xco_cp_cds=>view_entity( cds_name )->associations->all->get( ).
      WHEN OTHERS. " Other views don't have associations, so we return an empty table
        CLEAR associations.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_compositions.

    " Find the DDL source for the given CDS name and return all Compositions of the CDS entity
    CASE me->get_cds_type( cds_name ).
      WHEN 'V'. "CDS View (OLD)
        compositions = xco_cp_cds=>view( cds_name )->compositions->all->get( ).
      WHEN 'W'. "CDS View Entity (NEW)
        compositions = xco_cp_cds=>view_entity( cds_name )->compositions->all->get( ).
      WHEN OTHERS. " Other views don't have compositions, so we return an empty table
        CLEAR compositions.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_fields.

    " Find the DDL source for the given CDS name and return all fields of the CDS entity
    fields = xco_cp_cds=>entity( cds_name )->fields->all->get( ).

  ENDMETHOD.
ENDCLASS.
