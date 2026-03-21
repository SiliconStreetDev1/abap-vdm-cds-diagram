"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! PURPOSE: RAP Query Provider for the VDM Diagram Generator.
"! Extracts UI filters, dynamically deserializes JSON formatting based on the
"! selected engine, and passes native ABAP structures to the renderer constructors.
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
    " 0. DATA DECLARATIONS
    " -------------------------------------------------------------------------
    DATA diagrams TYPE STANDARD TABLE OF zce_vdm_diagram WITH DEFAULT KEY.
    DATA diagram  TYPE zce_vdm_diagram.

    " Primary entity filters captured from the UI5 SmartTable/FilterBar
    DATA cds_filter         TYPE string.
    DATA engine_key         TYPE string.
    DATA format_config_json TYPE string. " Captures the JSON formatting payload from the UI

    " Default structural configuration variables (Node detail depth)
    DATA max_level       TYPE i VALUE 1.
    DATA show_base       TYPE abap_boolean VALUE abap_false.
    DATA show_keys       TYPE abap_boolean VALUE abap_false.
    DATA show_fields     TYPE abap_boolean VALUE abap_false.
    DATA assoc_fields    TYPE abap_boolean VALUE abap_false.
    DATA custom_only     TYPE abap_boolean VALUE abap_false.

    " Line rendering configurations (What edges to draw)
    DATA line_assoc      TYPE abap_boolean VALUE abap_true.
    DATA line_comp       TYPE abap_boolean VALUE abap_true.
    DATA line_inherit    TYPE abap_boolean VALUE abap_true.

    " Discovery/Traversal configurations (Which paths to follow down the tree)
    DATA disc_assoc      TYPE abap_boolean VALUE abap_true.
    DATA disc_comp       TYPE abap_boolean VALUE abap_true.
    DATA disc_inherit    TYPE abap_boolean VALUE abap_true.

    " Raw comma-separated lists for targeted View inclusion/exclusion
    DATA include_string  TYPE string.
    DATA exclude_string  TYPE string.

    " -------------------------------------------------------------------------
    " 1. STRICT RAP CONTRACT FULFILLMENT (Paging)
    " Extract paging details to ensure we don't over-fetch if the UI is just
    " checking for total counts or scrolling.
    " -------------------------------------------------------------------------
    DATA(paging) = io_request->get_paging( ).
    DATA(offset) = paging->get_offset( ).

    " -------------------------------------------------------------------------
    " 2. EXTRACT ALL FILTERS SAFELY
    " Loop through the incoming RAP ranges and assign them to our typed variables.
    " We use to_upper() to ensure case-insensitive matching for boolean flags.
    " -------------------------------------------------------------------------
    TRY.
        DATA(filter_ranges) = io_request->get_filter( )->get_as_ranges( ).

        LOOP AT filter_ranges INTO DATA(filter_range).
          DATA(raw_value) = to_upper( CONV string( filter_range-range[ 1 ]-low ) ).
          DATA(is_true)   = xsdbool( raw_value = 'TRUE' OR raw_value = 'X' ).

          CASE to_upper( filter_range-name ).
            WHEN 'CDSNAME'.         cds_filter         = filter_range-range[ 1 ]-low.
            WHEN 'RENDERERENGINE'.  engine_key         = filter_range-range[ 1 ]-low.
            WHEN 'FORMATCONFIG'.    format_config_json = filter_range-range[ 1 ]-low.
            WHEN 'MAXLEVEL'.        max_level          = filter_range-range[ 1 ]-low.
            WHEN 'SHOWBASE'.        show_base          = is_true.
            WHEN 'SHOWKEYS'.        show_keys          = is_true.
            WHEN 'SHOWFIELDS'.      show_fields        = is_true.
            WHEN 'SHOWASSOCFIELDS'. assoc_fields       = is_true.
            WHEN 'CUSTOMDEVONLY'.   custom_only        = is_true.
            WHEN 'LINEASSOC'.       line_assoc         = is_true.
            WHEN 'LINECOMP'.        line_comp          = is_true.
            WHEN 'LINEINHERIT'.     line_inherit       = is_true.
            WHEN 'DISCASSOC'.       disc_assoc         = is_true.
            WHEN 'DISCCOMP'.        disc_comp          = is_true.
            WHEN 'DISCINHERIT'.     disc_inherit       = is_true.
            WHEN 'INCLUDECDS'.      include_string     = filter_range-range[ 1 ]-low.
            WHEN 'EXCLUDECDS'.      exclude_string     = filter_range-range[ 1 ]-low.
          ENDCASE.
        ENDLOOP.
      CATCH cx_root.
        " Silently catch missing filters to allow defaults to persist
    ENDTRY.

    " -------------------------------------------------------------------------
    " 3. HANDLE EXITS & PAGING TRAPS
    " If no root CDS view is provided, or the UI is requesting a second page
    " (offset > 0) for a single diagram, exit early to save processing power.
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
    " Assign the core identifiers to the outgoing RAP entity record.
    " -------------------------------------------------------------------------
    diagram-cdsname        = cds_filter.
    diagram-rendererengine = engine_key.
    DATA(cds_name_xco)     = to_upper( cds_filter ).

    " -------------------------------------------------------------------------
    " 5. PARSE COMMA-SEPARATED WHITELIST/BLACKLIST
    " Convert UI5 comma-separated strings into standard ABAP tables for the generator.
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
    " 6. STRATEGY FACTORY & DYNAMIC DESERIALIZATION
    " We use /UI2/CL_JSON here specifically because UI5 JSON payloads are
    " loosely typed. /UI2 handles type coercion (string to int) and ignores
    " extra fields, preventing XSLT Data Loss dumps.
    " -------------------------------------------------------------------------
    DATA renderer TYPE REF TO zcl_vdm_diagram_base.

    CASE to_upper( engine_key ).
      WHEN 'PLANTUML'.
        DATA plantuml_format TYPE zcl_vdm_diagram_plantuml=>ty_format.
        IF format_config_json IS NOT INITIAL.
          /ui2/cl_json=>deserialize( EXPORTING json = format_config_json CHANGING data = plantuml_format ).
        ENDIF.
        renderer = NEW zcl_vdm_diagram_plantuml( format = plantuml_format ).
        diagram-fileextension = '.puml'.

      WHEN 'GRAPHVIZ'.
        DATA graphviz_format TYPE zcl_vdm_diagram_graphviz=>ty_format.
        IF format_config_json IS NOT INITIAL.
          /ui2/cl_json=>deserialize( EXPORTING json = format_config_json CHANGING data = graphviz_format ).
        ENDIF.
        renderer = NEW zcl_vdm_diagram_graphviz( format = graphviz_format ).
        diagram-fileextension = '.dot'.

      WHEN 'D2'.
        DATA d2_format TYPE zcl_vdm_diagram_d2=>ty_format.
        IF format_config_json IS NOT INITIAL.
          /ui2/cl_json=>deserialize( EXPORTING json = format_config_json CHANGING data = d2_format ).
        ENDIF.
        renderer = NEW zcl_vdm_diagram_d2( format = d2_format ).
        diagram-fileextension = '.d2'.

      WHEN 'CYTOSCAPE'. " <-- INTERACTIVE ENGINE
        DATA cytoscape_format TYPE zcl_vdm_diagram_cytoscape=>ty_format.
        IF format_config_json IS NOT INITIAL.
          " We apply pretty_mode here so UI5's layoutAlgorithm maps to layout_algorithm safely
          /ui2/cl_json=>deserialize(
            EXPORTING
              json        = format_config_json
              pretty_name = /ui2/cl_json=>pretty_mode-camel_case
            CHANGING
              data        = cytoscape_format
          ).
        ENDIF.
        renderer = NEW zcl_vdm_diagram_cytoscape( format = cytoscape_format ).
        diagram-fileextension = '.json'.

      WHEN OTHERS. " MERMAID as default
        DATA mermaid_format TYPE zcl_vdm_diagram_mermaid=>ty_format.
        IF format_config_json IS NOT INITIAL.
          /ui2/cl_json=>deserialize( EXPORTING json = format_config_json CHANGING data = mermaid_format ).
        ENDIF.
        renderer = NEW zcl_vdm_diagram_mermaid( format = mermaid_format ).
        diagram-fileextension = '.mmd'.
    ENDCASE.

    " -------------------------------------------------------------------------
    " 7. GENERATION ENGINE EXECUTOR
    " Pass the fully configured Selection parameters and the specific Renderer
    " instance into the core Generator.
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

        " Execute the traversal loop and extract the final payload string
        diagram-diagrampayload = generator->generate_as_string( ).

      CATCH cx_root INTO DATA(exception).
        diagram-diagrampayload = |Error: { exception->get_text( ) }|.
    ENDTRY.

    APPEND diagram TO diagrams.

    " -------------------------------------------------------------------------
    " 8. RESPOND TO RAP FRAMEWORK
    " Return the constructed entity record back to the UI5 OData service.
    " -------------------------------------------------------------------------
    IF io_request->is_data_requested( ).
      io_response->set_data( diagrams ).
    ENDIF.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( 1 ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
