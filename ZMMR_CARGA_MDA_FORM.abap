*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_FORM
*&---------------------------------------------------------------------*
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

*---------------------------------------------------------------------*
* 9200 - ALV Generador
*---------------------------------------------------------------------*
FORM alv_9200_init.
  DATA ls_stable TYPE lvc_s_stbl.

  IF go_cont_9200 IS INITIAL.
    CREATE OBJECT go_cont_9200
      EXPORTING
        container_name = 'CC_ALV_9200'.

    CREATE OBJECT go_grid_9200
      EXPORTING
        i_parent = go_cont_9200.

    CREATE OBJECT go_evt_9200.
    SET HANDLER go_evt_9200->handle_toolbar      FOR go_grid_9200.
    SET HANDLER go_evt_9200->handle_user_command FOR go_grid_9200.
    SET HANDLER go_evt_9200->handle_double_click FOR go_grid_9200.
    SET HANDLER go_evt_9200->handle_data_changed FOR go_grid_9200.

    CALL METHOD go_grid_9200->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified.

    PERFORM build_fcat_9200.
    PERFORM get_data_generador.

    CLEAR gs_layo_9200.
    gs_layo_9200-zebra      = 'X'.
    gs_layo_9200-cwidth_opt = 'X'.
    gs_layo_9200-sel_mode   = 'A'.
    gs_layo_9200-stylefname = 'CELLTAB'.

    CALL METHOD go_grid_9200->set_table_for_first_display
      EXPORTING
        is_layout       = gs_layo_9200
      CHANGING
        it_outtab       = gt_gen
        it_fieldcatalog = gt_fcat_9200.

    gv_alv_9200 = 'X'.
  ELSE.
    PERFORM get_data_generador.
    ls_stable-row = 'X'.
    ls_stable-col = 'X'.
    CALL METHOD go_grid_9200->refresh_table_display
      EXPORTING
        is_stable = ls_stable.
  ENDIF.
ENDFORM.

FORM set_row_style USING iv_edit TYPE c
                   CHANGING cs_gen TYPE ty_gen.
  DATA: ls_styl  TYPE lvc_s_styl,
        lv_style TYPE lvc_style.

  IF iv_edit = 'X'.
    lv_style = cl_gui_alv_grid=>mc_style_enabled.
  ELSE.
    lv_style = cl_gui_alv_grid=>mc_style_disabled.
  ENDIF.

  REFRESH cs_gen-celltab.

  CLEAR ls_styl.
  ls_styl-fieldname = 'CANTIDAD'.
  ls_styl-style     = lv_style.
  INSERT ls_styl INTO TABLE cs_gen-celltab.

  CLEAR ls_styl.
  ls_styl-fieldname = 'FECHA_DOC'.
  ls_styl-style     = lv_style.
  INSERT ls_styl INTO TABLE cs_gen-celltab.

  CLEAR ls_styl.
  ls_styl-fieldname = 'COMENTARIO'.
  ls_styl-style     = lv_style.
  INSERT ls_styl INTO TABLE cs_gen-celltab.
ENDFORM.

FORM get_data_generador.
  DATA lv_comment TYPE ztmm_potxt_mda-comentario.

  REFRESH gt_gen.

  SELECT id_carga id_linea proveedor material cantidad unidad fecha_doc ebeln ebelp pedido_gen
    INTO CORRESPONDING FIELDS OF TABLE gt_gen
    FROM ztmm_cargas_mda.

  LOOP AT gt_gen INTO gs_gen.
    CLEAR lv_comment.
    SELECT SINGLE comentario INTO lv_comment
      FROM ztmm_potxt_mda
      WHERE id_carga = gs_gen-id_carga
        AND id_linea = gs_gen-id_linea.

    gs_gen-comentario = lv_comment.

    IF gs_gen-pedido_gen = 'X' AND gs_gen-ebeln IS NOT INITIAL.
      gs_gen-estado = icon_led_green.
    ELSE.
      gs_gen-estado = icon_led_red.
    ENDIF.

    PERFORM set_row_style USING space CHANGING gs_gen.
    MODIFY gt_gen FROM gs_gen.
  ENDLOOP.

  gt_gen_old = gt_gen.
ENDFORM.

FORM build_fcat_9200.
  REFRESH gt_fcat_9200.

  PERFORM add_fcat USING 'ESTADO'     'Estado'     ''  ''.
  PERFORM add_fcat USING 'ID_CARGA'   'ID carga'   ''  ''.
  PERFORM add_fcat USING 'ID_LINEA'   'ID línea'   ''  ''.
  PERFORM add_fcat USING 'PROVEEDOR'  'Proveedor'  ''  ''.
  PERFORM add_fcat USING 'MATERIAL'   'Material'   ''  'X'.
  PERFORM add_fcat USING 'CANTIDAD'   'Cantidad'   'X' ''.
  PERFORM add_fcat USING 'UNIDAD'     'UM'         ''  ''.
  PERFORM add_fcat USING 'FECHA_DOC'  'Fecha'      'X' ''.
  PERFORM add_fcat USING 'EBELN'      'Pedido'     ''  'X'.
  PERFORM add_fcat USING 'EBELP'      'Pos.'       ''  ''.
  PERFORM add_fcat USING 'PEDIDO_GEN' 'Gen.'       ''  ''.
  PERFORM add_fcat USING 'COMENTARIO' 'Comentario' 'X' ''.
ENDFORM.

FORM add_fcat USING iv_field TYPE lvc_fname
                    iv_text  TYPE char40
                    iv_edit  TYPE c
                    iv_hot   TYPE c.
  DATA ls_fcat TYPE lvc_s_fcat.

  CLEAR ls_fcat.
  ls_fcat-fieldname = iv_field.
  ls_fcat-coltext   = iv_text.
  ls_fcat-scrtext_l = iv_text.
  ls_fcat-edit      = iv_edit.
  ls_fcat-hotspot   = iv_hot.

  IF iv_field = 'ESTADO'.
    ls_fcat-icon = 'X'.
  ENDIF.

  APPEND ls_fcat TO gt_fcat_9200.
ENDFORM.

FORM get_selected_gen_rows CHANGING ct_sel TYPE tt_gen.
  DATA: lt_rows TYPE lvc_t_row,
        ls_row  TYPE lvc_s_row,
        ls_gen  TYPE ty_gen.

  REFRESH ct_sel.

  IF go_grid_9200 IS NOT BOUND.
    RETURN.
  ENDIF.

  CALL METHOD go_grid_9200->get_selected_rows
    IMPORTING
      et_index_rows = lt_rows.

  LOOP AT lt_rows INTO ls_row.
    READ TABLE gt_gen INTO ls_gen INDEX ls_row-index.
    IF sy-subrc = 0.
      APPEND ls_gen TO ct_sel.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM has_pending_changes CHANGING cv_pending TYPE c.
  DATA: ls_new TYPE ty_gen,
        ls_old TYPE ty_gen.

  cv_pending = space.

  LOOP AT gt_gen INTO ls_new.
    READ TABLE gt_gen_old INTO ls_old
      WITH KEY id_carga = ls_new-id_carga
               id_linea = ls_new-id_linea.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    IF ls_new-cantidad   <> ls_old-cantidad OR
       ls_new-fecha_doc  <> ls_old-fecha_doc OR
       ls_new-comentario <> ls_old-comentario.
      cv_pending = 'X'.
      EXIT.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM open_edit_mode.
  DATA: lt_sel   TYPE tt_gen,
        ls_gen   TYPE ty_gen,
        ls_lock  TYPE ty_lock,
        lv_count TYPE i.

  IF go_grid_9200 IS NOT BOUND.
    RETURN.
  ENDIF.

  PERFORM get_selected_gen_rows CHANGING lt_sel.

  IF lt_sel IS INITIAL.
    MESSAGE 'Selecciona filas (selector estándar izquierda)' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  REFRESH gt_locks.
  lv_count = 0.

  LOOP AT lt_sel INTO ls_gen.
    IF ls_gen-pedido_gen = 'X'.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'ENQUEUE_EZTMM_POTXT_MDA'
      EXPORTING
        id_carga     = ls_gen-id_carga
        id_linea     = ls_gen-id_linea
      EXCEPTIONS
        foreign_lock = 1
        OTHERS       = 2.

    IF sy-subrc = 0.
      CLEAR ls_lock.
      ls_lock-id_carga = ls_gen-id_carga.
      ls_lock-id_linea = ls_gen-id_linea.
      APPEND ls_lock TO gt_locks.
      lv_count = lv_count + 1.
    ENDIF.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'No hay filas editables seleccionadas' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  LOOP AT gt_gen INTO gs_gen.
    READ TABLE gt_locks INTO ls_lock
      WITH KEY id_carga = gs_gen-id_carga
               id_linea = gs_gen-id_linea.
    IF sy-subrc = 0 AND gs_gen-pedido_gen IS INITIAL.
      PERFORM set_row_style USING 'X' CHANGING gs_gen.
    ELSE.
      PERFORM set_row_style USING space CHANGING gs_gen.
    ENDIF.
    MODIFY gt_gen FROM gs_gen.
  ENDLOOP.

  CALL METHOD go_grid_9200->set_ready_for_input
    EXPORTING
      i_ready_for_input = 1.

  CALL METHOD go_grid_9200->refresh_table_display.
