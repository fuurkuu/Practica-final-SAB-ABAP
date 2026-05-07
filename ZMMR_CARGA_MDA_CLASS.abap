*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_CLASS
*&---------------------------------------------------------------------*
" IMPORTANTE:
" - Aquí solo van clases locales (DEFINITION/IMPLEMENTATION).
" - No redeclarar CONSTANTS/TYPES/DATA globales que ya están en TOP.

CLASS lcl_evt_9300 DEFINITION.
  PUBLIC SECTION.
    METHODS handle_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.
    METHODS handle_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    METHODS handle_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column es_row_no.
ENDCLASS.

CLASS lcl_evt_9300 IMPLEMENTATION.
  METHOD handle_toolbar.
  ENDMETHOD.

  METHOD handle_user_command.
  ENDMETHOD.

  METHOD handle_double_click.
  ENDMETHOD.
ENDCLASS.
