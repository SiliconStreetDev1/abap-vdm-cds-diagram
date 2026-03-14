"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! PURPOSE: RAP Query Provider for the VDM Diagram Generator.
"! Extracts complex UI filters (including tokens and booleans), maps them
"! to the generation engine, and returns the constructed payload to the UI.
CLASS zcl_vdm_diagram_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.

CLASS zcl_vdm_diagram_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    " -------------------------------------------------------------------------
    " 0. DATA DECLARATIONS (Clean ABAP - No Hungarian Notation)
    " -------------------------------------------------------------------------
    DATA diagrams TYPE STANDARD TABLE OF zce_vdm_diagram WITH DEFAULT KEY.
    DATA diagram  TYPE zce_vdm_diagram.

    " Primary entity filters
    DATA cds_filter      TYPE string.
    DATA engine_key      TYPE string.

    " Default configuration variables
    DATA max_level       TYPE i VALUE 1.
    DATA show_base       TYPE abap_boolean VALUE abap_false.
    DATA show_keys       TYPE abap_boolean VALUE abap_false.
    DATA show_fields     TYPE abap_boolean VALUE abap_false.
    DATA assoc_fields    TYPE abap_boolean VALUE abap_false.
    DATA custom_only     TYPE abap_boolean VALUE abap_false.

    " Line rendering configurations
    DATA line_assoc      TYPE abap_boolean VALUE abap_true.
    DATA line_comp       TYPE abap_boolean VALUE abap_true.
    DATA line_inherit    TYPE abap_boolean VALUE abap_true.

    " Discovery (traversal) configurations
    DATA disc_assoc      TYPE abap_boolean VALUE abap_true.
    DATA disc_comp       TYPE abap_boolean VALUE abap_true.
    DATA disc_inherit    TYPE abap_boolean VALUE abap_true.

    " Raw comma-separated lists from UI5 MultiInputs
    DATA include_string  TYPE string.
    DATA exclude_string  TYPE string.

    " -------------------------------------------------------------------------
    " 1. STRICT RAP CONTRACT FULFILLMENT (Paging)
    " -------------------------------------------------------------------------
    DATA(paging) = io_request->get_paging( ).
    DATA(offset) = paging->get_offset( ).

    " -------------------------------------------------------------------------
    " 2. EXTRACT ALL FILTERS SAFELY
    " Iterate through the OData filter ranges and map them to our local state
    " -------------------------------------------------------------------------
    TRY.
        DATA(filter_ranges) = io_request->get_filter( )->get_as_ranges( ).

        LOOP AT filter_ranges INTO DATA(filter_range).
          " Normalize boolean handling since OData can pass 'true', 'TRUE', or 'X'
          DATA(raw_value) = to_upper( CONV string( filter_range-range[ 1 ]-low ) ).
          DATA(is_true)   = xsdbool( raw_value = 'TRUE' OR raw_value = 'X' ).

          CASE to_upper( filter_range-name ).
            WHEN 'CDSNAME'.         cds_filter   = filter_range-range[ 1 ]-low.
            WHEN 'RENDERERENGINE'.  engine_key   = filter_range-range[ 1 ]-low.
            WHEN 'MAXLEVEL'.        max_level    = filter_range-range[ 1 ]-low.
            WHEN 'SHOWBASE'.        show_base    = is_true.
            WHEN 'SHOWKEYS'.        show_keys    = is_true.
            WHEN 'SHOWFIELDS'.      show_fields  = is_true.
            WHEN 'SHOWASSOCFIELDS'. assoc_fields = is_true.
            WHEN 'CUSTOMDEVONLY'.   custom_only  = is_true.
            WHEN 'LINEASSOC'.       line_assoc   = is_true.
            WHEN 'LINECOMP'.        line_comp    = is_true.
            WHEN 'LINEINHERIT'.     line_inherit = is_true.
            WHEN 'DISCASSOC'.       disc_assoc   = is_true.
            WHEN 'DISCCOMP'.        disc_comp    = is_true.
            WHEN 'DISCINHERIT'.     disc_inherit = is_true.
            WHEN 'INCLUDECDS'.      include_string = filter_range-range[ 1 ]-low.
            WHEN 'EXCLUDECDS'.      exclude_string = filter_range-range[ 1 ]-low.
          ENDCASE.
        ENDLOOP.
      CATCH cx_root.
        " If filters are missing or malformed, the defaults defined above will safely apply
    ENDTRY.

    " -------------------------------------------------------------------------
    " 3. HANDLE EXITS & PAGING TRAPS
    " If there's no root CDS view to analyze, or if UI5 is paginating past the
    " first record (we only ever return 1 payload), exit early.
    " -------------------------------------------------------------------------
    IF cds_filter IS INITIAL OR offset > 0.
      IF io_request->is_data_requested( ).
        io_response->set_data( diagrams ).
      ENDIF.
      IF io_request->is_total_numb_of_rec_requested( ).
        io_response->set_total_number_of_records( COND #( WHEN offset > 0 THEN 1 ELSE 0 ) ).
      ENDIF.
      RETURN.
    ENDIF.

    " -------------------------------------------------------------------------
    " 4. POST-VALIDATION MAP
    " Prepare the entity and ensure the target CDS name is uppercase for XCO
    " -------------------------------------------------------------------------
    diagram-cdsname        = cds_filter.
    diagram-rendererengine = engine_key.
    DATA(cds_name_xco)     = to_upper( cds_filter ).

    " -------------------------------------------------------------------------
    " 5. PARSE COMMA-SEPARATED WHITELIST/BLACKLIST INTO TABLES
    " Converts standard strings into XCO-compatible object name tables
    " -------------------------------------------------------------------------
    DATA include_list TYPE sxco_t_cds_object_names.
    DATA exclude_list TYPE sxco_t_cds_object_names.

    IF include_string IS NOT INITIAL.
      SPLIT include_string AT ',' INTO TABLE DATA(raw_includes).
      include_list = VALUE #( FOR item IN raw_includes ( CONV #( to_upper( condense( item ) ) ) ) ).
    ENDIF.

    IF exclude_string IS NOT INITIAL.
      SPLIT exclude_string AT ',' INTO TABLE DATA(raw_excludes).
      exclude_list = VALUE #( FOR item IN raw_excludes ( CONV #( to_upper( condense( item ) ) ) ) ).
    ENDIF.

    " -------------------------------------------------------------------------
    " 6. STRATEGY FACTORY
    " Instantiate the correct syntax generator based on the UI dropdown
    " -------------------------------------------------------------------------
    DATA renderer TYPE REF TO zcl_vdm_diagram_base.

    CASE to_upper( engine_key ).
      WHEN 'PLANTUML'.
        renderer = NEW zcl_vdm_diagram_plantuml( ).
        diagram-fileextension = '.puml'.
      WHEN 'GRAPHVIZ'.
        renderer = NEW zcl_vdm_diagram_graphviz( ).
        diagram-fileextension = '.dot'.
      WHEN 'D2'.
        renderer = NEW zcl_vdm_diagram_d2( ).
        diagram-fileextension = '.d2'.
      WHEN OTHERS.
        renderer = NEW zcl_vdm_diagram_mermaid( ).
        diagram-fileextension = '.mmd'.
    ENDCASE.

    " -------------------------------------------------------------------------
    " 7. GENERATION ENGINE EXECUTOR
    " Map all parsed UI states into the generator's selection parameters
    " -------------------------------------------------------------------------
    TRY.
        DATA(generator) = NEW zcl_vdm_diagram_generator(
          renderer  = renderer
          selection = VALUE #(
            cds_name                 = CONV #( cds_name_xco )
            max_allowed_level        = max_level
            base                     = show_base
            keys                     = show_keys
            fields                   = show_fields
            associations_fields      = assoc_fields
            custom_developments_only = custom_only
            lines                    = VALUE #( associations = line_assoc
                                                compositions = line_comp
                                                inheritance  = line_inherit )
            discovery                = VALUE #( associations = disc_assoc
                                                compositions = disc_comp
                                                inheritance  = disc_inherit )
            include_cds              = include_list
            exclude_cds              = exclude_list
          )
        ).

        " Execute the deep analysis and get the formatted syntax
        diagram-diagrampayload = generator->generate_as_string( ).

      CATCH cx_root INTO DATA(exception).
        " Graceful error handling: pass the backend dump text to the UI safely
        diagram-diagrampayload = |Error: { exception->get_text( ) }|.
    ENDTRY.

    APPEND diagram TO diagrams.

    " -------------------------------------------------------------------------
    " 8. RESPOND TO RAP FRAMEWORK
    " -------------------------------------------------------------------------
    IF io_request->is_data_requested( ).
      io_response->set_data( diagrams ).
    ENDIF.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( 1 ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