ENDFORM.

FORM close_edit_mode.
  DATA ls_lock TYPE ty_lock.

  LOOP AT gt_locks INTO ls_lock.
    CALL FUNCTION 'DEQUEUE_EZTMM_POTXT_MDA'
      EXPORTING
        id_carga = ls_lock-id_carga
        id_linea = ls_lock-id_linea.
  ENDLOOP.
  REFRESH gt_locks.

  LOOP AT gt_gen INTO gs_gen.
    PERFORM set_row_style USING space CHANGING gs_gen.
    MODIFY gt_gen FROM gs_gen.
  ENDLOOP.

  IF go_grid_9200 IS BOUND.
    CALL METHOD go_grid_9200->set_ready_for_input
      EXPORTING
        i_ready_for_input = 0.
    CALL METHOD go_grid_9200->refresh_table_display.
  ENDIF.
ENDFORM.

FORM save_gen_changes.
  DATA: ls_new  TYPE ty_gen,
        ls_old  TYPE ty_gen,
        ls_lock TYPE ty_lock.

  IF go_grid_9200 IS BOUND.
    CALL METHOD go_grid_9200->check_changed_data.
  ENDIF.

  LOOP AT gt_gen INTO ls_new.
    READ TABLE gt_gen_old INTO ls_old
      WITH KEY id_carga = ls_new-id_carga
               id_linea = ls_new-id_linea.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    READ TABLE gt_locks INTO ls_lock
      WITH KEY id_carga = ls_new-id_carga
               id_linea = ls_new-id_linea.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    IF ls_new-cantidad = ls_old-cantidad AND
       ls_new-fecha_doc = ls_old-fecha_doc AND
       ls_new-comentario = ls_old-comentario.
      CONTINUE.
    ENDIF.

    IF ls_old-pedido_gen = 'X'.
      CONTINUE.
    ENDIF.

    UPDATE ztmm_cargas_mda
      SET cantidad = ls_new-cantidad
          fecha_doc = ls_new-fecha_doc
          umodi = sy-uname
          fsist = sy-datum
          hmodi = sy-uzeit
      WHERE id_carga = ls_new-id_carga
        AND id_linea = ls_new-id_linea.

    PERFORM upsert_comment USING ls_new-id_carga ls_new-id_linea ls_new-comentario.
  ENDLOOP.

  COMMIT WORK.
  PERFORM close_edit_mode.
  PERFORM get_data_generador.

  IF go_grid_9200 IS BOUND.
    CALL METHOD go_grid_9200->refresh_table_display.
  ENDIF.

  MESSAGE 'Cambios guardados' TYPE 'S'.
ENDFORM.

FORM upsert_comment USING iv_id_carga TYPE ztmm_potxt_mda-id_carga
                          iv_id_linea TYPE ztmm_potxt_mda-id_linea
                          iv_comment  TYPE ztmm_potxt_mda-comentario.
  DATA ls_txt TYPE ztmm_potxt_mda.

  SELECT SINGLE * INTO ls_txt
    FROM ztmm_potxt_mda
    WHERE id_carga = iv_id_carga
      AND id_linea = iv_id_linea.

  IF sy-subrc = 0.
    UPDATE ztmm_potxt_mda
      SET comentario = iv_comment
          aenam      = sy-uname
          aedat      = sy-datum
          aezet      = sy-uzeit
      WHERE id_carga = iv_id_carga
        AND id_linea = iv_id_linea.
  ELSE.
    CLEAR ls_txt.
    ls_txt-id_carga   = iv_id_carga.
    ls_txt-id_linea   = iv_id_linea.
    ls_txt-comentario = iv_comment.
    ls_txt-ernam      = sy-uname.
    ls_txt-erdat      = sy-datum.
    ls_txt-erzet      = sy-uzeit.
    ls_txt-aenam      = sy-uname.
    ls_txt-aedat      = sy-datum.
    ls_txt-aezet      = sy-uzeit.
    INSERT ztmm_potxt_mda FROM ls_txt.
  ENDIF.
ENDFORM.

FORM get_cfg_po CHANGING cs_cfg TYPE ztmm_cfgpo_mda.
  CLEAR cs_cfg.

  SELECT SINGLE *
    INTO cs_cfg
    FROM ztmm_cfgpo_mda
    WHERE uname  = sy-uname
      AND activo = 'X'.

  IF sy-subrc <> 0.
    SELECT SINGLE *
      INTO cs_cfg
      FROM ztmm_cfgpo_mda
      WHERE activo = 'X'.
  ENDIF.

  IF sy-subrc <> 0.
    MESSAGE 'No existe configuración activa en ZTMM_CFGPO_MDA' TYPE 'E'.
  ENDIF.
ENDFORM.

FORM generate_po_selected.
  DATA: lt_sel       TYPE tt_gen,
        lt_group     TYPE tt_gen,
        ls_sel       TYPE ty_gen,
        lv_prev_prov TYPE ztmm_cargas_mda-proveedor,
        lv_prev_fec  TYPE ztmm_cargas_mda-fecha_doc,
        lv_prev_com  TYPE ztmm_potxt_mda-comentario,
        lv_pend      TYPE c,
        lv_group_ok  TYPE c,
        lv_ok        TYPE i,
        lv_err       TYPE i,
        lv_msg       TYPE string,
        lv_ok_txt    TYPE c LENGTH 10,
        lv_err_txt   TYPE c LENGTH 10.

  IF go_grid_9200 IS BOUND.
    CALL METHOD go_grid_9200->check_changed_data.
  ENDIF.

  PERFORM has_pending_changes CHANGING lv_pend.
  IF lv_pend = 'X'.
    MESSAGE 'Guarda antes de generar pedido' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM get_selected_gen_rows CHANGING lt_sel.
  IF lt_sel IS INITIAL.
    MESSAGE 'Selecciona filas (selector estándar izquierda)' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  DELETE lt_sel WHERE pedido_gen = 'X'.

  IF lt_sel IS INITIAL.
    MESSAGE 'Todas las filas seleccionadas ya están generadas' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SORT lt_sel BY proveedor fecha_doc comentario material.

  CLEAR: lv_prev_prov, lv_prev_fec, lv_prev_com.
  REFRESH lt_group.
  CLEAR: lv_ok, lv_err.

  LOOP AT lt_sel INTO ls_sel.
    IF lv_prev_prov IS INITIAL.
      lv_prev_prov = ls_sel-proveedor.
      lv_prev_fec  = ls_sel-fecha_doc.
      lv_prev_com  = ls_sel-comentario.
    ENDIF.

    IF ls_sel-proveedor  <> lv_prev_prov OR
       ls_sel-fecha_doc  <> lv_prev_fec  OR
       ls_sel-comentario <> lv_prev_com.

      CLEAR lv_group_ok.
      PERFORM create_po_group USING lv_prev_prov lv_prev_fec lv_prev_com
                              CHANGING lt_group lv_group_ok.

      IF lv_group_ok = 'X'.
        lv_ok = lv_ok + 1.
      ELSE.
        lv_err = lv_err + 1.
      ENDIF.

      REFRESH lt_group.
      lv_prev_prov = ls_sel-proveedor.
      lv_prev_fec  = ls_sel-fecha_doc.
      lv_prev_com  = ls_sel-comentario.
    ENDIF.

    APPEND ls_sel TO lt_group.
  ENDLOOP.

  IF lt_group IS NOT INITIAL.
    CLEAR lv_group_ok.
    PERFORM create_po_group USING lv_prev_prov lv_prev_fec lv_prev_com
                            CHANGING lt_group lv_group_ok.
    IF lv_group_ok = 'X'.
      lv_ok = lv_ok + 1.
    ELSE.
      lv_err = lv_err + 1.
    ENDIF.
  ENDIF.

  PERFORM get_data_generador.
  IF go_grid_9200 IS BOUND.
    CALL METHOD go_grid_9200->refresh_table_display.
  ENDIF.

  WRITE lv_ok TO lv_ok_txt.
  WRITE lv_err TO lv_err_txt.
  CONDENSE lv_ok_txt.
  CONDENSE lv_err_txt.

  CONCATENATE 'Generación grupos OK=' lv_ok_txt 'ERR=' lv_err_txt
    INTO lv_msg SEPARATED BY space.

  IF lv_err > 0.
    MESSAGE lv_msg TYPE 'S' DISPLAY LIKE 'E'.
  ELSE.
    MESSAGE lv_msg TYPE 'S'.
  ENDIF.
