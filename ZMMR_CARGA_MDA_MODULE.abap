*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_MODULE
*&---------------------------------------------------------------------*
" Módulos PBO/PAI de dynpros.

MODULE status_9000 OUTPUT.
  SET PF-STATUS 'S9000'.
  SET TITLEBAR  'T9000'.
ENDMODULE.

MODULE user_command_9000 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.
ENDMODULE.
