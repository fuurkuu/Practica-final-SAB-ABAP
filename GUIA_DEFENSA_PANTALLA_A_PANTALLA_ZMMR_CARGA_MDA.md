# GUIA DE DEFENSA PANTALLA A PANTALLA - `ZMMR_CARGA_MDA`

Documento pensado para defensa tecnica/funcional ante revision senior.
Esta guia esta alineada con el estado actual del repo (arquitectura con un solo include de forms: `ZMMR_CARGA_MDA_FORM`).

---

## 0) MAPA RAPIDO PARA BUSCAR CON `CTRL+F`

## Programa principal
- Include: `ZMMR_CARGA_MDA.abap`
- Buscar:
  - `REPORT zmmr_carga_mda.`
  - `INCLUDE zmmr_carga_mda_top.`
  - `INCLUDE zmmr_carga_mda_form.`

## Globales y tipos
- Include: `ZMMR_CARGA_MDA_TOP.abap`
- Buscar:
  - `CONSTANTS: gc_obj_carga`
  - `DATA: gt_gen`
  - `DATA: gt_flow`
  - `DATA: go_grid_9200`
  - `DATA: go_grid_9300`

## PBO/PAI de pantallas
- Include: `ZMMR_CARGA_MDA_MODULE.abap`
- Buscar:
  - `MODULE status_9000 OUTPUT.`
  - `MODULE user_command_9000 INPUT.`
  - `MODULE user_command_9100 INPUT.`
  - `MODULE pbo_9200 OUTPUT.`
  - `MODULE pbo_9300 OUTPUT.`
  - `MODULE pbo_9400 OUTPUT.`

## Clases de eventos ALV
- Include: `ZMMR_CARGA_MDA_CLASS.abap`
- Buscar:
  - `CLASS lcl_evt_9200`
  - `CLASS lcl_evt_9300`
  - `METHOD handle_toolbar.`
  - `METHOD handle_user_command.`
  - `METHOD handle_double_click.`
  - `METHOD handle_data_changed.`

## Logica funcional (todos los FORMs)
- Include: `ZMMR_CARGA_MDA_FORM.abap`
- Buscar:
  - `FORM run`
  - `FORM process_lines`
  - `FORM validate_business_line`
  - `FORM generate_po_selected`
  - `FORM create_po_group`
  - `FORM get_data_9300`
  - `FORM send_mail_csv_9300`
  - `FORM print_form_9300`

---

## 1) ARQUITECTURA REAL DEL PROGRAMA

El programa esta separado por capas:

1. **TOP**: tipos, constantes, globales.
2. **CLASS**: eventos ALV y utilidades OO.
3. **MODULE**: transicion entre dynpros (PBO/PAI).
4. **FORM**: reglas de negocio (carga, PO, flujo, mail, log).

### Includes exactos (estado actual)

- `ZMMR_CARGA_MDA_TOP`
- `ZMMR_CARGA_MDA_SCREEN`
- `ZMMR_CARGA_MDA_CLASS`
- `ZMMR_CARGA_MDA_MODULE`
- `ZMMR_CARGA_MDA_FORM`

---

## 2) FLUJO GENERAL DE EJECUCION

1. Usuario ejecuta `ZMMR_CARGA_MDA`.
2. Entra a dynpro principal 9000.
3. Desde 9000 navega por botones:
   - 9100: carga de archivo
   - 9200: generador de pedidos
   - 9300: flujo completo + banco + Adobe + mail
   - 9400 / SLG1: log

Buscar para defender esto:
- `MODULE user_command_9000 INPUT.` en `ZMMR_CARGA_MDA_MODULE.abap`

---

## 3) PANTALLA 9000 (MENU PRINCIPAL)

## 3.1 Donde esta en codigo

- Include: `ZMMR_CARGA_MDA_MODULE.abap`
- Modulos:
  - `MODULE status_9000 OUTPUT.`
  - `MODULE user_command_9000 INPUT.`

## 3.2 Que hace

