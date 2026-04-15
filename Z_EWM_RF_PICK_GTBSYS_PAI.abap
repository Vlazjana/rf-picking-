FUNCTION z_ewm_rf_pick_gtbsys_pai.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC OPTIONAL
*"     REFERENCE(ZT_WHO_SCREEN) TYPE  ZTTRF_ZPISYS_WHO_SCREEN OPTIONAL
*"     REFERENCE(S_WHO_SCREEN) TYPE  ZSRF_ZPISYS_WHO_SCREEN OPTIONAL
*"     REFERENCE(NESTPT) TYPE  /SCWM/S_RF_NESTED OPTIONAL
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM OPTIONAL
*"     REFERENCE(T_RF_PICK_HUS) TYPE  /SCWM/TT_RF_PICK_HUS OPTIONAL
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT OPTIONAL
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"       OPTIONAL
*"----------------------------------------------------------------------
*
*  DATA: ls_rsrc_mem TYPE /scwm/rsrc.
*  DATA(lv_step)  = /scwm/cl_rf_bll_srvc=>get_step( ).
*  DATA(lv_fcode) = /scwm/cl_rf_bll_srvc=>get_fcode( ).
*
*  CALL FUNCTION '/SCWM/RSRC_RESOURCE_MEMORY'
*    EXPORTING
*      iv_uname = sy-uname
*    CHANGING
*      cs_rsrc  = ls_rsrc_mem.
*
*** Get skipped WOs
*  DATA(lo_skip_wo) = /scwm/cl_rf_pick_exc_skip_wo=>get_instance(
*                       iv_lgnum = ls_rsrc_mem-lgnum ).
*  gt_skipped_wos = lo_skip_wo->get_skipped_wos( ).
*
** Get remaining available WOs
*  DATA lt_who_remaining TYPE TABLE OF /scwm/who.
*  PERFORM get_who_list
*    TABLES lt_who_remaining
*    USING  ls_rsrc_mem.
*
** Filter out skipped WOs
*  LOOP AT gt_skipped_wos ASSIGNING FIELD-SYMBOL(<ls_skip>).
*    DATA(lv_who) = |{ <ls_skip>-who ALPHA = IN }|.
*    DELETE lt_who_remaining WHERE who = lv_who.
*
*  ENDLOOP.
*
** Clear old data
*  CLEAR: who, ordim_confirm, tt_ordim_confirm.
*
*  IF lt_who_remaining IS INITIAL.
*    /scwm/cl_rf_bll_srvc=>message(
*      EXPORTING
*        iv_flg_continue_flow = 'X'
*        iv_msgid             = '/SCWM/RF_EN'
*        iv_msgno             = '056' ).
*    /scwm/cl_rf_bll_srvc=>set_fcode(
*      /scwm/cl_rf_bll_srvc=>c_fcode_leave ).
*    /scwm/cl_rf_bll_srvc=>set_prmod(
*      EXPORTING
*        iv_prmod    = /scwm/cl_rf_bll_srvc=>c_prmod_background
*        iv_ovr_cust = 'X' ).
*    RETURN.
*  ENDIF.
*
**/scwm/cl_rf_bll_srvc=>init_call_stack_optimizer( ).
**/scwm/cl_rf_bll_srvc=>set_flg_stack( iv_flg_stack = 'X' ).
** /scwm/cl_rf_bll_srvc=>set_prmod( EXPORTING iv_prmod =
** /scwm/cl_rf_bll_srvc=>c_prmod_background iv_ovr_cust = 'X' ).
**  /scwm/cl_rf_bll_srvc=>set_fcode( /scwm/cl_rf_bll_srvc=>c_fcode_compl_ltrans ).
*  /scwm/cl_rf_bll_srvc=>set_prmod(
*    /scwm/cl_rf_bll_srvc=>c_prmod_background ).
*
*  /scwm/cl_rf_bll_srvc=>set_fcode(
*    /scwm/cl_rf_bll_srvc=>c_fcode_compl_ltrans ).
*  EXPORT gt_skipped_wos TO MEMORY ID 'Z_SKIP_WO'.


  DATA: ls_rsrc_mem TYPE /scwm/rsrc.
  DATA: lt_who_remaining TYPE TABLE OF /scwm/who.

  CALL FUNCTION '/SCWM/RSRC_RESOURCE_MEMORY'
    EXPORTING
      iv_uname = sy-uname
    CHANGING
      cs_rsrc  = ls_rsrc_mem.

  IMPORT gt_skipped_wos FROM MEMORY ID 'Z_SKIP_WO'.

  DATA(lo_skip_wo) = /scwm/cl_rf_pick_exc_skip_wo=>get_instance(
                       iv_lgnum = ls_rsrc_mem-lgnum ).

  APPEND LINES OF lo_skip_wo->get_skipped_wos( ) TO gt_skipped_wos.

  PERFORM get_who_list
    TABLES lt_who_remaining
    USING  ls_rsrc_mem.

  LOOP AT gt_skipped_wos ASSIGNING FIELD-SYMBOL(<ls_skip>).
    DELETE lt_who_remaining WHERE who = |{ <ls_skip>-who ALPHA = IN }|.
  ENDLOOP.

  CLEAR: who, ordim_confirm, tt_ordim_confirm.

  IF lt_who_remaining IS INITIAL.
    FREE MEMORY ID 'Z_SKIP_WO'.
    /scwm/cl_rf_bll_srvc=>message(
      EXPORTING
        iv_flg_continue_flow = 'X'
        iv_msgid             = '/SCWM/RF_EN'
        iv_msgno             = '056' ).
    /scwm/cl_rf_bll_srvc=>set_fcode(
      /scwm/cl_rf_bll_srvc=>c_fcode_leave ).
    /scwm/cl_rf_bll_srvc=>set_prmod(
      EXPORTING
        iv_prmod    = /scwm/cl_rf_bll_srvc=>c_prmod_background
        iv_ovr_cust = 'X' ).
    RETURN.
  ENDIF.

  EXPORT gt_skipped_wos TO MEMORY ID 'Z_SKIP_WO'.

  /scwm/cl_rf_bll_srvc=>set_prmod(
  /scwm/cl_rf_bll_srvc=>c_prmod_background ).
  /scwm/cl_rf_bll_srvc=>set_fcode(
  /scwm/cl_rf_bll_srvc=>c_fcode_compl_ltrans ).

ENDFUNCTION.
