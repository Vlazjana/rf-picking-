FUNCTION z_ewm_rf_print_pai.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM OPTIONAL
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC OPTIONAL
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT OPTIONAL
*"     REFERENCE(S_WHO_SCREEN) TYPE  ZSRF_ZPISYS_WHO_SCREEN OPTIONAL
*"     REFERENCE(ZT_WHO_SCREEN) TYPE  ZTTRF_ZPISYS_WHO_SCREEN OPTIONAL
*"----------------------------------------------------------------------

*BREAK-POINT.

  CONSTANTS: lc_smartform TYPE tdsfname VALUE 'ZEWM_PICKING_PROC'.

  DATA : lv_fm_name TYPE rs38l_fnam,
         lv_printer TYPE rspopname,
         ls_ctrl_op TYPE ssfctrlop,
         ls_comp_op TYPE ssfcompop,
         ls_return  TYPE ssfcrescl,
         lv_msg     TYPE string.
  DATA : lt_print_label TYPE TABLE OF zsrf_zpisys_who_screen.

  DATA: lv_barcode TYPE /scwm/de_huident.

  " 1. Check at least one WT confirmed
  SELECT COUNT(*) FROM /scwm/ordim_c
    WHERE lgnum = @who-lgnum
      AND who   = @who-who
    INTO @DATA(lv_confirmed_count).

  IF lv_confirmed_count = 0.
*    MESSAGE 'Nessun task confermato' TYPE 'E'.
    MESSAGE e042(zewm_rf_msg).
    RETURN.
  ENDIF.

  " Get DLOC from confirmed tasks

  SELECT SINGLE nlpla
    FROM /scwm/ordim_O
    WHERE lgnum = @resource-lgnum
      AND who   = @who-who
    INTO @DATA(lv_dloc).


  DATA(lv_outb_del) = s_who_screen-pdo.
  SHIFT lv_outb_del LEFT DELETING LEADING '0'.

  s_who_screen-pdo = lv_outb_del.
  s_who_screen-lgnum =  resource-lgnum.
  s_who_screen-rsrc =  resource-rsrc.
  s_who_screen-z_dats = sy-datum.
  s_who_screen-nlpla  = lv_dloc.


  APPEND s_who_screen TO lt_print_label.
* Stampa etichetta
* Stampa Smartform*******************************************************************************
  CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
    EXPORTING
      formname           = lc_smartform
    IMPORTING
      fm_name            = lv_fm_name
    EXCEPTIONS
      no_form            = 1
      no_function_module = 2
      OTHERS             = 3.

  IF sy-subrc <> 0.
*    MESSAGE 'SmartForm non trovato/attivato' TYPE 'E'.  " message class
    MESSAGE e035(zewm_rf_msg).
  ENDIF.

  ls_ctrl_op-no_dialog   = abap_true.
*  ls_ctrl_op-preview     = abap_false.
  ls_ctrl_op-preview     = abap_true.
  ls_comp_op-tdprinter   = 'PDFPRINTER'.
  ls_comp_op-tddest      = 'ZPDF'.
  ls_comp_op-tdcopies    = 1.
  ls_comp_op-tdimmed     = abap_true.   " stampa immediata (non trattiene in spool)
*  ls_comp_op-tddelete    = abap_true.   " cancella spool dopo stampa
  ls_comp_op-tddelete    = abap_false.   " non cancella spool dopo stampa
  ls_comp_op-tdfinal     = abap_true.   " chiude il job di stampa

  CALL FUNCTION lv_fm_name
    EXPORTING
      control_parameters = ls_ctrl_op
      output_options     = ls_comp_op
      user_settings      = abap_false     "non usare impostazioni utente?
    IMPORTING
      job_output_info    = ls_return
    TABLES
      it_zrf_picking     = lt_print_label
    EXCEPTIONS
      formatting_error   = 1
      internal_error     = 2
      send_error         = 3
      user_canceled      = 4
      OTHERS             = 5.

  CASE sy-subrc.
    WHEN 0.
      "OK
*      aggiungi data_stampa
      MODIFY zrf_picking FROM TABLE lt_print_label.
      IF sy-subrc = 0.
        COMMIT WORK AND WAIT.
      ELSE.
*        MESSAGE 'Errore Salvataggio dopo stampa' TYPE 'E'.
        MESSAGE e043(zewm_rf_msg).
      ENDIF.

*        gv_stampato = 'X'.

    WHEN 1.
      "Errore di formattazione (es. reference field mancante, overflow)
*      MESSAGE 'Errore formattazione etichetta' INTO lv_msg.
*      MESSAGE 'Errore formattazione etichetta' TYPE 'E'.
      MESSAGE e036(zewm_rf_msg).
      " Logga in SLG1 per debug
*      perform_slog( iv_msg = lv_msg iv_type = 'E' ).

    WHEN 2.
      "Errore interno SmartForms
*      MESSAGE 'Errore interno SmartForms' INTO lv_msg.
*      MESSAGE 'Errore interno SmartForms' TYPE 'E'..
      MESSAGE e037(zewm_rf_msg).
*      perform_slog( iv_msg = lv_msg iv_type = 'E' ).

    WHEN 3.
      "Errore invio alla stampante
*      MESSAGE 'Errore invio a stampante &1' INTO lv_msg.
*      MESSAGE 'Errore invio a stampante &1' TYPE 'E'.
*      perform_slog( iv_msg = lv_msg iv_type = 'E' ).
      MESSAGE e038(zewm_rf_msg).

    WHEN 4.
      "Operatore ha cancellato (non dovrebbe accadere perchè si manda in stampa senza popup)
*      MESSAGE 'Stampa annullata' TYPE 'E'.
      MESSAGE e039(zewm_rf_msg).

    WHEN OTHERS.
*      MESSAGE 'Errore generico stampa' INTO lv_msg.
*      MESSAGE 'Errore generico stampa' TYPE 'E'.
      MESSAGE e040(zewm_rf_msg).
*      perform_slog( iv_msg = lv_msg iv_type = 'E' ).

  ENDCASE.


ENDFUNCTION.
