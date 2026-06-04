"! <p class="shorttext synchronized">VDM Diagram Generator Engine</p>
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
CLASS zcl_vdm_diagram_xco_adp DEFINITION
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
    "! Reads the raw DDL source code from the database using standard DDIC APIs
    METHODS get_ddl_source
      IMPORTING
        cds_name           TYPE sxco_cds_object_name
      RETURNING
        VALUE(source_code) TYPE string.

    "! Executes a cached PCRE regular expression against a target string
    METHODS extract_regex_matches
      IMPORTING
        pattern        TYPE string
        text           TYPE string
      RETURNING
        VALUE(matches) TYPE match_result_tab.

  PRIVATE SECTION.
    " Cache structures to prevent redundant database reads for raw DDL
    TYPES: BEGIN OF ddl_cache_entry,
             name   TYPE sxco_cds_object_name,
             source TYPE string,
           END OF ddl_cache_entry.

    " PERFORMANCE FIX: Cache structure to prevent redundant Regex PCRE compilations
    TYPES: BEGIN OF ty_regex_cache,
             pattern TYPE string,
             regex   TYPE REF TO cl_abap_regex,
           END OF ty_regex_cache.

    " PERFORMANCE FIX: Cache structure to prevent redundant ABAP Repository hits for entity types
    TYPES: BEGIN OF ty_type_cache,
             cds_name TYPE sxco_cds_object_name,
             type     TYPE zvdm_diagram_cds_type,
           END OF ty_type_cache.

    " Hashed tables for high-performance O(1) lookups during deep recursion
    DATA ddl_cache   TYPE HASHED TABLE OF ddl_cache_entry WITH UNIQUE KEY name.
    DATA regex_cache TYPE HASHED TABLE OF ty_regex_cache WITH UNIQUE KEY pattern.
    DATA type_cache  TYPE HASHED TABLE OF ty_type_cache WITH UNIQUE KEY cds_name.
ENDCLASS.