- Define `PF-STATUS` y `TITLEBAR`.
- Controla el subscreen activo (`gv_subscr`).
- Redirige por botones:
  - `BTN1` -> 9100
  - `BTN2` -> 9200
  - `BTN3` -> 9300 (abre filtros antes)
  - `BTN4` -> abre log (`display_slg_log`)

## 3.3 Como defenderla

Si te preguntan "como cambia de pantalla":
- Respuesta: en `user_command_9000`, cambiando `gv_subscr` y refrescando ALV cuando aplica.

---

## 4) PANTALLA 9100 (CARGA DE ARCHIVO)

## 4.1 Donde esta en codigo

- PAI:
  - `MODULE user_command_9100 INPUT.` (`ZMMR_CARGA_MDA_MODULE`)
- FORMs llamados:
  - `FORM f4_file` (abrir dialogo)
  - `FORM run` (proceso completo)

## 4.2 Flujo tecnico exacto

`LOAD` -> `run`:

1. `validate_file`
2. `upload_file`
3. `get_next_number` para ID de carga (`gc_obj_carga`)
4. `process_lines`
5. `add_log` + mensaje final

## 4.3 De donde salen los datos y validaciones

### Archivo local
- Lectura con `cl_gui_frontend_services=>gui_upload`
- Tabla interna: `gt_raw`

### Parseo de cada linea
- Se intenta separacion por TAB.
- Si no, fallback por espacios.

### Validacion de negocio por linea (`validate_business_line`)

Tablas consultadas:
- `LFA1` (proveedor existe)
- `MARA` (material existe)
- `ZTMM_CFGPO_MDA` (config activa)
- `LFM1` (proveedor extendido a EKORG)
- `MARC` (material extendido a WERKS)
- `EINA` + `EINE` (info record activo en EKORG)

### Persistencia final de la carga
- Insert en `ZTMM_CARGAS_MDA`

## 4.4 Logging

Cada error/exito de linea llama a:
- `add_log` -> `bal_add_message` -> `BAL_LOG_MSG_ADD` -> `BAL_DB_SAVE`

Objeto BAL:
- `gc_bal_obj = 'ZMML_MDA'`
- `gc_bal_sub = 'PROCESO'`

---

## 5) PANTALLA 9200 (ALV GENERADOR + CREACION DE PEDIDO)

Esta es la pantalla clave para defender "como se crea el pedido".

## 5.1 Donde esta en codigo

- PBO:
  - `MODULE pbo_9200 OUTPUT.` -> `PERFORM alv_9200_init`
- Include principal:
  - `ZMMR_CARGA_MDA_FORM.abap`
- Bloque de forms 9200:
  - Desde `FORM alv_9200_init` hasta `FORM nav_mm03_purch`
- Clase de eventos:
  - `CLASS lcl_evt_9200` en `ZMMR_CARGA_MDA_CLASS.abap`

## 5.2 Datos que muestra el ALV 9200

Form:
- `FORM get_data_generador`

Lee:
- `ZTMM_CARGAS_MDA`
- `ZTMM_POTXT_MDA` (comentario por linea)

Campos clave de salida:
- `ID_CARGA`, `ID_LINEA`, `PROVEEDOR`, `MATERIAL`, `CANTIDAD`, `FECHA_DOC`
- `EBELN`, `EBELP`, `PEDIDO_GEN`, `COMENTARIO`
- `ESTADO` (icono rojo/verde)

## 5.3 Edicion controlada

Toolbar 9200 (`handle_toolbar`):
- `ZEDIT`, `ZSAVE`, `ZCLOSE`, `ZGENPO`

Flujo:
- `open_edit_mode`:
  - obtiene filas seleccionadas
  - bloquea por lock object `EZTMM_POTXT_MDA` (`ENQUEUE_...`)
  - habilita input solo para campos permitidos
- `save_gen_changes`:
  - valida cambios
  - actualiza `ZTMM_CARGAS_MDA` (cantidad/fecha)
  - upsert de comentario en `ZTMM_POTXT_MDA`
- `close_edit_mode`:
  - libera locks (`DEQUEUE_...`)

## 5.4 Navegacion desde ALV 9200

