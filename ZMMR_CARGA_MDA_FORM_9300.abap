*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_FORM_9300
*&---------------------------------------------------------------------*

*---------------------------------------------------------------------*
* 9300 - Flujo completo + correo
*---------------------------------------------------------------------*
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
        <fs_fcat>-emphasize = 'C510'.
      WHEN 'MATNR'.
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

FORM handle_ic1_9300.
  DATA: ls_row_id TYPE lvc_s_row,
        ls_col_id TYPE lvc_s_col,
        ls_flow   TYPE zemm_flujo_mda.

  IF go_grid_9300 IS NOT BOUND.
    RETURN.
  ENDIF.

  CALL METHOD go_grid_9300->get_current_cell
    IMPORTING
      es_row_id = ls_row_id
      es_col_id = ls_col_id.

  IF ls_row_id-index IS INITIAL.
    RETURN.
  ENDIF.

  READ TABLE gt_flow INTO ls_flow INDEX ls_row_id-index.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  CASE ls_col_id-fieldname.
    WHEN 'EBELN'.
      IF ls_flow-ebeln IS NOT INITIAL.
        PERFORM nav_me23n USING ls_flow-ebeln.
      ENDIF.
    WHEN 'MATNR'.
      IF ls_flow-matnr IS NOT INITIAL.
        PERFORM nav_mm03_purch USING ls_flow-matnr.
      ENDIF.
  ENDCASE.
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