ENDFORM.

FORM create_po_group USING iv_proveedor TYPE ztmm_cargas_mda-proveedor
                           iv_fecha_doc TYPE ztmm_cargas_mda-fecha_doc
                           iv_comment   TYPE ztmm_potxt_mda-comentario
                     CHANGING ct_group    TYPE tt_gen
                              cv_group_ok TYPE c.

  DATA: ls_cfg     TYPE ztmm_cfgpo_mda,
        ls_first   TYPE ty_gen,
        ls_line    TYPE ty_gen,
        ls_agg     TYPE ty_agg,
        lt_agg     TYPE STANDARD TABLE OF ty_agg WITH DEFAULT KEY,
        lv_itemno  TYPE n LENGTH 5,
        lv_ebeln   TYPE ebeln,
        lv_vendor  TYPE lifnr,
        lv_error   TYPE c,
        lv_upd     TYPE i,
        lv_err_msg TYPE string.

  DATA: ls_head  TYPE bapimepoheader,
        ls_headx TYPE bapimepoheaderx,
        ls_item  TYPE bapimepoitem,
        ls_itemx TYPE bapimepoitemx,
        ls_sch   TYPE bapimeposchedule,
        ls_schx  TYPE bapimeposchedulx,
        ls_ret   TYPE bapiret2.

  DATA: lt_item   TYPE TABLE OF bapimepoitem,
        lt_itemx  TYPE TABLE OF bapimepoitemx,
        lt_sch    TYPE TABLE OF bapimeposchedule,
        lt_schx   TYPE TABLE OF bapimeposchedulx,
        lt_return TYPE TABLE OF bapiret2.

  DATA: lv_msg   TYPE string,
        lv_idcar TYPE ztmm_log_mda-id_carga,
        lv_idlin TYPE ztmm_log_mda-id_linea.

  cv_group_ok = space.

  READ TABLE ct_group INTO ls_first INDEX 1.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  lv_idcar = ls_first-id_carga.
  CLEAR lv_idlin.

  PERFORM get_cfg_po CHANGING ls_cfg.

  REFRESH lt_agg.
  LOOP AT ct_group INTO ls_line.
    READ TABLE lt_agg INTO ls_agg WITH KEY material = ls_line-material.
    IF sy-subrc = 0.
      ls_agg-cantidad = ls_agg-cantidad + ls_line-cantidad.
      MODIFY lt_agg FROM ls_agg INDEX sy-tabix.
    ELSE.
      CLEAR ls_agg.
      ls_agg-material = ls_line-material.
      ls_agg-cantidad = ls_line-cantidad.
      IF ls_cfg-meins IS INITIAL.
        ls_agg-unidad = gc_unidad.
      ELSE.
        ls_agg-unidad = ls_cfg-meins.
      ENDIF.
      APPEND ls_agg TO lt_agg.
    ENDIF.
  ENDLOOP.

  CLEAR: ls_head, ls_headx.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = iv_proveedor
    IMPORTING
      output = lv_vendor.

  ls_head-doc_type  = ls_cfg-bsart.
  IF lv_vendor IS INITIAL.
    ls_head-vendor = iv_proveedor.
  ELSE.
    ls_head-vendor = lv_vendor.
  ENDIF.
  ls_head-purch_org = ls_cfg-ekorg.
  ls_head-pur_group = ls_cfg-ekgrp.
  ls_head-doc_date  = sy-datum.

  ls_headx-doc_type  = 'X'.
  ls_headx-vendor    = 'X'.
  ls_headx-purch_org = 'X'.
  ls_headx-pur_group = 'X'.
  ls_headx-doc_date  = 'X'.

  REFRESH: lt_item, lt_itemx, lt_sch, lt_schx, lt_return.
  CLEAR lv_itemno.

  LOOP AT lt_agg INTO ls_agg.
    lv_itemno = lv_itemno + 10.
    ls_agg-po_item = lv_itemno.
    MODIFY lt_agg FROM ls_agg INDEX sy-tabix.

    CLEAR ls_item.
    ls_item-po_item  = ls_agg-po_item.
    ls_item-material = ls_agg-material.
    ls_item-plant    = ls_cfg-werks.
    ls_item-quantity = ls_agg-cantidad.
    ls_item-po_unit  = ls_agg-unidad.
    APPEND ls_item TO lt_item.

    CLEAR ls_itemx.
    ls_itemx-po_item  = ls_agg-po_item.
    ls_itemx-po_itemx = 'X'.
    ls_itemx-material = 'X'.
    ls_itemx-plant    = 'X'.
    ls_itemx-quantity = 'X'.
    ls_itemx-po_unit  = 'X'.
    APPEND ls_itemx TO lt_itemx.

    CLEAR ls_sch.
    ls_sch-po_item       = ls_agg-po_item.
    ls_sch-sched_line    = '0001'.
    ls_sch-delivery_date = iv_fecha_doc.
    ls_sch-quantity      = ls_agg-cantidad.
    APPEND ls_sch TO lt_sch.

    CLEAR ls_schx.
    ls_schx-po_item       = ls_agg-po_item.
    ls_schx-sched_line    = '0001'.
    ls_schx-po_itemx      = 'X'.
    ls_schx-sched_linex   = 'X'.
    ls_schx-delivery_date = 'X'.
    ls_schx-quantity      = 'X'.
    APPEND ls_schx TO lt_schx.
  ENDLOOP.

  CALL FUNCTION 'BAPI_PO_CREATE1'
    EXPORTING
      poheader         = ls_head
      poheaderx        = ls_headx
    IMPORTING
      exppurchaseorder = lv_ebeln
    TABLES
      return           = lt_return
      poitem           = lt_item
      poitemx          = lt_itemx
      poschedule       = lt_sch
      poschedulex      = lt_schx.

  lv_error = space.
  LOOP AT lt_return INTO ls_ret.
    IF ls_ret-type = 'E' OR ls_ret-type = 'A'.
      lv_error = 'X'.
    ENDIF.
    lv_msg = ls_ret-message.
    PERFORM add_log USING lv_idcar lv_idlin ls_ret-type lv_msg.
  ENDLOOP.

  IF lv_error = 'X' OR lv_ebeln IS INITIAL.
    CLEAR lv_err_msg.
    LOOP AT lt_return INTO ls_ret WHERE type = 'E' OR type = 'A'.
      IF lv_err_msg IS INITIAL.
        lv_err_msg = ls_ret-message.
      ELSE.
        CONCATENATE lv_err_msg ' | ' ls_ret-message INTO lv_err_msg.
      ENDIF.
    ENDLOOP.

    IF lv_err_msg IS INITIAL.
      lv_err_msg = 'BAPI_PO_CREATE1 devolvió error sin detalle'.
    ENDIF.

    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    PERFORM add_log USING lv_idcar lv_idlin 'E' lv_err_msg.
    COMMIT WORK AND WAIT.
    RETURN.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = 'X'.

  CLEAR lv_upd.
  LOOP AT ct_group INTO ls_line.
    READ TABLE lt_agg INTO ls_agg WITH KEY material = ls_line-material.
    IF sy-subrc <> 0.
      PERFORM add_log USING ls_line-id_carga ls_line-id_linea 'E' 'No se encontró material agregado'.
      CONTINUE.
    ENDIF.

    UPDATE ztmm_cargas_mda
      SET ebeln      = lv_ebeln
          ebelp      = ls_agg-po_item
          pedido_gen = 'X'
          umodi      = sy-uname
          fsist      = sy-datum
          hmodi      = sy-uzeit
      WHERE id_carga = ls_line-id_carga
        AND id_linea = ls_line-id_linea.

    IF sy-subrc = 0.
      lv_upd = lv_upd + 1.
    ELSE.
      PERFORM add_log USING ls_line-id_carga ls_line-id_linea 'E' 'Error actualizando ZTMM_CARGAS_MDA'.
    ENDIF.
  ENDLOOP.

  IF lv_upd = 0.
    PERFORM add_log USING lv_idcar lv_idlin 'E' 'Pedido creado pero sin líneas actualizadas'.
    RETURN.
  ENDIF.

  IF iv_comment IS NOT INITIAL.
    LOOP AT lt_agg INTO ls_agg.
      PERFORM save_po_text USING lv_ebeln ls_agg-po_item iv_comment.
    ENDLOOP.
  ENDIF.

  COMMIT WORK.
  PERFORM add_log USING lv_idcar lv_idlin 'S' 'Pedido generado correctamente'.

  cv_group_ok = 'X'.
