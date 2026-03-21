"! <p class="shorttext synchronized">VDM Cytoscape JSON Renderer (XCO Framework)</p>
"! Generates a structured JSON payload for Cytoscape.js using the modern XCO library.
"! Inherits from the standard base class to utilize the text buffer and selection state.
CLASS zcl_vdm_diagram_cytoscape DEFINITION
  PUBLIC
  INHERITING FROM zcl_vdm_diagram_base
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "! Advanced formatting instructions passed to the UI5 frontend.
    "! Controls the physics engine and applies SAP Fiori themes.
    TYPES: BEGIN OF ty_format,
             layout_algorithm TYPE string,     " e.g., 'cose' (physics), 'grid'
             theme            TYPE string,     " 'fiori_light' or 'fiori_dark'
             animate          TYPE abap_bool,  " True for smooth physics transitions
             node_spacing     TYPE i,          " Distance between entities (e.g., 100)
           END OF ty_format.

    "! Injects the formatting configuration during instantiation.
    METHODS constructor IMPORTING format TYPE ty_format OPTIONAL.

    " Redefine all standard hooks inherited from the base class
    METHODS zif_vdm_diagram_hooks~on_start REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_end REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_entity_start REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_entity_end REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_base_elements REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_fields REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_associations REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_relationship REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_legend REDEFINITION.

    " ---------------------------------------------------------------------
    " Cytoscape JSON Data Structures
    " Placed in public section to ensure XCO can reflect on them properly
    " ---------------------------------------------------------------------
    TYPES: BEGIN OF ty_node_data,
             id           TYPE string,
             label        TYPE string,
             is_focal     TYPE abap_bool,
             is_union     TYPE abap_bool,
             keys         TYPE string_table,
             standard     TYPE string_table,
             base_sources TYPE string_table,
             associations TYPE string_table,
           END OF ty_node_data.

    TYPES: BEGIN OF ty_node,
             data TYPE ty_node_data,
           END OF ty_node.

    TYPES: BEGIN OF ty_edge_data,
             id            TYPE string,
             source        TYPE string,
             target        TYPE string,
             label         TYPE string,
             cardinality   TYPE string,
             relation_type TYPE string,
             color_hint    TYPE string,
             source_anchor TYPE string,
           END OF ty_edge_data.

    TYPES: BEGIN OF ty_edge,
             data TYPE ty_edge_data,
           END OF ty_edge.

    TYPES: BEGIN OF ty_graph_config,
             format TYPE ty_format,
           END OF ty_graph_config.

    TYPES: BEGIN OF ty_elements,
             config TYPE ty_graph_config,
             nodes  TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY,
             edges  TYPE STANDARD TABLE OF ty_edge WITH EMPTY KEY,
           END OF ty_elements.

  PRIVATE SECTION.
    DATA format       TYPE ty_format.
    DATA elements     TYPE ty_elements.
    DATA current_node TYPE ty_node.

    "! Serializes the collected elements into CamelCase JSON using XCO.
    METHODS serialize_to_json RETURNING VALUE(result) TYPE string.

ENDCLASS.



CLASS zcl_vdm_diagram_cytoscape IMPLEMENTATION.


  METHOD constructor.
    " MUST call super to initialize base class state (e.g., the text buffer)
    super->constructor( ).

    " Apply user format or fallback to Fiori defaults
    IF format IS INITIAL.
      me->format-layout_algorithm = 'cose'.
      me->format-theme            = 'fiori_light'.
      me->format-animate          = abap_true.
      me->format-node_spacing     = 100.
    ELSE.
      me->format = format.
    ENDIF.

    CLEAR: me->elements, me->current_node.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_start.
    " Initialize payload and attach the Fiori configuration
    CLEAR me->elements.
    me->elements-config-format = me->format.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_entity_start.
    " Initialize node buffer. Parameters like alias and is_focal_entity
    " are implicitly available from the redefinition signature.
    me->current_node = VALUE #(
      data = VALUE #(
        id       = alias
        label    = alias
        is_focal = is_focal_entity
      )
    ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_base_elements.
    me->current_node-data-is_union = is_union_entity.
    LOOP AT base_sources INTO DATA(source).
      APPEND source TO me->current_node-data-base_sources.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_fields.
    " selection-keys and selection-fields are inherited from the base class
    IF selection-keys = abap_true.
      LOOP AT key_fields INTO DATA(key).
        APPEND key TO me->current_node-data-keys.
      ENDLOOP.
    ENDIF.

    IF standard_fields IS NOT INITIAL AND selection-fields = abap_true.
      LOOP AT standard_fields INTO DATA(field).
        APPEND field TO me->current_node-data-standard.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_associations.
    LOOP AT association_aliases INTO DATA(assoc).
      APPEND assoc TO me->current_node-data-associations.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_entity_end.
    APPEND me->current_node TO me->elements-nodes.
    CLEAR me->current_node.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_relationship.
    " Mirror the exact relationship type coloring logic
    DATA(color_hint) = SWITCH string( relationship_type
      WHEN zcl_vdm_diagram_generator=>c_relation_type-association OR zcl_vdm_diagram_generator=>c_relation_type-composition
        THEN COND #( WHEN is_parent_entity = abap_true OR has_parent_entity = abap_true THEN '#0a6ed1' ELSE '#188918' )
      ELSE '#32363a' ).

    " Handle field-level anchor mapping
    DATA(source_anchor) = COND string(
      WHEN selection-associations_fields = abap_true AND association_alias IS NOT INITIAL
      THEN association_alias
      ELSE ''
    ).

    DATA(edge) = VALUE ty_edge(
      data = VALUE #(
        id            = |{ source_alias }_to_{ target_alias }_{ association_alias }|
        source        = source_alias
        target        = target_alias
        label         = association_alias
        cardinality   = cardinality_text
        relation_type = relationship_type
        color_hint    = color_hint
        source_anchor = source_anchor
      )
    ).

    APPEND edge TO me->elements-edges.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_legend.
    " Legends are handled by UI5 Native controls, not the JSON payload.
    " Intentionally left blank.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_end.
    " Serialize the collected objects into JSON
    DATA(json_output) = me->serialize_to_json( ).

    " Push the JSON payload to the base class buffer utilizing add_text.
    " This ensures the generator can retrieve it identically to PlantUML.
    add_text( json_output ).
  ENDMETHOD.


  METHOD serialize_to_json.
    " Utilize the modern ABAP Cloud XCO framework for JSON serialization.
    " The fluent API converts the ABAP structure and strictly applies
    " camelCase transformation to satisfy the JavaScript frontend.
    result = xco_cp_json=>data->from_abap( me->elements )->apply(
      VALUE #( ( xco_cp_json=>transformation->underscore_to_camel_case ) )
    )->to_string( ).
  ENDMETHOD.

ENDCLASS.
