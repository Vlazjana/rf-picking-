FUNCTION z_ewm_rf_pick_dest_pbo .
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(SELECTION) TYPE  /SCWM/S_RF_SELECTION OPTIONAL
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC OPTIONAL
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT OPTIONAL
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM OPTIONAL
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"       OPTIONAL
*"     REFERENCE(TT_NESTED_HU) TYPE  /SCWM/TT_RF_NESTED_HU OPTIONAL
*"     REFERENCE(T_RF_PICK_HUS) TYPE  /SCWM/TT_RF_PICK_HUS OPTIONAL
*"     REFERENCE(CT_SERNR) TYPE  /SCWM/TT_RF_SERNR OPTIONAL
*"     REFERENCE(CT_SERNR_DIFF) TYPE  /SCWM/TT_RF_SERNR OPTIONAL
*"     REFERENCE(CS_SN) TYPE  /SCWM/S_RF_SN OPTIONAL
*"     REFERENCE(WME_VERIF) TYPE  /SCWM/S_WME_VERIF OPTIONAL
*"     REFERENCE(CT_SERNR_LSCK) TYPE  /SCWM/TT_RF_SERNR OPTIONAL
*"     REFERENCE(NESTPT) TYPE  /SCWM/S_RF_NESTED OPTIONAL
*"     REFERENCE(S_WHO_SCREEN) TYPE  ZSRF_ZPISYS_WHO_SCREEN OPTIONAL
*"     REFERENCE(ZT_WHO_SCREEN) TYPE  ZTTRF_ZPISYS_WHO_SCREEN OPTIONAL
*"----------------------------------------------------------------------


  /scwm/cl_rf_bll_srvc=>init_screen_param( ).
  /scwm/cl_rf_bll_srvc=>set_screen_param( 'ORDIM_CONFIRM' ).
  /scwm/cl_rf_bll_srvc=>set_screen_param( 'S_WHO_SCREEN' ).
  /scwm/cl_rf_bll_srvc=>set_screen_param( 'TT_ORDIM_CONFIRM' ).
  /scwm/cl_rf_bll_srvc=>set_screen_param( '/SCWM/TT_RF_PICK_HUS' ).

  /scwm/cl_rf_bll_srvc=>set_scr_tabname(
iv_scr_tabname = '/SCWM/TT_RF_PICK_HUS' ).

  IF gt_who_screen IS INITIAL.
    SELECT matnr, nr_packaging ,maktx
      FROM ztewm_rf_rcv_sc6
      WHERE lgnum = @resource-lgnum
        AND rsrc  = @resource-rsrc
        AND who   = @gv_who
      INTO CORRESPONDING FIELDS OF TABLE @gt_who_screen.
    IF gt_who_screen IS INITIAL.
      DO 3 TIMES.
        APPEND INITIAL LINE TO gt_who_screen.
      ENDDO.
    ENDIF.
  ENDIF.

  IF gt_scan IS INITIAL.
    SELECT zzlabel, zzcertstat, zzlabel_scan ,zzcheckbox
      FROM ztewm_rf_rcvscan
      WHERE lgnum = @resource-lgnum
        AND rsrc  = @resource-rsrc
        AND who   = @gv_who
      INTO CORRESPONDING FIELDS OF TABLE @gt_scan.
  ENDIF.

  SELECT SINGLE *
    FROM ztewm_rf_recov
    WHERE lgnum = @resource-lgnum
      AND rsrc  = @resource-rsrc
      AND who   = @gv_who
    INTO @DATA(ls_rec_full).

  IF sy-subrc = 0.
    MOVE-CORRESPONDING ls_rec_full TO s_who_screen.
    gv_nr_etichette  = ls_rec_full-nr_etichette.
    gv_all_confirmed = ls_rec_full-all_confirmed.

    SELECT SINGLE nlpla
      FROM /scwm/ordim_o
      WHERE lgnum = @resource-lgnum
        AND who   = @gv_who
      INTO @s_who_screen-nlpla.

    ls_rec_full-all_confirmed = gv_all_confirmed.
    ls_rec_full-recover_scr   = 'ZPICK6'.
    MODIFY ztewm_rf_recov FROM @ls_rec_full.
  ENDIF.

  IF gv_all_confirmed = 'X' AND
     gt_scan IS NOT INITIAL AND
     NOT line_exists( gt_scan[ zzcertstat = ' ' ] ).

    LOOP AT gt_certificazione ASSIGNING FIELD-SYMBOL(<ls_cert>).
      READ TABLE gt_scan WITH KEY zzlabel = <ls_cert>-zzlabel
        TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        APPEND VALUE #(
          zzlabel      = <ls_cert>-zzlabel
          zzcertstat   = ' '
          zzlabel_scan = ' '
        ) TO gt_scan.
      ENDIF.
    ENDLOOP.

  ELSE.

    LOOP AT gt_certificazione ASSIGNING FIELD-SYMBOL(<ls_cert_new>).
      READ TABLE gt_scan WITH KEY zzlabel = <ls_cert_new>-zzlabel
        TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        APPEND VALUE #(
          zzlabel      = <ls_cert_new>-zzlabel
          zzcertstat   = ' '
          zzlabel_scan = ' '
        ) TO gt_scan.
      ENDIF.
    ENDLOOP.

  ENDIF.

*  DELETE FROM ztewm_rf_rcvscan
*    WHERE lgnum = @resource-lgnum
*      AND rsrc  = @resource-rsrc
*      AND who   = @gv_who.

  DATA lt_scan TYPE STANDARD TABLE OF ztewm_rf_rcvscan WITH EMPTY KEY.

  LOOP AT gt_scan INTO DATA(ls_scan).
    APPEND VALUE ztewm_rf_rcvscan(
      mandt        = sy-mandt
      lgnum        = resource-lgnum
      rsrc         = resource-rsrc
      who          = gv_who
      zzlabel      = ls_scan-zzlabel
      zzcertstat   = ls_scan-zzcertstat
      zzlabel_scan = ls_scan-zzlabel_scan
      zzcheckbox   = ls_scan-zzcheckbox
    ) TO lt_scan.
  ENDLOOP.

  IF lt_scan IS NOT INITIAL.
   MODIFY ztewm_rf_rcvscan FROM TABLE @lt_scan.
  ENDIF.

  COMMIT WORK AND WAIT.

  IF gv_all_confirmed = 'X' AND
     gt_scan IS NOT INITIAL AND
     NOT line_exists( gt_scan[ zzcertstat = ' ' ] ).

*    /scwm/cl_rf_bll_srvc=>set_screen_param( 'S_WHO_SCREEN' ).
    /scwm/cl_rf_bll_srvc=>set_screlm_input_on( gc_scr_elmnt_nlpla_vrf ).

  ELSE.

*    /scwm/cl_rf_bll_srvc=>init_screen_param( ).
*    /scwm/cl_rf_bll_srvc=>set_screen_param( 'S_WHO_SCREEN' ).
    /scwm/cl_rf_bll_srvc=>set_screlm_input_off( gc_scr_elmnt_nlpla_vrf ).

  ENDIF.


ENDFUNCTION.