ENDFORM.

FORM save_po_text USING iv_ebeln TYPE ebeln
                        iv_ebelp TYPE ebelp
                        iv_text  TYPE ztmm_potxt_mda-comentario.
  DATA: ls_head  TYPE thead,
        ls_tline TYPE tline,
        lt_lines TYPE TABLE OF tline.

  CLEAR ls_head.
  ls_head-tdobject = 'EKPO'.
  ls_head-tdid     = 'F01'.
  ls_head-tdspras  = sy-langu.
  CONCATENATE iv_ebeln iv_ebelp INTO ls_head-tdname.

  REFRESH lt_lines.
  CLEAR ls_tline.
  ls_tline-tdformat = '*'.
  ls_tline-tdline   = iv_text.
  APPEND ls_tline TO lt_lines.

  CALL FUNCTION 'SAVE_TEXT'
    EXPORTING
      header          = ls_head
      insert          = 'X'
      savemode_direct = 'X'
    TABLES
      lines           = lt_lines
    EXCEPTIONS
      OTHERS          = 1.
ENDFORM.

FORM nav_me23n USING iv_ebeln TYPE ebeln.
  SET PARAMETER ID 'BES' FIELD iv_ebeln.
  CALL TRANSACTION 'ME23N' AND SKIP FIRST SCREEN.
ENDFORM.

FORM nav_mm03_purch USING iv_matnr TYPE matnr.
  DATA: ls_cfg TYPE ztmm_cfgpo_mda,
        lv_mxx TYPE c LENGTH 1.

  PERFORM get_cfg_po CHANGING ls_cfg.

  SET PARAMETER ID 'MAT' FIELD iv_matnr.

  IF ls_cfg-werks IS NOT INITIAL.
    SET PARAMETER ID 'WRK' FIELD ls_cfg-werks.
  ENDIF.

  lv_mxx = 'E'.
  SET PARAMETER ID 'MXX' FIELD lv_mxx.

  CALL TRANSACTION 'MM03' AND SKIP FIRST SCREEN.
ENDFORM.

FORM get_data_9300.
  TYPES: BEGIN OF ty_mail_map,
           lifnr     TYPE lifnr,
           smtp_addr TYPE adr6-smtp_addr,
           flgdefault TYPE adr6-flgdefault,
         END OF ty_mail_map.
  TYPES: BEGIN OF ty_po_mail,
           ebeln     TYPE ebeln,
           smtp_addr TYPE adr6-smtp_addr,
         END OF ty_po_mail.

  FIELD-SYMBOLS: <fs_flow>      TYPE any,
                 <fs_mail_sent> TYPE any,
                 <fs_icon_mail> TYPE any,
                 <fs_smtp_addr> TYPE any,
                 <fs_lifnr>     TYPE any,
                 <fs_proveedor> TYPE any,
                 <fs_ebeln>     TYPE any.
  DATA: lv_mail_stat TYPE c,
        lv_smtp_assigned TYPE c,
        lv_lifnr     TYPE lifnr,
        lv_ebeln     TYPE ebeln,
        lv_vendor_key TYPE lifnr,
        lv_mail_flag TYPE ty_fieldname30,
        ls_mail_map  TYPE ty_mail_map,
        ls_po_mail   TYPE ty_po_mail.
  DATA lt_mail_map TYPE STANDARD TABLE OF ty_mail_map WITH DEFAULT KEY.
  DATA lt_po_mail TYPE STANDARD TABLE OF ty_po_mail WITH DEFAULT KEY.

  REFRESH gt_flow.

  SELECT
    h~ebeln,
    h~bukrs,
    h~bsart,
    h~bstyp,
    h~loekz       AS loekz_h,
    h~statu,
    h~aedat,
    h~ernam,
    h~lifnr,
    h~spras,
    h~zterm,
    h~ekorg,
    h~ekgrp,
    h~waers,
    h~bedat,
    h~knumv,

    p~ebelp,
    p~matnr,
    p~menge,
    p~meins,
    p~netpr,
    p~mwskz,

    c~id_carga,
    c~nombre_fich,
    c~fecha_carga,
    c~hora_carga,
    c~usuario_carga AS usuario,
    c~ruta_fich,

    l~name1        AS name1,
    l~land1        AS land1,
    l~regio        AS regio,
    l~ort01        AS ort01,
    l~stras        AS stras,
    l~pstlz        AS pstlz,
    ad~smtp_addr   AS smtp_addr,

    m~mtart        AS mtart,
    m~mbrsh        AS mbrsh,
    m~matkl        AS matkl,
    m~meins        AS meins_b,
    m~tragr        AS tragr,

    i~lifnr        AS lifnr_inf,
    i~infnr        AS infnr,
    li~name1       AS name1_inf

    INTO CORRESPONDING FIELDS OF TABLE @gt_flow
    FROM ztmm_cargas_mda AS c
    INNER JOIN ekko AS h
      ON h~ebeln = c~ebeln
    INNER JOIN ekpo AS p
      ON p~ebeln = c~ebeln
     AND p~ebelp = c~ebelp
    LEFT JOIN lfa1 AS l
      ON l~lifnr = h~lifnr
    LEFT JOIN adr6 AS ad
      ON ad~addrnumber = l~adrnr
     AND ad~flgdefault = 'X'
    LEFT JOIN mara AS m
      ON m~matnr = p~matnr
    LEFT JOIN eina AS i
      ON i~matnr = p~matnr
     AND i~lifnr = h~lifnr
     AND i~loekz = ''
    LEFT JOIN eine AS e
      ON e~infnr = i~infnr
     AND e~ekorg = h~ekorg
    LEFT JOIN lfa1 AS li
      ON li~lifnr = i~lifnr.

  REFRESH lt_mail_map.
  REFRESH lt_po_mail.
  CLEAR lv_mail_flag.
  PERFORM get_mail_flag_component_9300 CHANGING lv_mail_flag.
  IF gt_flow IS NOT INITIAL.
    SELECT
      l~lifnr,
      ad~smtp_addr,
      ad~flgdefault
      INTO TABLE @lt_mail_map
      FROM lfa1 AS l
      INNER JOIN adr6 AS ad
        ON ad~addrnumber = l~adrnr
      FOR ALL ENTRIES IN @gt_flow
      WHERE l~lifnr = @gt_flow-lifnr
        AND ad~smtp_addr <> @space.

    SORT lt_mail_map BY lifnr flgdefault DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_mail_map COMPARING lifnr.

    SELECT h~ebeln,
           ad~smtp_addr
      INTO TABLE @lt_po_mail
      FROM ekko AS h
      INNER JOIN adr6 AS ad
        ON ad~addrnumber = h~adrnr
      FOR ALL ENTRIES IN @gt_flow
      WHERE h~ebeln = @gt_flow-ebeln
        AND ad~smtp_addr <> @space.

    SORT lt_po_mail BY ebeln.
    DELETE ADJACENT DUPLICATES FROM lt_po_mail COMPARING ebeln.
  ENDIF.

  LOOP AT gt_flow ASSIGNING <fs_flow>.
    CLEAR: lv_mail_stat, lv_smtp_assigned, lv_ebeln.

    ASSIGN COMPONENT 'SMTP_ADDR' OF STRUCTURE <fs_flow> TO <fs_smtp_addr>.
    IF sy-subrc = 0.
      lv_smtp_assigned = 'X'.
    ENDIF.

    IF lv_smtp_assigned = 'X' AND <fs_smtp_addr> IS INITIAL.
      ASSIGN COMPONENT 'EBELN' OF STRUCTURE <fs_flow> TO <fs_ebeln>.
      IF sy-subrc = 0 AND <fs_ebeln> IS NOT INITIAL.
        lv_ebeln = <fs_ebeln>.
        CLEAR ls_po_mail.
        READ TABLE lt_po_mail INTO ls_po_mail WITH KEY ebeln = lv_ebeln.
        IF sy-subrc = 0 AND ls_po_mail-smtp_addr IS NOT INITIAL.
          <fs_smtp_addr> = ls_po_mail-smtp_addr.
        ENDIF.
      ENDIF.
    ENDIF.

    IF lv_smtp_assigned = 'X' AND <fs_smtp_addr> IS INITIAL.
      CLEAR lv_vendor_key.
      ASSIGN COMPONENT 'LIFNR' OF STRUCTURE <fs_flow> TO <fs_lifnr>.
      IF sy-subrc = 0 AND <fs_lifnr> IS NOT INITIAL.
        lv_vendor_key = <fs_lifnr>.
      ELSE.
        ASSIGN COMPONENT 'PROVEEDOR' OF STRUCTURE <fs_flow> TO <fs_proveedor>.
        IF sy-subrc = 0 AND <fs_proveedor> IS NOT INITIAL.
          lv_vendor_key = <fs_proveedor>.
        ENDIF.
      ENDIF.

      IF lv_vendor_key IS NOT INITIAL.
        lv_lifnr = lv_vendor_key.
        CLEAR ls_mail_map.
        READ TABLE lt_mail_map INTO ls_mail_map WITH KEY lifnr = lv_lifnr.
        IF sy-subrc = 0.
          <fs_smtp_addr> = ls_mail_map-smtp_addr.
        ENDIF.
      ENDIF.
    ENDIF.

    IF lv_mail_flag IS NOT INITIAL.
      ASSIGN COMPONENT 'EBELN' OF STRUCTURE <fs_flow> TO <fs_ebeln>.
      IF sy-subrc = 0 AND <fs_ebeln> IS NOT INITIAL.
        lv_ebeln = <fs_ebeln>.
        PERFORM is_mail_sent_for_ebeln_9300 USING lv_ebeln lv_mail_flag CHANGING lv_mail_stat.
      ENDIF.

      ASSIGN COMPONENT 'MAIL_ENVIADO' OF STRUCTURE <fs_flow> TO <fs_mail_sent>.
      IF sy-subrc = 0.
        <fs_mail_sent> = lv_mail_stat.
      ELSE.
        ASSIGN COMPONENT 'ENVIADO_MAIL' OF STRUCTURE <fs_flow> TO <fs_mail_sent>.
        IF sy-subrc = 0.
          <fs_mail_sent> = lv_mail_stat.
        ELSE.
          ASSIGN COMPONENT 'MAIL_SENT' OF STRUCTURE <fs_flow> TO <fs_mail_sent>.
          IF sy-subrc = 0.
            <fs_mail_sent> = lv_mail_stat.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    ASSIGN COMPONENT 'ICON_MAIL' OF STRUCTURE <fs_flow> TO <fs_icon_mail>.
    IF sy-subrc = 0.
      IF lv_mail_stat = 'X'.
        <fs_icon_mail> = icon_led_green.
      ELSE.
        <fs_icon_mail> = icon_led_red.
      ENDIF.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM alv_9300_init.
  PERFORM get_data_9300.

  IF go_cont_9300 IS INITIAL.
    CREATE OBJECT go_cont_9300
      EXPORTING
        container_name = 'CC_ALV_9300'.

    CREATE OBJECT go_grid_9300
      EXPORTING
        i_parent = go_cont_9300.

    CREATE OBJECT go_evt_9300.
    SET HANDLER go_evt_9300->handle_double_click FOR go_grid_9300.
    SET HANDLER go_evt_9300->handle_toolbar      FOR go_grid_9300.
    SET HANDLER go_evt_9300->handle_user_command FOR go_grid_9300.

    PERFORM build_fcat_9300.

    CLEAR gs_layo_9300.
    gs_layo_9300-sel_mode   = 'A'.
    gs_layo_9300-zebra      = 'X'.
    gs_layo_9300-cwidth_opt = 'X'.

    CALL METHOD go_grid_9300->set_table_for_first_display
      EXPORTING
        is_layout       = gs_layo_9300
      CHANGING
        it_outtab       = gt_flow
        it_fieldcatalog = gt_fcat_9300.

    CALL METHOD go_grid_9300->set_toolbar_interactive.
  ELSE.
    CALL METHOD go_grid_9300->set_toolbar_interactive.
    CALL METHOD go_grid_9300->refresh_table_display.
  ENDIF.
