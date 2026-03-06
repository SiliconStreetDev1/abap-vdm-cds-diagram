"! <p class="shorttext synchronized">VDM PlantUML Specific Renderer</p>
CLASS zcl_vdm_diagram_plantuml DEFINITION PUBLIC INHERITING FROM zcl_vdm_diagram_base FINAL CREATE PUBLIC.
  PUBLIC SECTION.

    " PlantUML retains the classic formatting options to ensure 100% backward compatibility
    TYPES: BEGIN OF ty_format,
             ortho      TYPE abap_bool,
             polyline   TYPE abap_bool,
             spaced_out TYPE abap_bool,
             staggered  TYPE abap_bool,
             modern     TYPE abap_bool,
           END OF ty_format.

    METHODS constructor IMPORTING format TYPE ty_format OPTIONAL.

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



CLASS ZCL_VDM_DIAGRAM_PLANTUML IMPLEMENTATION.


  METHOD constructor.
    super->constructor( ).
    me->format = format.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_associations.
    add_text( '-- Associations --' ).
    LOOP AT association_aliases INTO DATA(assoc).
      add_text( assoc ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_base_elements.
    add_text( COND #( WHEN is_union_entity = abap_true THEN '-- Union --' ELSE '-- Base --' ) ).
    LOOP AT base_sources INTO DATA(source).
      add_text( source ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_end.
    add_text( '@enduml' ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_entity_end.
    add_text( '}' ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_entity_start.
    DATA(color) = COND string( WHEN is_focal_entity = abap_true THEN ' #gray' ELSE '' ).
    add_text( |entity "{ alias }"{ color } \{| ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_fields.
    IF selection-keys = abap_true.
      add_text( '---' ).
      LOOP AT key_fields INTO DATA(key).
        add_text( |*{ key }| ).
      ENDLOOP.
    ENDIF.
    IF standard_fields IS NOT INITIAL AND selection-fields = abap_true.
      add_text( '---' ).
      LOOP AT standard_fields INTO DATA(field).
        add_text( field ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_legend.
    add_text( 'legend right' ).
    add_text( '|Color| Type |' ).
    add_text( '|<#green>|Association|' ).
    add_text( '|<#blue>|Composition|' ).
    add_text( '|<#black>|Inheritance|' ).
    add_text( 'endlegend' ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_relationship.
    DATA(color) = SWITCH string( relationship_type
      WHEN zcl_vdm_diagram_generator=>c_relation_type-association OR zcl_vdm_diagram_generator=>c_relation_type-composition
        THEN COND #( WHEN is_parent_entity = abap_true OR has_parent_entity = abap_true THEN '#blue' ELSE '#green' )
      ELSE '#black' ).

    DATA(arrow) = SWITCH string( relationship_type
      WHEN zcl_vdm_diagram_generator=>c_relation_type-composition THEN |*-[{ color }]->|
      WHEN zcl_vdm_diagram_generator=>c_relation_type-inheritance THEN |.[{ color }].>|
      ELSE |-[{ color }]->| ).

    DATA(source_anchor) = COND string( WHEN selection-associations_fields = abap_true AND association_alias IS NOT INITIAL
                                       THEN |{ source_alias }::{ association_alias }| ELSE source_alias ).

    add_text( |{ source_anchor } { arrow } { target_alias } : { cardinality_text }| ).
  ENDMETHOD.


  METHOD zif_vdm_diagram_hooks~on_start.
    add_text( '@startuml' ).

    IF format-polyline = abap_true. add_text( 'skinparam linetype polyline' ). ENDIF.
    IF format-ortho = abap_true. add_text( 'skinparam linetype ortho' ). ENDIF.
    IF format-spaced_out = abap_true.
      add_text( 'skinparam nodesep 150' ).
      add_text( 'skinparam ranksep 150' ).
    ENDIF.
    IF format-modern = abap_true.
      add_text( 'skinparam shadowing false' ).
      add_text( 'skinparam roundcorner 15' ).
    ENDIF.

    add_text( 'top to bottom direction' ).
  ENDMETHOD.
ENDCLASS.
