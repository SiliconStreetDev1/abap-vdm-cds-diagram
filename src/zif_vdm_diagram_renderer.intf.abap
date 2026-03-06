"! <p class="shorttext synchronized">VDM Diagram Renderer Interface</p>
"! © 2026 Silicon Street Limited. All Rights Reserved.
"!
"! Defines the contract for any diagram engine injected into the generator.
"! Notice that formatting options are completely absent here, as they belong
"! strictly to the concrete classes.
INTERFACE zif_vdm_diagram_renderer PUBLIC.

  "! Executes the rendering engine with the fully parsed SAP data
  "! @parameter hierarchies | The recursive hierarchy data extracted via XCO
  "! @parameter selection   | The original user configuration and scope
  "! @parameter diagram_code | The final generated text file content
  METHODS build IMPORTING hierarchies TYPE zcl_vdm_diagram_generator=>tty_cds_hierarchy
                          selection   TYPE zcl_vdm_diagram_generator=>ty_selection
                RETURNING VALUE(diagram_code) TYPE string_table.

ENDINTERFACE.
