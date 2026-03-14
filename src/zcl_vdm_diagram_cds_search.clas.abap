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

CLASS zcl_vdm_diagram_cds_search IMPLEMENTATION.

* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_VDM_DIAGRAM_CDS_SEARCH->IF_RAP_QUERY_PROVIDER~SELECT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_REQUEST                     TYPE REF TO IF_RAP_QUERY_REQUEST
* | [--->] IO_RESPONSE                    TYPE REF TO IF_RAP_QUERY_RESPONSE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD if_rap_query_provider~select.
    DATA: lt_result     TYPE STANDARD TABLE OF zce_vdm_diagram_cds_search,
          lt_result_all TYPE STANDARD TABLE OF zce_vdm_diagram_cds_search.

    " 1. ENTERPRISE HARDENING: Wrap the entire execution in a TRY/CATCH.
    " If the XCO framework fails or memory limits are hit, we return an empty payload
    " rather than causing a system dump (ST22) and crashing the Fiori app.
    TRY.
        " Extract the search query from the UI5 request
        DATA(lv_search_string) = get_search_string( io_request ).

        " 2. UX ENHANCEMENT: Implicit Wildcards for Type-Ahead
        " If the user types "ZBLX" without a wildcard, standard SQL looks for exact matches.
        " For a UI5 F4 help, we want "starts with" behavior unless explicitly wildcarded.
        IF lv_search_string IS NOT INITIAL AND
           lv_search_string NS '*' AND
           lv_search_string NS '%'.
          lv_search_string = lv_search_string && '*'.
        ENDIF.

        " 3. PARANOIA CHECK: Prevent massive unconstrained DB loads.
        " If completely empty (user just opens the dialog), default to 'Z*'
        " to only fetch custom objects and save database load.
        IF lv_search_string IS INITIAL.
          lv_search_string = 'Z*'.
        ENDIF.

        " 4. Execute the search via the XCO Adapter
        DATA(lo_xco_adapter) = NEW zcl_vdm_diagram_xco_adp( ).
        DATA(lt_cds_names)   = lo_xco_adapter->zif_vdm_diagram_xco_adapter~search_for_cds( lv_search_string ).

        " 5. Map the raw string array into the Custom Entity structure
        lt_result_all = VALUE #( FOR lv_name IN lt_cds_names ( cdsname = lv_name ) ).

        " 6. Sort results alphabetically to ensure consistent UI5 pagination
        SORT lt_result_all BY cdsname ASCENDING.

        " 7. Handle standard OData $count requests (Required for UI5 Smart Controls)
        IF io_request->is_total_numb_of_rec_requested( ) = abap_true.
          io_response->set_total_number_of_records( lines( lt_result_all ) ).
        ENDIF.

        " 8. Handle standard OData $top and $skip requests (Pagination)
        IF io_request->is_data_requested( ) = abap_true.
          DATA(lo_paging) = io_request->get_paging( ).
          DATA(lv_offset) = lo_paging->get_offset( ).
          DATA(lv_page_size) = lo_paging->get_page_size( ).

          DATA(lv_total_lines) = lines( lt_result_all ).

          " If UI5 requests all data (-1)
          IF lv_page_size = if_rap_query_paging=>page_size_unlimited.
            lt_result = lt_result_all.


          " Only page if offset is safely within the bounds of the actual data
          ELSEIF lv_offset < lv_total_lines.

            " Calculate the safe maximum index to read up to, preventing ITAB_ILLEGAL_INDEX dumps
            DATA(lv_max_index) = lv_offset + lv_page_size.
            IF lv_max_index > lv_total_lines.
              lv_max_index = lv_total_lines.
            ENDIF.

            " Slice the internal table to match the requested page
            LOOP AT lt_result_all ASSIGNING FIELD-SYMBOL(<ls_result>)
                 FROM ( lv_offset + 1 )
                 TO lv_max_index.
              APPEND <ls_result> TO lt_result.
            ENDLOOP.

          ENDIF.

          " Return the final payload to the RAP framework
          io_response->set_data( lt_result ).
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        " Graceful fallback on error: Send empty dataset back to UI.
        " This ensures the UI5 app does not crash, even if the backend fails.
        io_response->set_data( lt_result ).
        IF io_request->is_total_numb_of_rec_requested( ) = abap_true.
          io_response->set_total_number_of_records( 0 ).
        ENDIF.
    ENDTRY.

  ENDMETHOD.

* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_VDM_DIAGRAM_CDS_SEARCH->GET_SEARCH_STRING
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_REQUEST                     TYPE REF TO IF_RAP_QUERY_REQUEST
* | [<-()] RV_SEARCH_STRING               TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_search_string.

    " Check 1: Did the user type into the generic OData search bar?
    rv_search_string = io_request->get_search_expression( ).

    " Check 2: If the search bar is empty, did they use the specific column filter?
    IF rv_search_string IS INITIAL.
      TRY.
          DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
          ASSIGN lt_ranges[ name = 'CDSNAME' ] TO FIELD-SYMBOL(<ls_range>).

          IF sy-subrc = 0 AND lines( <ls_range>-range ) > 0.
            " Extract the 'LOW' value from the first condition of the range
            rv_search_string = <ls_range>-range[ 1 ]-low.

            " Handle 'Contains Pattern' (CP) operators gracefully from UI5 filters
            IF <ls_range>-range[ 1 ]-option = 'CP' AND rv_search_string NS '*'.
               rv_search_string = '*' && rv_search_string && '*'.
            ENDIF.
          ENDIF.

        CATCH cx_rap_query_filter_no_range.
          " No filter parameters were provided, string remains initial
      ENDTRY.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
