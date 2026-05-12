# Documentacion tecnica integral - `ZMMR_CARGA_MDA`

## 1) Objetivo del programa

`ZMMR_CARGA_MDA` implementa un flujo MM completo:

1. **Carga de archivo** de lineas de pedido a tabla custom.
2. **Generacion de pedidos de compra** por reglas de agrupacion usando `BAPI_PO_CREATE1`.
3. **Visualizacion de flujo documental** en ALV con navegacion a `ME23N` / `MM03`.
4. **Impresion/preview** de formulario Adobe.
5. **Envio de mail** con CSV del flujo.
6. **Logging de proceso** en Application Log (SLG1).

---

## 2) Arquitectura por includes

Programa principal:

- `ZMMR_CARGA_MDA.abap`

Includes funcionales:

- `ZMMR_CARGA_MDA_TOP` -> tipos/constantes/globales.
- `ZMMR_CARGA_MDA_SCREEN` -> reservado para selection-screen.
- `ZMMR_CARGA_MDA_CLASS` -> handlers ALV y utilidades OO.
- `ZMMR_CARGA_MDA_MODULE` -> PBO/PAI dynpros.
- `ZMMR_CARGA_MDA_FORM_GLOBAL` -> carga, validaciones, rangos, BAL.
- `ZMMR_CARGA_MDA_FORM_9200` -> ALV generador + creacion POs.
- `ZMMR_CARGA_MDA_FORM_9300` -> flujo completo + formulario + correo.
- `ZMMR_CARGA_MDA_FORM_9400` -> ALV de log legacy.

> Punto de entrada actual:
>
> - `START-OF-SELECTION` -> `CALL SCREEN 9000`.

---

## 3) Flujo de ejecucion (end-to-end)

## 3.1 Arranque

1. Ejecuta `ZMMR_CARGA_MDA`.
2. `CALL SCREEN 9000`.
3. `status_9000` define `PF-STATUS`, `TITLEBAR` y subscreen default `9100`.

## 3.2 Pantalla 9100 - Carga

- `BRWS` -> `f4_file` (dialogo local).
- `LOAD` -> `run`:
  - `validate_file`
  - `upload_file`
  - `get_next_number` (`gc_obj_carga`)
  - `process_lines`
    - parseo y conversiones
    - `validate_business_line`
    - `INSERT` en `ZTMM_CARGAS_MDA`
    - `add_log` (BAL)
  - mensaje final con OK/ERR.

## 3.3 Pantalla 9200 - Generador

- `alv_9200_init` crea grid y eventos.
- Usuario puede:
  - editar filas bloqueadas por lock object
  - guardar cambios (`save_gen_changes`)
  - generar pedidos (`generate_po_selected`)
- Creacion de PO:
  - agrupacion por `PROVEEDOR + FECHA_DOC + COMENTARIO`
  - agregacion por material
  - `BAPI_PO_CREATE1`
  - commit/rollback segun retorno
  - actualizacion `ZTMM_CARGAS_MDA` (EBELN/EBELP/PEDIDO_GEN)
  - guardado de texto de posicion (`SAVE_TEXT`).

## 3.4 Pantalla 9300 - Flujo completo

- `alv_9300_init` + filtros (`popup_filtros_9300`).
- Joins de negocio (`EKKO`, `EKPO`, `LFA1`, `MARA`, `EINA/EINE`, etc.).
- Navegacion a transacciones desde ALV:
  - `EBELN` -> `ME23N`
  - `MATNR` -> `MM03`
- Funciones:
  - popup bancario proveedor (`show_bank_popup_9300`)
  - Adobe Form preview/print (`print_form_9300`)
  - envio de mail CSV (`send_mail_csv_9300`).

## 3.5 Pantalla 9400 / boton log

- `display_slg_log` abre `SLG1` (Application Log estandar).
- `alv_9400_init` existe como vista de tabla custom `ZTMM_LOG_MDA` (legacy).

---

## 4) Dynpros, PBO/PAI y comandos

## 4.1 Dynpro 9000 (contenedor principal)

- **PBO**: `status_9000`
- **PAI**: `user_command_9000`
- Comandos:
  - `BTN1` -> subscreen 9100
  - `BTN2` -> subscreen 9200
  - `BTN3` -> popup filtros + subscreen 9300
  - `BTN4` -> `display_slg_log`
  - `BACK/EXIT/CANC*` -> `LEAVE TO SCREEN 0`.

## 4.2 Dynpro 9100 (carga)

