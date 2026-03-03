"! <p class="shorttext synchronized">VDM PlantUML Generator</p>
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
class ZCL_VDM_PLANTUML_GENERATOR definition
  public
  final
  create public .

public section.

  types:
    BEGIN OF ty_granular_toggle,
        inheritance  TYPE abap_bool,
        associations TYPE abap_bool,
        compositions TYPE abap_bool,
      END OF ty_granular_toggle .
  types:
    BEGIN OF ty_cds_name_filter,
             cds_name TYPE sxco_cds_object_name,
           END OF ty_cds_name_filter .
  types:
    tty_cds_name_filter TYPE TABLE OF ty_cds_name_filter WITH DEFAULT KEY .
  types:
    BEGIN OF ty_selection,
        cds_name                       TYPE sxco_cds_object_name,
        "Discovery (Which entities to find via recursion)

        "Discovery and Lines are split into granular toggles for Associations, Compositions, and Inheritance,
        "to give more flexibility to the user. The user might not want to see the lines for Inheritance for example, but still want to discover the parent CDS and its fields.
        discovery                      TYPE ty_granular_toggle,

        "Content (What is inside the entity box) ---
        base                           TYPE abap_bool,
        keys                           TYPE abap_bool,
        fields                         TYPE abap_bool,
        associations_fields            TYPE abap_bool,


        "Connectivity (Which lines to draw between boxes)
        "This will also basically enable Discovery options for the same
        lines                          TYPE ty_granular_toggle,


        " How Many levels we want to show
        max_allowed_level              TYPE int4,

        " Custom Developments Only (Whether to include all CDS Views or just those starting with Z and Y, as a lot of standard CDS Views can create noise in the diagram)
        custom_developments_only       TYPE abap_bool,


        " Force Render All Relationships (Even if the target CDS doesn't meet the Discovery criteria, we might still want to show it as a box with limited information,
        " instead of just showing a line without a box, as it gives more context to the user about the relationship)
        force_render_all_relationships TYPE abap_bool,

        " Filter Tables
        include_cds                    TYPE tty_cds_name_filter,
        exclude_cds                    TYPE tty_cds_name_filter,

      END OF ty_selection .
  types:
    BEGIN OF ty_cds_relationship,
        target           TYPE sxco_cds_object_name,
        target_uppercase TYPE sxco_cds_object_name,
        alias            TYPE sxco_ddef_alias_name,
        type             TYPE zvdm_plantuml_cds_relat_type,
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
        association TYPE zvdm_plantuml_cds_relat_type VALUE 'A',
        composition TYPE zvdm_plantuml_cds_relat_type VALUE 'C',
        inheritance TYPE  zvdm_plantuml_cds_relat_type VALUE 'I',
      END OF c_relation_type .
  data:
    relationships TYPE TABLE OF ty_cds_relationship WITH DEFAULT KEY .

  methods CONSTRUCTOR
    importing
      !SELECTION type TY_SELECTION
      !FORMAT type ZCL_VDM_PLANTUML_ENTITY=>TY_FORMAT_OPTIONS optional
    raising
      ZCX_VDM_PLANTUML_GENERATOR .
  methods GENERATE
    returning
      value(PLANTUML) type STRING_TABLE .
  methods GET_MESSAGES
    returning
      value(MESSAGES) type SXCO_T_MESSAGES .
protected section.

  data HIERARCHIES type TTY_CDS_HIERARCHY .
  data SELECTION type TY_SELECTION .
  data MESSAGES type SXCO_T_MESSAGES .
  data XCO_ADAPTER type ref to ZIF_VDM_PLANTUML_XCO_ADAPTER .
  data FORMAT type ZCL_VDM_PLANTUML_ENTITY=>TY_FORMAT_OPTIONS .

  methods _ITERATE
    importing
      !CDS_NAME type SXCO_CDS_OBJECT_NAME
      !CHILD_CDS_NAME type SXCO_CDS_OBJECT_NAME optional
      !CURRENT_LEVEL type INT4 .
  methods _VALIDATE_SELECTION
    raising
      ZCX_VDM_PLANTUML_GENERATOR .
  methods _INITIALIZE_ON_GENERATE .
  methods _INITIALIZE_XCO_ADAPTER
    raising
      ZCX_VDM_PLANTUML_GENERATOR .
  methods _IS_CLOUD
    returning
      value(IS_CLOUD) type ABAP_BOOL .
  methods _DETERMINE_RELATIONSHIPS
    changing
      !CS_HIERARCHY type TY_CDS_HIERARCHY .
