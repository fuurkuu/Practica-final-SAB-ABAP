*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_FORM_GLOBAL
*&---------------------------------------------------------------------*

*---------------------------------------------------------------------*
* GLOBAL - reutilizable entre dynpros
*---------------------------------------------------------------------*
FORM run USING iv_file TYPE rlgrap-filename.
  DATA: lv_msg          TYPE string,
        lv_ok_txt       TYPE c LENGTH 20,
        lv_err_txt      TYPE c LENGTH 20,
        lv_id_linea_ini TYPE ztmm_log_mda-id_linea.

  CLEAR: gv_ok, gv_err, lv_id_linea_ini.
  CLEAR gv_bal_log_handle.
  CLEAR gv_bal_extnumber.
  REFRESH gt_bal_log_handle.

  PERFORM validate_file USING iv_file.
  PERFORM upload_file USING iv_file.
  PERFORM get_next_number USING gc_obj_carga CHANGING gv_id_carga.
  PERFORM process_lines USING iv_file gv_id_carga CHANGING gv_ok gv_err.

  WRITE gv_ok TO lv_ok_txt.
  WRITE gv_err TO lv_err_txt.
  CONDENSE lv_ok_txt.
  CONDENSE lv_err_txt.

  CONCATENATE 'Carga' gv_id_carga 'finalizada. OK=' lv_ok_txt 'ERR=' lv_err_txt
    INTO lv_msg SEPARATED BY space.

  PERFORM add_log USING gv_id_carga lv_id_linea_ini 'S' lv_msg.
  COMMIT WORK.
  MESSAGE lv_msg TYPE 'S'.
ENDFORM.

FORM f4_file CHANGING cv_file TYPE rlgrap-filename.
  DATA: lt_filetab TYPE filetable,
        ls_file    TYPE file_table,
        lv_rc      TYPE i,
        lv_action  TYPE i.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      default_extension = 'txt'
      file_filter       = 'Text files (*.txt)|*.txt|'
    CHANGING
      file_table        = lt_filetab
      rc                = lv_rc
      user_action       = lv_action
    EXCEPTIONS
      OTHERS            = 1.

  IF sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok AND lv_rc > 0.
    READ TABLE lt_filetab INTO ls_file INDEX 1.
    IF sy-subrc = 0.
      cv_file = ls_file-filename.
    ENDIF.
  ENDIF.
ENDFORM.

FORM validate_file USING iv_file TYPE rlgrap-filename.
  DATA: lv_file_str TYPE string,
        lv_lower    TYPE string.

  IF iv_file IS INITIAL.
    MESSAGE e398(00) WITH 'Debes indicar fichero'.
  ENDIF.

  lv_file_str = iv_file.
  lv_lower    = lcl_util=>to_lower( lv_file_str ).

  IF lv_lower NP '*.txt'.
    MESSAGE e398(00) WITH 'El fichero debe tener extensión .TXT'.
  ENDIF.
ENDFORM.

FORM upload_file USING iv_file TYPE rlgrap-filename.
  DATA lv_filename TYPE string.

  REFRESH gt_raw.
  lv_filename = iv_file.

  CALL METHOD cl_gui_frontend_services=>gui_upload
    EXPORTING
      filename = lv_filename
      filetype = 'ASC'
    CHANGING
      data_tab = gt_raw
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0 OR gt_raw IS INITIAL.
    MESSAGE e398(00) WITH 'Error leyendo fichero o fichero vacío'.
  ENDIF.
ENDFORM.