Clase/method:
- `lcl_evt_9200->handle_double_click`

Reglas:
- columna `EBELN` -> `nav_me23n` -> `ME23N`
- columna `MATERIAL` -> `nav_mm03_purch` -> `MM03`

## 5.5 COMO SE CREA EL PEDIDO (detalle defendible)

## Paso A - Entrada

Form:
- `generate_po_selected`

Hace:
1. valida que no haya cambios pendientes (`has_pending_changes`)
2. toma filas seleccionadas (`get_selected_gen_rows`)
3. excluye ya generadas (`PEDIDO_GEN = 'X'`)
4. agrupa por:
   - `PROVEEDOR`
   - `FECHA_DOC`
   - `COMENTARIO`

## Paso B - Construccion del grupo

Form:
- `create_po_group`

Subpasos:
1. carga configuracion activa (`get_cfg_po`) desde `ZTMM_CFGPO_MDA`:
   - `BSART`, `EKORG`, `EKGRP`, `WERKS`, `MEINS`
2. agrega cantidades por material (`lt_agg`)
3. arma cabecera BAPI (`bapimepoheader`):
   - vendor, org compras, grupo compras, fecha doc
4. arma items/schedules:
   - `POITEM`, `POITEMX`, `POSCHEDULE`, `POSCHEDULEX`
5. llama a `BAPI_PO_CREATE1`
6. procesa retornos:
   - si error -> `BAPI_TRANSACTION_ROLLBACK` + log
   - si OK -> `BAPI_TRANSACTION_COMMIT`
7. actualiza `ZTMM_CARGAS_MDA`:
   - `EBELN`, `EBELP`, `PEDIDO_GEN = 'X'`
8. si hay comentario:
   - `save_po_text` (FM `SAVE_TEXT`, objeto `EKPO`, ID `F01`)

## Paso C - Trazabilidad

Durante todo el proceso se registran mensajes con:
- `add_log` / BAL (SLG1)

## 5.6 Tablas y objetos usados en 9200

### Z
- `ZTMM_CARGAS_MDA`
- `ZTMM_POTXT_MDA`
- `ZTMM_CFGPO_MDA`

### Estandar
- BAPI `BAPI_PO_CREATE1`
- `EKKO/EKPO` (indirectamente por creacion)
- `SAVE_TEXT` para texto de posicion

### Concurrencia
- `ENQUEUE_EZTMM_POTXT_MDA`
- `DEQUEUE_EZTMM_POTXT_MDA`

---

## 6) PANTALLA 9300 (FLUJO COMPLETO + DATOS BANCARIOS + FORM + MAIL)

## 6.1 Donde esta en codigo

- PBO:
  - `MODULE pbo_9300 OUTPUT.` -> `alv_9300_init`
- Clase eventos:
  - `lcl_evt_9300` en `ZMMR_CARGA_MDA_CLASS.abap`
- Forms clave:
  - `get_data_9300`
  - `popup_filtros_9300`
  - `show_bank_popup_9300`
  - `print_form_9300`
  - `send_mail_csv_9300`

## 6.2 Como se cargan los datos del flujo (fuente exacta)

Form:
- `get_data_9300`

Select principal (join grande):
- Base `ZTMM_CARGAS_MDA c`
- Join `EKKO h`
- Join `EKPO p`
- Left joins:
  - `LFA1 l`
  - `ADR6 ad`
  - `MARA m`
  - `EINA i`
  - `EINE e`
  - `LFA1 li` (proveedor info record)

Objetivo:
- construir `gt_flow` (estructura `ZEMM_FLUJO_MDA`) con datos de pedido, proveedor, material, carga y correo.

## 6.3 Logica de correos en get_data_9300

Dentro de `get_data_9300`:

Tipos locales:
- `ty_mail_map` (mail por proveedor)
- `ty_po_mail` (mail por pedido)

Tablas internas auxiliares:
- `lt_mail_map`
- `lt_po_mail`

Uso:
1. intenta mail por pedido (`lt_po_mail`)
2. fallback a mail por proveedor (`lt_mail_map`)
3. calcula icono mail enviado/no enviado

