*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_FORM_9200
*&---------------------------------------------------------------------*

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