FORM process_lines USING iv_file TYPE rlgrap-filename
                         iv_id_carga TYPE ztmm_cargas_mda-id_carga
                   CHANGING cv_ok TYPE i
                            cv_err TYPE i.
  DATA: ls_raw          TYPE ty_raw_line,
        ls_carga        TYPE ztmm_cargas_mda,
        lt_parts        TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
        lv_line         TYPE string,
        lv_prov         TYPE ztmm_cargas_mda-proveedor,
        lv_mat          TYPE ztmm_cargas_mda-material,
        lv_qty_txt      TYPE string,
        lv_date_txt     TYPE string,
        lv_qty          TYPE ztmm_cargas_mda-cantidad,
        lv_date_int     TYPE ztmm_cargas_mda-fecha_doc,
        lv_id_linea     TYPE ztmm_cargas_mda-id_linea,
        lv_id_linea_ini TYPE ztmm_log_mda-id_linea,
        lv_name_fich    TYPE string,
        lv_prov_up      TYPE string,
        lv_valid_line   TYPE c,
        lv_val_msg      TYPE string,
        lv_msg          TYPE string,
        lv_tabix_txt    TYPE c LENGTH 10.

  CLEAR lv_id_linea_ini.
  PERFORM get_file_name USING iv_file CHANGING lv_name_fich.

  LOOP AT gt_raw INTO ls_raw.
    lv_line = ls_raw.
    SHIFT lv_line LEFT DELETING LEADING space.
    IF lv_line IS INITIAL.
      CONTINUE.
    ENDIF.

    CLEAR: lv_prov, lv_mat, lv_qty_txt, lv_date_txt.
    SPLIT lv_line AT cl_abap_char_utilities=>horizontal_tab
      INTO lv_prov lv_mat lv_qty_txt lv_date_txt.

    IF lv_date_txt IS INITIAL.
      REFRESH lt_parts.
      SPLIT lv_line AT space INTO TABLE lt_parts.
      DELETE lt_parts WHERE table_line IS INITIAL.
      READ TABLE lt_parts INTO lv_prov INDEX 1.
      READ TABLE lt_parts INTO lv_mat INDEX 2.
      READ TABLE lt_parts INTO lv_qty_txt INDEX 3.
      READ TABLE lt_parts INTO lv_date_txt INDEX 4.
    ENDIF.

    lv_prov_up = lv_prov.
    TRANSLATE lv_prov_up TO UPPER CASE.
    IF lv_prov_up = 'PROVEEDOR'.
      CONTINUE.
    ENDIF.

    IF lv_prov IS INITIAL OR lv_mat IS INITIAL OR lv_qty_txt IS INITIAL OR lv_date_txt IS INITIAL.
      cv_err = cv_err + 1.
      WRITE sy-tabix TO lv_tabix_txt.
      CONDENSE lv_tabix_txt.
      CONCATENATE 'Línea' lv_tabix_txt ': formato inválido' INTO lv_msg SEPARATED BY space.
      PERFORM add_log USING iv_id_carga lv_id_linea_ini 'E' lv_msg.
      CONTINUE.
    ENDIF.

    TRY.
        lv_qty = lv_qty_txt.
      CATCH cx_sy_conversion_no_number.
        cv_err = cv_err + 1.
        WRITE sy-tabix TO lv_tabix_txt.
        CONDENSE lv_tabix_txt.
        CONCATENATE 'Línea' lv_tabix_txt ': cantidad inválida' INTO lv_msg SEPARATED BY space.
        PERFORM add_log USING iv_id_carga lv_id_linea_ini 'E' lv_msg.
        CONTINUE.
    ENDTRY.

    CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
      EXPORTING
        date_external            = lv_date_txt
      IMPORTING
        date_internal            = lv_date_int
      EXCEPTIONS
        date_external_is_invalid = 1
        OTHERS                   = 2.

    IF sy-subrc <> 0.
      cv_err = cv_err + 1.
      WRITE sy-tabix TO lv_tabix_txt.
      CONDENSE lv_tabix_txt.
      CONCATENATE 'Línea' lv_tabix_txt ': fecha inválida' INTO lv_msg SEPARATED BY space.
      PERFORM add_log USING iv_id_carga lv_id_linea_ini 'E' lv_msg.
      CONTINUE.
    ENDIF.

    CLEAR: lv_valid_line, lv_val_msg.
    PERFORM validate_business_line USING lv_prov lv_mat CHANGING lv_valid_line lv_val_msg.
    IF lv_valid_line <> 'X'.
      cv_err = cv_err + 1.
      WRITE sy-tabix TO lv_tabix_txt.
      CONDENSE lv_tabix_txt.
      CONCATENATE 'Línea' lv_tabix_txt ':' lv_val_msg INTO lv_msg SEPARATED BY space.
      PERFORM add_log USING iv_id_carga lv_id_linea_ini 'E' lv_msg.
      CONTINUE.
    ENDIF.

    PERFORM get_next_number USING gc_obj_linea CHANGING lv_id_linea.

    CLEAR ls_carga.

    ls_carga-id_carga      = iv_id_carga.
    ls_carga-id_linea      = lv_id_linea.
    ls_carga-proveedor     = lv_prov.
    ls_carga-material      = lv_mat.
    ls_carga-cantidad      = lv_qty.
    ls_carga-unidad        = gc_unidad.
    ls_carga-fecha_doc     = lv_date_int.
    ls_carga-nombre_fich   = lv_name_fich.
    ls_carga-ruta_fich     = iv_file.
    ls_carga-usuario_carga = sy-uname.
    ls_carga-fecha_carga   = sy-datum.
    ls_carga-hora_carga    = sy-uzeit.

    INSERT ztmm_cargas_mda FROM ls_carga.
    IF sy-subrc = 0.
      cv_ok = cv_ok + 1.
    ELSE.
      cv_err = cv_err + 1.
      WRITE sy-tabix TO lv_tabix_txt.
      CONDENSE lv_tabix_txt.
      CONCATENATE 'Línea' lv_tabix_txt ': error INSERT ZTMM_CARGAS_MDA' INTO lv_msg SEPARATED BY space.
      PERFORM add_log USING iv_id_carga lv_id_linea 'E' lv_msg.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM validate_business_line USING iv_proveedor TYPE ztmm_cargas_mda-proveedor
                                  iv_material  TYPE ztmm_cargas_mda-material
                            CHANGING cv_valid  TYPE c
                                     cv_msg    TYPE string.
  DATA: lv_lifnr_key TYPE lifnr,
        lv_matnr_key TYPE matnr,
        lv_dummy_lifnr TYPE lifnr,
        lv_dummy_matnr TYPE matnr,
        lv_infnr TYPE eina-infnr,
        ls_cfg   TYPE ztmm_cfgpo_mda.

  cv_valid = space.
  CLEAR cv_msg.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = iv_proveedor
    IMPORTING
      output = lv_lifnr_key.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input  = iv_material
    IMPORTING
      output = lv_matnr_key
    EXCEPTIONS
      OTHERS = 1.
  IF sy-subrc <> 0.
    lv_matnr_key = iv_material.
  ENDIF.

  SELECT SINGLE lifnr
    FROM lfa1
    INTO lv_dummy_lifnr
    WHERE lifnr = lv_lifnr_key.
  IF sy-subrc <> 0.
    cv_msg = 'proveedor inexistente en LFA1'.
    RETURN.
  ENDIF.

  SELECT SINGLE matnr
    FROM mara
    INTO lv_dummy_matnr
    WHERE matnr = lv_matnr_key.
  IF sy-subrc <> 0.
    cv_msg = 'material inexistente en MARA'.
    RETURN.
  ENDIF.

  CLEAR ls_cfg.
  SELECT SINGLE *
    INTO ls_cfg
    FROM ztmm_cfgpo_mda
    WHERE uname  = sy-uname
      AND activo = 'X'.

  IF sy-subrc <> 0.
    SELECT SINGLE *
      INTO ls_cfg
      FROM ztmm_cfgpo_mda
      WHERE activo = 'X'.
  ENDIF.

  IF sy-subrc <> 0.
    cv_msg = 'no hay configuración activa en ZTMM_CFGPO_MDA'.
    RETURN.
  ENDIF.

  IF ls_cfg-ekorg IS NOT INITIAL.
    SELECT SINGLE lifnr
      FROM lfm1
      INTO lv_dummy_lifnr
      WHERE lifnr = lv_lifnr_key
        AND ekorg = ls_cfg-ekorg.
    IF sy-subrc <> 0.
      cv_msg = 'proveedor no extendido a EKORG de configuración'.
      RETURN.
    ENDIF.
  ENDIF.

  IF ls_cfg-werks IS NOT INITIAL.
    SELECT SINGLE matnr
      FROM marc
      INTO lv_dummy_matnr
      WHERE matnr = lv_matnr_key
        AND werks = ls_cfg-werks.
    IF sy-subrc <> 0.
      cv_msg = 'material no extendido a WERKS de configuración'.
      RETURN.
    ENDIF.
  ENDIF.

  IF ls_cfg-ekorg IS NOT INITIAL.
    SELECT SINGLE a~infnr
      FROM eina AS a
      INNER JOIN eine AS e
        ON e~infnr = a~infnr
      INTO lv_infnr
      WHERE a~lifnr = lv_lifnr_key
        AND a~matnr = lv_matnr_key
        AND a~loekz = space
        AND e~ekorg = ls_cfg-ekorg.
    IF sy-subrc <> 0.
      cv_msg = 'sin registro info proveedor-material en EKORG (EINA/EINE)'.
      RETURN.
    ENDIF.
  ENDIF.

  cv_valid = 'X'.