- **PBO**: `status_9100`
- **PAI**: `user_command_9100`
- Comandos:
  - `BRWS` (buscar archivo)
  - `LOAD` (ejecutar carga).

## 4.3 Dynpro 9200 (generador)

- **PBO**: `pbo_9200` -> `alv_9200_init`
- **PAI**: `pai_9200` (extension futura)
- Toolbar ALV:
  - `ZEDIT`, `ZSAVE`, `ZCLOSE`, `ZGENPO`
- Navegacion:
  - doble click directo (`handle_double_click`)
  - comando estandar `&IC1` (`handle_user_command`).

## 4.4 Dynpro 9300 (flujo)

- **PBO**: `pbo_9300` -> `alv_9300_init`
- **PAI**: `pai_9300`
- Toolbar ALV:
  - `ZBANK`, `ZFORMV`, `ZFORMP`, `ZMAIL`
- Navegacion:
  - doble click directo (`handle_double_click`)
  - comando estandar `&IC1`.

## 4.5 Dynpro 9400 (log)

- **PBO**: `pbo_9400` -> `alv_9400_init`
- **PAI**: `pai_9400`

---

## 5) Inventario de objetos Z y donde se usan

## 5.1 Tablas / estructuras custom

| Objeto | Tipo | Uso funcional | Rutinas donde se usa |
|---|---|---|---|
| `ZTMM_CARGAS_MDA` | Tabla | Persistencia principal de carga y estado de generacion | `process_lines`, `get_data_generador`, `save_gen_changes`, `create_po_group`, `get_data_9300`, `mark_mail_sent_for_ebeln_9300`, `get_data_9400` (indirecto por carga) |
| `ZTMM_POTXT_MDA` | Tabla | Comentarios por linea de carga / texto origen | `get_data_generador`, `upsert_comment` |
| `ZTMM_CFGPO_MDA` | Tabla | Configuracion de compras activa (BSART/EKORG/EKGRP/WERKS/MEINS) | `validate_business_line`, `get_cfg_po` |
| `ZTMM_LOG_MDA` | Tabla | Log custom legacy | `get_data_9400`, `build_fcat_9400` |
| `ZEMM_FLUJO_MDA` | Estructura DDIC | Estructura de salida ALV 9300 | `gt_flow`, `build_fcat_9300`, `get_data_9300` |

## 5.2 Objetos de bloqueo / rangos / log

| Objeto | Tipo | Valor / nombre | Uso |
|---|---|---|---|
| `EZTMM_POTXT_MDA` | Lock object | FM `ENQUEUE_/DEQUEUE_...` | Bloqueo por fila durante edicion en 9200 (`open_edit_mode` / `close_edit_mode`) |
| `ZMMCAR_MDA` | Rango (`INRI-OBJECT`) | `gc_obj_carga` | ID de carga (`get_next_number`) |
| `ZMMLIN_MDA` | Rango (`INRI-OBJECT`) | `gc_obj_linea` | ID de linea (`get_next_number`) |
| `ZMMLOG_MDA` | Rango (`INRI-OBJECT`) | `gc_obj_log` | correlativo tecnico para log |
| `ZMML_MDA` | BAL Object | `gc_bal_obj` | Application Log |
| `PROCESO` | BAL Subobject | `gc_bal_sub` | Segmentacion de log en SLG1 |
| `01` | Numero de intervalo | `gc_nr_range` | Intervalo usado por `NUMBER_GET_NEXT` |

## 5.3 Formulario

| Objeto | Tipo | Uso |
|---|---|---|
| `ZMMF_PEDIDO_MDA` | Adobe Form (SFP) | Visualizacion e impresion desde `print_form_9300` mediante `FP_FUNCTION_MODULE_NAME` |

---

## 6) Inventario de tablas estandar leidas/escritas

| Tabla | Rol en el programa | Rutinas |
|---|---|---|
| `LFA1` | Validacion de proveedor y datos proveedor | `validate_business_line`, `get_data_9300`, `get_supplier_mail_9300`, `print_form_9300` |
| `LFM1` | Validacion proveedor por org. compras | `validate_business_line`, `show_bank_popup_9300` |
| `LFBK` | Cuentas bancarias de proveedor | `show_bank_popup_9300` |
| `BNKA` | Nombre de banco | `show_bank_popup_9300` |
| `MARA` | Validacion y datos material | `validate_business_line`, `get_data_9300` |
| `MARC` | Validacion material por centro | `validate_business_line` |
| `EINA` / `EINE` | Validacion de info record compra activa | `validate_business_line`, `get_data_9300` |
| `EKKO` | Cabecera pedido (flujo/mail) | `get_data_9300`, `get_po_mail_9300` |
| `EKPO` | Posiciones pedido | `get_data_9300`, `print_form_9300` |
| `ADR6` | Correos de direccion | `get_data_9300`, `get_po_mail_9300`, `get_supplier_mail_9300` |
| `ADRC` | Datos direccion para form | `print_form_9300` |
| `T001` | Datos sociedad para form | `print_form_9300` |