## 6.4 Navegacion ALV 9300

`lcl_evt_9300->handle_double_click`:
- `EBELN` -> `nav_me23n` (`ME23N`)
- `MATNR` -> `nav_mm03_purch` (`MM03`)

## 6.5 Popup de filtros

Form:
- `popup_filtros_9300`

Tecnica:
- FM `POPUP_GET_VALUES`

Filtros:
- `EKKO-EBELN`
- `EKKO-AEDAT`
- `ZTMM_CARGAS_MDA-FECHA_CARGA`
- `ZTMM_CARGAS_MDA-ID_CARGA`

## 6.6 Datos bancarios (boton ZBANK)

Form:
- `show_bank_popup_9300`

Tablas:
- `LFM1` (condiciones proveedor por org compras)
- `LFBK` (cuentas bancarias)
- `BNKA` (nombre banco)

UI:
- muestra popup SALV con `cl_salv_table`.

## 6.7 Adobe Form (botones ZFORMV / ZFORMP)

Form:
- `print_form_9300`

Flujo:
1. toma pedido seleccionado
2. carga cabecera/posiciones/datos contexto:
   - `EKKO`, `EKPO`, `LFA1`, `ADRC`, `T001`, `ZTMM_CARGAS_MDA`
3. obtiene FM de Adobe:
   - `FP_FUNCTION_MODULE_NAME` para `ZMMF_PEDIDO_MDA`
4. abre job:
   - `FP_JOB_OPEN`
5. llama FM generado
6. cierra job:
   - `FP_JOB_CLOSE`
7. en modo impresion (`P`) abre `SP01`

## 6.8 Envio de mail CSV (boton ZMAIL)

Form:
- `send_mail_csv_9300`

Resumen:
1. toma filas seleccionadas
2. exige un mismo proveedor en la seleccion
3. evita reenvio si flag de mail ya esta en `X` (si existe componente)
4. popup destinatarios:
   - `popup_mail_receivers_9300`
5. arma CSV de seleccion
6. convierte a binario:
   - `SCMS_STRING_TO_XSTRING`
   - agrega BOM UTF-8
   - `SCMS_XSTRING_TO_BINARY`
7. envia por `CL_BCS`
8. marca enviado:
   - `mark_mail_sent_for_ebeln_9300`
9. log + refresh ALV

Subforms de apoyo:
- `get_po_mail_9300`
- `get_supplier_mail_9300`
- `append_mail_tokens_9300`
- `is_valid_mail_9300`
- `get_mail_flag_component_9300`
- `is_mail_sent_for_ebeln_9300`
- `mark_mail_sent_for_ebeln_9300`

---

## 7) PANTALLA 9400 (LOG)

## 7.1 Donde esta en codigo

- PBO:
  - `MODULE pbo_9400 OUTPUT.` -> `alv_9400_init`
- Forms:
  - `get_data_9400`
  - `build_fcat_9400`
  - `alv_9400_init`

## 7.2 Fuente de datos

- Tabla `ZTMM_LOG_MDA` (log legacy)

### Nota importante de defensa

El log operativo oficial del proceso ya esta orientado a BAL/SLG1:
- `display_slg_log` abre `SLG1`
- `add_log` usa BAL (`BAL_LOG_*`, `BAL_DB_SAVE`)

Por eso puedes explicar:
- 9400 es vista de tabla custom historica
- SLG1 es la traza estandar actual.

---

## 8) CLASES Y EVENTOS (RESUMEN DEFENDIBLE)

Include:
- `ZMMR_CARGA_MDA_CLASS.abap`

## `lcl_util`
- `to_lower`: normalizacion para validacion de extension de archivo.

## `lcl_evt_9200`
- `handle_toolbar`: define botones de gestion en 9200.
- `handle_user_command`: enruta `ZEDIT/ZSAVE/ZCLOSE/ZGENPO`.
- `handle_double_click`: navegacion a `ME23N/MM03`.
- `handle_data_changed`: bloquea modificaciones invalidas.

