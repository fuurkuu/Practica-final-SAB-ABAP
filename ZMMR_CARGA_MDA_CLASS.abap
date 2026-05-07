*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_CLASS
*&---------------------------------------------------------------------*
CLASS lcl_util DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS to_lower
      IMPORTING iv_text TYPE string
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS lcl_evt_9200 DEFINITION.
  PUBLIC SECTION.
    METHODS handle_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.
    METHODS handle_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    METHODS handle_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column es_row_no.
    METHODS handle_data_changed
      FOR EVENT data_changed OF cl_gui_alv_grid
      IMPORTING er_data_changed e_ucomm.
ENDCLASS.

CLASS lcl_evt_9300 DEFINITION.
  PUBLIC SECTION.
    METHODS handle_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.
    METHODS handle_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    METHODS handle_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column es_row_no.
ENDCLASS.

CLASS lcl_util IMPLEMENTATION.
  METHOD to_lower.
    rv_text = iv_text.
    TRANSLATE rv_text TO LOWER CASE.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_evt_9200 IMPLEMENTATION.
  METHOD handle_toolbar.
    DATA ls_btn TYPE stb_button.

    CLEAR ls_btn.
    ls_btn-butn_type = 3.
    APPEND ls_btn TO e_object->mt_toolbar.

    CLEAR ls_btn.
    ls_btn-function  = 'ZEDIT'.
    ls_btn-icon      = icon_change.
    ls_btn-quickinfo = 'Editar seleccionadas'.
    ls_btn-text      = 'Editar'.
    ls_btn-disabled  = space.
    APPEND ls_btn TO e_object->mt_toolbar.

    CLEAR ls_btn.
    ls_btn-function  = 'ZSAVE'.
    ls_btn-icon      = icon_system_save.
    ls_btn-quickinfo = 'Guardar cambios'.
    ls_btn-text      = 'Guardar'.
    ls_btn-disabled  = space.
    APPEND ls_btn TO e_object->mt_toolbar.

    CLEAR ls_btn.
    ls_btn-function  = 'ZCLOSE'.
    ls_btn-icon      = icon_locked.
    ls_btn-quickinfo = 'Cerrar edición'.
    ls_btn-text      = 'Cerrar edición'.
    ls_btn-disabled  = space.
    APPEND ls_btn TO e_object->mt_toolbar.

    CLEAR ls_btn.
    ls_btn-butn_type = 3.
    APPEND ls_btn TO e_object->mt_toolbar.

    CLEAR ls_btn.
    ls_btn-function  = 'ZGENPO'.
    ls_btn-icon      = icon_execute_object.
    ls_btn-quickinfo = 'Generar pedidos'.
    ls_btn-text      = 'Generar pedido'.
    ls_btn-disabled  = space.
    APPEND ls_btn TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD handle_user_command.
    CASE e_ucomm.
      WHEN 'ZEDIT'.
        PERFORM open_edit_mode.
      WHEN 'ZSAVE'.
        PERFORM save_gen_changes.
      WHEN 'ZCLOSE'.
        PERFORM close_edit_mode.
      WHEN 'ZGENPO'.
        PERFORM generate_po_selected.
    ENDCASE.
  ENDMETHOD.

  METHOD handle_double_click.
    DATA ls_gen TYPE ty_gen.

    READ TABLE gt_gen INTO ls_gen INDEX e_row-index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE e_column-fieldname.
      WHEN 'EBELN'.
        IF ls_gen-ebeln IS NOT INITIAL.
          PERFORM nav_me23n USING ls_gen-ebeln.
        ENDIF.
      WHEN 'MATERIAL'.
        IF ls_gen-material IS NOT INITIAL.
          PERFORM nav_mm03_purch USING ls_gen-material.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD handle_data_changed.
    DATA: ls_mod  TYPE lvc_s_modi,
          ls_lock TYPE ty_lock,
          ls_gen  TYPE ty_gen.

    LOOP AT er_data_changed->mt_mod_cells INTO ls_mod.
      READ TABLE gt_gen INTO ls_gen INDEX ls_mod-row_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      IF ls_gen-pedido_gen = 'X'.
        MESSAGE 'La línea ya tiene pedido generado y no es editable' TYPE 'S' DISPLAY LIKE 'E'.
        CONTINUE.
      ENDIF.

      READ TABLE gt_locks INTO ls_lock
        WITH KEY id_carga = ls_gen-id_carga
                 id_linea = ls_gen-id_linea.
      IF sy-subrc <> 0.
        MESSAGE 'Bloquea la fila con Editar antes de modificar' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_evt_9300 IMPLEMENTATION.
  METHOD handle_toolbar.
    DATA ls_btn TYPE stb_button.

    CLEAR ls_btn.
    ls_btn-butn_type = 3.
    APPEND ls_btn TO e_object->mt_toolbar.

    CLEAR ls_btn.
    ls_btn-function  = 'ZBANK'.
    ls_btn-icon      = icon_display.
    ls_btn-quickinfo = 'Mostrar datos bancarios'.
    ls_btn-text      = 'Datos bancarios'.
    ls_btn-disabled  = space.
    APPEND ls_btn TO e_object->mt_toolbar.

    CLEAR ls_btn.
    ls_btn-function  = 'ZFORMV'.
    ls_btn-icon      = icon_display.
    ls_btn-quickinfo = 'Previsualizar formulario'.
    ls_btn-text      = 'Ver formulario'.
    ls_btn-disabled  = space.
    APPEND ls_btn TO e_object->mt_toolbar.

    CLEAR ls_btn.
    ls_btn-function  = 'ZFORMP'.
    ls_btn-icon      = icon_print.
    ls_btn-quickinfo = 'Imprimir formulario'.
    ls_btn-text      = 'Imprimir formulario'.
    ls_btn-disabled  = space.
    APPEND ls_btn TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD handle_user_command.
    CASE e_ucomm.
      WHEN 'ZBANK'.
        PERFORM show_bank_popup_9300.
      WHEN 'ZFORMV'.
        PERFORM print_form_9300 USING 'V'.
      WHEN 'ZFORMP'.
        PERFORM print_form_9300 USING 'P'.
    ENDCASE.
  ENDMETHOD.

  METHOD handle_double_click.
    DATA ls_flow TYPE zemm_flujo_mda.

    READ TABLE gt_flow INTO ls_flow INDEX e_row-index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE e_column-fieldname.
      WHEN 'EBELN'.
        IF ls_flow-ebeln IS NOT INITIAL.
          PERFORM nav_me23n USING ls_flow-ebeln.
        ENDIF.
      WHEN 'MATNR'.
        IF ls_flow-matnr IS NOT INITIAL.
          PERFORM nav_mm03_purch USING ls_flow-matnr.
        ENDIF.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