ENDFORM.

FORM popup_filtros_9300.
  DATA: lt_fields TYPE TABLE OF sval,
        ls_field  TYPE sval.

  REFRESH lt_fields.

  CLEAR ls_field.
  ls_field-tabname   = 'EKKO'.
  ls_field-fieldname = 'EBELN'.
  ls_field-value     = gv_f_ebeln.
  APPEND ls_field TO lt_fields.

  CLEAR ls_field.
  ls_field-tabname   = 'EKKO'.
  ls_field-fieldname = 'AEDAT'.
  ls_field-value     = gv_f_aedat.
  APPEND ls_field TO lt_fields.

  CLEAR ls_field.
  ls_field-tabname   = 'ZTMM_CARGAS_MDA'.
  ls_field-fieldname = 'FECHA_CARGA'.
  ls_field-value     = gv_f_fecha_carga.
  APPEND ls_field TO lt_fields.

  CLEAR ls_field.
  ls_field-tabname   = 'ZTMM_CARGAS_MDA'.
  ls_field-fieldname = 'ID_CARGA'.
  ls_field-value     = gv_f_id_carga.
  APPEND ls_field TO lt_fields.

  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING
      popup_title = 'Filtros flujo completo'
    TABLES
      fields      = lt_fields
    EXCEPTIONS
      error_in_fields = 1
      OTHERS          = 2.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  READ TABLE lt_fields INTO ls_field INDEX 1.
  IF sy-subrc = 0. gv_f_ebeln = ls_field-value. ENDIF.

  READ TABLE lt_fields INTO ls_field INDEX 2.
  IF sy-subrc = 0. gv_f_aedat = ls_field-value. ENDIF.

  READ TABLE lt_fields INTO ls_field INDEX 3.
  IF sy-subrc = 0. gv_f_fecha_carga = ls_field-value. ENDIF.

  READ TABLE lt_fields INTO ls_field INDEX 4.
  IF sy-subrc = 0. gv_f_id_carga = ls_field-value. ENDIF.
ENDFORM.

