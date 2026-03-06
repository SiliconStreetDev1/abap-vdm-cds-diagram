"! <p class="shorttext synchronized">VDM Diagram Hooks Interface</p>
"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! Defines the mandatory exit points triggered by the Base Rendering Engine.
"! Any new diagram format (e.g., DOT, Structurizr) must implement these hooks.
INTERFACE zif_vdm_diagram_hooks PUBLIC.

  "! Triggered at the very beginning of the diagram generation.
  "! Use this to set up global configurations, directions, or skin parameters.
  METHODS on_start.

  "! Triggered at the very end of the diagram generation.
  "! Use this to close any open tags or append closing file syntax.
  METHODS on_end.

  "! Triggered when an entity (table/view) definition begins.
  "! @parameter alias | The visual name of the entity
  "! @parameter is_focal_entity | True if this is the primary entity requested by the user
  METHODS on_entity_start IMPORTING alias           TYPE string
                                    is_focal_entity TYPE abap_bool.

  "! Triggered when an entity definition is fully processed and needs to be closed.
  "! @parameter alias | The visual name of the entity
  "! @parameter is_focal_entity | True if this is the primary entity requested by the user
  METHODS on_entity_end   IMPORTING alias           TYPE string
                                    is_focal_entity TYPE abap_bool.

  "! Triggered to render the underlying tables/views that make up this entity.
  "! @parameter is_union_entity | True if the base sources are combined via UNION
  "! @parameter base_sources | List of the underlying DDIC or CDS view names
  METHODS on_base_elements IMPORTING is_union_entity TYPE abap_bool
                                     base_sources    TYPE string_table.

  "! Triggered to render the fields of an entity, separated by key and non-key.
  "! @parameter key_fields | List of fields marked as primary keys
  "! @parameter standard_fields | List of regular data fields
  METHODS on_fields        IMPORTING key_fields      TYPE string_table
                                     standard_fields TYPE string_table.

  "! Triggered to render the list of associations published by the entity.
  "! @parameter association_aliases | List of exposed association names
  METHODS on_associations  IMPORTING association_aliases TYPE string_table.

  "! Triggered to draw a line connecting two entities.
  "! @parameter source_alias | The originating entity name
  "! @parameter target_alias | The destination entity name
  "! @parameter relationship_type | Association, Composition, or Inheritance
  "! @parameter cardinality_text | Formatted cardinality (e.g., "1..*")
  "! @parameter is_parent_entity | True if the source is the parent in a composition
  "! @parameter has_parent_entity | True if the target is the parent in a composition
  "! @parameter association_alias | The specific field name of the association
  METHODS on_relationship  IMPORTING source_alias      TYPE string
                                     target_alias      TYPE string
                                     relationship_type TYPE string
                                     cardinality_text  TYPE string
                                     is_parent_entity  TYPE abap_bool
                                     has_parent_entity TYPE abap_bool
                                     association_alias TYPE string.

  "! Triggered to render a visual legend explaining colors and line types.
  METHODS on_legend.

ENDINTERFACE.