## `lcl_evt_9300`
- `handle_toolbar`: define `ZBANK/ZFORMV/ZFORMP/ZMAIL`.
- `handle_user_command`: ejecuta esos forms.
- `handle_double_click`: navegacion a `ME23N/MM03`.

---

## 9) TABLAS, ESTRUCTURAS, RANGOS Y OBJETOS Z (QUE PEDIRAN EN DEFENSA)

## 9.1 Objetos Z de datos

- `ZTMM_CARGAS_MDA` (tabla core del flujo)
- `ZTMM_POTXT_MDA` (comentarios por linea)
- `ZTMM_CFGPO_MDA` (configuracion de compras)
- `ZTMM_LOG_MDA` (log legacy)
- `ZEMM_FLUJO_MDA` (estructura de salida 9300)

## 9.2 Objetos de numeracion y log

Definidos en `ZMMR_CARGA_MDA_TOP`:
- `gc_obj_carga = ZMMCAR_MDA`
- `gc_obj_linea = ZMMLIN_MDA`
- `gc_obj_log = ZMMLOG_MDA`
- `gc_nr_range = 01`
- `gc_bal_obj = ZMML_MDA`
- `gc_bal_sub = PROCESO`

## 9.3 Lock object

- `EZTMM_POTXT_MDA`
- usado en 9200 para edicion segura por fila.

## 9.4 Formulario

- `ZMMF_PEDIDO_MDA`

---

## 10) RESPUESTAS CORTAS PARA PREGUNTAS DIFICILES

## "De donde sale este dato en 9300?"

Respuesta:
- `FORM get_data_9300` en `ZMMR_CARGA_MDA_FORM`
- join principal entre `ZTMM_CARGAS_MDA`, `EKKO`, `EKPO` y maestros.

## "Como se crea exactamente el pedido?"

Respuesta:
- `FORM generate_po_selected` agrupa seleccion.
- `FORM create_po_group` arma payload BAPI.
- `CALL FUNCTION 'BAPI_PO_CREATE1'`.
- commit/rollback segun retorno.
- actualiza `ZTMM_CARGAS_MDA` con `EBELN/EBELP/PEDIDO_GEN`.

## "Como controlas que el usuario no edite cualquier cosa?"

Respuesta:
- lock object por fila (`ENQUEUE_EZTMM_POTXT_MDA`) en `open_edit_mode`.
- validaciones en `handle_data_changed`.
- no permite editar lineas con pedido generado.

## "Donde veo trazabilidad?"

Respuesta:
- `add_log` -> BAL (`BAL_LOG_CREATE`, `BAL_LOG_MSG_ADD`, `BAL_DB_SAVE`).
- consulta final en `SLG1` via `display_slg_log`.

## "Como decides a quien enviar el correo?"

Respuesta:
- primero mail del pedido (`get_po_mail_9300`)
- fallback mail proveedor (`get_supplier_mail_9300`)
- validacion de destinatarios (`is_valid_mail_9300`).

---

## 11) CHECKLIST DE DEMO PARA DEFENSA

1. Entrar 9100, cargar archivo valido y mostrar mensaje final.
2. Mostrar error de linea invalida y luego SLG1.
3. Ir 9200, editar una linea, guardar.
4. Seleccionar lineas y generar pedido (mostrar `EBELN` devuelto).
5. Doble click en `EBELN` -> abre `ME23N`.
6. Ir 9300, aplicar filtros, mostrar flujo.
7. Boton banco (`ZBANK`) mostrando popup.
8. Boton formulario (`ZFORMV`) preview.
9. Boton mail (`ZMAIL`) con CSV y estado icono.

---

## 12) RESUMEN EJECUTIVO (30 SEGUNDOS)

`ZMMR_CARGA_MDA` implementa un proceso MM end-to-end: carga estructurada desde TXT, validacion de maestro/configuracion, generacion de pedido por BAPI con control transaccional, visualizacion de flujo con navegacion SAP estandar, salida Adobe, envio de mail con CSV y trazabilidad completa por Application Log.

