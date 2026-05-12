REPORT zmmr_carga_mda.

* Programa principal:
* - Centraliza la practica completa de carga -> generacion -> flujo -> log.
* - El comportamiento se reparte en includes para separar responsabilidades.
INCLUDE zmmr_carga_mda_top.
INCLUDE zmmr_carga_mda_screen.
INCLUDE zmmr_carga_mda_class.
INCLUDE zmmr_carga_mda_module.
INCLUDE zmmr_carga_mda_form_global.
INCLUDE zmmr_carga_mda_form_9200.
INCLUDE zmmr_carga_mda_form_9300.
INCLUDE zmmr_carga_mda_form_9400.

* Punto de entrada de ejecucion en SAP GUI.
START-OF-SELECTION.
  CALL SCREEN 9000.
