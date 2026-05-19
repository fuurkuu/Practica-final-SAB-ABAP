*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_TOP
*&---------------------------------------------------------------------*
TYPE-POOLS: icon, lvc.

CLASS lcl_evt_9200 DEFINITION DEFERRED.
CLASS lcl_evt_9300 DEFINITION DEFERRED.

TYPES: ty_raw_line TYPE c LENGTH 1024.
TYPES ty_fieldname30 TYPE c LENGTH 30.
TYPES tt_mail_recipients TYPE STANDARD TABLE OF adr6-smtp_addr WITH DEFAULT KEY.

CONSTANTS: gc_obj_carga TYPE inri-object    VALUE 'ZMMCAR_MDA',
           gc_obj_linea TYPE inri-object    VALUE 'ZMMLIN_MDA',
           gc_bal_obj   TYPE balobj_d       VALUE 'ZMML_MDA',
           gc_bal_sub   TYPE balsubobj      VALUE 'PROCESO',
           gc_nr_range  TYPE inri-nrrangenr VALUE '01',
           gc_unidad    TYPE meins          VALUE 'ST'.

DATA: ok_code   TYPE sy-ucomm,
      save_ok   TYPE sy-ucomm,
      gv_subscr TYPE sy-dynnr VALUE '9100',
      gv_file   TYPE rlgrap-filename.

DATA: gt_raw      TYPE STANDARD TABLE OF ty_raw_line WITH DEFAULT KEY,
      gv_id_carga TYPE ztmm_cargas_mda-id_carga,
      gv_ok       TYPE i,
      gv_err      TYPE i.

DATA: gv_bal_log_handle TYPE balloghndl,
      gv_bal_extnumber  TYPE balnrext,
      gt_bal_log_handle TYPE bal_t_logh.

TYPES: BEGIN OF ty_gen,
         estado     TYPE icon_d,
         id_carga   TYPE ztmm_cargas_mda-id_carga,
         id_linea   TYPE ztmm_cargas_mda-id_linea,
         proveedor  TYPE ztmm_cargas_mda-proveedor,
         material   TYPE ztmm_cargas_mda-material,
         cantidad   TYPE ztmm_cargas_mda-cantidad,
         unidad     TYPE ztmm_cargas_mda-unidad,
         fecha_doc  TYPE ztmm_cargas_mda-fecha_doc,
         ebeln      TYPE ztmm_cargas_mda-ebeln,
         ebelp      TYPE ztmm_cargas_mda-ebelp,
         pedido_gen TYPE ztmm_cargas_mda-pedido_gen,
         comentario TYPE ztmm_potxt_mda-comentario,
         celltab    TYPE lvc_t_styl,
       END OF ty_gen.

TYPES tt_gen TYPE STANDARD TABLE OF ty_gen WITH DEFAULT KEY.

TYPES: BEGIN OF ty_lock,
         id_carga TYPE ztmm_potxt_mda-id_carga,
         id_linea TYPE ztmm_potxt_mda-id_linea,
       END OF ty_lock.

TYPES: BEGIN OF ty_agg,
         material TYPE ztmm_cargas_mda-material,
         cantidad TYPE ztmm_cargas_mda-cantidad,
         unidad   TYPE ztmm_cargas_mda-unidad,
         po_item  TYPE ebelp,
       END OF ty_agg.

DATA: gt_gen     TYPE tt_gen,
      gt_gen_old TYPE tt_gen,
      gs_gen     TYPE ty_gen.

DATA: gt_locks TYPE STANDARD TABLE OF ty_lock WITH DEFAULT KEY.

DATA: go_cont_9200 TYPE REF TO cl_gui_custom_container,
      go_grid_9200 TYPE REF TO cl_gui_alv_grid,
      gt_fcat_9200 TYPE lvc_t_fcat,
      gs_layo_9200 TYPE lvc_s_layo,
      gv_alv_9200  TYPE c LENGTH 1.
DATA go_evt_9200 TYPE REF TO lcl_evt_9200.

DATA: gt_flow TYPE STANDARD TABLE OF zemm_flujo_mda WITH DEFAULT KEY,
      gs_flow TYPE zemm_flujo_mda.

DATA: go_cont_9300 TYPE REF TO cl_gui_custom_container,
      go_grid_9300 TYPE REF TO cl_gui_alv_grid,
      gt_fcat_9300 TYPE lvc_t_fcat,
      gs_layo_9300 TYPE lvc_s_layo.

DATA: gv_9300_need_popup TYPE c VALUE 'X',
      gv_f_ebeln         TYPE ebeln,
      gv_f_aedat         TYPE aedat,
      gv_f_fecha_carga   TYPE ztmm_cargas_mda-fecha_carga,
      gv_f_id_carga      TYPE ztmm_cargas_mda-id_carga.

DATA go_evt_9300 TYPE REF TO lcl_evt_9300.

TYPES: BEGIN OF ty_bank_popup,
         lifnr    TYPE lifnr,
         ekorg    TYPE ekorg,
         zterm    TYPE dzterm,
         inco1    TYPE inco1,
         banco    TYPE bnka-banka,
         banks    TYPE banks,
         bankn    TYPE bankn,
       END OF ty_bank_popup.

DATA gt_bank_popup TYPE STANDARD TABLE OF ty_bank_popup WITH DEFAULT KEY.