---

## 7) APIs/FMs y su responsabilidad

| FM / API | Tipo | Para que se usa |
|---|---|---|
| `BAPI_PO_CREATE1` | BAPI | Creacion de pedido de compra |
| `BAPI_TRANSACTION_COMMIT` / `ROLLBACK` | BAPI | Confirmacion/reversion transaccional de creacion |
| `SAVE_TEXT` | SAPscript text | Texto de posicion de PO |
| `NUMBER_GET_NEXT` | Number range | IDs secuenciales (carga/linea/log) |
| `BAL_LOG_CREATE`, `BAL_LOG_MSG_ADD`, `BAL_DB_SAVE` | Application Log | Logging tecnico consultable en SLG1 |
| `CONVERSION_EXIT_ALPHA_INPUT` | Conversion | Normalizacion de proveedor |
| `CONVERSION_EXIT_MATN1_INPUT` | Conversion | Normalizacion de material |
| `CONVERT_DATE_TO_INTERNAL` | Conversion | Fecha externa -> interna |
| `LVC_FIELDCATALOG_MERGE` | ALV | Catalogo desde DDIC |
| `FP_FUNCTION_MODULE_NAME`, `FP_JOB_OPEN/CLOSE` | Adobe Forms | Resolucion FM generado y ciclo de impresion |
| `SCMS_STRING_TO_XSTRING`, `SCMS_XSTRING_TO_BINARY` | Conversion binaria | Adjuntar CSV en email |
| `POPUP_GET_VALUES` | UI | Captura filtros / destinatarios |
| `ENQUEUE_/DEQUEUE_EZTMM_POTXT_MDA` | Lock | Control de concurrencia en edicion |

---

## 8) Clases y eventos ALV

## 8.1 `lcl_util`

- `to_lower`: utilidad para comparaciones robustas de texto/extension.

## 8.2 `lcl_evt_9200`

- `handle_toolbar`: botones de edicion/generacion.
- `handle_user_command`: comandos custom y `&IC1`.
- `handle_double_click`: navegacion ME23N/MM03.
- `handle_data_changed`: validaciones de celdas editadas.

## 8.3 `lcl_evt_9300`

- `handle_toolbar`: botones banco/form/mail.
- `handle_user_command`: comandos custom y `&IC1`.
- `handle_double_click`: navegacion ME23N/MM03.

---

## 9) Mapa de FORMs por bloque funcional

## 9.1 Global (`ZMMR_CARGA_MDA_FORM_GLOBAL`)

`run`, `f4_file`, `validate_file`, `upload_file`, `process_lines`, `validate_business_line`, `get_next_number`, `add_log`, `bal_init`, `bal_add_message`, `bal_save`, `display_slg_log`, `get_file_name`.

## 9.2 Generador 9200 (`ZMMR_CARGA_MDA_FORM_9200`)

`alv_9200_init`, `set_row_style`, `get_data_generador`, `build_fcat_9200`, `handle_ic1_9200`, `add_fcat`, `get_selected_gen_rows`, `has_pending_changes`, `open_edit_mode`, `close_edit_mode`, `save_gen_changes`, `upsert_comment`, `get_cfg_po`, `generate_po_selected`, `create_po_group`, `save_po_text`, `nav_me23n`, `nav_mm03_purch`.

## 9.3 Flujo 9300 (`ZMMR_CARGA_MDA_FORM_9300`)

`get_data_9300`, `alv_9300_init`, `popup_filtros_9300`, `print_form_9300`, `build_fcat_9300`, `handle_ic1_9300`, `show_bank_popup_9300`, `send_mail_csv_9300`, `get_po_mail_9300`, `get_supplier_mail_9300`, `popup_mail_receivers_9300`, `append_mail_tokens_9300`, `is_valid_mail_9300`, `get_mail_flag_component_9300`, `is_mail_sent_for_ebeln_9300`, `mark_mail_sent_for_ebeln_9300`.

## 9.4 Log 9400 (`ZMMR_CARGA_MDA_FORM_9400`)