FORM print_form_9300 USING iv_action TYPE c.
  DATA: ls_flow      TYPE zemm_flujo_mda,
        lt_sel       TYPE lvc_t_row,
        ls_row       TYPE lvc_s_row,
        ls_ekko      TYPE ekko,
        lt_ekpo      TYPE ztymm_ekpo_mda,
        ls_lfa1      TYPE lfa1,
        ls_adrc      TYPE adrc,
        ls_t001      TYPE t001,
        lt_carg      TYPE ztymm_cargas_mda,
        lv_fm        TYPE funcname,
        ls_out       TYPE sfpoutputparams,
        ls_docparams TYPE sfpdocparams.

  CALL METHOD go_grid_9300->get_selected_rows
    IMPORTING
      et_index_rows = lt_sel.

  IF lt_sel IS INITIAL.
    MESSAGE 'Selecciona un pedido' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  READ TABLE lt_sel INTO ls_row INDEX 1.
  READ TABLE gt_flow INTO ls_flow INDEX ls_row-index.
  IF sy-subrc <> 0 OR ls_flow-ebeln IS INITIAL.
    MESSAGE 'No se ha podido obtener el pedido' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SELECT SINGLE * FROM ekko INTO ls_ekko WHERE ebeln = ls_flow-ebeln.
  IF sy-subrc <> 0.
    MESSAGE 'No existe cabecera EKKO para ese pedido' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SELECT ebelp,
         matnr,
         menge,
         meins,
         netpr,
         @ls_ekko-waers AS waers
    FROM ekpo
    INTO CORRESPONDING FIELDS OF TABLE @lt_ekpo
    WHERE ebeln = @ls_flow-ebeln.

  SELECT SINGLE * FROM lfa1 INTO ls_lfa1 WHERE lifnr = ls_ekko-lifnr.
  SELECT SINGLE * FROM t001 INTO ls_t001 WHERE bukrs = ls_ekko-bukrs.
  SELECT SINGLE * FROM adrc INTO ls_adrc WHERE addrnumber = ls_lfa1-adrnr.

  SELECT * FROM ztmm_cargas_mda INTO TABLE lt_carg WHERE ebeln = ls_flow-ebeln.

  CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
    EXPORTING
      i_name     = 'ZMMF_PEDIDO_MDA'
    IMPORTING
      e_funcname = lv_fm
    EXCEPTIONS
      OTHERS     = 1.
  IF sy-subrc <> 0 OR lv_fm IS INITIAL.
    MESSAGE 'No se pudo obtener FM del formulario' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CLEAR ls_out.
  IF iv_action = 'V'.
    ls_out-preview  = 'X'.
    ls_out-nodialog = 'X'.
  ELSE.
    ls_out-preview  = space.
    ls_out-nodialog = 'X'.
    ls_out-dest     = 'LP01'.
    ls_out-reqnew   = 'X'.
  ENDIF.

  CALL FUNCTION 'FP_JOB_OPEN'
    CHANGING
      ie_outputparams = ls_out
    EXCEPTIONS
      OTHERS          = 1.
  IF sy-subrc <> 0.
    MESSAGE 'Error abriendo job Adobe' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CLEAR ls_docparams.
  ls_docparams-langu = sy-langu.

  CALL FUNCTION lv_fm
    EXPORTING
      /1bcdwb/docparams = ls_docparams
      e_ekko            = ls_ekko
      e_lfa1            = ls_lfa1
      e_adrc            = ls_adrc
      e_t001            = ls_t001
      t_ekpo            = lt_ekpo
      t_cargas          = lt_carg
      ztymm_cargas_mda  = lt_carg
    EXCEPTIONS
      usage_error       = 1
      system_error      = 2
      internal_error    = 3
      OTHERS            = 4.

  IF sy-subrc <> 0.
    CALL FUNCTION 'FP_JOB_CLOSE'.
    MESSAGE 'Error llamando al formulario Adobe' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'FP_JOB_CLOSE'
    EXCEPTIONS
      OTHERS = 1.
  IF iv_action = 'P'.
    CALL TRANSACTION 'SP01' AND SKIP FIRST SCREEN.
  ENDIF.
ENDFORM.

FORM build_fcat_9300.
  REFRESH gt_fcat_9300.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZEMM_FLUJO_MDA'
    CHANGING
      ct_fieldcat      = gt_fcat_9300
    EXCEPTIONS
      OTHERS           = 1.

  IF sy-subrc <> 0 OR gt_fcat_9300 IS INITIAL.
    MESSAGE 'No se pudo construir catálogo de campos 9300' TYPE 'E'.
  ENDIF.

  LOOP AT gt_fcat_9300 ASSIGNING FIELD-SYMBOL(<fs_fcat>).
    CASE <fs_fcat>-fieldname.
      WHEN 'EBELN'.
        <fs_fcat>-hotspot   = 'X'.
        <fs_fcat>-emphasize = 'C510'.
      WHEN 'MATNR'.
        <fs_fcat>-hotspot   = 'X'.
        <fs_fcat>-emphasize = 'C510'.
      WHEN 'ICON_INFO'.
        <fs_fcat>-icon = 'X'.
      WHEN 'ICON_MAIL'.
        <fs_fcat>-icon      = 'X'.
        <fs_fcat>-coltext   = 'Mail'.
        <fs_fcat>-scrtext_l = 'Mail'.
    ENDCASE.
  ENDLOOP.
ENDFORM.

FORM show_bank_popup_9300.
  DATA: lt_rows    TYPE lvc_t_row,
        ls_row     TYPE lvc_s_row,
        lv_lines   TYPE i,
        ls_flow    TYPE zemm_flujo_mda,
        ls_lfm1    TYPE lfm1,
        lt_lfbk    TYPE STANDARD TABLE OF lfbk WITH DEFAULT KEY,
        ls_lfbk    TYPE lfbk,
        ls_popup   TYPE ty_bank_popup,
        lv_banka   TYPE bnka-banka,
        lo_alv     TYPE REF TO cl_salv_table,
        lo_funcs   TYPE REF TO cl_salv_functions_list,
        lo_display TYPE REF TO cl_salv_display_settings.

  IF go_grid_9300 IS NOT BOUND.
    RETURN.
  ENDIF.

  CALL METHOD go_grid_9300->get_selected_rows
    IMPORTING
      et_index_rows = lt_rows.

  DESCRIBE TABLE lt_rows LINES lv_lines.
  IF lv_lines <> 1.
    MESSAGE 'Selecciona un único registro' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  READ TABLE lt_rows INTO ls_row INDEX 1.
  READ TABLE gt_flow INTO ls_flow INDEX ls_row-index.
  IF sy-subrc <> 0.
    MESSAGE 'No se pudo leer la fila seleccionada' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SELECT SINGLE *
    INTO ls_lfm1
    FROM lfm1
    WHERE lifnr = ls_flow-lifnr
      AND ekorg = ls_flow-ekorg.

  IF sy-subrc <> 0.
    MESSAGE 'No hay datos LFM1 para proveedor/org compras' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  REFRESH gt_bank_popup.

  SELECT *
    INTO TABLE lt_lfbk
    FROM lfbk
    WHERE lifnr = ls_flow-lifnr.

  IF lt_lfbk IS INITIAL.
    CLEAR ls_popup.
    ls_popup-lifnr = ls_lfm1-lifnr.
    ls_popup-ekorg = ls_lfm1-ekorg.
    ls_popup-zterm = ls_lfm1-zterm.
    ls_popup-inco1 = ls_lfm1-inco1.
    APPEND ls_popup TO gt_bank_popup.
  ELSE.
    LOOP AT lt_lfbk INTO ls_lfbk.
      CLEAR lv_banka.
      SELECT SINGLE banka
        INTO lv_banka
        FROM bnka
        WHERE banks = ls_lfbk-banks
          AND bankl = ls_lfbk-bankl.

      CLEAR ls_popup.
      ls_popup-lifnr = ls_lfm1-lifnr.
      ls_popup-ekorg = ls_lfm1-ekorg.
      ls_popup-zterm = ls_lfm1-zterm.
      ls_popup-inco1 = ls_lfm1-inco1.
      ls_popup-banco = lv_banka.
      ls_popup-banks = ls_lfbk-banks.
      ls_popup-bankn = ls_lfbk-bankn.
      APPEND ls_popup TO gt_bank_popup.
    ENDLOOP.
  ENDIF.

  TRY.
      CALL METHOD cl_salv_table=>factory
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_bank_popup.

      lo_funcs = lo_alv->get_functions( ).
      lo_funcs->set_all( abap_true ).

      lo_display = lo_alv->get_display_settings( ).
      lo_display->set_striped_pattern( abap_true ).

      lo_alv->set_screen_popup(
        start_column = 5
        end_column   = 170
        start_line   = 2
        end_line     = 22 ).

      lo_alv->display( ).
    CATCH cx_salv_msg.
      MESSAGE 'Error mostrando popup de datos bancarios' TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
ENDFORM.

*---------------------------------------------------------------------*
* 9400 - Log del proceso
*---------------------------------------------------------------------*
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
    MESSAGE 'No se pudo construir catálogo de campos 9400' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

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

