*&---------------------------------------------------------------------*
*& Include          ZMMR_CARGA_MDA_MODULE
*&---------------------------------------------------------------------*
MODULE status_9000 OUTPUT.
  SET PF-STATUS 'STATUS'.
  SET TITLEBAR  'TITLE'.

  IF gv_subscr IS INITIAL.
    gv_subscr = '9100'.
  ENDIF.
ENDMODULE.

MODULE user_command_9000 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'BTN1'.
      gv_subscr = '9100'.

    WHEN 'BTN2'.
      gv_subscr = '9200'.

    WHEN 'BTN3'.
      PERFORM popup_filtros_9300.
      gv_subscr = '9300'.

      IF go_grid_9300 IS BOUND.
        PERFORM get_data_9300.
        CALL METHOD go_grid_9300->refresh_table_display.
      ENDIF.

    WHEN 'BTN4'.
      PERFORM display_slg_log.

    WHEN 'BACK2' OR 'LEAVE2' OR 'CANCEL2'
      OR 'BACK'  OR 'EXIT'   OR 'CANC'.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.

MODULE status_9100 OUTPUT.
ENDMODULE.

MODULE user_command_9100 INPUT.
  save_ok = ok_code.

  CASE save_ok.
    WHEN 'BRWS'.
      PERFORM f4_file CHANGING gv_file.
      CLEAR ok_code.

    WHEN 'LOAD'.
      IF gv_file IS INITIAL.
        MESSAGE 'Indica un fichero primero' TYPE 'S' DISPLAY LIKE 'E'.
      ELSE.
        PERFORM run USING gv_file.
      ENDIF.
      CLEAR ok_code.
  ENDCASE.
ENDMODULE.

MODULE pbo_9200 OUTPUT.
  PERFORM alv_9200_init.
ENDMODULE.

MODULE pai_9200 INPUT.
ENDMODULE.

MODULE pbo_9300 OUTPUT.
  PERFORM alv_9300_init.
ENDMODULE.

MODULE pai_9300 INPUT.
ENDMODULE.

MODULE pbo_9400 OUTPUT.
  " Logging unificado por SLG1 (BTN4 -> display_slg_log).
ENDMODULE.

MODULE pai_9400 INPUT.
ENDMODULE.
