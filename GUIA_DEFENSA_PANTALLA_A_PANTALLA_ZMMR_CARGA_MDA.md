# GUIA DE DEFENSA POR PANTALLAS - `ZMMR_CARGA_MDA`

Objetivo de esta guia: que puedas responder rapido "de donde sale esto", "donde esta en codigo" y "como funciona" siguiendo la misma estructura por pantalla.

Estado tecnico documentado: arquitectura actual con un solo include funcional (`ZMMR_CARGA_MDA_FORM`) y logging unificado en SLG1/BAL.

---

## 1) PAGINA PRINCIPAL Y BLOQUE COMPARTIDO

## 1.1 Donde esta en codigo (ruta rapida)

- Programa: `ZMMR_CARGA_MDA.abap`
  - `REPORT zmmr_carga_mda.`
  - Includes: `top`, `screen`, `class`, `module`, `form`
- Globales: `ZMMR_CARGA_MDA_TOP.abap`
- Eventos ALV: `ZMMR_CARGA_MDA_CLASS.abap`
- PBO/PAI: `ZMMR_CARGA_MDA_MODULE.abap`
- Reglas de negocio: `ZMMR_CARGA_MDA_FORM.abap`

## 1.2 Tablas (y objetos) compartidos mas importantes

### Tablas Z
- `ZTMM_CARGAS_MDA` (tabla principal del flujo)
- `ZTMM_POTXT_MDA` (comentarios por linea)
- `ZTMM_CFGPO_MDA` (configuracion activa para crear PO)
- `ZEMM_FLUJO_MDA` (estructura de salida de ALV 9300)

### Tablas estandar usadas en varios puntos
- `LFA1`, `LFM1`, `LFBK`, `BNKA`
- `MARA`, `MARC`
- `EINA`, `EINE`
- `EKKO`, `EKPO`
- `ADR6`, `ADRC`, `T001`

### Objetos tecnicos compartidos
- Rangos: `gc_obj_carga`, `gc_obj_linea` (SNRO via `NUMBER_GET_NEXT`)
- Logging: `gc_bal_obj = ZMML_MDA`, `gc_bal_sub = PROCESO`
- Lock object: `EZTMM_POTXT_MDA`

## 1.3 Funciones/metodos compartidos y que hacen

### Utilidad
- `lcl_util=>to_lower` (Include `..._CLASS`): normaliza texto para validaciones.

### Logging unificado (SLG/BAL)
- `FORM add_log`
- `FORM bal_init`
- `FORM bal_add_message`
- `FORM bal_save`
- `FORM display_slg_log` (abre `SLG1`)

### Navegacion a transacciones
- `FORM nav_me23n`
- `FORM nav_mm03_purch`

## 1.4 Como funciona el programa a alto nivel

1. Ejecutas report y entras a pantalla 9000.
2. Desde 9000 navegas a:
   - 9100 (carga)
   - 9200 (generador PO)
   - 9300 (flujo completo)
   - boton log (`SLG1`)
3. Toda la trazabilidad se guarda por BAL y se consulta en SLG1.

---

## 2) PANTALLA 9000 - MENU PRINCIPAL

## 2.1 Donde esta

Include: `ZMMR_CARGA_MDA_MODULE.abap`

- `MODULE status_9000 OUTPUT.`
- `MODULE user_command_9000 INPUT.`

## 2.2 Tablas que usa

No consulta tablas directamente. Orquesta navegacion y refrescos.

## 2.3 Funciones/rutinas relacionadas

- `popup_filtros_9300` (antes de entrar a 9300)
- `get_data_9300` + refresh grid (si 9300 ya esta instanciado)
- `display_slg_log` (boton de log)

## 2.4 Como funciona

- Define status y titlebar.
- Controla `gv_subscr` para mostrar 9100/9200/9300.
- Comandos:
  - `BTN1` -> 9100
  - `BTN2` -> 9200
  - `BTN3` -> filtros + 9300
  - `BTN4` -> SLG1

---

## 3) PANTALLA 9100 - CARGA DE ARCHIVO

## 3.1 Donde esta

Include `ZMMR_CARGA_MDA_MODULE.abap`:
- `MODULE user_command_9100 INPUT.`

Include `ZMMR_CARGA_MDA_FORM.abap`:
- `FORM f4_file`
- `FORM run`
- `FORM validate_file`
- `FORM upload_file`
- `FORM process_lines`
- `FORM validate_business_line`

## 3.2 Tablas que usa (y para que)

- `ZTMM_CARGAS_MDA`: insert de lineas de carga.
- `ZTMM_CFGPO_MDA`: leer configuracion activa.
- `LFA1`, `MARA`: validar proveedor/material.
- `LFM1`, `MARC`: validar extension de proveedor/material en org/centro.
- `EINA`, `EINE`: validar info record de compras.

