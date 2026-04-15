FUNCTION Z_EWM_SCWM_RF_WHO_SELECT.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_MAN_WO_SEL) TYPE  XFELD DEFAULT SPACE
*"     REFERENCE(IV_RECFILT_MODE) TYPE  XFELD DEFAULT SPACE
*"     REFERENCE(IT_FILTER_WHO) TYPE  /SCWM/TT_WHO_INT OPTIONAL
*"  CHANGING
*"     REFERENCE(SELECTION) TYPE  /SCWM/S_RF_SELECTION OPTIONAL
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT
*"     REFERENCE(T_RF_PICK_HUS) TYPE  /SCWM/TT_RF_PICK_HUS
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"     REFERENCE(CT_WO_RSRC_TY) TYPE  /SCWM/TT_WO_RSRC_TY
*"     REFERENCE(SUCCESS) TYPE  SYSUBRC
*"----------------------------------------------------------------------
* Pass the selected WHOs to Rsrc Mgmt for selecting and locking
* the best WHO. Gets the WHO, WHOHU and TO data.

  DATA: ls_wo_rsrc_ty     TYPE /scwm/wo_rsrc_ty,
        ls_who            TYPE /scwm/s_who_int,
        ls_whohu          TYPE /scwm/s_whohu,
        ls_rf_pick_hus    TYPE /scwm/s_rf_pick_hus,
        ls_ordim_o        TYPE /scwm/ordim_o,
        ls_attributes     TYPE /scwm/s_who_att,
        lt_src_hu_open_to TYPE /scwm/tt_ordim_o,
        lt_dst_hu_open_to TYPE /scwm/tt_ordim_o,
        lt_whr_open_to    TYPE /scwm/tt_ordim_o,
        lt_whohu          TYPE /scwm/tt_whohu_int,
        lt_ordim_o        TYPE /scwm/tt_ordim_o,
        lv_work_who       TYPE /scwm/de_who,
        lv_work_who_int   TYPE i,
        lv_lines          TYPE numc4,
        ls_resource       TYPE /scwm/rsrc,
        lv_applic         TYPE /scwm/de_applic,
        lv_ltrans         TYPE /scwm/de_ltrans.

  CLEAR: lv_work_who.
* Get application and transaction data.
  lv_applic = /scwm/cl_rf_bll_srvc=>get_applic( ).
  lv_ltrans = /scwm/cl_rf_bll_srvc=>get_ltrans( ).

*   Select and lock warehouse order
  MOVE-CORRESPONDING resource TO ls_resource.

* The WR could contain more WOs that is why a check is needed if
* any WO from the request is locked by other user
  FIELD-SYMBOLS <fs_wo_rsrc_ty> TYPE /scwm/wo_rsrc_ty.
  IF lines( ct_wo_rsrc_ty ) > 1.
    LOOP AT ct_wo_rsrc_ty ASSIGNING <fs_wo_rsrc_ty>.
      TRY.
*       Try to lock warehouse order
          CALL FUNCTION '/SCWM/WHO_GET'
            EXPORTING
              iv_lgnum    = ls_resource-lgnum
              iv_lock_who = 'X'
              iv_lock_to  = 'X'
              iv_whoid    = <fs_wo_rsrc_ty>-who
            IMPORTING
              es_who      = ls_who.
*       Lock is not success, skip the WO
        CATCH /scwm/cx_core.
          DELETE ct_wo_rsrc_ty WHERE who = <fs_wo_rsrc_ty>-who.
      ENDTRY.
    ENDLOOP.
*   clear the locks
    CALL FUNCTION 'DEQUEUE_ALL'.
  ENDIF.
* IF lv_ltrans <> 'ZPISYS'.
  CALL FUNCTION '/SCWM/RSRC_WHO_SELECT'
    EXPORTING
      iv_applic         = lv_applic
      iv_ltrans         = lv_ltrans
      iv_man_wo_sel     = iv_man_wo_sel
      iv_recfilt_mode   = iv_recfilt_mode
      it_filter_who     = it_filter_who
    CHANGING
      cs_rsrc           = ls_resource
      ct_wo_rsrc_ty     = ct_wo_rsrc_ty
    EXCEPTIONS
      no_rstyp_attached = 1
      OTHERS            = 2.
*  ENDIF.
  IF sy-subrc <> 0.

*   Dequeue all otherwise the entered WO is locked until Tx end
*     E.g. if user enters a putaway WO in RF picking
    success = sy-subrc.
    CALL FUNCTION 'DEQUEUE_ALL'.
    RETURN.

  ENDIF.
*   ENDIF.

  READ TABLE ct_wo_rsrc_ty INDEX 1 INTO ls_wo_rsrc_ty.  "#EC CI_NOORDER
  MOVE-CORRESPONDING ls_resource TO resource.


* Get WO and TO data
  TRY.
      CALL FUNCTION '/SCWM/WHO_SELECT'
        EXPORTING
          iv_to      = gc_xfeld
          iv_lgnum   = resource-lgnum
          iv_who     = ls_wo_rsrc_ty-who
*         IV_TOPWHO  =
*         IV_LOCK_WHO         = ' '
*         IV_LOCK_TO = ' '
*         IO_PROT    =
*         IT_WHO     =
        IMPORTING
          es_who     = who
*         ET_WHO     = lt_who
          et_whohu   = lt_whohu
          et_ordim_o = lt_ordim_o.

    CATCH /scwm/cx_core.
    CLEANUP.
      REFRESH: lt_whohu, lt_ordim_o.
      CLEAR who.
  ENDTRY.

  LOOP AT lt_whohu INTO ls_whohu.
    MOVE-CORRESPONDING ls_whohu TO ls_rf_pick_hus.
    APPEND ls_rf_pick_hus TO t_rf_pick_hus.
  ENDLOOP.

  IF NOT lt_ordim_o[] IS INITIAL.
    LOOP AT lt_ordim_o INTO ls_ordim_o.
      CLEAR ordim_confirm.
      IF ls_ordim_o-conf_error IS INITIAL.
        MOVE-CORRESPONDING ls_ordim_o TO ordim_confirm.
        APPEND ordim_confirm TO tt_ordim_confirm.
      ENDIF.
    ENDLOOP.
    IF tt_ordim_confirm IS INITIAL.
*      MESSAGE e005 WITH ls_wo_rsrc_ty-who.
    ENDIF.
  ELSE.
*    MESSAGE e005 WITH ls_wo_rsrc_ty-who.
  ENDIF.

* Set global variable for WHO if manually assigned
  gv_who_man_assign = who-man_assign.

* Set global variable for WHO number
  gv_who = who-who.

* Sort TOs
  CALL FUNCTION '/SCWM/RF_PICK_WHO_TO_SORT'
    CHANGING
      ordim_confirm    = ordim_confirm
      tt_ordim_confirm = tt_ordim_confirm
      who              = who.

* Unlock the WTs
  LOOP AT lt_ordim_o INTO ls_ordim_o.
    CALL FUNCTION 'DEQUEUE_/SCWM/ELLTAKE'
      EXPORTING
        lgnum = resource-lgnum
        tanum = ls_ordim_o-tanum.
  ENDLOOP.

ENDFUNCTION.
