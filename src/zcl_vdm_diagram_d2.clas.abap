"! <p class="shorttext synchronized">VDM D2 Lang Specific Renderer</p>
"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! Implements the hook interface to output modern D2 declarative syntax.
CLASS zcl_vdm_diagram_d2 DEFINITION PUBLIC INHERITING FROM zcl_vdm_diagram_base FINAL CREATE PUBLIC.
  PUBLIC SECTION.

    " =========================================================================
    " D2-SPECIFIC FORMATTING OPTIONS
    " =========================================================================
    " D2 supports unique rendering features like sketch mode (hand-drawn style).
    TYPES: BEGIN OF ty_format,
             direction     TYPE string,    " Layout flow: 'down', 'up', 'right', 'left'
             sketch_mode   TYPE abap_bool, " True to render as a hand-drawn whiteboard sketch
             primary_color TYPE string,    " Hex code for the focal entity background (e.g., '#e1f5fe')
           END OF ty_format.

    "! Constructor to inject formatting options directly into this specific engine
    METHODS constructor IMPORTING format TYPE ty_format OPTIONAL.

    " =========================================================================
    " HOOK REDEFINITIONS
    " =========================================================================
    METHODS zif_vdm_diagram_hooks~on_start REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_end REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_entity_start REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_entity_end REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_base_elements REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_fields REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_associations REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_relationship REDEFINITION.
    METHODS zif_vdm_diagram_hooks~on_legend REDEFINITION.

  PRIVATE SECTION.
    DATA format TYPE ty_format.
ENDCLASS.



CLASS ZCL_VDM_DIAGRAM_D2 IMPLEMENTATION.


  METHOD constructor.
    " Call the abstract base class constructor to ensure safe initialization
    super->constructor( ).
    me->format = format.

    " Apply smart defaults if the caller didn't provide specific formats
    IF me->format-direction IS INITIAL.     me->format-direction     = 'down'. ENDIF.
    IF me->format-primary_color IS INITIAL. me->format-primary_color = 'gray'. ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_associations.
    " Skipped: To keep the sql_table shape clean in D2, we let the actual
    " relationship arrows represent the associations visually outside the box.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_base_elements.
    " Skipped: D2's strict 'sql_table' shape does not handle arbitrary text blocks well.
    " It expects pure Key/Value pairs for columns. Rendering text here breaks the shape.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_end.
    " D2 requires no closing tags for the document itself, so this remains empty.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_entity_end.
    " Close the shape definition block
    add_text( '}' ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_entity_start.
    " Open the shape definition block using the entity alias
    add_text( |{ alias }: \{| ).

    " Utilize D2's native 'sql_table' shape, which is perfectly suited for VDM entities
    add_text( '  shape: sql_table' ).

    " Apply the global 'primary' class (defined in on_start) if this is the root entity requested
    IF is_focal_entity = abap_true.
      add_text( '  class: primary' ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_fields.
    " In D2 sql_tables, columns are defined as key/value pairs.
    " Primary keys can be explicitly defined via nested constraints \{ constraint: primary_key \}
    IF selection-keys = abap_true.
      LOOP AT key_fields INTO DATA(key).
        add_text( |  { key }: * \{ constraint: primary_key \}| ).
      ENDLOOP.
    ENDIF.

    " Standard fields are just added as basic string columns
    IF selection-fields = abap_true.
      LOOP AT standard_fields INTO DATA(field).
        add_text( |  { field }: -| ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_legend.
    " Skipped: A floating legend is not natively supported in D2's declarative syntax
    " in a visually pleasing way without hacky invisible nodes.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_relationship.
    " Determine connection line color logically based on relationship type
    " Blue for composition/parent, Green for association, Black for inheritance.
    DATA(color) = SWITCH string( relationship_type
      WHEN zcl_vdm_diagram_generator=>c_relation_type-association OR zcl_vdm_diagram_generator=>c_relation_type-composition
        THEN COND #( WHEN is_parent_entity = abap_true OR has_parent_entity = abap_true THEN 'blue' ELSE 'green' )
      ELSE 'black' ).

    " Use D2 nested styles to create dashed lines specifically for Inheritance
    DATA(arrow) = SWITCH string( relationship_type
      WHEN zcl_vdm_diagram_generator=>c_relation_type-inheritance THEN 'style.stroke-dash: 5'
      ELSE '' ).

    " Create the connection line syntax (Source -> Target : Label) and open a style block
    add_text( |{ source_alias } -> { target_alias }: { cardinality_text } \{| ).

    " Apply the determined color
    add_text( |  style.stroke: { color }| ).

    " Apply the dashed line style if it was set
    IF arrow IS NOT INITIAL.
      add_text( |  { arrow }| ).
    ENDIF.

    " Close the edge style block
    add_text( '}' ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_start.
    " Apply the global layout direction for the entire D2 board
    add_text( |direction: { format-direction }| ).

    " Apply hand-drawn sketch mode if requested by the user
    IF format-sketch_mode = abap_true.
      add_text( 'sketch: true' ).
    ENDIF.

    " Define global class styles for reusability.
    " Here we create a 'primary' class that applies the requested hex color fill.
    add_text( 'classes: {' ).
    add_text( |  primary: \{ style.fill: "{ format-primary_color }" \}| ).
    add_text( '}' ).
  ENDMETHOD.
ENDCLASS.