private section.

  methods _INITIALIZE_SELECTION .
ENDCLASS.



CLASS ZCL_VDM_PLANTUML_GENERATOR IMPLEMENTATION.


  METHOD constructor.

    me->selection = selection. " Set Selection for later usage
    me->format = format. " Set Formats

    " Initialize Selection with default values and also do any conversions needed,
    "     like upper case etc, so that we have a consistent format for the rest of the program
    _initialize_selection( ).

    " Basic Validations for Selections passed
    _validate_selection( ).

    " Initialize XCO Adapter depending on the environment we are in, as the API's are different for Cloud and On-Premise, we have created Adapters to abstract that difference,
    " so we just have to initialize the correct adapter and the rest of the code can be the same for both environments
    _initialize_xco_adapter( ).

  ENDMETHOD.


  METHOD generate.

    "  Initialize any internal tables or variables before we start the generation process
    _initialize_on_generate( ).

    " Start the Recursive Iteration to build Hierarchies with the starting CDS View provided by the user, and the current level 1
    _iterate( cds_name      = selection-cds_name
              current_level = 1 ).

    " Generate PlantUML
    plantuml = NEW zcl_vdm_plantuml_entity( hierarchies = hierarchies
                                            selection   = selection
                                            format = format
                                            )->build( ).
  ENDMETHOD.


  METHOD _initialize_on_generate.

    " Clear any tables or structures before we attempt to generate
    CLEAR hierarchies.

  ENDMETHOD.


  METHOD _initialize_xco_adapter.

    " Define the class name as a string based on the environment
    DATA(class_name) = COND string(
      WHEN _is_cloud( ) = abap_true THEN 'ZCL_VDM_PLANTUML_XCO_ADP_CP'
      ELSE                               'ZCL_VDM_PLANTUML_XCO_ADP'
    ).

    TRY.
        CREATE OBJECT xco_adapter TYPE (class_name).
      CATCH cx_sy_create_object_error.
    ENDTRY.

  ENDMETHOD.


  METHOD _is_cloud.
    " We check if the XCO Tenant is 'Empty'.
    " In BTP, this returns the subaccount/tenant details.
    " In On-Premise, even if XCO_CP is available, the tenant returns an initial/unassigned state.
    DATA(tenant) = xco_cp=>current->tenant( ).
    TRY.
        " Check if the tenant actually has content
        IF tenant->get_id( ) IS INITIAL.
          is_cloud = abap_false. " We are On-Premise
        ELSE.
          is_cloud = abap_true.  " We are in the Cloud (BTP)
        ENDIF.
      CATCH cx_root.
        is_cloud = abap_false. " If there was an issue accessing the tenant, we assume On-Premise to avoid issues with missing API's
    ENDTRY.
  ENDMETHOD.


  METHOD _iterate.