ENDFORM.

FORM get_next_number USING iv_object TYPE inri-object
                     CHANGING cv_number TYPE any.
  DATA: lv_number    TYPE n LENGTH 10,
        lv_subrc_txt TYPE c LENGTH 10,
        lv_msg       TYPE c LENGTH 255.

  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr = gc_nr_range
      object      = iv_object
    IMPORTING
      number      = lv_number
    EXCEPTIONS
      OTHERS      = 1.

  IF sy-subrc <> 0.
    WRITE sy-subrc TO lv_subrc_txt.
    CONDENSE lv_subrc_txt.
    CONCATENATE 'Error SNRO objeto' iv_object 'SUBRC' lv_subrc_txt INTO lv_msg SEPARATED BY space.
    MESSAGE e398(00) WITH lv_msg.
  ENDIF.

  cv_number = lv_number.
ENDFORM.

FORM add_log USING iv_id_carga TYPE ztmm_log_mda-id_carga
                   iv_id_linea TYPE ztmm_log_mda-id_linea
                   iv_nivel    TYPE ztmm_log_mda-nivel
                   iv_msg      TYPE string.
  PERFORM bal_add_message USING iv_id_carga iv_id_linea iv_nivel iv_msg.
ENDFORM.

FORM bal_init USING iv_id_carga TYPE ztmm_log_mda-id_carga.
  DATA ls_bal_log TYPE bal_s_log.
  DATA lv_extnumber TYPE balnrext.

  CLEAR lv_extnumber.
  IF iv_id_carga IS NOT INITIAL.
    lv_extnumber = iv_id_carga.
  ENDIF.

  IF gv_bal_log_handle IS NOT INITIAL AND gv_bal_extnumber = lv_extnumber.
    RETURN.
  ENDIF.

  CLEAR ls_bal_log.
  ls_bal_log-object    = gc_bal_obj.
  ls_bal_log-subobject = gc_bal_sub.
  ls_bal_log-aluser    = sy-uname.
  ls_bal_log-alprog    = sy-repid.
  IF lv_extnumber IS NOT INITIAL.
    ls_bal_log-extnumber = lv_extnumber.
  ENDIF.

  CALL FUNCTION 'BAL_LOG_CREATE'
    EXPORTING
      i_s_log      = ls_bal_log
    IMPORTING
      e_log_handle = gv_bal_log_handle
    EXCEPTIONS
      OTHERS       = 1.

  IF sy-subrc = 0 AND gv_bal_log_handle IS NOT INITIAL.
    gv_bal_extnumber = lv_extnumber.
    INSERT gv_bal_log_handle INTO TABLE gt_bal_log_handle.
  ENDIF.