FORM send_mail_csv_9300.
  DATA: lt_rows          TYPE lvc_t_row,
        ls_row           TYPE lvc_s_row,
        ls_sel_flow      TYPE zemm_flujo_mda,
        ls_csv_flow      TYPE zemm_flujo_mda,
        lt_orders        TYPE SORTED TABLE OF ebeln WITH UNIQUE KEY table_line,
        lv_ebeln         TYPE ebeln,
        lv_lifnr         TYPE lifnr,
        lv_default_mail  TYPE adr6-smtp_addr,
        lv_mail_flag     TYPE c LENGTH 30,
        lv_mail_sent     TYPE c,
        lv_cancel        TYPE c,
        lv_orders_txt    TYPE string,
        lv_csv_line      TYPE string,
        lv_csv_full      TYPE string,
        lv_qty_txt       TYPE c LENGTH 30,
        lv_fecha_txt     TYPE c LENGTH 20,
        lv_body_line     TYPE soli,
        lv_subject       TYPE so_obj_des VALUE 'Pedido de compra creado',
        lv_sent_to_all   TYPE c LENGTH 1,
        lv_log_msg       TYPE string,
        lv_id_carga_log  TYPE ztmm_cargas_mda-id_carga,
        lv_id_linea_log  TYPE ztmm_log_mda-id_linea,
        lv_bom_utf8(3)   TYPE x VALUE 'EFBBBF'.

  DATA: lt_receivers     TYPE tt_mail_recipients,
        ls_receiver      TYPE adr6-smtp_addr,
        lt_csv_lines     TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
        lt_message_body  TYPE bcsy_text,
        lt_csv_hex       TYPE solix_tab,
        lv_csv_xstring   TYPE xstring.

  DATA: lo_send_request  TYPE REF TO cl_bcs,
        lo_document      TYPE REF TO cl_document_bcs,
        lo_sender        TYPE REF TO if_sender_bcs,
        lo_recipient     TYPE REF TO if_recipient_bcs.

  IF go_grid_9300 IS NOT BOUND.
    RETURN.
  ENDIF.

  CALL METHOD go_grid_9300->get_selected_rows
    IMPORTING
      et_index_rows = lt_rows.

  IF lt_rows IS INITIAL.
    MESSAGE 'Selecciona al menos una fila para enviar mail' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CLEAR: lv_lifnr, lv_default_mail, lv_id_carga_log, lv_id_linea_log.
  REFRESH lt_orders.

  LOOP AT lt_rows INTO ls_row.
    READ TABLE gt_flow INTO ls_sel_flow INDEX ls_row-index.
    IF sy-subrc <> 0 OR ls_sel_flow-ebeln IS INITIAL.
      CONTINUE.
    ENDIF.

    IF lv_lifnr IS INITIAL.
      lv_lifnr = ls_sel_flow-lifnr.
    ELSEIF lv_lifnr <> ls_sel_flow-lifnr.
      MESSAGE 'Solo se pueden enviar pedidos del mismo proveedor' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF lv_default_mail IS INITIAL.
      IF ls_sel_flow-smtp_addr IS NOT INITIAL.
        lv_default_mail = ls_sel_flow-smtp_addr.
      ELSEIF ls_sel_flow-ebeln IS NOT INITIAL.
        PERFORM get_po_mail_9300 USING ls_sel_flow-ebeln CHANGING lv_default_mail.
      ELSEIF ls_sel_flow-lifnr IS NOT INITIAL.
        PERFORM get_supplier_mail_9300 USING ls_sel_flow-lifnr CHANGING lv_default_mail.
      ENDIF.
    ENDIF.

    IF lv_id_carga_log IS INITIAL.
      lv_id_carga_log = ls_sel_flow-id_carga.
    ENDIF.

    INSERT ls_sel_flow-ebeln INTO TABLE lt_orders.
  ENDLOOP.

  IF lt_orders IS INITIAL.
    MESSAGE 'No hay pedidos válidos en la selección' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM get_mail_flag_component_9300 CHANGING lv_mail_flag.
  IF lv_mail_flag IS INITIAL.
    MESSAGE 'Falta campo MAIL_ENVIADO/ENVIADO_MAIL/MAIL_SENT en ZTMM_CARGAS_MDA (se enviará sin control de reenvío)' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

  IF lv_mail_flag IS NOT INITIAL.
    LOOP AT lt_orders INTO lv_ebeln.
      CLEAR lv_mail_sent.
      PERFORM is_mail_sent_for_ebeln_9300 USING lv_ebeln lv_mail_flag CHANGING lv_mail_sent.
      IF lv_mail_sent = 'X'.
        CONCATENATE 'El pedido' lv_ebeln 'ya fue enviado por correo' INTO lv_log_msg SEPARATED BY space.
        MESSAGE lv_log_msg TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDIF.

  IF lv_default_mail IS INITIAL.
    MESSAGE 'No hay email maestro. Introduce destinatario manualmente en el popup' TYPE 'S'.
  ENDIF.

  PERFORM popup_mail_receivers_9300 USING lv_default_mail CHANGING lt_receivers lv_cancel.
  IF lv_cancel = 'X' OR lt_receivers IS INITIAL.
    RETURN.
  ENDIF.

  REFRESH lt_csv_lines.
  APPEND 'Proveedor;Numero de pedido;Posicion;Material;Cantidad;Fichero cargado;Fecha de carga' TO lt_csv_lines.

  CLEAR lv_orders_txt.
  LOOP AT lt_orders INTO lv_ebeln.
    IF lv_orders_txt IS INITIAL.
      lv_orders_txt = lv_ebeln.
    ELSE.
      CONCATENATE lv_orders_txt lv_ebeln INTO lv_orders_txt SEPARATED BY ', '.
    ENDIF.

    LOOP AT gt_flow INTO ls_csv_flow WHERE ebeln = lv_ebeln.
      CLEAR: lv_qty_txt, lv_fecha_txt, lv_csv_line.
      WRITE ls_csv_flow-menge TO lv_qty_txt.
      CONDENSE lv_qty_txt.
      WRITE ls_csv_flow-fecha_carga TO lv_fecha_txt.

      CONCATENATE ls_csv_flow-lifnr
                  ls_csv_flow-ebeln
                  ls_csv_flow-ebelp
                  ls_csv_flow-matnr
                  lv_qty_txt
                  ls_csv_flow-nombre_fich
                  lv_fecha_txt
        INTO lv_csv_line SEPARATED BY ';'.
      APPEND lv_csv_line TO lt_csv_lines.
    ENDLOOP.
  ENDLOOP.

  CLEAR lv_csv_full.
  LOOP AT lt_csv_lines INTO lv_csv_line.
    IF lv_csv_full IS INITIAL.
      lv_csv_full = lv_csv_line.
    ELSE.
      CONCATENATE lv_csv_full cl_abap_char_utilities=>cr_lf lv_csv_line INTO lv_csv_full.
    ENDIF.
  ENDLOOP.

  CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
    EXPORTING
      text   = lv_csv_full
    IMPORTING
      buffer = lv_csv_xstring
    EXCEPTIONS
      OTHERS = 1.
  IF sy-subrc <> 0.
    MESSAGE 'No se pudo convertir el CSV para adjuntar' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " BOM UTF-8 para que Excel interprete correctamente tildes y eñes
  CONCATENATE lv_bom_utf8 lv_csv_xstring INTO lv_csv_xstring IN BYTE MODE.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer     = lv_csv_xstring
    TABLES
      binary_tab = lt_csv_hex
    EXCEPTIONS
      OTHERS     = 1.
  IF sy-subrc <> 0.
    MESSAGE 'No se pudo preparar adjunto CSV' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  REFRESH lt_message_body.
  APPEND 'Estimado proveedor,' TO lt_message_body.
  APPEND space TO lt_message_body.
  CLEAR lv_body_line.
  CONCATENATE 'Por el presente correo se le informa de los pedidos' lv_orders_txt
    'con los datos adjuntos en el mail.' INTO lv_body_line SEPARATED BY space.
  APPEND lv_body_line TO lt_message_body.
  APPEND space TO lt_message_body.
  APPEND 'Reciba un cordial saludo.' TO lt_message_body.

  TRY.
      lo_send_request = cl_bcs=>create_persistent( ).
      lo_document = cl_document_bcs=>create_document(
                      i_type    = 'RAW'
                      i_text    = lt_message_body
                      i_subject = lv_subject ).

      lo_document->add_attachment(
        EXPORTING
          i_attachment_type    = 'CSV'
          i_attachment_subject = 'Listado_ALV_9300'
          i_att_content_hex    = lt_csv_hex ).

      lo_send_request->set_document( lo_document ).

      lo_sender = cl_sapuser_bcs=>create( sy-uname ).
      lo_send_request->set_sender( lo_sender ).

      LOOP AT lt_receivers INTO ls_receiver.
        lo_recipient = cl_cam_address_bcs=>create_internet_address( ls_receiver ).
        lo_send_request->add_recipient(
          EXPORTING
            i_recipient = lo_recipient
            i_express   = 'X' ).
      ENDLOOP.

      lo_send_request->send(
        EXPORTING
          i_with_error_screen = 'X'
        RECEIVING
          result              = lv_sent_to_all ).
    CATCH cx_document_bcs.
      MESSAGE 'Error creando documento de correo' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    CATCH cx_bcs.
      MESSAGE 'Error técnico enviando correo' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  COMMIT WORK.

  IF lv_mail_flag IS NOT INITIAL.
    LOOP AT lt_orders INTO lv_ebeln.
      PERFORM mark_mail_sent_for_ebeln_9300 USING lv_ebeln lv_mail_flag.
    ENDLOOP.
  ENDIF.
  COMMIT WORK.

  CLEAR lv_log_msg.
  CONCATENATE 'Correo generado para pedidos:' lv_orders_txt INTO lv_log_msg SEPARATED BY space.
  PERFORM add_log USING lv_id_carga_log lv_id_linea_log 'S' lv_log_msg.

  IF go_grid_9300 IS BOUND.
    PERFORM get_data_9300.
    CALL METHOD go_grid_9300->refresh_table_display.
  ENDIF.

  MESSAGE 'Correo enviado (revisar SOST: en desarrollo puede quedar en espera)' TYPE 'S'.