## 3.3 Funciones principales

- `cl_gui_frontend_services=>file_open_dialog` (seleccion archivo)
- `cl_gui_frontend_services=>gui_upload` (subida a `gt_raw`)
- `CONVERT_DATE_TO_INTERNAL`
- `CONVERSION_EXIT_ALPHA_INPUT`
- `CONVERSION_EXIT_MATN1_INPUT`
- `NUMBER_GET_NEXT`
- logging via `add_log` (BAL)

## 3.4 Flujo funcional exacto

`LOAD` -> `run`:

1. valida nombre/ext del archivo.
2. sube contenido TXT.
3. genera id de carga.
4. procesa linea por linea:
   - parsea
   - convierte cantidad/fecha
   - valida negocio
   - inserta en `ZTMM_CARGAS_MDA`
5. genera log final OK/ERR.

---

## 4) PANTALLA 9200 - GENERADOR DE PEDIDOS

## 4.1 Donde esta

Include `ZMMR_CARGA_MDA_MODULE.abap`:
- `MODULE pbo_9200 OUTPUT.` -> `alv_9200_init`

Include `ZMMR_CARGA_MDA_CLASS.abap`:
- `lcl_evt_9200`:
  - `handle_toolbar`
  - `handle_user_command`
  - `handle_double_click`
  - `handle_data_changed`

Include `ZMMR_CARGA_MDA_FORM.abap`:
- `alv_9200_init`, `get_data_generador`, `build_fcat_9200`
- `open_edit_mode`, `save_gen_changes`, `close_edit_mode`
- `generate_po_selected`, `create_po_group`
- `save_po_text`, `get_cfg_po`
- `nav_me23n`, `nav_mm03_purch`

## 4.2 Tablas que usa

- `ZTMM_CARGAS_MDA` (lectura y actualizacion)
- `ZTMM_POTXT_MDA` (lectura/upsert comentarios)
- `ZTMM_CFGPO_MDA` (config para crear PO)

## 4.3 Funciones/APIs usadas

- `ENQUEUE_EZTMM_POTXT_MDA` / `DEQUEUE_EZTMM_POTXT_MDA`
- `BAPI_PO_CREATE1`
- `BAPI_TRANSACTION_COMMIT`
- `BAPI_TRANSACTION_ROLLBACK`
- `SAVE_TEXT`
- `CONVERSION_EXIT_ALPHA_INPUT`

## 4.4 Como funciona la pantalla

1. Inicializa ALV con eventos y catalogo.
2. Carga datos de carga + comentario + estado visual.
3. Permite editar solo filas bloqueadas y no generadas.
4. Guarda cambios en tablas Z.
5. Permite navegacion por doble click:
   - `EBELN` -> ME23N
   - `MATERIAL` -> MM03

## 4.5 Como se crea el pedido (respuesta completa de defensa)

Entrada: `FORM generate_po_selected`

1. valida que no existan cambios pendientes sin guardar.
2. toma filas seleccionadas y quita las ya generadas.
3. agrupa por `proveedor + fecha_doc + comentario`.
4. por cada grupo llama `create_po_group`.

Dentro de `create_po_group`:

1. lee configuracion activa (`get_cfg_po`) desde `ZTMM_CFGPO_MDA`.
2. agrega cantidades por material (`lt_agg`).
3. arma estructuras BAPI:
   - `bapimepoheader/headerx`
   - `bapimepoitem/itemx`
   - `bapimeposchedule/schedulex`
4. ejecuta `BAPI_PO_CREATE1`.
5. si hay errores:
   - analiza `RETURN`
   - rollback
   - log de error
6. si OK:
   - commit
   - update `ZTMM_CARGAS_MDA` con `EBELN/EBELP/PEDIDO_GEN`
   - guarda texto de posicion (`SAVE_TEXT`) si hay comentario
   - log de exito

---

## 5) PANTALLA 9300 - FLUJO COMPLETO, BANCO, FORMULARIO, MAIL

## 5.1 Donde esta

Include `ZMMR_CARGA_MDA_MODULE.abap`:
- `MODULE pbo_9300 OUTPUT.` -> `alv_9300_init`

Include `ZMMR_CARGA_MDA_CLASS.abap`:
- `lcl_evt_9300`:
  - `handle_toolbar`
  - `handle_user_command`
  - `handle_double_click`

Include `ZMMR_CARGA_MDA_FORM.abap`:
- `get_data_9300`, `alv_9300_init`, `popup_filtros_9300`
- `show_bank_popup_9300`
- `print_form_9300`
- `send_mail_csv_9300` y forms de apoyo de mail

## 5.2 Tablas que usa

