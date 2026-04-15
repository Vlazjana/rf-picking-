FUNCTION Z_EWM_RF_PICK_WHO_PIBUSR_PBO .
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(SELECTION) TYPE  /SCWM/S_RF_SELECTION
*"----------------------------------------------------------------------

  DATA: lv_ltrans          TYPE /scwm/de_ltrans,
        lc_doccat_whr_pdo  TYPE /scwm/de_doccat VALUE 'PDO',
        lc_doccat_whr_wmr  TYPE /scwm/de_doccat VALUE 'WMR',
        ls_pdo_text        TYPE dd07v,
        ls_wmr_text        LIKE dd07v,
        lv_subrc           TYPE sy-subrc,
        lv_char40          TYPE /scwm/de_rf_text,
        lv_value           type DOMVALUE_L.

*------------
DATA: ls_rsrc           TYPE /scwm/rsrc,
      is_rsrc           TYPE /scwm/rsrc,
      ls_rsgrp_queue    TYPE /scwm/trsgr_q_sq,
      lt_rsgrp_queue    TYPE /scwm/tt_rsgr_q_sq,
      lv_fcode          TYPE /scwm/de_fcode.
*-----
* /scwm/cl_rf_bll_srvc=>set_ltrans_simu( 'PISYSG' ).
  BREAK-POINT ID /scwm/rf_picking.

* Get logical transaction
  lv_ltrans = /scwm/cl_rf_bll_srvc=>get_ltrans( ).
  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).

* set screen parameter
  /scwm/cl_rf_bll_srvc=>set_screen_param('SELECTION').
  CLEAR selection.

  IF lv_ltrans = ltrans_pick_by_whr or lv_ltrans = ltrans_work_by_wr.

    lv_value = lc_doccat_whr_pdo.
    CALL FUNCTION 'DD_DOMVALUE_TEXT_GET'
      EXPORTING
        domname  = '/SCWM/DO_DOCCAT'
        value    = lv_value
        langu    = sy-langu
      IMPORTING
        dd07v_wa = ls_pdo_text
        rc       = lv_subrc.

    IF lv_subrc = 0.
      selection-whr_doccat = ls_pdo_text-domvalue_l.
      selection-whr_doccat_text = ls_pdo_text-ddtext.
    ELSE.
      selection-whr_doccat = lc_doccat_whr_pdo.
    ENDIF.

    lv_value = lc_doccat_whr_wmr.
    CALL FUNCTION 'DD_DOMVALUE_TEXT_GET'
      EXPORTING
        domname  = '/SCWM/DO_DOCCAT'
        value    = lv_value
        langu    = sy-langu
      IMPORTING
        dd07v_wa = ls_wmr_text
        rc       = lv_subrc.

*   Filling list options for WHR document category type
    /scwm/cl_rf_bll_srvc=>init_listbox(
                                   '/SCWM/S_RF_SELECTION-WHR_DOCCAT' ).

    MOVE ls_pdo_text-ddtext TO lv_char40.
    /scwm/cl_rf_bll_srvc=>insert_listbox(
        iv_fieldname = '/SCWM/S_RF_SELECTION-WHR_DOCCAT'
        iv_fld_dscr = '/SCWM/S_RF_SELECTION-WHR_DOCCAT_TEXT'
        iv_value = lc_doccat_whr_pdo
        iv_text = lv_char40 ).

    MOVE ls_wmr_text-ddtext TO lv_char40.
    /scwm/cl_rf_bll_srvc=>insert_listbox(
        iv_fieldname = '/SCWM/S_RF_SELECTION-WHR_DOCCAT'
        iv_fld_dscr = '/SCWM/S_RF_SELECTION-WHR_DOCCAT_TEXT'
        iv_value = lc_doccat_whr_wmr
        iv_text = lv_char40 ).

  ENDIF.

*--------

** Get default values
  CALL FUNCTION '/SCWM/RSRC_RESOURCE_MEMORY'
    EXPORTING
      iv_uname = sy-uname
    CHANGING
      cs_rsrc  = ls_rsrc.

  CALL METHOD /scwm/cl_tm=>set_lgnum( ls_rsrc-lgnum ).

  IF lv_ltrans = ltrans_work_by_hu OR
     lv_ltrans = ltrans_work_by_wo OR
     lv_ltrans = ltrans_work_by_wr.

*   update resource to avoid semi system guided processing
*   after manual selection
    CALL FUNCTION '/SCWM/RSRC_READ_SINGLE'
      EXPORTING
        iv_lgnum          =  ls_rsrc-lgnum
        iv_rsrc           =  ls_rsrc-rsrc
        iv_db_lock        = 'X'
      IMPORTING
        es_rsrc           = is_rsrc.

    CLEAR:  is_rsrc-semi_lgpla,
            is_rsrc-semi_queue,
            is_rsrc-semi_queue_chg.

    CALL FUNCTION '/SCWM/RSRC_RESOURCE_SET'
      EXPORTING
        iv_action = wmegc_update
        is_rsrc   = is_rsrc.

    COMMIT WORK AND WAIT.
    CALL METHOD /scwm/cl_tm=>cleanup( ).
  ELSE.
*   Get resource
    CALL FUNCTION '/SCWM/RSRC_READ_SINGLE'
      EXPORTING
        iv_lgnum          =  ls_rsrc-lgnum
        iv_rsrc           =  ls_rsrc-rsrc
      IMPORTING
        es_rsrc           = is_rsrc.
  ENDIF.

* Read data and fill listbox for F8
* Intitialize values for dynpro field
  /scwm/cl_rf_bll_srvc=>init_listbox( '/SCWM/S_RF_SELECTION-QUEUE' ).

* Read valid queues for the actual resource group
  CALL FUNCTION '/SCWM/RSRC_RSGRP_QUEUE_GET'
    EXPORTING
      iv_lgnum       = is_rsrc-lgnum
      iv_rsrc_grp    = is_rsrc-rsrc_grp
    IMPORTING
      et_rsgrp_queue = lt_rsgrp_queue.

* Pass the listbox values to the framework
  LOOP AT lt_rsgrp_queue INTO ls_rsgrp_queue.
    MOVE ls_rsgrp_queue-queue TO lv_char40.
    /scwm/cl_rf_bll_srvc=>insert_listbox(
      iv_fieldname = '/SCWM/S_RF_SELECTION-QUEUE'
      iv_value = lv_char40
      iv_text = lv_char40 ).
  ENDLOOP.

*--------

ENDFUNCTION.
