"! <p class="shorttext synchronized">Behavior Implementation for VDM Variants</p>
"! Handles instance-level authorization checks to ensure that only the original
"! creator of a variant has the authority to update or delete it.
CLASS lhc_Variant DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Variant RESULT result.

    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR Variant~validateMandatoryFields.

    "! Retrieves the active user securely, defaulting to empty on failure.
    METHODS get_active_user RETURNING VALUE(active_user) TYPE syuname.
ENDCLASS.

CLASS lhc_Variant IMPLEMENTATION.
  METHOD get_instance_authorizations.
    DATA(active_user) = get_active_user( ).

    READ ENTITIES OF zr_vdm_diagram_variant_tp IN LOCAL MODE
         ENTITY Variant
         FIELDS ( CreatedBy ) WITH CORRESPONDING #( keys )
         RESULT DATA(variants).

    " ARCHITECT RULE: ALWAYS loop over the requested 'keys', not the read 'variants'.
    " If a key does not exist in the DB, looping over 'variants' leaves it unanswered,
    " resulting in a catastrophic RAP framework dump.
    LOOP AT keys REFERENCE INTO DATA(key_ref).
      APPEND VALUE #( %tky = key_ref->%tky ) TO result ASSIGNING FIELD-SYMBOL(<result>).

      ASSIGN variants[ %tky = key_ref->%tky ] TO FIELD-SYMBOL(<variant>).
      DATA(is_authorized) = xsdbool( sy-subrc = 0 AND ( ( active_user IS NOT INITIAL AND <variant>-CreatedBy = active_user ) or <variant>-IsGlobal = abap_true  ) ).

      DATA(auth_status) = COND #( WHEN is_authorized = abap_true
                                  THEN if_abap_behv=>auth-allowed
                                  ELSE if_abap_behv=>auth-unauthorized ).

      " Enterprise Best Practice: Only map authorizations that the framework explicitly requested
      IF requested_authorizations-%update = if_abap_behv=>mk-on.
        <result>-%update = auth_status.
      ENDIF.
      IF requested_authorizations-%delete = if_abap_behv=>mk-on.
        <result>-%delete = auth_status.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMandatoryFields.
    READ ENTITIES OF zr_vdm_diagram_variant_tp IN LOCAL MODE
         ENTITY Variant
         FIELDS ( VariantName CdsName Configuration ) WITH CORRESPONDING #( keys )
         RESULT DATA(variants).

    LOOP AT variants REFERENCE INTO DATA(variant).
      DATA(has_error) = abap_false.

      " ARCHITECT RULE: Clear the state area before validation to prevent duplicate
      " message stacking on the UI during multiple save attempts.
      APPEND VALUE #( %tky = variant->%tky %state_area = 'VALIDATE_MANDATORY' ) TO reported-variant.

      IF variant->VariantName IS INITIAL.
        has_error = abap_true.
        APPEND VALUE #( %tky                 = variant->%tky
                        %state_area          = 'VALIDATE_MANDATORY'
                        %msg                 = new_message( id       = 'ZVDM_VARIANT'
                                                            number   = '000'
                                                            v1       = 'Variant Name'
                                                            severity = if_abap_behv_message=>severity-error )
                        %element-VariantName = if_abap_behv=>mk-on ) TO reported-variant.
      ENDIF.

      IF variant->CdsName IS INITIAL.
        has_error = abap_true.
        APPEND VALUE #( %tky             = variant->%tky
                        %state_area      = 'VALIDATE_MANDATORY'
                        %msg             = new_message( id       = 'ZVDM_VARIANT'
                                                        number   = '000'
                                                        v1       = 'CDS Name'
                                                        severity = if_abap_behv_message=>severity-error )
                        %element-CdsName = if_abap_behv=>mk-on ) TO reported-variant.
      ENDIF.

      IF variant->Configuration IS INITIAL.
        has_error = abap_true.
        APPEND VALUE #( %tky                   = variant->%tky
                        %state_area            = 'VALIDATE_MANDATORY'
                        %msg                   = new_message( id       = 'ZVDM_VARIANT'
                                                              number   = '000'
                                                              v1       = 'Configuration'
                                                              severity = if_abap_behv_message=>severity-error )
                        %element-Configuration = if_abap_behv=>mk-on ) TO reported-variant.
      ENDIF.

      " If any field failed, abort the save once for this specific variant entity
      IF has_error = abap_true.
        APPEND VALUE #( %tky = variant->%tky ) TO failed-variant.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_active_user.
    " CL_ABAP_CONTEXT_INFO=>GET_USER_TECHNICAL_NAME does not raise exceptions.
    " Wrapping it in a TRY...CATCH causes an unreachable code warning in Strict ABAP Cloud.
    active_user = cl_abap_context_info=>get_user_technical_name( ).
  ENDMETHOD.
ENDCLASS.