`get_data_9400`, `build_fcat_9400`, `alv_9400_init`.

---

## 10) Reglas de negocio clave (defensa funcional)

1. **No se inserta una linea si falla validacion de negocio** (proveedor, material, config activa, info record).
2. **Edicion controlada en 9200**:
   - solo filas bloqueadas por usuario
   - no se edita fila ya generada (`PEDIDO_GEN = X`).
3. **Generacion de PO por grupos**:
   - clave de agrupacion: proveedor + fecha_doc + comentario
   - agregacion por material en una sola posicion.
4. **Consistencia transaccional**:
   - rollback si BAPI devuelve error
   - commit explicito si creacion correcta.
5. **Idempotencia de envio mail**:
   - chequeo de flag de envio antes de reenviar (si el campo existe).
6. **Fallback de email**:
   - direccion de PO -> direccion proveedor default -> direccion proveedor alternativa.
7. **Trazabilidad obligatoria**:
   - todo evento significativo se registra en BAL y se consulta en `SLG1`.

---

## 11) Seguridad, concurrencia y trazabilidad

- **Concurrencia**: lock object por fila en edicion.
- **Trazabilidad**:
  - IDs de carga y linea por rango numerico.
  - mensajes de proceso en Application Log.
- **Errores**:
  - manejo con `sy-subrc`, BAPI return y mensajes de usuario.
- **Riesgo controlado**:
  - no se continua flujo cuando faltan prerequisitos de maestro/config.

---

## 12) Dependencias tecnicas y prerrequisitos

1. Dynpros: `9000`, `9100`, `9200`, `9300`, `9400`.
2. PF-STATUS `STATUS` y TITLEBAR `TITLE`.
3. Objetos DDIC custom creados y activos.
4. Objetos SNRO (`ZMMCAR_MDA`, `ZMMLIN_MDA`, `ZMMLOG_MDA`) con intervalo `01`.
5. BAL object/subobject activos (`ZMML_MDA`/`PROCESO`).
6. Formulario Adobe `ZMMF_PEDIDO_MDA` activo.
7. Maestro MM/Vendor consistente para datos de prueba.

---

## 13) Guia de defensa frente a revision senior

## 13.1 Preguntas tipicas y respuesta corta

**Q1: Como garantizas integridad al crear pedidos?**  
Se valida maestro previo + agrupacion determinista + BAPI con rollback/commit y update posterior de trazabilidad.

**Q2: Como auditas errores de negocio?**  
Application Log BAL con object/subobject y persistencia inmediata (`BAL_DB_SAVE` + commit), consultable en `SLG1`.

**Q3: Como evitas condiciones de carrera al editar?**  
Bloqueo explicito por fila con lock object `EZTMM_POTXT_MDA` durante modo edicion.

**Q4: Como manejas datos incompletos de mail?**  
Cadena de fallback (PO -> proveedor default -> proveedor alternativo) y validacion sintactica de destinatarios.

**Q5: Por que modularizado por includes?**  
Separacion de responsabilidades por contexto (global, 9200, 9300, 9400) para mantenimiento, pruebas y trazabilidad.

## 13.2 Evidencias a mostrar en demo

1. Carga valida + carga con error (mostrar logs en SLG1).
2. Edicion de linea con lock y guardado.
3. Generacion de PO correcta y error controlado (si maestro invalido).
4. Doble click de navegacion en 9200/9300.
5. Preview Adobe + impresion.
6. Envio de mail CSV y marcado de enviado.

---

## 14) Riesgos tecnicos y mejoras recomendadas

1. **Legacy de `ZTMM_LOG_MDA`**: mantenerlo solo como historico o retirarlo si SLG1 es la unica fuente oficial.
2. **Rendimiento**: considerar buffering/caching para validaciones maestras en cargas grandes.
3. **Tests**: cubrir parseo, agrupacion y reglas de mail con clases ABAP Unit.
4. **Control de cambios**: encapsular BAPI y BAL en clases de servicio para pruebas unitarias.
5. **UX**: reforzar mensajes con contexto de fila y causa exacta.

---

## 15) Resumen para presentar en 30 segundos

> El programa implementa un flujo MM completo y trazable: carga archivo, valida maestro y configuracion, genera pedidos por BAPI con control transaccional, muestra flujo documental con navegacion estandar SAP, imprime formulario Adobe, envia CSV por correo y registra todo en Application Log consultable en SLG1.  
> Esta dividido por includes y capas (global/eventos/dynpros) para facilitar mantenimiento y defensa tecnica.