### Flujo principal
- base `ZTMM_CARGAS_MDA`
- joins `EKKO`, `EKPO`, `LFA1`, `ADR6`, `MARA`, `EINA`, `EINE`

### Banco
- `LFM1`, `LFBK`, `BNKA`

### Formulario
- `EKKO`, `EKPO`, `LFA1`, `ADRC`, `T001`, `ZTMM_CARGAS_MDA`

### Correo
- `ADR6` (mail pedido/proveedor)
- `ZTMM_CARGAS_MDA` (flag de envio si existe campo)

## 5.3 Funciones/APIs usadas

- `LVC_FIELDCATALOG_MERGE`
- `POPUP_GET_VALUES`
- `FP_FUNCTION_MODULE_NAME`, `FP_JOB_OPEN`, `FP_JOB_CLOSE`
- `SCMS_STRING_TO_XSTRING`, `SCMS_XSTRING_TO_BINARY`
- `CL_BCS`, `CL_DOCUMENT_BCS`, `CL_CAM_ADDRESS_BCS`
- `CL_SALV_TABLE`

## 5.4 Como funciona la pantalla

1. aplica filtros opcionales.
2. construye ALV de flujo desde joins de pedido/carga/maestro.
3. doble click de navegacion:
   - `EBELN` -> ME23N
   - `MATNR` -> MM03
4. botones toolbar:
   - `ZBANK`: popup datos bancarios
   - `ZFORMV` / `ZFORMP`: Adobe preview/print
   - `ZMAIL`: envio CSV por correo

## 5.5 Logica de mail (punto que suelen preguntar)

En `get_data_9300`:
- tipos locales `ty_mail_map`, `ty_po_mail`
- tablas internas `lt_mail_map`, `lt_po_mail`

Se usan para evitar consultas por cada fila:
1. primer intento: mail por pedido (`lt_po_mail`)
2. fallback: mail por proveedor (`lt_mail_map`)
3. luego se calcula estado de envio.

En `send_mail_csv_9300`:
1. valida seleccion y mismo proveedor.
2. verifica no reenvio (si existe componente de flag).
3. solicita destinatarios.
4. arma CSV, agrega BOM UTF-8, adjunta y envia.
5. marca enviados y registra log.

---

## 6) LOGGING (SIN VIA LEGACY) - SLG1/BAL

## 6.1 Donde esta

Include `ZMMR_CARGA_MDA_FORM.abap`:
- `FORM add_log`
- `FORM bal_init`
- `FORM bal_add_message`
- `FORM bal_save`
- `FORM display_slg_log`

Include `ZMMR_CARGA_MDA_MODULE.abap`:
- `BTN4` en `user_command_9000` llama `display_slg_log`

## 6.2 Como funciona

1. `add_log` recibe mensaje y severidad.
2. `bal_init` crea/recupera handle BAL.
3. `bal_add_message` agrega mensaje al log.
4. `bal_save` persiste.
5. `display_slg_log` guarda y abre `SLG1`.

Nota: el camino antiguo basado en tabla custom de log fue retirado del flujo activo.

---

## 7) INDICE RAPIDO POR PANTALLA (CTRL+F)

## 9000
- `status_9000`
- `user_command_9000`

## 9100
- `user_command_9100`
- `run`
- `process_lines`
- `validate_business_line`

## 9200
- `alv_9200_init`
- `get_data_generador`
- `open_edit_mode`
- `save_gen_changes`
- `generate_po_selected`
- `create_po_group`

## 9300
- `alv_9300_init`
- `get_data_9300`
- `popup_filtros_9300`
- `show_bank_popup_9300`
- `print_form_9300`
- `send_mail_csv_9300`

## Log/SLG
- `add_log`
- `bal_add_message`
- `display_slg_log`

---

## 8) RESPUESTAS CORTAS PARA DEFENDER RAPIDO

## "De donde sale este campo en 9300?"
- De `FORM get_data_9300`, join principal desde `ZTMM_CARGAS_MDA` con `EKKO/EKPO` y maestros.

## "Como se crea el PO exactamente?"
- `generate_po_selected` agrupa seleccion, `create_po_group` arma payload y llama `BAPI_PO_CREATE1`, luego commit/rollback y update de tablas Z.

## "Como garantizas concurrencia en edicion?"
- Lock por fila con `ENQUEUE_EZTMM_POTXT_MDA` y liberacion con `DEQUEUE_EZTMM_POTXT_MDA`.

## "Donde veo trazabilidad?"
- En `SLG1`, porque el log va por BAL (`BAL_LOG_CREATE`, `BAL_LOG_MSG_ADD`, `BAL_DB_SAVE`).

## "Como decides email destino?"
- Primero por pedido (`get_po_mail_9300`), fallback a proveedor (`get_supplier_mail_9300`), y validacion en `is_valid_mail_9300`.