" Iterate Through CDS Hierachy

    TRY.
        DATA(cds_name_upper) = to_upper( cds_name ).

        " Avoid duplicates and infinite loops
        IF line_exists( hierarchies[ cds_name_uppercase = cds_name_upper ] ).
          RETURN.
        ENDIF.

        " Level depth guard ( Exit when Limit is Met )
        IF current_level > selection-max_allowed_level.
          RETURN.
        ENDIF.

        " Filters Inclusion / Exclusion / Namespace

        IF cds_name_upper  <> selection-cds_name. " Ignore Exclude, Include and Namespace if its the Selection CDS ( So Our Parent doesn't get filtered out before we even start )

          " 1. Exclusion List (Skip if specifically excluded)
          IF selection-exclude_cds IS NOT INITIAL
             AND line_exists( selection-exclude_cds[ cds_name = cds_name_upper ] ).
            RETURN.
          ENDIF.

          " 2. Inclusion List (If list is provided, ONLY allow these names)
          IF selection-include_cds IS NOT INITIAL
             AND NOT line_exists( selection-include_cds[ cds_name = cds_name_upper ] ).
            RETURN.
          ENDIF.

          " 3. Namespace filter (If Requested)
          IF selection-custom_developments_only = abap_true
             AND NOT ( cds_name_upper CP 'Z*' OR cds_name_upper CP 'Y*' ).
            RETURN.
          ENDIF.

        ENDIF.

        " Grab metadata from the adapter
        DATA(hierarchy) = VALUE ty_cds_hierarchy(

                                cds_name_uppercase = cds_name_upper
                                alias             = xco_adapter->get_cds_name_from_ddl( cds_name )
                                index             = current_level
                                fields            = xco_adapter->get_fields( cds_name )
                                associations      = xco_adapter->get_associations( cds_name )
                                compositions      = xco_adapter->get_compositions( cds_name )
                                sources           = xco_adapter->get_sources( cds_name ) ).

        " Map out how this CDS connects to others
        _determine_relationships( CHANGING cs_hierarchy = hierarchy ).

        INSERT hierarchy INTO TABLE me->hierarchies.

        " Dig deeper into all discovered targets (Assoc, Comp, and Sources)
        LOOP AT hierarchy-relationships INTO DATA(relationship).
          _iterate( cds_name      = relationship-target_uppercase
                    current_level = current_level + 1 ).
        ENDLOOP.

      CATCH cx_xco_ar_existence_exception INTO DATA(existence_exception).
        APPEND xco_cp=>message( VALUE #(
                 msgty = 'E'
                 msgid = existence_exception->if_t100_message~t100key-msgid
                 msgno = existence_exception->if_t100_message~t100key-msgno
                 msgv1 = existence_exception->if_t100_dyn_msg~msgv1
                 msgv2 = existence_exception->if_t100_dyn_msg~msgv2 ) ) TO messages.
    ENDTRY.

  ENDMETHOD.


  METHOD _validate_selection.

    "> CDS Name is Mandatory
    IF selection-cds_name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_vdm_plantuml_generator
        EXPORTING
          textid = zcx_vdm_plantuml_generator=>mandatory
          msgv1  = 'CDS Name'.
    ENDIF.

  ENDMETHOD.


  METHOD _determine_relationships.

    " Logic: We fetch targets if Discovery is ON, or if visibility (Lines/Fields) is ON.
    "           This ensures that if a user wants a line, we 'find' the target box.

    " 1. Associations
    IF selection-discovery-associations = abap_true OR
       selection-lines-associations     = abap_true.

      LOOP AT cs_hierarchy-associations INTO DATA(association).

        " Addtional Detection on Cardinality ( Basically where XCO drops the ball )
        DATA(cardinality) =  xco_adapter->get_cardinality( assocname = association->content( )->get_alias( )
                                                            cds_name = cs_hierarchy-cds_name_uppercase
                                                            hasparent = association->content( )->get_to_parent_indicator( )
                                                            currentcardinality =  association->content( )->get_cardinality( ) ) .


        APPEND VALUE #( target          = xco_adapter->get_cds_name_from_ddl( association->content( )->get_target( ) )
                        target_uppercase = to_upper( association->content( )->get_target( ) )
                        alias           = association->content( )->get_alias( )
                        type            = c_relation_type-association
                        has_parent       = association->content( )->get_to_parent_indicator( )
                        cardinality     =  cardinality ) TO
                                                                      cs_hierarchy-relationships.
      ENDLOOP.
    ENDIF.

    " 2. Compositions
    IF selection-discovery-compositions = abap_true OR
       selection-lines-compositions     = abap_true.

      LOOP AT cs_hierarchy-compositions INTO DATA(composition).
        APPEND VALUE #( target          = xco_adapter->get_cds_name_from_ddl( composition->target )
                        target_uppercase = to_upper( composition->target )
                        alias           = composition->content( )->get_alias( )
                        type            = c_relation_type-composition
                        is_parent        = abap_true
                        cardinality      = CORRESPONDING #( composition->content( )->get_cardinality( ) ) ) TO cs_hierarchy-relationships.
      ENDLOOP.
    ENDIF.

    " 3. Inheritance (Based on Sources)
    IF selection-discovery-inheritance = abap_true OR
       selection-lines-inheritance     = abap_true.

      LOOP AT cs_hierarchy-sources INTO DATA(source).
        APPEND VALUE #( target          = xco_adapter->get_cds_name_from_ddl( source )
                        target_uppercase = to_upper( source )
                        type            = c_relation_type-inheritance
                        cardinality     = VALUE #( min = 1 max = 1 )
                      ) TO cs_hierarchy-relationships.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_messages.
    " Get any messages collected during generation
    messages = me->messages.
  ENDMETHOD.


  METHOD _initialize_selection.
    " Make sure starting CDS and all filter lists are Uppercase for consistent comparison
    me->selection-cds_name  = to_upper(  me->selection-cds_name ).

    " We need at least one level!
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
ENDCLASS.
