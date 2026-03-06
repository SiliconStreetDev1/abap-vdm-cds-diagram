"! <p class="shorttext synchronized">VDM Diagram Generator Engine</p>
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
class ZCL_VDM_DIAGRAM_GENERATOR definition
  public
  final
  create public .

public section.

  types:
    " =========================================================================
    " TYPES & CONFIGURATION
    " =========================================================================
    "Granular toggles to control which relationships are discovered and drawn
    BEGIN OF ty_granular_toggle,
        inheritance  TYPE abap_bool,
        associations TYPE abap_bool,
        compositions TYPE abap_bool,
      END OF ty_granular_toggle .
  types:
    "Structure for inclusion/exclusion filtering
    BEGIN OF ty_cds_name_filter,
        cds_name TYPE sxco_cds_object_name,
      END OF ty_cds_name_filter .
  types:
    tty_cds_name_filter TYPE TABLE OF ty_cds_name_filter WITH DEFAULT KEY .
  types:
    "The primary configuration payload passed by the user
    BEGIN OF ty_selection,
        cds_name                       TYPE sxco_cds_object_name,

        " Discovery (Which entities to find via recursion)
        discovery                      TYPE ty_granular_toggle,

        " Content (What attributes are displayed inside the entity box)
        base                           TYPE abap_bool,
        keys                           TYPE abap_bool,
        fields                         TYPE abap_bool,
        associations_fields            TYPE abap_bool,

        " Connectivity (Which lines to explicitly draw between boxes)
        lines                          TYPE ty_granular_toggle,

        " Scope Limiter: How many levels down/up the hierarchy we should traverse
        max_allowed_level              TYPE int4,

        " Custom Developments Only (Restrict output to Z* and Y* namespaces)
        custom_developments_only       TYPE abap_bool,

        " Force Render All Relationships (Show target box even if not in discovery scope)
        force_render_all_relationships TYPE abap_bool,

        " Filter Tables (Whitelist and Blacklist)
        include_cds                    TYPE tty_cds_name_filter,
        exclude_cds                    TYPE tty_cds_name_filter,
      END OF ty_selection .
  types:
    " =========================================================================
    " INTERNAL HIERARCHY TYPES (Passed to the Renderer)
    " =========================================================================
    BEGIN OF ty_cds_relationship,
        target           TYPE sxco_cds_object_name,
        target_uppercase TYPE sxco_cds_object_name,
        alias            TYPE sxco_ddef_alias_name,
        type             TYPE zvdm_diagram_cds_relat_type,
        has_parent       TYPE abap_bool,
        is_parent        TYPE abap_bool,
        cardinality      TYPE if_xco_cds_association_content=>ts_cardinality,
      END OF ty_cds_relationship .
  types:
    tty_cds_relationship TYPE TABLE OF ty_cds_relationship WITH DEFAULT KEY .
  types:
    BEGIN OF ty_cds_hierarchy,
        cds_name_uppercase TYPE sxco_cds_object_name,
        sources            TYPE TABLE OF sxco_cds_object_name WITH DEFAULT KEY,
        union              TYPE abap_bool,
        alias              TYPE string,
        index              TYPE int4,
        fields             TYPE sxco_t_cds_fields,
        associations       TYPE sxco_t_cds_associations,
        compositions       TYPE sxco_t_cds_compositions,
        relationships      TYPE tty_cds_relationship,
      END OF ty_cds_hierarchy .
  types:
    tty_cds_hierarchy TYPE SORTED TABLE OF ty_cds_hierarchy WITH NON-UNIQUE KEY index .

  constants:
    BEGIN OF c_relation_type,
        association TYPE zvdm_diagram_cds_relat_type VALUE 'A',
        composition TYPE zvdm_diagram_cds_relat_type VALUE 'C',
        inheritance TYPE zvdm_diagram_cds_relat_type VALUE 'I',
      END OF c_relation_type .

    " =========================================================================
    " PUBLIC METHODS
    " =========================================================================
    "! Initializes the generator with the user's configuration and preferred renderer
    "! @parameter selection   | The configuration scope (root entity, depth, toggles)
    "! @parameter format      | Global layout preferences (e.g., ortho lines)
    "! @parameter io_renderer | Constructor Injection: The specific engine (PlantUML, Mermaid, etc.) to use.
  methods CONSTRUCTOR
    importing
      !SELECTION type TY_SELECTION
      !RENDERER type ref to ZIF_VDM_DIAGRAM_RENDERER optional
    raising
      ZCX_VDM_DIAGRAM_GENERATOR .
    "! Executes the data extraction and triggers the injected rendering engine
    "! @parameter diagram_code | The final string table containing the diagram syntax
  methods GENERATE
    returning
      value(DIAGRAM_CODE) type STRING_TABLE .
    "! Retrieves any errors or warnings encountered during XCO parsing
  methods GET_MESSAGES
    returning
      value(MESSAGES) type SXCO_T_MESSAGES .
  PROTECTED SECTION.
    DATA hierarchies TYPE tty_cds_hierarchy.
    DATA selection   TYPE ty_selection.
    DATA messages    TYPE sxco_t_messages.
    DATA xco_adapter TYPE REF TO zif_vdm_diagram_xco_adapter.

    DATA renderer    TYPE REF TO zif_vdm_diagram_renderer.

    METHODS _iterate
      IMPORTING
        !cds_name       TYPE sxco_cds_object_name
        !child_cds_name TYPE sxco_cds_object_name OPTIONAL
        !current_level  TYPE int4.

    METHODS _validate_selection RAISING zcx_vdm_diagram_generator.
    METHODS _initialize_on_generate.
    METHODS _initialize_xco_adapter RAISING zcx_vdm_diagram_generator.
    METHODS _is_cloud RETURNING VALUE(is_cloud) TYPE abap_bool.
    METHODS _determine_relationships CHANGING !cs_hierarchy TYPE ty_cds_hierarchy.

  PRIVATE SECTION.
    METHODS _initialize_selection.
