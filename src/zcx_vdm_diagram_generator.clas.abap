class ZCX_VDM_DIAGRAM_GENERATOR definition
  public
  inheriting from CX_STATIC_CHECK
  create public .

public section.

  interfaces IF_T100_MESSAGE .
  interfaces IF_T100_DYN_MSG .

  aliases MSGTY
    for IF_T100_DYN_MSG~MSGTY .
  aliases MSGV1
    for IF_T100_DYN_MSG~MSGV1 .
  aliases MSGV2
    for IF_T100_DYN_MSG~MSGV2 .
  aliases MSGV3
    for IF_T100_DYN_MSG~MSGV3 .
  aliases MSGV4
    for IF_T100_DYN_MSG~MSGV4 .

  constants:
    begin of MANDATORY,
      msgid type symsgid value 'ZVDM_VDM_DIAGRAM',
      msgno type symsgno value '000',
      attr1 type scx_attrname value 'msgv1',
      attr2 type scx_attrname value '',
      attr3 type scx_attrname value '',
      attr4 type scx_attrname value '',
    end of MANDATORY .

  methods CONSTRUCTOR
    importing
      !TEXTID like IF_T100_MESSAGE=>T100KEY optional
      !PREVIOUS like PREVIOUS optional
      !MSGTY type SYMSGTY optional
      !MSGV1 type SYMSGV optional
      !MSGV2 type SYMSGV optional
      !MSGV3 type SYMSGV optional
      !MSGV4 type SYMSGV optional .
protected section.
private section.
ENDCLASS.



CLASS ZCX_VDM_DIAGRAM_GENERATOR IMPLEMENTATION.


  method CONSTRUCTOR.
CALL METHOD SUPER->CONSTRUCTOR
EXPORTING
PREVIOUS = PREVIOUS
.
me->MSGTY = MSGTY .
me->MSGV1 = MSGV1 .
me->MSGV2 = MSGV2 .
me->MSGV3 = MSGV3 .
me->MSGV4 = MSGV4 .
clear me->textid.
if textid is initial.
  IF_T100_MESSAGE~T100KEY = IF_T100_MESSAGE=>DEFAULT_TEXTID.
else.
  IF_T100_MESSAGE~T100KEY = TEXTID.
endif.
  endmethod.
ENDCLASS.
