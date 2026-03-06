"! <p class="shorttext synchronized">VDM Mermaid.js Specific Renderer</p>
"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! Implements the hook interface to output Mermaid classDiagram syntax.
CLASS zcl_vdm_diagram_mermaid DEFINITION PUBLIC INHERITING FROM zcl_vdm_diagram_base FINAL CREATE PUBLIC.
  PUBLIC SECTION.

    " =========================================================================
    " MERMAID-SPECIFIC FORMATTING OPTIONS
    " =========================================================================
    "! Mermaid supports native theming and directional flow controls.
    TYPES: BEGIN OF ty_format,
             direction TYPE string, " Layout flow: 'TB' (Top-Bottom), 'LR' (Left-Right), 'RL', 'BT'
             theme     TYPE string, " Built-in themes: 'default', 'dark', 'forest', 'neutral'
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



CLASS ZCL_VDM_DIAGRAM_MERMAID IMPLEMENTATION.


  METHOD constructor.
    " Call the abstract base class constructor to ensure safe initialization
    super->constructor( ).
    me->format = format.

    " Apply smart defaults if the caller didn't provide specific formats
    IF me->format-direction IS INITIAL. me->format-direction = 'TB'. ENDIF.
    IF me->format-theme IS INITIAL.     me->format-theme     = 'default'. ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_associations.
    " Use the # (Protected) modifier to represent published associations
    LOOP AT association_aliases INTO DATA(assoc).
      add_text( |    # { assoc }| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_base_elements.
    " Mermaid class blocks do not support arbitrary text dividers like PlantUML.
    " We mock headers by using stereotyped methods (<<...>>) and the package visibility modifier (~).
    add_text( COND #( WHEN is_union_entity = abap_true THEN '    <<Union>>' ELSE '    <<Base>>' ) ).

    " List all the base tables or views that make up this entity
    LOOP AT base_sources INTO DATA(source).
      add_text( |    ~{ source }| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_end.
    " Mermaid requires no closing tag at the end of the file, so this remains empty.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_entity_end.
    " Close the class definition block
    add_text( |  \}| ).

    " In Mermaid, styles cannot be applied inline during class definition.
    " They must be applied globally outside the class block. Here we highlight the focal entity.
    IF is_focal_entity = abap_true.
      add_text( |  style { alias } fill:gray,stroke:#333,stroke-width:2px| ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_entity_start.
    " Open the class definition block using the entity alias
    add_text( |  class { alias } \{| ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_fields.
    " Use Mermaid Object-Oriented visibility modifiers to distinguish field types visually:
    " + (Public) represents Key fields
    IF selection-keys = abap_true.
      LOOP AT key_fields INTO DATA(key).
        add_text( |    + { key }| ).
      ENDLOOP.
    ENDIF.

    " - (Private) represents Standard data fields
    IF selection-fields = abap_true.
      LOOP AT standard_fields INTO DATA(field).
        add_text( |    - { field }| ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_legend.
    " Skipped. Mermaid UI generally handles class semantics natively without a drawn legend.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_relationship.
    " Map semantic relationships to Mermaid's specific edge syntax:
    " *--  : Composition (Solid line with filled diamond)
    " |..> : Inheritance (Dotted line with arrow)
    " -->  : Association (Solid line with standard arrow)
    DATA(arrow) = SWITCH string( relationship_type
      WHEN zcl_vdm_diagram_generator=>c_relation_type-composition THEN '*--'
      WHEN zcl_vdm_diagram_generator=>c_relation_type-inheritance THEN '|..>'
      ELSE '-->' ).

    " Construct the final relationship line.
    " IMPORTANT: Mermaid requires edge labels (cardinality) to be wrapped in double quotes.
    add_text( |  { source_alias } { arrow } { target_alias } : "{ cardinality_text }"| ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_start.
    " If a specific theme is requested (like 'dark' or 'forest'), we must inject
    " the Mermaid initialization directive at the very top of the file.
    IF format-theme <> 'default'.
      add_text( |%%\{init: \{'theme': '{ format-theme }'\} \}%%| ).
    ENDIF.

    " Declare the diagram type
    add_text( 'classDiagram' ).

    " Apply the requested layout direction (e.g., Top-to-Bottom or Left-to-Right)
    add_text( |direction { format-direction }| ).
  ENDMETHOD.
ENDCLASS.