ENDCLASS.



CLASS ZCL_VDM_DIAGRAM_GENERATOR IMPLEMENTATION.


  METHOD constructor.
    me->selection = selection.


    " 1. Dependency Injection: Store the passed engine, or default to PlantUML
    IF renderer IS BOUND.
      me->renderer = renderer.
    ELSE.
      " Fallback to PlantUML if the caller doesn't specify an engine
      me->renderer = NEW zcl_vdm_diagram_plantuml( ).
    ENDIF.

    " 2. Setup and validate inputs
    _initialize_selection( ).
    _validate_selection( ).

    " 3. Determine if we are on BTP or On-Premise to load the correct XCO logic
    _initialize_xco_adapter( ).
  ENDMETHOD.


  METHOD generate.
    _initialize_on_generate( ).

    " 1. Extract all the SAP data recursively starting from the root CDS
    _iterate( cds_name      = selection-cds_name
              current_level = 1 ).

    " 2. Pass the completely extracted and mapped data structure to the
    "    injected rendering engine to generate the syntax.
    diagram_code = me->renderer->build(
                     hierarchies = me->hierarchies
                     selection   = me->selection
                     ).
  ENDMETHOD.


  METHOD get_messages.
    messages = me->messages.
  ENDMETHOD.


  METHOD _determine_relationships.
    " Evaluate Associations
    IF selection-discovery-associations = abap_true OR
       selection-lines-associations     = abap_true.

      LOOP AT cs_hierarchy-associations INTO DATA(association).
        DATA(cardinality) =  xco_adapter->get_cardinality( assocname = association->content( )->get_alias( )
                                                           cds_name = cs_hierarchy-cds_name_uppercase
                                                           hasparent = association->content( )->get_to_parent_indicator( )
                                                           currentcardinality =  association->content( )->get_cardinality( ) ).

        APPEND VALUE #( target           = xco_adapter->get_cds_name_from_ddl( association->content( )->get_target( ) )
                        target_uppercase = to_upper( association->content( )->get_target( ) )
                        alias            = association->content( )->get_alias( )
                        type             = c_relation_type-association
                        has_parent       = association->content( )->get_to_parent_indicator( )
                        cardinality      = cardinality ) TO cs_hierarchy-relationships.
      ENDLOOP.
    ENDIF.

    " Evaluate Compositions
    IF selection-discovery-compositions = abap_true OR
       selection-lines-compositions     = abap_true.

      LOOP AT cs_hierarchy-compositions INTO DATA(composition).
        APPEND VALUE #( target           = xco_adapter->get_cds_name_from_ddl( composition->target )
                        target_uppercase = to_upper( composition->target )
                        alias            = composition->content( )->get_alias( )
                        type             = c_relation_type-composition
                        is_parent        = abap_true
                        cardinality      = CORRESPONDING #( composition->content( )->get_cardinality( ) ) ) TO cs_hierarchy-relationships.
      ENDLOOP.
    ENDIF.

    " Evaluate Inheritance (Upward Data Sources)
    IF selection-discovery-inheritance = abap_true OR
       selection-lines-inheritance     = abap_true.

      LOOP AT cs_hierarchy-sources INTO DATA(source).
        APPEND VALUE #( target           = xco_adapter->get_cds_name_from_ddl( source )
                        target_uppercase = to_upper( source )
                        type             = c_relation_type-inheritance
                        cardinality      = VALUE #( min = 1 max = 1 )
                      ) TO cs_hierarchy-relationships.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD _initialize_on_generate.
    " Ensure we start with a clean slate for multiple runs
    CLEAR hierarchies.
    CLEAR messages.
  ENDMETHOD.


  METHOD _initialize_selection.
    " Ensure all inputs are uppercase to prevent case-sensitivity misses during recursion
    me->selection-cds_name = to_upper( me->selection-cds_name ).

    " Ensure a minimum depth is set
    IF me->selection-max_allowed_level = 0.
      me->selection-max_allowed_level = 1.
    ENDIF.

    LOOP AT me->selection-include_cds ASSIGNING FIELD-SYMBOL(<include>).
      <include>-cds_name = to_upper( <include>-cds_name ).
    ENDLOOP.

    LOOP AT me->selection-exclude_cds ASSIGNING FIELD-SYMBOL(<exclude>).
      <exclude>-cds_name = to_upper( <exclude>-cds_name ).
    ENDLOOP.
  ENDMETHOD.


  METHOD _initialize_xco_adapter.
    " Dynamic instantiation of the environment-specific adapter to avoid syntax errors
    " if Cloud objects are missing in an On-Premise system.
    DATA(class_name) = COND string(
      WHEN _is_cloud( ) = abap_true THEN 'ZCL_VDM_DIAGRAM_XCO_ADP_CP'
      ELSE                               'ZCL_VDM_DIAGRAM_XCO_ADP'
    ).

    TRY.
        CREATE OBJECT xco_adapter TYPE (class_name).
      CATCH cx_sy_create_object_error.
        " Handle missing adapter exception if needed
    ENDTRY.
  ENDMETHOD.


  METHOD _is_cloud.
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


  METHOD _iterate.
    TRY.
        DATA(cds_name_upper) = to_upper( cds_name ).

        " Guard 1: Prevent infinite loops from bidirectional associations
        IF line_exists( hierarchies[ cds_name_uppercase = cds_name_upper ] ).
          RETURN.
        ENDIF.

        " Guard 2: Respect the user's recursion depth limit
        IF current_level > selection-max_allowed_level.
          RETURN.
        ENDIF.

        " Filters: Do not filter out the root entity requested by the user
        IF cds_name_upper <> selection-cds_name.

          " Blacklist check
          IF selection-exclude_cds IS NOT INITIAL
             AND line_exists( selection-exclude_cds[ cds_name = cds_name_upper ] ).
            RETURN.
          ENDIF.

          " Whitelist check
          IF selection-include_cds IS NOT INITIAL
             AND NOT line_exists( selection-include_cds[ cds_name = cds_name_upper ] ).
            RETURN.
          ENDIF.
        ENDIF.

        " Namespace Check: Filter standard SAP noise if requested
        IF selection-custom_developments_only = abap_true
           AND NOT ( cds_name_upper CP 'Z*' OR cds_name_upper CP 'Y*' ).
          RETURN.
        ENDIF.

        " Extract all metadata for the current entity via the XCO adapter
        DATA(hierarchy) = VALUE ty_cds_hierarchy(
                                cds_name_uppercase = cds_name_upper
                                alias             = xco_adapter->get_cds_name_from_ddl( cds_name )
                                index             = current_level
                                fields            = xco_adapter->get_fields( cds_name )
                                associations      = xco_adapter->get_associations( cds_name )
                                compositions      = xco_adapter->get_compositions( cds_name )
                                sources           = xco_adapter->get_sources( cds_name ) ).

        " Map outgoing connections (lines) from this entity
        _determine_relationships( CHANGING cs_hierarchy = hierarchy ).

        " Save the mapped entity to the global collection
        INSERT hierarchy INTO TABLE me->hierarchies.

        " Recursively traverse all the targets we just mapped
        LOOP AT hierarchy-relationships INTO DATA(relationship).
          _iterate( cds_name      = relationship-target_uppercase
                    current_level = current_level + 1 ).
        ENDLOOP.

      CATCH cx_xco_ar_existence_exception INTO DATA(existence_exception).
        " Gracefully handle and log views that don't exist or are inactive
        APPEND xco_cp=>message( VALUE #(
                 msgty = 'E'
                 msgid = existence_exception->if_t100_message~t100key-msgid
                 msgno = existence_exception->if_t100_message~t100key-msgno
                 msgv1 = existence_exception->if_t100_dyn_msg~msgv1
                 msgv2 = existence_exception->if_t100_dyn_msg~msgv2 ) ) TO messages.
    ENDTRY.
  ENDMETHOD.


  METHOD _validate_selection.
    " The generator cannot start without a root entity
    IF selection-cds_name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_vdm_diagram_generator
        EXPORTING
          textid = zcx_vdm_diagram_generator=>mandatory
          msgv1  = 'CDS Name'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
