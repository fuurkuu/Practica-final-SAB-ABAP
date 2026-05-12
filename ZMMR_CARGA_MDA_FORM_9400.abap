*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_FORM_9400
*&---------------------------------------------------------------------*

*---------------------------------------------------------------------*
* 9400 - Log del proceso
*---------------------------------------------------------------------*
*----------------------------------------------------------------------*
* FORM get_data_9400
* Proposito: Carga datos de log (por carga o global) para visualizacion.
*----------------------------------------------------------------------*
FORM get_data_9400.
  REFRESH gt_log_9400.

  IF gv_id_carga IS NOT INITIAL.
    SELECT *
      INTO TABLE gt_log_9400
      FROM ztmm_log_mda
      WHERE id_carga = gv_id_carga.
  ENDIF.

  IF gt_log_9400 IS INITIAL.
    SELECT *
      INTO TABLE gt_log_9400
      FROM ztmm_log_mda.
  ENDIF.

  SORT gt_log_9400 BY log_id DESCENDING.
ENDFORM.

*----------------------------------------------------------------------*
* FORM build_fcat_9400
* Proposito: Construye catalogo de campos del ALV de log (dynpro 9400).
*----------------------------------------------------------------------*
FORM build_fcat_9400.
  REFRESH gt_fcat_9400.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZTMM_LOG_MDA'
    CHANGING
      ct_fieldcat      = gt_fcat_9400
    EXCEPTIONS
      OTHERS           = 1.

  IF sy-subrc <> 0 OR gt_fcat_9400 IS INITIAL.
    MESSAGE 'No se pudo construir catalogo de campos 9400' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM alv_9400_init
* Proposito: Inicializa/actualiza ALV de log en dynpro 9400.
*----------------------------------------------------------------------*
FORM alv_9400_init.
  PERFORM get_data_9400.

  IF go_cont_9400 IS INITIAL.
    CREATE OBJECT go_cont_9400
      EXPORTING
        container_name = 'CC_ALV_9400'.

    CREATE OBJECT go_grid_9400
      EXPORTING
        i_parent = go_cont_9400.

    PERFORM build_fcat_9400.

    CLEAR gs_layo_9400.
    gs_layo_9400-sel_mode   = 'A'.
    gs_layo_9400-zebra      = 'X'.
    gs_layo_9400-cwidth_opt = 'X'.

    CALL METHOD go_grid_9400->set_table_for_first_display
      EXPORTING
        is_layout       = gs_layo_9400
      CHANGING
        it_outtab       = gt_log_9400
        it_fieldcatalog = gt_fcat_9400.
  ELSE.
    CALL METHOD go_grid_9400->refresh_table_display.
  ENDIF.
ENDFORM.