ENDFORM.

FORM bal_add_message USING iv_id_carga TYPE ztmm_log_mda-id_carga
                           iv_id_linea TYPE ztmm_log_mda-id_linea
                           iv_nivel    TYPE ztmm_log_mda-nivel
                           iv_msg      TYPE string.
  DATA: ls_bal_msg TYPE bal_s_msg,
        lv_msgty   TYPE symsgty,
        lv_linea   TYPE c LENGTH 20,
        lv_text200 TYPE c LENGTH 200.

  PERFORM bal_init USING iv_id_carga.
  IF gv_bal_log_handle IS INITIAL.
    RETURN.
  ENDIF.

  lv_msgty = iv_nivel.
  TRANSLATE lv_msgty TO UPPER CASE.
  IF lv_msgty <> 'S' AND lv_msgty <> 'I' AND lv_msgty <> 'W' AND
     lv_msgty <> 'E' AND lv_msgty <> 'A'.
    lv_msgty = 'I'.
  ENDIF.

  CLEAR lv_text200.
  IF iv_id_linea IS NOT INITIAL.
    CLEAR lv_linea.
    WRITE iv_id_linea TO lv_linea.
    CONDENSE lv_linea.
    CONCATENATE 'Linea' lv_linea '-' iv_msg INTO lv_text200 SEPARATED BY space.
  ELSE.
    lv_text200 = iv_msg.
  ENDIF.

  CLEAR ls_bal_msg.
  ls_bal_msg-msgty = lv_msgty.
  ls_bal_msg-msgid = '00'.
  ls_bal_msg-msgno = '398'.
  ls_bal_msg-msgv1 = lv_text200+0(50).
  ls_bal_msg-msgv2 = lv_text200+50(50).
  ls_bal_msg-msgv3 = lv_text200+100(50).
  ls_bal_msg-msgv4 = lv_text200+150(50).

  CALL FUNCTION 'BAL_LOG_MSG_ADD'
    EXPORTING
      i_log_handle = gv_bal_log_handle
      i_s_msg      = ls_bal_msg
    EXCEPTIONS
      OTHERS       = 1.

  IF sy-subrc = 0.
    PERFORM bal_save.
  ENDIF.
ENDFORM.

FORM bal_save.
  IF gt_bal_log_handle IS INITIAL.
    RETURN.
  ENDIF.

  CALL FUNCTION 'BAL_DB_SAVE'
    EXPORTING
      i_save_all     = 'X'
      i_t_log_handle = gt_bal_log_handle
    EXCEPTIONS
      OTHERS         = 1.
ENDFORM.

FORM display_slg_log.
  " Guarda y abre SLG1 siempre, sin lógica adicional
  PERFORM bal_save.
  COMMIT WORK AND WAIT.
  CALL TRANSACTION 'SLG1'.
ENDFORM.

FORM get_file_name USING iv_full_path TYPE rlgrap-filename
                   CHANGING cv_name TYPE string.
  DATA: lv_aux    TYPE string,
        lt_tokens TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

  lv_aux = iv_full_path.
  REPLACE ALL OCCURRENCES OF '\' IN lv_aux WITH '/'.
  SPLIT lv_aux AT '/' INTO TABLE lt_tokens.
  READ TABLE lt_tokens INTO cv_name INDEX lines( lt_tokens ).
  IF sy-subrc <> 0 OR cv_name IS INITIAL.
    cv_name = iv_full_path.
  ENDIF.
ENDFORM.
