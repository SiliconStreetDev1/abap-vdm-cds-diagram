CLASS zcl_vdm_diagram_query DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zcl_vdm_diagram_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_diagrams TYPE STANDARD TABLE OF zce_vdm_diagram WITH DEFAULT KEY.
    DATA ls_diagram  TYPE zce_vdm_diagram.

    DATA lv_cds_filter TYPE string.
    DATA lv_engine     TYPE string.

    " Default configuration variables
    DATA lv_max_level    TYPE i VALUE 1.
    DATA lv_base         TYPE abap_boolean VALUE abap_false.
    DATA lv_keys         TYPE abap_boolean VALUE abap_false.
    DATA lv_fields       TYPE abap_boolean VALUE abap_false.
    DATA lv_assoc_fields TYPE abap_boolean VALUE abap_false.
    DATA lv_custom_only  TYPE abap_boolean VALUE abap_false.
    DATA lv_line_assoc   TYPE abap_boolean VALUE abap_true.
    DATA lv_line_comp    TYPE abap_boolean VALUE abap_true.
    DATA lv_line_inherit TYPE abap_boolean VALUE abap_true.
    DATA lv_include_str  TYPE string.
    DATA lv_exclude_str  TYPE string.

    " 1. STRICT RAP CONTRACT FULFILLMENT
    DATA(lo_paging)    = io_request->get_paging( ).
    DATA(lv_offset)    = lo_paging->get_offset( ).

    " 2. EXTRACT ALL FILTERS SAFELY
    TRY.
        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
        LOOP AT lt_ranges INTO DATA(ls_range).
          " Use a macro/helper logic for boolean since OData can send 'true' or 'X'
          DATA(lv_val) = to_upper( CONV string( ls_range-range[ 1 ]-low ) ).
          DATA(lv_bool) = xsdbool( lv_val = 'TRUE' OR lv_val = 'X' ).

          CASE to_upper( ls_range-name ).
            WHEN 'CDSNAME'.         lv_cds_filter   = ls_range-range[ 1 ]-low.
            WHEN 'RENDERERENGINE'.  lv_engine       = ls_range-range[ 1 ]-low.
            WHEN 'MAXLEVEL'.        lv_max_level    = ls_range-range[ 1 ]-low.
            WHEN 'SHOWBASE'.        lv_base         = lv_bool.
            WHEN 'SHOWKEYS'.        lv_keys         = lv_bool.
            WHEN 'SHOWFIELDS'.      lv_fields       = lv_bool.
            WHEN 'SHOWASSOCFIELDS'. lv_assoc_fields = lv_bool.
            WHEN 'CUSTOMDEVONLY'.   lv_custom_only  = lv_bool.
            WHEN 'LINEASSOC'.       lv_line_assoc   = lv_bool.
            WHEN 'LINECOMP'.        lv_line_comp    = lv_bool.
            WHEN 'LINEINHERIT'.     lv_line_inherit = lv_bool.
            WHEN 'INCLUDECDS'.      lv_include_str  = ls_range-range[ 1 ]-low.
            WHEN 'EXCLUDECDS'.      lv_exclude_str  = ls_range-range[ 1 ]-low.
          ENDCASE.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.

    " 3. HANDLE EXITS & PAGING TRAPS
    IF lv_cds_filter IS INITIAL OR lv_offset > 0.
      IF io_request->is_data_requested( ). io_response->set_data( lt_diagrams ). ENDIF.
      IF io_request->is_total_numb_of_rec_requested( ).
        io_response->set_total_number_of_records( COND #( WHEN lv_offset > 0 THEN 1 ELSE 0 ) ).
      ENDIF.
      RETURN.
    ENDIF.

    " 4. POST-VALIDATION MAP
    ls_diagram-CdsName        = lv_cds_filter.
    ls_diagram-RendererEngine = lv_engine.
    DATA(lv_cds_xco)          = to_upper( lv_cds_filter ).

    " 5. PARSE COMMA-SEPARATED WHITELIST/BLACKLIST INTO TABLES
    DATA lt_include_xco TYPE STANDARD TABLE OF sxco_cds_object_name.
    DATA lt_exclude_xco TYPE STANDARD TABLE OF sxco_cds_object_name.

    IF lv_include_str IS NOT INITIAL.
      SPLIT lv_include_str AT ',' INTO TABLE DATA(lt_inc_strings).
      LOOP AT lt_inc_strings INTO DATA(lv_inc).
        APPEND to_upper( condense( lv_inc ) ) TO lt_include_xco.
      ENDLOOP.
    ENDIF.

    IF lv_exclude_str IS NOT INITIAL.
      SPLIT lv_exclude_str AT ',' INTO TABLE DATA(lt_exc_strings).
      LOOP AT lt_exc_strings INTO DATA(lv_exc).
        APPEND to_upper( condense( lv_exc ) ) TO lt_exclude_xco.
      ENDLOOP.
    ENDIF.

    " 6. STRATEGY FACTORY
    DATA lo_renderer TYPE REF TO zcl_vdm_diagram_base.
    CASE to_upper( lv_engine ).
      WHEN 'PLANTUML'. lo_renderer = NEW zcl_vdm_diagram_plantuml( ). ls_diagram-FileExtension = '.puml'.
      WHEN 'GRAPHVIZ'. lo_renderer = NEW zcl_vdm_diagram_graphviz( ). ls_diagram-FileExtension = '.dot'.
      WHEN 'D2'.       lo_renderer = NEW zcl_vdm_diagram_d2( ).       ls_diagram-FileExtension = '.d2'.
      WHEN OTHERS.     lo_renderer = NEW zcl_vdm_diagram_mermaid( ).  ls_diagram-FileExtension = '.mmd'.
    ENDCASE.

    " 7. GENERATION ENGINE (Fully mapped to your API)
    TRY.
        DATA(lo_generator) = NEW zcl_vdm_diagram_generator(
          renderer  = lo_renderer
          selection = VALUE #(
            cds_name                 = CONV #( lv_cds_xco )
            max_allowed_level        = lv_max_level
            base                     = lv_base
            keys                     = lv_keys
            fields                   = lv_fields
            associations_fields      = lv_assoc_fields
            custom_developments_only = lv_custom_only
            lines                    = VALUE #( associations = lv_line_assoc compositions = lv_line_comp inheritance = lv_line_inherit )
            include_cds              = lt_include_xco
            exclude_cds              = lt_exclude_xco
          )
        ).

        ls_diagram-DiagramPayload = lo_generator->generate_as_string( ).

      CATCH cx_root INTO DATA(lx_error).
        ls_diagram-DiagramPayload = |Error: { lx_error->get_text( ) }|.
    ENDTRY.

    APPEND ls_diagram TO lt_diagrams.

    " 8. RESPOND
    IF io_request->is_data_requested( ). io_response->set_data( lt_diagrams ). ENDIF.
    IF io_request->is_total_numb_of_rec_requested( ). io_response->set_total_number_of_records( 1 ). ENDIF.

  ENDMETHOD.
ENDCLASS.