CLASS ZCL_VDM_DIAGRAM_XCO_ADP IMPLEMENTATION.


  METHOD extract_regex_matches.
    DATA regex_object TYPE REF TO cl_abap_regex.

    " PERFORMANCE FIX: Check if the regex pattern is already compiled in the local memory cache.
    " Compiling PCRE expressions is CPU-heavy. Caching them prevents thousands of redundant compilations.
    ASSIGN regex_cache[ pattern = pattern ] TO FIELD-SYMBOL(<cached_regex>).
    IF sy-subrc = 0.
      regex_object = <cached_regex>-regex.
    ELSE.
      TRY.
          " Compile the PCRE regex and store the instantiated object in the cache for O(1) retrieval
          regex_object = cl_abap_regex=>create_pcre( pattern = pattern ).
          INSERT VALUE #( pattern = pattern regex = regex_object ) INTO TABLE regex_cache.
        CATCH cx_sy_regex.
          CLEAR matches.
          RETURN.
      ENDTRY.
    ENDIF.

    " Execute the standard matcher using the compiled (or cached) engine
    TRY.
        DATA(matcher) = regex_object->create_matcher( text = text ).
        matches       = matcher->find_all( ).
      CATCH cx_sy_matcher.
        CLEAR matches.
    ENDTRY.
  ENDMETHOD.


  METHOD get_ddl_source.
    " Get Raw DDL source code for a given CDS name, with caching to optimize performance.
    DATA(normalized_name) = to_upper( cds_name ).

    " Check cache first to avoid redundant database reads
    ASSIGN ddl_cache[ name = normalized_name ] TO FIELD-SYMBOL(<cache_entry>).
    IF sy-subrc = 0.
      source_code = <cache_entry>-source.
      RETURN.
    ENDIF.

    " Read raw DDL source from the DDIC handler
    TRY.
        cl_dd_ddl_handler_factory=>create( )->read( EXPORTING name         = CONV ddlname( normalized_name )
                                                    IMPORTING ddddlsrcv_wa = DATA(source_wa) ).
        source_code = source_wa-source.
      CATCH cx_dd_ddl_read.
        source_code = ''.
    ENDTRY.

    " Store the result in the cache
    INSERT VALUE #( name   = normalized_name
                    source = source_code ) INTO TABLE ddl_cache.
  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_cds_name_from_ddl.

    " PURPOSE: Normalizes the CDS DDL name by parsing the source code.
    " This logic extracts the actual developer-defined name (preserving casing like CamelCase)
    " from the DDL source based on the specific CDS entity type (View, Entity, or Projection).
    " It acts as a bridge between the technical DDL name and the descriptive alias.

    " Initial validation: If no name is provided, exit early with the empty input
    IF cds_name IS INITIAL.
      ddlcds_name = cds_name.
      RETURN.
    ENDIF.

    " Fetch the raw DDL source code; if missing, fallback to the provided technical name
    DATA(source_code) = get_ddl_source( cds_name ).
    IF source_code IS INITIAL.
      ddlcds_name = cds_name.
      RETURN.
    ENDIF.

    " Determine the DDL keyword to search for based on the CDS type
    " W = View Entity, V = Define View, P = Projection View
    DATA(keyword) = SWITCH string( me->get_cds_type( cds_name )
      WHEN 'W' THEN `view entity`
      WHEN 'V' THEN `define view`
      WHEN 'P' THEN `projection view`
      ELSE `` ).

    IF keyword IS NOT INITIAL.
      " Case-insensitive search for the keyword position within the source
      DATA(lower_source) = to_lower( source_code ).
      DATA(text_after) = substring_after( val = lower_source sub = keyword ).

      IF text_after IS NOT INITIAL.
        " Calculate the starting position of the actual name segment
        DATA(offset) = find( val = lower_source sub = keyword ) + strlen( keyword ).
        DATA(original_text) = substring( val = source_code off = offset ).

        " Isolate the name segment immediately following the keyword (splitting by space)
        DATA(found_name) = segment( val = condense( original_text ) index = 1 sep = ` ` ).

        " Clean up trailing semi-colons from the parsed segment
        found_name = replace( val = found_name sub = `;` with = `` ).

        " Map back to the original source to preserve developer casing (e.g., CamelCase)
        FIND FIRST OCCURRENCE OF found_name IN source_code IGNORING CASE MATCH OFFSET DATA(match_offset).
        IF sy-subrc = 0.
          " Extract the name with the length of the input to ensure we grab only the relevant segment
          ddlcds_name = substring( val = source_code off = match_offset len = strlen( cds_name ) ).
        ENDIF.
      ENDIF.
    ENDIF.

    " Fallback to the default name if parsing failed or if the parsed name doesn't match the entity
    IF ddlcds_name IS INITIAL OR to_upper( ddlcds_name ) <> to_upper( cds_name ).
      ddlcds_name = cds_name.
    ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_cds_type.
    DATA(normalized_cds_name) = CONV sxco_cds_object_name( to_upper( cds_name ) ).

    " PERFORMANCE FIX: Check the hashed memory cache first to avoid redundant database reads
    ASSIGN type_cache[ cds_name = normalized_cds_name ] TO FIELD-SYMBOL(<cache_entry>).
    IF sy-subrc = 0.
      type = <cache_entry>-type.
      RETURN.
    ENDIF.

    " Filter repository objects by the provided CDS name
    DATA(object_name_filter) = xco_abap_repository=>object_name->get_filter(
                                 xco_abap_sql=>constraint->equal( normalized_cds_name ) ).

    " Fetch the DDL definitions matching the filter
    DATA(type_definitions) = xco_abap_repository=>objects->ddls->where(
                               VALUE #( ( object_name_filter ) ) )->in( xco_abap=>repository )->get( ).

    " Extract the specific CDS type (e.g., View Entity vs DDIC-based View)
    IF lines( type_definitions ) = 1.
      type = type_definitions[ 1 ]->get_type( )->value.
    ENDIF.

    " Store the result in the cache for future O(1) lookups
    INSERT VALUE #( cds_name = normalized_cds_name type = type ) INTO TABLE type_cache.
  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_sources.
    TRY.
        " Attempt to fetch data sources via standard XCO Content API
        CASE me->get_cds_type( cds_name ).
          WHEN 'V'. APPEND xco_cds=>view( cds_name )->content( )->get_data_source( )-entity TO sources.
          WHEN 'W'. APPEND xco_cds=>view_entity( cds_name )->content( )->get_data_source( )-view_entity TO sources.
          WHEN 'P'. APPEND xco_cds=>projection_view( cds_name )->content( )->get_data_source( )-view_entity TO sources.
          WHEN OTHERS. CLEAR sources.
        ENDCASE.
      CATCH cx_xco_runtime_exception.
        " Fallback to manual Regex parsing if XCO cannot handle the view (e.g., UNIONs, JOINS)
        DATA(source_code) = get_ddl_source( cds_name ).
        IF source_code IS NOT INITIAL.
          DATA(regex_matches) = extract_regex_matches( pattern = `(?i)\b(?:from|join)\s+([a-zA-Z0-9_/]+)` text = source_code ).
          sources = VALUE #( FOR match IN regex_matches WHERE ( submatches IS NOT INITIAL )
                             LET match_sub = match-submatches[ 1 ] IN
                             ( substring( val = source_code off = match_sub-offset len = match_sub-length ) ) ).
        ENDIF.
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
    DATA(name_filter) = xco_abap_repository=>object_name->get_filter(
      xco_abap_sql=>constraint->contains_pattern( search_pattern )
    ).

    " 4. Query the ABAP repository specifically for DDLs (Data Definition Language objects)
    DATA(ddl_objects) = xco_abap_repository=>objects->ddls->where(
      VALUE #( ( name_filter ) )
    )->in( xco_abap=>repository )->get( ).

    " 5. Extract the names from the returned XCO objects into the flat result table
    cds_names = VALUE #( FOR ddl_object IN ddl_objects ( ddl_object->name ) ).

  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_fields.
    " Fetch all fields for the given entity
    fields = xco_cds=>entity( cds_name )->fields->all->get( ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_associations.
    " Associations are type-specific in XCO; determine the type first
    CASE me->get_cds_type( cds_name ).
      WHEN 'V'. associations = xco_cds=>view( cds_name )->associations->all->get( ).
      WHEN 'W'. associations = xco_cds=>view_entity( cds_name )->associations->all->get( ).
      WHEN OTHERS. CLEAR associations.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_cardinality.

    "----> Additional Cardinality logic
    " XCO occasionally returns [0..1] for associations defined as [1] due to how
    " underlying keys are analyzed. This logic parses the DDL source to force
    " [1..1] when [1] is explicitly defined in the source code.

    cardinality = currentcardinality.

    IF hasparent = abap_true. "If its a Parent Relationship we only want to show the cardinality on the child side
      cardinality-min = 1.
      cardinality-max = 1.
      RETURN.
    ENDIF.

    " Only process if the current cardinality is 0..1
    IF NOT ( cardinality-max = 1 AND cardinality-min = 0 ).
      RETURN.
    ENDIF.

    " Get DDL Source
    DATA(source) = get_ddl_source( cds_name ).
    IF source IS INITIAL OR assocname IS INITIAL.
      RETURN.
    ENDIF.

    " 1. Locate the specific association alias
    FIND FIRST OCCURRENCE OF assocname IN source IGNORING CASE MATCH OFFSET DATA(name_off).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 2. Look backwards to find the preceding 'ASSOCIATION' keyword
    DATA(prefix) = substring( val = source len = name_off ).
    DATA(start_off) = find( val = to_upper( prefix ) sub = 'ASSOCIATION' occ = -1 ).

    IF start_off < 0.
      RETURN.
    ENDIF.

    " 3. Isolate the line fragment
    DATA(line) = substring( val = source off = start_off len = name_off - start_off + strlen( assocname ) ).

    " 4. Prepare the association name for the regex (manually escape forward slashes if present)
    DATA(esc_name) = replace( val = assocname sub = '/' with = '\/' occ = 0 ).
    DATA(pattern) = `(?i)association\s*(?:\[([^\]]*)\])?[^;]*?\bas\s+` && esc_name && `\b`.

    " Execute optimized cached Regex method
    DATA(matches) = extract_regex_matches( pattern = pattern text = line ).

    IF lines( matches ) > 0.
      DATA(match) = matches[ 1 ].

      " 5. Check for explicit [ 1 ]
      IF lines( match-submatches ) > 0 AND match-submatches[ 1 ]-length > 0.
        DATA(sub_match) = match-submatches[ 1 ].
        DATA(val) = condense( val = substring( val = line off = sub_match-offset len = sub_match-length ) from = ` ` to = `` ).

        IF val = '1'.
          cardinality-min = 1.
          cardinality-max = 1.
        ENDIF.
      ENDIF.

    ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_xco_adapter~get_compositions.
    " Compositions are type-specific in XCO; determine the type first
    CASE me->get_cds_type( cds_name ).
      WHEN 'V'. compositions = xco_cds=>view( cds_name )->compositions->all->get( ).
      WHEN 'W'. compositions = xco_cds=>view_entity( cds_name )->compositions->all->get( ).
      WHEN OTHERS. CLEAR compositions.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
