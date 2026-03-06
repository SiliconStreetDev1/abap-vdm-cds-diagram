interface ZIF_VDM_DIAGRAM_CONVERTER
  public .
"! Converts source diagram code into a target diagram format
  "! @parameter it_source_code | The input code (e.g., PlantUML)
  "! @parameter rt_target_code | The output code (e.g., Mermaid)
  METHODS convert
    IMPORTING !source_code TYPE string_table
    RETURNING VALUE(target_code) TYPE string_table.
endinterface.