ENDFORM.

FORM get_po_mail_9300 USING iv_ebeln TYPE ebeln
                      CHANGING cv_mail TYPE adr6-smtp_addr.
  CLEAR cv_mail.

  IF iv_ebeln IS INITIAL.
    RETURN.
  ENDIF.

  SELECT SINGLE ad~smtp_addr
    INTO @cv_mail
    FROM ekko AS h
    INNER JOIN adr6 AS ad
      ON ad~addrnumber = h~adrnr
    WHERE h~ebeln = @iv_ebeln
      AND ad~smtp_addr <> @space.
ENDFORM.

FORM get_supplier_mail_9300 USING iv_lifnr TYPE lifnr
                            CHANGING cv_mail TYPE adr6-smtp_addr.
  CLEAR cv_mail.

  IF iv_lifnr IS INITIAL.
    RETURN.
  ENDIF.

  SELECT SINGLE ad~smtp_addr
    INTO @cv_mail
    FROM lfa1 AS l
    INNER JOIN adr6 AS ad
      ON ad~addrnumber = l~adrnr
    WHERE l~lifnr = @iv_lifnr
      AND ad~flgdefault = 'X'
      AND ad~smtp_addr <> @space.

  IF sy-subrc <> 0 OR cv_mail IS INITIAL.
    SELECT SINGLE ad~smtp_addr
      INTO @cv_mail
      FROM lfa1 AS l
      INNER JOIN adr6 AS ad
        ON ad~addrnumber = l~adrnr
      WHERE l~lifnr = @iv_lifnr
        AND ad~smtp_addr <> @space.
  ENDIF.
ENDFORM.

FORM popup_mail_receivers_9300 USING iv_default_mail TYPE adr6-smtp_addr
                               CHANGING ct_receivers TYPE tt_mail_recipients
                                        cv_cancel TYPE c.
  DATA: lt_fields TYPE TABLE OF sval,
        ls_field  TYPE sval,
        lv_mail   TYPE adr6-smtp_addr.

  cv_cancel = space.
  REFRESH ct_receivers.
  REFRESH lt_fields.

  CLEAR ls_field.
  ls_field-tabname   = 'ADR6'.
  ls_field-fieldname = 'SMTP_ADDR'.
  ls_field-value     = iv_default_mail.
  APPEND ls_field TO lt_fields.

  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING
      popup_title = 'Destinatarios (separar varios con ; o ,)'
    TABLES
      fields      = lt_fields
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc <> 0.
    MESSAGE 'No se pudo abrir popup de destinatarios' TYPE 'S' DISPLAY LIKE 'E'.
    cv_cancel = 'X'.
    RETURN.
  ENDIF.

  LOOP AT lt_fields INTO ls_field.
    lv_mail = ls_field-value.
    PERFORM append_mail_tokens_9300 USING lv_mail CHANGING ct_receivers.
  ENDLOOP.

  SORT ct_receivers.
  DELETE ADJACENT DUPLICATES FROM ct_receivers.

  IF ct_receivers IS INITIAL.
    MESSAGE 'Debes indicar al menos un email válido' TYPE 'S' DISPLAY LIKE 'E'.
    cv_cancel = 'X'.
  ENDIF.
ENDFORM.

FORM append_mail_tokens_9300 USING iv_mail_text TYPE adr6-smtp_addr
                             CHANGING ct_receivers TYPE tt_mail_recipients.
  DATA: lv_text      TYPE string,
        lv_token     TYPE string,
        lt_tokens    TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
        lv_mail      TYPE adr6-smtp_addr,
        lv_valid     TYPE c.

  IF iv_mail_text IS INITIAL.
    RETURN.
  ENDIF.

  lv_text = iv_mail_text.
  REPLACE ALL OCCURRENCES OF ',' IN lv_text WITH ';'.
  SPLIT lv_text AT ';' INTO TABLE lt_tokens.

  LOOP AT lt_tokens INTO lv_token.
    lv_mail = lv_token.
    CONDENSE lv_mail NO-GAPS.
    IF lv_mail IS INITIAL.
      CONTINUE.
    ENDIF.

    CLEAR lv_valid.
    PERFORM is_valid_mail_9300 USING lv_mail CHANGING lv_valid.
    IF lv_valid = 'X'.
      APPEND lv_mail TO ct_receivers.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM is_valid_mail_9300 USING iv_mail TYPE adr6-smtp_addr
                        CHANGING cv_valid TYPE c.
  cv_valid = space.
  IF iv_mail CS '@' AND iv_mail CS '.'.
    cv_valid = 'X'.
  ENDIF.
ENDFORM.

FORM get_mail_flag_component_9300 CHANGING cv_component TYPE ty_fieldname30.
  DATA ls_carga TYPE ztmm_cargas_mda.
  FIELD-SYMBOLS <fs_mail> TYPE any.

  CLEAR cv_component.

  SELECT SINGLE * INTO ls_carga
    FROM ztmm_cargas_mda
    WHERE ebeln <> space.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  ASSIGN COMPONENT 'MAIL_ENVIADO' OF STRUCTURE ls_carga TO <fs_mail>.
  IF sy-subrc = 0.
    cv_component = 'MAIL_ENVIADO'.
    RETURN.
  ENDIF.

  ASSIGN COMPONENT 'ENVIADO_MAIL' OF STRUCTURE ls_carga TO <fs_mail>.
  IF sy-subrc = 0.
    cv_component = 'ENVIADO_MAIL'.
    RETURN.
  ENDIF.

  ASSIGN COMPONENT 'MAIL_SENT' OF STRUCTURE ls_carga TO <fs_mail>.
  IF sy-subrc = 0.
    cv_component = 'MAIL_SENT'.
  ENDIF.
ENDFORM.

FORM is_mail_sent_for_ebeln_9300 USING iv_ebeln TYPE ebeln
                                       iv_mail_component TYPE ty_fieldname30
                                 CHANGING cv_sent TYPE c.
  DATA: lt_cargas TYPE STANDARD TABLE OF ztmm_cargas_mda WITH DEFAULT KEY,
        ls_carga  TYPE ztmm_cargas_mda.
  FIELD-SYMBOLS <fs_mail> TYPE any.

  cv_sent = space.
  REFRESH lt_cargas.

  SELECT *
    INTO TABLE lt_cargas
    FROM ztmm_cargas_mda
    WHERE ebeln = iv_ebeln.

  LOOP AT lt_cargas INTO ls_carga.
    ASSIGN COMPONENT iv_mail_component OF STRUCTURE ls_carga TO <fs_mail>.
    IF sy-subrc = 0 AND <fs_mail> = 'X'.
      cv_sent = 'X'.
      EXIT.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM mark_mail_sent_for_ebeln_9300 USING iv_ebeln TYPE ebeln
                                         iv_mail_component TYPE ty_fieldname30.
  DATA: lt_cargas TYPE STANDARD TABLE OF ztmm_cargas_mda WITH DEFAULT KEY,
        ls_carga  TYPE ztmm_cargas_mda.
  FIELD-SYMBOLS <fs_mail> TYPE any.

  REFRESH lt_cargas.
  SELECT *
    INTO TABLE lt_cargas
    FROM ztmm_cargas_mda
    WHERE ebeln = iv_ebeln.

  LOOP AT lt_cargas INTO ls_carga.
    ASSIGN COMPONENT iv_mail_component OF STRUCTURE ls_carga TO <fs_mail>.
    IF sy-subrc = 0.
      <fs_mail> = 'X'.
      MODIFY ztmm_cargas_mda FROM ls_carga.
    ENDIF.
  ENDLOOP.
ENDFORM.
