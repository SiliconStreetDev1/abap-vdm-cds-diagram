"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! PURPOSE: RAP Query Provider for ZCE_VDM_DIAGRAM_CDS_SEARCH.
"! Serves as the backend search engine for the UI5 Diagram F4 Value Help.
CLASS zcl_vdm_diagram_cds_search DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .

  PROTECTED SECTION.

  PRIVATE SECTION.
    "! Extracts the search string from either the generic search bar or the column filter
    METHODS get_search_string
      IMPORTING
        io_request              TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rv_search_string) TYPE string.
ENDCLASS.



CLASS ZCL_VDM_DIAGRAM_CDS_SEARCH IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA: paged_results TYPE STANDARD TABLE OF zce_vdm_diagram_cds_search,
          all_results   TYPE STANDARD TABLE OF zce_vdm_diagram_cds_search.

    " 1. ENTERPRISE HARDENING
    " Wrap execution in a TRY block to prevent ST22 dumps from framework or memory issues.
    TRY.
        " Identify the user's search intent
        DATA(search_query) = get_search_string( io_request ).

        " 2. UX ENHANCEMENT: Implicit Wildcards
        " If the user didn't provide a wildcard, append one to allow 'starts with' behavior.
        IF search_query IS NOT INITIAL AND
           search_query NS '*' AND
           search_query NS '%'.
          search_query = search_query && '*'.
        ENDIF.

        " 3. PERFORMANCE GUARD
        " Default to custom objects (Z*) if the search is empty to minimize DB load.
        IF search_query IS INITIAL.
          search_query = 'Z*'.
        ENDIF.

        " 4. Data Retrieval
        DATA(xco_adapter) = ZCL_VDM_DIAGRAM_XCO_FACTORY=>get_xco_adapter( ).
        DATA(cds_names)   = xco_adapter->search_for_cds( search_query ).

        " 5. Mapping
        " Map the string list into the custom entity structure using a modern constructor.
        all_results = VALUE #( FOR cds_name IN cds_names ( cdsname = cds_name ) ).

        " 6. Sort for Pagination Consistency
        SORT all_results BY cdsname ASCENDING.

        " 7. Handle $count Requests
        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( all_results ) ).
        ENDIF.

        " 8. Handle Pagination ($top / $skip)
        IF io_request->is_data_requested( ).
          DATA(paging)      = io_request->get_paging( ).
          DATA(offset)      = paging->get_offset( ).
          DATA(page_size)   = paging->get_page_size( ).
          DATA(total_lines) = lines( all_results ).

          " Scenario: UI5 requests the entire set
          IF page_size = if_rap_query_paging=>page_size_unlimited.
            paged_results = all_results.

          " Scenario: Standard paging within data bounds
          ELSEIF offset < total_lines.
            " Determine safe upper bound to avoid index errors
            DATA(max_index) = offset + page_size.
            IF max_index > total_lines.
              max_index = total_lines.
            ENDIF.

            " Slice the internal table to the requested window
            LOOP AT all_results ASSIGNING FIELD-SYMBOL(<result_row>)
                 FROM ( offset + 1 )
                 TO max_index.
              APPEND <result_row> TO paged_results.
            ENDLOOP.
          ENDIF.

          " Dispatch final data to the RAP framework
          io_response->set_data( paged_results ).
        ENDIF.

      CATCH cx_root.
        " Graceful Fallback: Return empty results on any system exception.
        io_response->set_data( paged_results ).
        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( 0 ).
        ENDIF.
    ENDTRY.

  ENDMETHOD.


  METHOD get_search_string.
    " Primary source: Generic OData search bar
    rv_search_string = io_request->get_search_expression( ).

    " Secondary source: Column-specific filtering (CDSNAME)
    IF rv_search_string IS INITIAL.
      TRY.
          DATA(filter_ranges) = io_request->get_filter( )->get_as_ranges( ).

          " Look specifically for the CDSNAME filter component
          ASSIGN filter_ranges[ name = 'CDSNAME' ] TO FIELD-SYMBOL(<cds_name_filter>).

          IF sy-subrc = 0 AND lines( <cds_name_filter>-range ) > 0.
            " Use the first range condition provided by the UI
            DATA(first_condition) = <cds_name_filter>-range[ 1 ].
            rv_search_string = first_condition-low.

            " Transform 'Contains Pattern' operators from UI5 into valid search wildcards
            IF first_condition-option = 'CP' AND rv_search_string NS '*'.
               rv_search_string = '*' && rv_search_string && '*'.
            ENDIF.
          ENDIF.

        CATCH cx_rap_query_filter_no_range.
          " No filters defined; return initial search string
      ENDTRY.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
