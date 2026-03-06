"! <p class="shorttext synchronized">VDM Diagram Generator - Abstract Base Engine</p>
"! © 2026 Silicon Street Limited. All Rights Reserved.
CLASS zcl_vdm_diagram_base DEFINITION PUBLIC ABSTRACT CREATE PUBLIC.

  PUBLIC SECTION.
    " 1. Implement the Renderer Contract for Dependency Injection
    INTERFACES zif_vdm_diagram_renderer.
    ALIASES build FOR zif_vdm_diagram_renderer~build.

    " 2. Enforce implementation of the hooks on all subclasses
    INTERFACES zif_vdm_diagram_hooks ABSTRACT METHODS
      on_start on_end on_entity_start on_entity_end on_base_elements
      on_fields on_associations on_relationship on_legend.

  PROTECTED SECTION.
    DATA hierarchies TYPE zcl_vdm_diagram_generator=>tty_cds_hierarchy.
    DATA selection   TYPE zcl_vdm_diagram_generator=>ty_selection.
    DATA diagram_tab TYPE string_table.

    "! Utility method for subclasses to push generated syntax to the output table
    METHODS add_text IMPORTING text TYPE string.

  PRIVATE SECTION.
    METHODS get_field_name IMPORTING field TYPE REF TO if_xco_cds_field RETURNING VALUE(fieldname) TYPE string.
    METHODS build_entities.
    METHODS build_relationships.
ENDCLASS.



CLASS ZCL_VDM_DIAGRAM_BASE IMPLEMENTATION.


  METHOD add_text.
    APPEND text TO me->diagram_tab.
  ENDMETHOD.


  METHOD build_entities.
    LOOP AT hierarchies ASSIGNING FIELD-SYMBOL(<hierarchy>).
      " Check if this entity is the root/focal point requested by the user
      DATA(is_primary) = xsdbool( to_upper( selection-cds_name ) = <hierarchy>-cds_name_uppercase ).

      " Signal the subclass to open the entity block.
      zif_vdm_diagram_hooks~on_entity_start( alias           = CONV string( <hierarchy>-alias )
                                             is_focal_entity = is_primary ).

      " Process Base/Union sources
      IF selection-base = abap_true.
        DATA(sources) = VALUE string_table( ).
        LOOP AT <hierarchy>-sources INTO DATA(source).
          APPEND CONV string( source ) TO sources.
        ENDLOOP.
        zif_vdm_diagram_hooks~on_base_elements( is_union_entity = <hierarchy>-union base_sources = sources ).
      ENDIF.

      " Process Fields
      DATA(keys)   = VALUE string_table( ).
      DATA(fields) = VALUE string_table( ).

      IF selection-keys = abap_true OR selection-fields = abap_true.
        LOOP AT <hierarchy>-fields REFERENCE INTO DATA(field_ref).
          DATA(is_key) = field_ref->*->content( )->get_key_indicator( ).
          DATA(name)   = get_field_name( field_ref->* ).

          IF name(1) = '_'. CONTINUE. ENDIF. " Skip raw associations

          IF is_key = abap_true.
            APPEND name TO keys.
          ELSE.
            APPEND name TO fields.
          ENDIF.
        ENDLOOP.
        zif_vdm_diagram_hooks~on_fields( key_fields = keys standard_fields = fields ).
      ENDIF.

      " Process Associations
      IF selection-associations_fields = abap_true.
        DATA(associations) = VALUE string_table( ).
        LOOP AT <hierarchy>-associations INTO DATA(assoc).
          APPEND CONV string( assoc->content( )->get_alias( ) ) TO associations.
        ENDLOOP.
        zif_vdm_diagram_hooks~on_associations( association_aliases = associations ).
      ENDIF.

      " Signal the subclass to close the entity block
      zif_vdm_diagram_hooks~on_entity_end( alias           = CONV string( <hierarchy>-alias )
                                           is_focal_entity = is_primary ).
    ENDLOOP.
  ENDMETHOD.


  METHOD build_relationships.
    CONSTANTS many_cardinality TYPE i VALUE 2147483647.

    LOOP AT hierarchies ASSIGNING FIELD-SYMBOL(<hierarchy>).
      LOOP AT <hierarchy>-relationships ASSIGNING FIELD-SYMBOL(<rel>).

        " Scope Validation: Skip if target isn't on the canvas
        IF selection-force_render_all_relationships = abap_false.
          IF NOT line_exists( hierarchies[ cds_name_uppercase = to_upper( <rel>-target ) ] ).
            CONTINUE.
          ENDIF.
        ENDIF.

        " Type Validation
        CASE <rel>-type.
          WHEN zcl_vdm_diagram_generator=>c_relation_type-association.
            IF selection-lines-associations = abap_false. CONTINUE. ENDIF.
          WHEN zcl_vdm_diagram_generator=>c_relation_type-composition.
            IF selection-lines-compositions = abap_false. CONTINUE. ENDIF.
          WHEN zcl_vdm_diagram_generator=>c_relation_type-inheritance.
            IF selection-lines-inheritance = abap_false. CONTINUE. ENDIF.
        ENDCASE.

        " Standardize Cardinality string
        DATA(min_text) = COND string( WHEN <rel>-cardinality-min = many_cardinality THEN '*' ELSE |{ <rel>-cardinality-min }| ).
        DATA(max_text) = COND string( WHEN <rel>-cardinality-max = many_cardinality THEN '*' ELSE |{ <rel>-cardinality-max }| ).
        DATA(formatted_cardinality) = COND string( WHEN min_text = max_text THEN min_text ELSE |{ min_text }..{ max_text }| ).

        " Dispatch sanitized data explicitly cast to strings
        zif_vdm_diagram_hooks~on_relationship(
                          source_alias      = CONV string( <hierarchy>-alias )
                          target_alias      = CONV string( <rel>-target )
                          relationship_type = CONV string( <rel>-type )
                          cardinality_text  = formatted_cardinality
                          is_parent_entity  = <rel>-is_parent
                          has_parent_entity = <rel>-has_parent
                          association_alias = CONV string( <rel>-alias ) ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_field_name.
    " Attempt to get the alias first, fallback to original name, then technical name
    DATA(content) = field->content( ).
    fieldname = content->get_alias( ).
    IF fieldname IS INITIAL. fieldname = content->get_original_name( ). ENDIF.
    IF fieldname IS INITIAL. fieldname = field->name. ENDIF.
  ENDMETHOD.


  METHOD zif_vdm_diagram_renderer~build.
    " 1. Bind the incoming data to the instance attributes
    me->hierarchies = hierarchies.
    me->selection   = selection.
    CLEAR me->diagram_tab.

    " 2. Execute the Template Method sequence
    zif_vdm_diagram_hooks~on_start( ).
    build_entities( ).
    build_relationships( ).
    zif_vdm_diagram_hooks~on_legend( ).
    zif_vdm_diagram_hooks~on_end( ).

    diagram_code = me->diagram_tab.
  ENDMETHOD.
ENDCLASS.
